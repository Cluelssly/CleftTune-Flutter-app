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
  double _storageUsed  = 0.0;
  double _storageLimit = 5120; // 5 GB in MB

  // ── Design tokens (matches trained_voice_screen) ──────────────────────────
  static const _bg       = Color(0xFF060F1A);
  static const _surface  = Color(0xFF0D1F2D);
  static const _card     = Color(0xFF112233);
  static const _teal     = Color(0xFF0ECFB0);
  static const _tealDeep = Color(0xFF0B5D5E);
  static const _accent   = Color(0xFF1AE5C8);

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
      final doc  = await _db.collection('users').doc(uid).get();
      if (!doc.exists) return;
      final data = doc.data()!;
      final ts   = data['lastSynced'] as Timestamp?;
      final mb   = (data['storageUsedMB'] as num?)?.toDouble() ?? 0.0;
      if (mounted) {
        setState(() {
          _storageUsed = mb;
          _lastSynced  = ts != null ? _formatTime(ts.toDate()) : 'Never';
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
      final corrections  = await _db.collection('users').doc(uid).collection('corrections').get();
      final translations = await _db.collection('translations').where('userId', isEqualTo: uid).get();

      double totalBytes = 0;
      for (final doc in corrections.docs)  totalBytes += utf8.encode(doc.data().toString()).length;
      for (final doc in translations.docs) totalBytes += utf8.encode(doc.data().toString()).length;
      final totalMB = totalBytes / (1024 * 1024);

      final now = DateTime.now();
      await _db.collection('users').doc(uid).set({
        'lastSynced':       FieldValue.serverTimestamp(),
        'storageUsedMB':    totalMB,
        'correctionCount':  corrections.docs.length,
        'translationCount': translations.docs.length,
      }, SetOptions(merge: true));
      await _registerDevice();

      if (mounted) {
        setState(() {
          _isSyncing   = false;
          _syncSuccess = true;
          _storageUsed = totalMB;
          _lastSynced  = _formatTime(now);
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
            content: Text('Sync failed: $e'),
            backgroundColor: Colors.redAccent,
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

  String get _storageLabelGB {
    final usedGB  = _storageUsed / 1024;
    final limitGB = _storageLimit / 1024;
    if (usedGB < 0.01) {
      return '${_storageUsed.toStringAsFixed(1)} MB of ${limitGB.toStringAsFixed(0)} GB used';
    }
    return '${usedGB.toStringAsFixed(2)} GB of ${limitGB.toStringAsFixed(0)} GB used';
  }

  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser?.uid;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top bar ─────────────────────────────────────────────────
              _buildTopBar(),
              const SizedBox(height: 20),

              // ── Header text ─────────────────────────────────────────────
              const Text(
                'Dashboard',
                style: TextStyle(
                  fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Your audio ecosystem is synchronized\nand secured across all active devices.',
                style: TextStyle(color: Colors.white38, fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 22),

              // ── Sync card ────────────────────────────────────────────────
              _buildSyncCard(),
              const SizedBox(height: 16),

              // ── Storage card ─────────────────────────────────────────────
              _buildStorageCard(),
              const SizedBox(height: 22),

              // ── Connected devices ────────────────────────────────────────
              _sectionLabel('Connected Devices'),
              const SizedBox(height: 12),

              if (uid == null)
                const Text('Not signed in', style: TextStyle(color: Colors.white38))
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
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(color: _teal, strokeWidth: 2),
                        ),
                      );
                    }

                    final docs = snapshot.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.devices_rounded, color: Colors.white24, size: 18),
                            SizedBox(width: 10),
                            Text('No devices registered yet. Tap Sync Now.',
                                style: TextStyle(color: Colors.white38, fontSize: 13)),
                          ],
                        ),
                      );
                    }

                    final activeCount = docs
                        .where((d) => (d['isActive'] as bool?) == true)
                        .length;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _teal.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _teal.withOpacity(0.2)),
                          ),
                          child: Text(
                            '$activeCount Active Session${activeCount == 1 ? '' : 's'}',
                            style: const TextStyle(color: _teal, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(height: 10),
                        ...docs.map((doc) {
                          final data     = doc.data() as Map<String, dynamic>;
                          final name     = data['name']     as String? ?? 'Unknown Device';
                          final platform = data['platform'] as String? ?? '';
                          final isActive = data['isActive'] as bool?   ?? false;
                          final ts       = data['lastSeen'] as Timestamp?;
                          final subtitle = isActive
                              ? 'This device'
                              : ts != null ? 'Last seen ${_formatTime(ts.toDate())}' : 'Unknown';
                          return _deviceCard(_deviceIcon(platform), name, subtitle, isActive);
                        }),
                      ],
                    );
                  },
                ),

              const SizedBox(height: 40),
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
              border: Border.all(color: Colors.white12),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Cloud Sync',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
              Text('Data & Device Management',
                  style: TextStyle(fontSize: 11, color: Colors.white38)),
            ],
          ),
        ),
        const CircleAvatar(
          backgroundColor: _tealDeep,
          radius: 18,
          child: Icon(Icons.person_rounded, color: Colors.white, size: 18),
        ),
      ],
    );
  }

  // ── Sync card ─────────────────────────────────────────────────────────────
  Widget _buildSyncCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _syncSuccess
              ? [const Color(0xFF0A5E4A), const Color(0xFF0B6E58)]
              : [const Color(0xFF0A3040), const Color(0xFF0C3A4A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: _syncSuccess ? _teal.withOpacity(0.5) : Colors.white10,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: (_syncSuccess ? _teal : Colors.transparent).withOpacity(0.12),
            blurRadius: 20, offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6, height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _syncSuccess ? Colors.greenAccent : _teal,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _syncSuccess ? 'Cloud Sync: Up to date' : 'Cloud Sync: Ready',
                  style: TextStyle(
                    color: _syncSuccess ? Colors.greenAccent : _teal,
                    fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _syncSuccess ? 'All Synced!' : "Everything's Ready.",
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            'Last synced: $_lastSynced',
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _syncSuccess ? Colors.greenAccent.withOpacity(0.85) : _tealDeep,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              icon: _isSyncing
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Icon(
                      _syncSuccess ? Icons.check_rounded : Icons.sync_rounded,
                      color: Colors.white, size: 18,
                    ),
              label: Text(
                _isSyncing ? 'Syncing...' : _syncSuccess ? 'Synced!' : 'Sync Now',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
              ),
              onPressed: _isSyncing ? null : _syncNow,
            ),
          ),
        ],
      ),
    );
  }

  // ── Storage card ──────────────────────────────────────────────────────────
  Widget _buildStorageCard() {
    final pct = (_storageUsed / _storageLimit).clamp(0.0, 1.0);
    final barColor = pct > 0.8 ? Colors.orangeAccent : _teal;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: _teal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.cloud_rounded, color: _teal, size: 18),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Cloud Storage',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14)),
                    Text('Secure encrypted backup',
                        style: TextStyle(color: Colors.white38, fontSize: 11)),
                  ],
                ),
              ),
              if (pct > 0.8)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orangeAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.orangeAccent.withOpacity(0.3)),
                  ),
                  child: const Text('LOW SPACE',
                      style: TextStyle(color: Colors.orangeAccent, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation(barColor),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_storageLabelGB,
                  style: const TextStyle(color: Colors.white54, fontSize: 12)),
              GestureDetector(
                onTap: () {},
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _teal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _teal.withOpacity(0.25)),
                  ),
                  child: const Text('Upgrade →',
                      style: TextStyle(color: _teal, fontSize: 11, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Device card ───────────────────────────────────────────────────────────
  Widget _deviceCard(IconData icon, String title, String subtitle, bool isActive) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? _teal.withOpacity(0.35) : Colors.white10,
          width: isActive ? 1.2 : 1.0,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isActive ? _teal.withOpacity(0.1) : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: isActive ? _teal : Colors.white38, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(color: Colors.white38, fontSize: 12)),
              ],
            ),
          ),
          if (isActive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _teal.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _teal.withOpacity(0.3)),
              ),
              child: const Text('Active',
                  style: TextStyle(color: _teal, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.4)),
            ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  IconData _deviceIcon(String platform) {
    final p = platform.toLowerCase();
    if (p.contains('ipad') || p.contains('tablet')) return Icons.tablet_rounded;
    if (p.contains('web') || p.contains('chrome') || p.contains('browser')) return Icons.web_rounded;
    return Icons.phone_android_rounded;
  }

  Widget _sectionLabel(String text) => Row(
    children: [
      const Icon(Icons.devices_rounded, color: Color(0xFF0ECFB0), size: 16),
      const SizedBox(width: 8),
      Text(text,
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15)),
    ],
  );
}