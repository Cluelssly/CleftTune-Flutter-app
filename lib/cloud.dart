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
  double _storageUsed  = 0.0;   // in MB
  double _storageLimit = 5120;  // 5 GB in MB

  // ── colours ──────────────────────────────────────────────────────────────
  static const _bg       = Color(0xFF0F172A);
  static const _cardDark = Color(0xFF1E293B);
  static const _cardMid  = Color(0xFF334155);

  // ── Persistent device ID key (survives logout) ────────────────────────────
  static const _deviceIdKey = 'clefttune_device_id';

  @override
  void initState() {
    super.initState();
    _loadCloudData();
    _registerDevice();
  }

  // ── Get or create a stable device ID stored locally ──────────────────────
  // This ID never changes, even if the user logs out and back in.
  Future<String> _getStableDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString(_deviceIdKey);
    if (id == null) {
      // Generate once and store permanently on this device
      id = 'device_${DateTime.now().millisecondsSinceEpoch}';
      await prefs.setString(_deviceIdKey, id);
    }
    return id;
  }

  // ── Load last-synced time + storage from Firestore ────────────────────────
  // Always reads from Firestore so data persists across logout/login.
  Future<void> _loadCloudData() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      final doc = await _db.collection('users').doc(uid).get();
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

  // ── Register this device in Firestore ─────────────────────────────────────
  // Uses a stable local device ID so the same device entry is reused
  // even after the user logs out and back in.
  Future<void> _registerDevice() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final deviceId = await _getStableDeviceId();

    // Detect platform name
    String platform = 'Mobile Device';
    try {
      platform = Theme.of(context).platform == TargetPlatform.iOS
          ? 'iOS'
          : 'Android';
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
      // deviceId stored so we can identify it later
      'deviceId': deviceId,
    }, SetOptions(merge: true));
  }

  // ── SYNC NOW ──────────────────────────────────────────────────────────────
  Future<void> _syncNow() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    setState(() {
      _isSyncing   = true;
      _syncSuccess = false;
    });

    try {
      // 1. Pull all corrections for this user
      final corrections = await _db
          .collection('users')
          .doc(uid)
          .collection('corrections')
          .get();

      // 2. Pull all translations for this user
      final translations = await _db
          .collection('translations')
          .where('userId', isEqualTo: uid)
          .get();

      // 3. Calculate rough storage used (serialize docs → count bytes)
      double totalBytes = 0;
      for (final doc in corrections.docs) {
        totalBytes += utf8.encode(doc.data().toString()).length;
      }
      for (final doc in translations.docs) {
        totalBytes += utf8.encode(doc.data().toString()).length;
      }
      final totalMB = totalBytes / (1024 * 1024);

      // 4. Save sync metadata back to user doc — persists across logout/login
      final now = DateTime.now();
      await _db.collection('users').doc(uid).set({
        'lastSynced':       FieldValue.serverTimestamp(),
        'storageUsedMB':    totalMB,
        'correctionCount':  corrections.docs.length,
        'translationCount': translations.docs.length,
      }, SetOptions(merge: true));

      // 5. Update device lastSeen
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
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
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
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser?.uid;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: CircleAvatar(
              backgroundColor: Colors.teal,
              child: Icon(Icons.person, color: Colors.white),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            const Text(
              'Dashboard',
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your audio ecosystem is synchronized\nand secured across all active devices.',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 20),

            // ── Sync status card ─────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _cardDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _syncSuccess
                      ? Colors.teal.withOpacity(0.6)
                      : Colors.white10,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _syncSuccess
                          ? Colors.green.withOpacity(0.15)
                          : Colors.white10,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _syncSuccess
                              ? Icons.check_circle_rounded
                              : Icons.cloud_outlined,
                          size: 14,
                          color: _syncSuccess ? Colors.green : Colors.teal,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _syncSuccess
                              ? 'Cloud Sync Status: Up to date'
                              : 'Cloud Sync Status: Ready',
                          style: TextStyle(
                            color: _syncSuccess ? Colors.green : Colors.teal,
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  Text(
                    _syncSuccess ? "All Synced!" : "Everything's Ready.",
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    'Last synced: $_lastSynced',
                    style: const TextStyle(color: Colors.white54),
                  ),

                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        padding: const EdgeInsets.all(14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: _isSyncing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.sync),
                      label: Text(_isSyncing ? 'Syncing...' : 'Sync Now'),
                      onPressed: _isSyncing ? null : _syncNow,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Storage card ─────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _cardDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Cloud Storage',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (_storageUsed / _storageLimit).clamp(0.0, 1.0),
                      backgroundColor: Colors.white12,
                      color: _storageUsed / _storageLimit > 0.8
                          ? Colors.orange
                          : Colors.teal,
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _storageLabelGB,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Upgrade Storage >',
                    style: TextStyle(color: Colors.teal),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Connected devices (real-time from Firestore) ──────────────────
            const Text(
              'Connected Devices',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
            const SizedBox(height: 10),

            if (uid == null)
              const Text('Not signed in',
                  style: TextStyle(color: Colors.white54))
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
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(
                            color: Colors.teal, strokeWidth: 2),
                      ),
                    );
                  }

                  final docs = snapshot.data?.docs ?? [];

                  if (docs.isEmpty) {
                    return const Text(
                      'No devices registered yet. Tap Sync Now.',
                      style: TextStyle(color: Colors.white54, fontSize: 13),
                    );
                  }

                  final activeCount = docs
                      .where((d) => (d['isActive'] as bool?) == true)
                      .length;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$activeCount Active Session${activeCount == 1 ? '' : 's'}',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 13),
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
                            : ts != null
                                ? 'Last seen ${_formatTime(ts.toDate())}'
                                : 'Unknown';

                        return _deviceCard(
                            _deviceIcon(platform), name, subtitle, isActive);
                      }),
                    ],
                  );
                },
              ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ── Device helpers ────────────────────────────────────────────────────────
  IconData _deviceIcon(String platform) {
    final p = platform.toLowerCase();
    if (p.contains('ipad') || p.contains('tablet')) return Icons.tablet;
    if (p.contains('web') || p.contains('chrome') || p.contains('browser')) {
      return Icons.web;
    }
    return Icons.phone_android;
  }

  Widget _deviceCard(
      IconData icon, String title, String subtitle, bool isActive) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardMid,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActive
              ? Colors.teal.withOpacity(0.4)
              : Colors.white10,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: isActive
                ? Colors.teal.withOpacity(0.2)
                : Colors.white10,
            child: Icon(icon,
                color: isActive ? Colors.teal : Colors.white54),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.white)),
                Text(subtitle,
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
          if (isActive)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.teal.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.teal.withOpacity(0.3)),
              ),
              child: const Text('Active',
                  style: TextStyle(color: Colors.teal, fontSize: 11)),
            ),
        ],
      ),
    );
  }
}