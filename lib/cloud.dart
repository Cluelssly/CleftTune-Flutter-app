import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Cloud extends StatefulWidget {
  const Cloud({super.key});

  @override
  State<Cloud> createState() => _CloudState();
}

class _CloudState extends State<Cloud> {
  final _db   = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  bool   _isSyncing    = false;
  bool   _syncSuccess  = false;
  String _lastSynced   = 'Never';
  double _storageLimit = 5120;

  double _translationsMB = 0.0;
  double _correctionsMB  = 0.0;
  double _otherMB        = 0.0;

  int _translationCount = 0;
  int _correctionCount  = 0;

  double get _storageUsed => _translationsMB + _correctionsMB + _otherMB;

  // ─── PALETTE (Sky Blue / Navy) ───────────────────────────────────────────
  static const Color _bg        = Color(0xFFEAF4FB);
  static const Color _surface   = Color(0xFFD6EEFF);
  static const Color _card      = Color(0xFFC2E0F8);
  static const Color _accent    = Color(0xFF0077B6);
  static const Color _accentDim = Color(0xFF005F8E);
  static const Color _textDark  = Color(0xFF0D2B4E);
  static const Color _textSub   = Color(0xFF5A7A96);
  static const Color _label     = Color(0xFF0077B6);

  static const _deviceIdKey = 'clefttune_device_id';

  @override
  void initState() {
    super.initState();
    _loadCloudData();
    _registerDevice();
  }

  Future<String> _getStableDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString(_deviceIdKey);
    if (id == null) {
      id = 'device_${DateTime.now().millisecondsSinceEpoch}';
      await prefs.setString(_deviceIdKey, id);
    }
    return id;
  }

  Future<void> _loadCloudData() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (!doc.exists) return;
      final data = doc.data()!;
      final ts   = data['lastSynced'] as Timestamp?;
      if (mounted) {
        setState(() {
          _translationsMB   = (data['translationsMB']  as num?)?.toDouble() ?? 0.0;
          _correctionsMB    = (data['correctionsMB']   as num?)?.toDouble() ?? 0.0;
          _otherMB          = (data['otherMB']         as num?)?.toDouble() ?? 0.0;
          _translationCount = (data['translationCount'] as num?)?.toInt() ?? 0;
          _correctionCount  = (data['correctionCount']  as num?)?.toInt() ?? 0;
          _lastSynced       = ts != null ? _formatTime(ts.toDate()) : 'Never';
        });
      }
    } catch (_) {}
  }

  Future<void> _registerDevice() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final deviceId = await _getStableDeviceId();
    String platform = 'Mobile Device';
    try {
      platform = Theme.of(context).platform == TargetPlatform.iOS ? 'iOS' : 'Android';
    } catch (_) {}
    await _db
        .collection('users')
        .doc(uid)
        .collection('devices')
        .doc(deviceId)
        .set({
      'name':     'Mobile Device ($platform)',
      'platform': platform,
      'lastSeen': FieldValue.serverTimestamp(),
      'isActive': true,
      'deviceId': deviceId,
    }, SetOptions(merge: true));
  }

  Future<void> _syncNow() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    setState(() { _isSyncing = true; _syncSuccess = false; });

    try {
      final results = await Future.wait([
        _db.collection('translations').where('userId', isEqualTo: uid).get(),
        _db.collection('users').doc(uid).collection('corrections').get(),
        _db.collection('users').doc(uid).collection('userdata').get(),
      ]);

      final translationDocs = results[0].docs;
      final correctionDocs  = results[1].docs;
      final otherDocs       = results[2].docs;

      double tMB = 0, cMB = 0, oMB = 0;
      for (final d in translationDocs) tMB += utf8.encode(d.data().toString()).length;
      for (final d in correctionDocs)  cMB += utf8.encode(d.data().toString()).length;
      for (final d in otherDocs)       oMB += utf8.encode(d.data().toString()).length;

      tMB /= (1024 * 1024);
      cMB /= (1024 * 1024);
      oMB /= (1024 * 1024);

      final now = DateTime.now();

      await _db.collection('users').doc(uid).set({
        'lastSynced':       FieldValue.serverTimestamp(),
        'translationsMB':   tMB,
        'correctionsMB':    cMB,
        'otherMB':          oMB,
        'storageUsedMB':    tMB + cMB + oMB,
        'translationCount': translationDocs.length,
        'correctionCount':  correctionDocs.length,
      }, SetOptions(merge: true));

      await _registerDevice();

      if (mounted) {
        setState(() {
          _isSyncing        = false;
          _syncSuccess      = true;
          _translationsMB   = tMB;
          _correctionsMB    = cMB;
          _otherMB          = oMB;
          _translationCount = translationDocs.length;
          _correctionCount  = correctionDocs.length;
          _lastSynced       = _formatTime(now);
        });
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _syncSuccess = false);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSyncing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: $e', style: const TextStyle(color: _textDark)),
            backgroundColor: Colors.redAccent.shade100,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60)  return 'Just now';
    if (diff.inMinutes < 60)  return '${diff.inMinutes} min ago';
    if (diff.inHours < 24)    return '${diff.inHours} hr ago';
    return '${diff.inDays} day(s) ago';
  }

  String _fmtMB(double mb) {
    if (mb < 0.001) return '0 B';
    if (mb < 1.0)   return '${(mb * 1024).toStringAsFixed(1)} KB';
    if (mb < 1024)  return '${mb.toStringAsFixed(2)} MB';
    return '${(mb / 1024).toStringAsFixed(2)} GB';
  }

  String get _storageLabelGB {
    final usedGB  = _storageUsed / 1024;
    final limitGB = _storageLimit / 1024;
    if (usedGB < 0.01) {
      return '${_fmtMB(_storageUsed)} of ${limitGB.toStringAsFixed(0)} GB used';
    }
    return '${usedGB.toStringAsFixed(2)} GB of ${limitGB.toStringAsFixed(0)} GB used';
  }

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser?.uid;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top Bar ──────────────────────────────────────────────────
              _buildTopBar(),
              const SizedBox(height: 18),

              // ── Page heading ─────────────────────────────────────────────
              Text('Dashboard',
                  style: TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold, color: _textDark)),
              const SizedBox(height: 4),
              Text(
                'Synchronized and secured across all active devices.',
                style: TextStyle(color: _textSub, fontSize: 12, height: 1.5),
              ),
              const SizedBox(height: 18),

              // ── ROW 1: Sync  |  Storage ──────────────────────────────────
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _buildSyncCard()),
                    const SizedBox(width: 12),
                    Expanded(child: _buildStorageCard()),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ── ROW 2: Stats  |  Stats ───────────────────────────────────
              if (_translationCount > 0 || _correctionCount > 0)
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        icon: Icons.translate_rounded,
                        value: '$_translationCount',
                        label: 'Translations',
                        color: _accent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        icon: Icons.tune_rounded,
                        value: '$_correctionCount',
                        label: 'Corrections',
                        color: const Color(0xFF0096C7),
                      ),
                    ),
                  ],
                ),

              if (_translationCount > 0 || _correctionCount > 0)
                const SizedBox(height: 12),

              // ── Storage category breakdown (full-width) ──────────────────
              _buildStorageCategoriesCard(),
              const SizedBox(height: 20),

              // ── Connected Devices heading ────────────────────────────────
              _sectionLabel('Connected Devices'),
              const SizedBox(height: 10),

              // ── ROW 3+: Device cards — two per row ───────────────────────
              if (uid == null)
                Text('Not signed in', style: TextStyle(color: _textSub))
              else
                StreamBuilder<QuerySnapshot>(
                  stream: _db
                      .collection('users')
                      .doc(uid)
                      .collection('devices')
                      .orderBy('lastSeen', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: CircularProgressIndicator(
                              color: _accent, strokeWidth: 2),
                        ),
                      );
                    }

                    final docs = snapshot.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _accent.withOpacity(0.15)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.devices_rounded, color: _textSub, size: 16),
                            const SizedBox(width: 10),
                            Text('No devices yet. Tap Sync Now.',
                                style: TextStyle(color: _textSub, fontSize: 12)),
                          ],
                        ),
                      );
                    }

                    final activeCount = docs
                        .where((d) => (d['isActive'] as bool?) == true)
                        .length;

                    // Build rows of 2 device cards
                    final deviceWidgets = docs.map((doc) {
                      final data     = doc.data() as Map<String, dynamic>;
                      final name     = data['name']     as String? ?? 'Unknown Device';
                      final platform = data['platform'] as String? ?? '';
                      final isActive = data['isActive'] as bool?   ?? false;
                      final ts       = data['lastSeen'] as Timestamp?;
                      final subtitle = isActive
                          ? 'This device'
                          : ts != null
                              ? 'Last seen ${_formatTime(ts.toDate())}'
                              : 'Unknown';
                      return _deviceCard(
                          _deviceIcon(platform), name, subtitle, isActive);
                    }).toList();

                    final rows = <Widget>[];
                    for (int i = 0; i < deviceWidgets.length; i += 2) {
                      rows.add(
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: deviceWidgets[i]),
                            const SizedBox(width: 12),
                            if (i + 1 < deviceWidgets.length)
                              Expanded(child: deviceWidgets[i + 1])
                            else
                              const Expanded(child: SizedBox()),
                          ],
                        ),
                      );
                      rows.add(const SizedBox(height: 10));
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _accent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _accent.withOpacity(0.25)),
                          ),
                          child: Text(
                            '$activeCount Active Session${activeCount == 1 ? '' : 's'}',
                            style: TextStyle(
                                color: _label,
                                fontSize: 11,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(height: 10),
                        ...rows,
                      ],
                    );
                  },
                ),

              const SizedBox(height: 36),
            ],
          ),
        ),
      ),
    );
  }

  // ── Top bar ───────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _accent.withOpacity(0.2)),
            ),
            child: Icon(Icons.arrow_back_ios_new_rounded,
                color: _textDark, size: 16),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cloud Sync',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _textDark)),
            Text('Data & Device Management',
                style: TextStyle(fontSize: 11, color: _textSub)),
          ],
        ),
      ],
    );
  }

  // ── Sync card (left column) ───────────────────────────────────────────────
  Widget _buildSyncCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _syncSuccess
              ? [const Color(0xFFB8EAD8), const Color(0xFFA2DFC8)]
              : [const Color(0xFFBEDDF5), const Color(0xFF9DCFEE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _syncSuccess
              ? Colors.green.withOpacity(0.4)
              : _accent.withOpacity(0.3),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: (_syncSuccess ? Colors.green : _accent).withOpacity(0.10),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status pill
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.45),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _syncSuccess ? Colors.green : _accent,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  _syncSuccess ? 'Up to date' : 'Ready',
                  style: TextStyle(
                    color: _syncSuccess
                        ? Colors.green.shade700
                        : _accentDim,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Headline
          Text(
            _syncSuccess ? 'All Synced!' : "Ready.",
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: _textDark),
          ),
          const SizedBox(height: 3),
          Text(
            'Last: $_lastSynced',
            style: TextStyle(color: _textSub, fontSize: 11),
          ),
          const Spacer(),
          const SizedBox(height: 14),

          // Sync button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _syncSuccess ? Colors.green.shade400 : _accent,
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              icon: _isSyncing
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : Icon(
                      _syncSuccess
                          ? Icons.check_rounded
                          : Icons.sync_rounded,
                      color: Colors.white,
                      size: 15,
                    ),
              label: Text(
                _isSyncing
                    ? 'Syncing...'
                    : _syncSuccess
                        ? 'Synced!'
                        : 'Sync Now',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13),
              ),
              onPressed: _isSyncing ? null : _syncNow,
            ),
          ),
        ],
      ),
    );
  }

  // ── Storage card (right column) ───────────────────────────────────────────
  Widget _buildStorageCard() {
    final pct = (_storageUsed / _storageLimit).clamp(0.0, 1.0);
    final barColor = pct > 0.8 ? Colors.orangeAccent : _accent;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _accent.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: _accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(Icons.cloud_rounded, color: _accent, size: 15),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Storage',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _textDark,
                        fontSize: 13)),
              ),
              if (pct > 0.8)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.orangeAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.orangeAccent.withOpacity(0.4)),
                  ),
                  child: const Text('LOW',
                      style: TextStyle(
                          color: Colors.orangeAccent,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8)),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: _accent.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation(barColor),
              minHeight: 7,
            ),
          ),
          const SizedBox(height: 8),

          // Used label
          Text(
            _storageLabelGB,
            style: TextStyle(color: _textSub, fontSize: 11),
          ),
          const Spacer(),
          const SizedBox(height: 12),

          // Upgrade button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: _accent.withOpacity(0.4)),
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {},
              child: Text('Upgrade Plan',
                  style: TextStyle(
                      color: _label,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Stat mini-card ────────────────────────────────────────────────────────
  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: TextStyle(
                      color: _textDark,
                      fontWeight: FontWeight.bold,
                      fontSize: 18)),
              Text(label,
                  style: TextStyle(color: _textSub, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Storage categories (full-width) ───────────────────────────────────────
  Widget _buildStorageCategoriesCard() {
    final categories = <_StorageCategory>[
      if (_translationsMB > 0)
        _StorageCategory('Translations', _translationsMB,
            const Color(0xFF0077B6), Icons.translate_rounded),
      if (_correctionsMB > 0)
        _StorageCategory('Corrections', _correctionsMB,
            const Color(0xFF0096C7), Icons.tune_rounded),
      if (_otherMB > 0)
        _StorageCategory(
            'Other', _otherMB, const Color(0xFF48CAE4), Icons.folder_rounded),
    ];

    if (categories.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _accent.withOpacity(0.12)),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded, color: _textSub, size: 14),
            const SizedBox(width: 8),
            Text('Tap Sync Now to calculate storage',
                style: TextStyle(color: _textSub, fontSize: 12)),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _accent.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(
            children: [
              Icon(Icons.pie_chart_rounded, color: _accent, size: 15),
              const SizedBox(width: 8),
              Text('Storage Breakdown',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _textDark,
                      fontSize: 13)),
            ],
          ),
          const SizedBox(height: 12),

          // Segmented bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 8,
              child: Row(
                children: categories.map((cat) {
                  final segPct =
                      (cat.sizeMB / _storageUsed).clamp(0.0, 1.0);
                  return Expanded(
                    flex: (segPct * 1000).round(),
                    child: Container(color: cat.color),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Two-column category rows
          ...List.generate(
            (categories.length / 2).ceil(),
            (rowIdx) {
              final a = categories[rowIdx * 2];
              final b = rowIdx * 2 + 1 < categories.length
                  ? categories[rowIdx * 2 + 1]
                  : null;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Expanded(child: _storageCategoryRow(a)),
                    if (b != null) ...[
                      const SizedBox(width: 12),
                      Expanded(child: _storageCategoryRow(b)),
                    ] else
                      const Expanded(child: SizedBox()),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _storageCategoryRow(_StorageCategory cat) {
    final pct =
        _storageUsed > 0 ? (cat.sizeMB / _storageUsed).clamp(0.0, 1.0) : 0.0;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: cat.color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(cat.icon, color: cat.color, size: 12),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(cat.name,
                      style: TextStyle(
                          color: _textDark,
                          fontSize: 11,
                          fontWeight: FontWeight.w500)),
                  Text(_fmtMB(cat.sizeMB),
                      style: TextStyle(
                          color: cat.color,
                          fontSize: 10,
                          fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 3),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: pct,
                  backgroundColor: _accent.withOpacity(0.1),
                  valueColor:
                      AlwaysStoppedAnimation(cat.color.withOpacity(0.7)),
                  minHeight: 3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Device card ───────────────────────────────────────────────────────────
  Widget _deviceCard(
      IconData icon, String title, String subtitle, bool isActive) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? _accent.withOpacity(0.4) : _accent.withOpacity(0.12),
          width: isActive ? 1.2 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isActive
                      ? _accent.withOpacity(0.12)
                      : _accent.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
                child:
                    Icon(icon, color: isActive ? _accent : _textSub, size: 18),
              ),
              const Spacer(),
              if (isActive)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: _accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _accent.withOpacity(0.35)),
                  ),
                  child: Text('Active',
                      style: TextStyle(
                          color: _label,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _textDark,
                  fontSize: 12)),
          const SizedBox(height: 2),
          Text(subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: _textSub, fontSize: 10)),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  IconData _deviceIcon(String platform) {
    final p = platform.toLowerCase();
    if (p.contains('ipad') || p.contains('tablet'))
      return Icons.tablet_rounded;
    if (p.contains('web') || p.contains('chrome') || p.contains('browser'))
      return Icons.web_rounded;
    return Icons.phone_android_rounded;
  }

  Widget _sectionLabel(String text) => Row(
        children: [
          Icon(Icons.devices_rounded, color: _label, size: 15),
          const SizedBox(width: 7),
          Text(text,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _textDark,
                  fontSize: 14)),
        ],
      );
}

// ── Data class ────────────────────────────────────────────────────────────────
class _StorageCategory {
  final String   name;
  final double   sizeMB;
  final Color    color;
  final IconData icon;
  const _StorageCategory(this.name, this.sizeMB, this.color, this.icon);
}