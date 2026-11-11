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

  bool   _checking   = true;   // reading the saved "already synced" flag
  bool   _isSyncing  = false;
  bool   _syncFailed = false;
  bool   _synced     = false;
  String _lastSynced = '';

  static const double _storageLimit = 5120; // MB (5 GB)

  double _translationsMB = 0.0;
  double _correctionsMB  = 0.0;
  double _otherMB        = 0.0;
  int    _translationCount = 0;
  int    _correctionCount  = 0;

  double get _storageUsed => _translationsMB + _correctionsMB + _otherMB;

  // ─── PALETTE (Sky Blue / Navy) ───────────────────────────────────────────
  static const Color _bg       = Color(0xFFEAF4FB);
  static const Color _surface  = Color(0xFFD6EEFF);
  static const Color _accent   = Color(0xFF0077B6);
  static const Color _accent2  = Color(0xFF0096C7);
  static const Color _accent3  = Color(0xFF48CAE4);
  static const Color _textDark = Color(0xFF0D2B4E);
  static const Color _textSub  = Color(0xFF5A7A96);

  static const _deviceIdKey = 'clefttune_device_id';

  // Saved per user, so once this device has synced it never syncs again.
  String _syncedKey(String uid) => 'clefttune_synced_$uid';

  @override
  void initState() {
    super.initState();
    _init();
  }

  // ── Startup: show saved details, only sync if it has never synced ─────────
  Future<void> _init() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _checking = false);
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final alreadySynced = prefs.getBool(_syncedKey(uid)) ?? false;

    await _loadCloudData(); // just reads saved numbers, does not sync

    if (alreadySynced) {
      if (mounted) setState(() { _synced = true; _checking = false; });
      return; // do NOT sync again
    }

    if (mounted) setState(() => _checking = false);
    await _syncNow(); // first time only
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
          _translationsMB   = (data['translationsMB']   as num?)?.toDouble() ?? 0.0;
          _correctionsMB    = (data['correctionsMB']    as num?)?.toDouble() ?? 0.0;
          _otherMB          = (data['otherMB']          as num?)?.toDouble() ?? 0.0;
          _translationCount = (data['translationCount'] as num?)?.toInt() ?? 0;
          _correctionCount  = (data['correctionCount']  as num?)?.toInt() ?? 0;
          _lastSynced       = ts != null ? _formatTime(ts.toDate()) : '';
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
    setState(() { _isSyncing = true; _syncFailed = false; });

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

      // Remember it, so reopening the screen never syncs again.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_syncedKey(uid), true);

      if (mounted) {
        setState(() {
          _isSyncing        = false;
          _synced           = true;
          _translationsMB   = tMB;
          _correctionsMB    = cMB;
          _otherMB          = oMB;
          _translationCount = translationDocs.length;
          _correctionCount  = correctionDocs.length;
          _lastSynced       = _formatTime(DateTime.now());
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() { _isSyncing = false; _syncFailed = true; });
      }
    }
  }

  // ── Formatting helpers ────────────────────────────────────────────────────
  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24)   return '${diff.inHours} hr ago';
    return '${diff.inDays} day(s) ago';
  }

  String _fmtMB(double mb) {
    if (mb < 0.001) return '0 B';
    if (mb < 1.0)   return '${(mb * 1024).toStringAsFixed(1)} KB';
    if (mb < 1024)  return '${mb.toStringAsFixed(2)} MB';
    return '${(mb / 1024).toStringAsFixed(2)} GB';
  }

  IconData _deviceIcon(String platform) {
    final p = platform.toLowerCase();
    if (p.contains('ipad') || p.contains('tablet')) return Icons.tablet_rounded;
    if (p.contains('web') || p.contains('chrome') || p.contains('browser')) {
      return Icons.web_rounded;
    }
    return Icons.phone_android_rounded;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser?.uid;
    final showDetails = uid != null && _synced && !_isSyncing && !_syncFailed;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _header(),
                  const SizedBox(height: 18),
                  _statusCard(uid != null),
                  if (showDetails) ...[
                    const SizedBox(height: 24),
                    _sectionTitle('Overview', Icons.dashboard_rounded),
                    const SizedBox(height: 10),
                    _overviewRow(),
                    const SizedBox(height: 24),
                    _sectionTitle('Storage', Icons.cloud_rounded),
                    const SizedBox(height: 10),
                    _storageCard(),
                    const SizedBox(height: 24),
                    _sectionTitle('Connected Devices', Icons.devices_rounded),
                    const SizedBox(height: 10),
                    _devicesSection(uid),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _header() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Cloud Sync',
            style: TextStyle(
                fontSize: 24, fontWeight: FontWeight.bold, color: _textDark)),
        SizedBox(height: 4),
        Text('Your data and connected devices.',
            style: TextStyle(color: _textSub, fontSize: 12, height: 1.5)),
      ],
    );
  }

  // ── Status box (no sync button) ───────────────────────────────────────────
  Widget _statusCard(bool signedIn) {
    final bool done = signedIn && _synced && !_isSyncing && !_syncFailed;

    final Color tone = _syncFailed
        ? Colors.redAccent
        : done
            ? Colors.green.shade600
            : _accent;

    String title;
    String subtitle;
    if (_checking) {
      title = 'Checking...';
      subtitle = '';
    } else if (!signedIn) {
      title = 'Not signed in';
      subtitle = 'Sign in to sync your data.';
    } else if (_isSyncing) {
      title = 'Syncing...';
      subtitle = 'Please wait a moment.';
    } else if (_syncFailed) {
      title = 'Sync failed';
      subtitle = 'Tap here to try again.';
    } else if (done) {
      title = 'Already synced';
      subtitle = _lastSynced.isEmpty ? '' : 'Last synced: $_lastSynced';
    } else {
      title = 'Getting ready...';
      subtitle = '';
    }

    return GestureDetector(
      // Only works after a failed first sync.
      onTap: (_syncFailed && !_isSyncing) ? _syncNow : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: tone.withOpacity(0.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: tone.withOpacity(0.35), width: 1.2),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: tone.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: (_isSyncing || _checking)
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: tone, strokeWidth: 2.5),
                      )
                    : Icon(
                        _syncFailed
                            ? Icons.error_outline_rounded
                            : Icons.cloud_done_rounded,
                        color: tone,
                        size: 26,
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: _textDark)),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(subtitle,
                        style: const TextStyle(color: _textSub, fontSize: 12)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Section title ─────────────────────────────────────────────────────────
  Widget _sectionTitle(String text, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: _accent, size: 16),
        const SizedBox(width: 8),
        Text(text,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: _textDark,
                fontSize: 15)),
      ],
    );
  }

  // ── Overview: three compact stats ─────────────────────────────────────────
  Widget _overviewRow() {
    return Row(
      children: [
        Expanded(
          child: _statTile(Icons.translate_rounded, '$_translationCount',
              'Translations', _accent),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statTile(Icons.tune_rounded, '$_correctionCount',
              'Corrections', _accent2),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statTile(Icons.cloud_rounded, _fmtMB(_storageUsed),
              'Storage used', _accent3),
        ),
      ],
    );
  }

  Widget _statTile(IconData icon, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value,
                style: const TextStyle(
                    color: _textDark,
                    fontWeight: FontWeight.bold,
                    fontSize: 17)),
          ),
          const SizedBox(height: 2),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _textSub, fontSize: 11)),
        ],
      ),
    );
  }

  // ── Storage: usage bar + breakdown in one card ────────────────────────────
  Widget _storageCard() {
    final pct = (_storageUsed / _storageLimit).clamp(0.0, 1.0);
    final barColor = pct > 0.8 ? Colors.orangeAccent : _accent;

    final categories = <_StorageCategory>[
      if (_translationsMB > 0)
        _StorageCategory('Translations', _translationsMB, _accent,
            Icons.translate_rounded),
      if (_correctionsMB > 0)
        _StorageCategory(
            'Corrections', _correctionsMB, _accent2, Icons.tune_rounded),
      if (_otherMB > 0)
        _StorageCategory('Other', _otherMB, _accent3, Icons.folder_rounded),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _accent.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${_fmtMB(_storageUsed)} used',
                  style: const TextStyle(
                      color: _textDark,
                      fontWeight: FontWeight.w700,
                      fontSize: 14)),
              Text('of ${(_storageLimit / 1024).toStringAsFixed(0)} GB',
                  style: const TextStyle(color: _textSub, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: _accent.withOpacity(0.12),
              valueColor: AlwaysStoppedAnimation(barColor),
            ),
          ),
          if (categories.isNotEmpty) ...[
            const SizedBox(height: 16),
            Divider(height: 1, color: _accent.withOpacity(0.15)),
            const SizedBox(height: 14),
            for (int i = 0; i < categories.length; i++) ...[
              _categoryRow(categories[i]),
              if (i != categories.length - 1) const SizedBox(height: 12),
            ],
          ],
        ],
      ),
    );
  }

  Widget _categoryRow(_StorageCategory cat) {
    final share =
        _storageUsed > 0 ? (cat.sizeMB / _storageUsed).clamp(0.0, 1.0) : 0.0;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: cat.color.withOpacity(0.14),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(cat.icon, color: cat.color, size: 14),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(cat.name,
                      style: const TextStyle(
                          color: _textDark,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                  Text('${_fmtMB(cat.sizeMB)} · ${(share * 100).round()}%',
                      style: TextStyle(
                          color: cat.color,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: share,
                  minHeight: 4,
                  backgroundColor: _accent.withOpacity(0.10),
                  valueColor: AlwaysStoppedAnimation(cat.color),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Devices: one clean list ───────────────────────────────────────────────
  Widget _devicesSection(String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('users')
          .doc(uid)
          .collection('devices')
          .orderBy('lastSeen', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(color: _accent, strokeWidth: 2),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _accent.withOpacity(0.15)),
            ),
            child: const Row(
              children: [
                Icon(Icons.devices_rounded, color: _textSub, size: 16),
                SizedBox(width: 10),
                Text('No devices yet.',
                    style: TextStyle(color: _textSub, fontSize: 12)),
              ],
            ),
          );
        }

        final activeCount = docs
            .where((d) =>
                ((d.data() as Map<String, dynamic>)['isActive'] as bool?) ==
                true)
            .length;

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _accent.withOpacity(0.15)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _accent.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _accent.withOpacity(0.25)),
                      ),
                      child: Text(
                        '$activeCount active session${activeCount == 1 ? '' : 's'}',
                        style: const TextStyle(
                            color: _accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              for (int i = 0; i < docs.length; i++) ...[
                Divider(height: 1, color: _accent.withOpacity(0.12)),
                _deviceTile(docs[i].data() as Map<String, dynamic>),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _deviceTile(Map<String, dynamic> data) {
    final name     = data['name']     as String? ?? 'Unknown Device';
    final platform = data['platform'] as String? ?? '';
    final isActive = data['isActive'] as bool?   ?? false;
    final ts       = data['lastSeen'] as Timestamp?;
    final subtitle = isActive
        ? 'This device'
        : ts != null
            ? 'Last seen ${_formatTime(ts.toDate())}'
            : 'Unknown';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: _accent.withOpacity(isActive ? 0.14 : 0.06),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(_deviceIcon(platform),
                color: isActive ? _accent : _textSub, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _textDark,
                        fontSize: 13)),
                const SizedBox(height: 2),
                Text(subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _textSub, fontSize: 11)),
              ],
            ),
          ),
          if (isActive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _accent.withOpacity(0.35)),
              ),
              child: const Text('Active',
                  style: TextStyle(
                      color: _accent,
                      fontSize: 10,
                      fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }
}

// ── Data class ────────────────────────────────────────────────────────────────
class _StorageCategory {
  final String   name;
  final double   sizeMB;
  final Color    color;
  final IconData icon;
  const _StorageCategory(this.name, this.sizeMB, this.color, this.icon);
}