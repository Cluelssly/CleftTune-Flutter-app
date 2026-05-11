import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ── Data model ────────────────────────────────────────────────────────────────
class NotifItem {
  final String id;
  final String title;
  final String body;
  final String type;
  final DateTime timestamp;
  bool isRead;

  NotifItem({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.timestamp,
    required this.isRead,
  });

  factory NotifItem.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return NotifItem(
      id:        doc.id,
      title:     d['title'] ?? '',
      body:      d['body']  ?? '',
      type:      d['type']  ?? 'reminder',
      timestamp: (d['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead:    d['isRead'] ?? false,
    );
  }
}

// ── Notification Helper ───────────────────────────────────────────────────────
class NotificationHelper {
  static Future<void> send({
    required String title,
    required String body,
    required String type,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .add({
      'title':     title,
      'body':      body,
      'type':      type,
      'isRead':    false,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> trainingStarted()  => send(
    title: 'Voice Training Started',
    body:  'CleftTune is now learning your voice. This may take a few moments.',
    type:  'training',
  );
  static Future<void> trainingCompleted({double? accuracy}) => send(
    title: 'Training Complete ✅',
    body:  accuracy != null
        ? 'Your voice model improved to ${accuracy.toStringAsFixed(1)}% accuracy.'
        : 'Your AI voice model has been updated successfully.',
    type:  'training',
  );
  static Future<void> trainingFailed() => send(
    title: 'Training Failed',
    body:  'Voice training encountered an issue. Please try again.',
    type:  'training',
  );
  static Future<void> wordDeleted(String word) => send(
    title: 'Word Removed',
    body:  '"$word" has been deleted from your corrected words list.',
    type:  'word_deleted',
  );
  static Future<void> wordAdded(String word) => send(
    title: 'Word Added',
    body:  '"$word" was added to your corrected words list.',
    type:  'word_added',
  );
  static Future<void> wordUpdated(String oldWord, String newWord) => send(
    title: 'Word Updated',
    body:  '"$oldWord" has been updated to "$newWord".',
    type:  'word_added',
  );
  static Future<void> premiumPaymentReminder({int daysLeft = 3}) => send(
    title: 'Payment Due in $daysLeft Days 💳',
    body:  'Your subscription renews in $daysLeft days.',
    type:  'premium_pay',
  );
  static Future<void> premiumActivated({String method = ''}) => send(
    title: 'Premium Activated 🎉',
    body:  method.isNotEmpty ? 'Confirmed via $method. Enjoy all features!' : 'Your Premium subscription is now active!',
    type:  'premium_active',
  );
  static Future<void> premiumRenewed({String method = ''}) => send(
    title: 'Subscription Renewed ✅',
    body:  'CleftTune Premium renewed successfully. Thank you!',
    type:  'premium_active',
  );
  static Future<void> premiumCancelled() => send(
    title: 'Subscription Cancelled',
    body:  'Your Premium subscription has been cancelled.',
    type:  'premium_cancel',
  );
  static Future<void> premiumExpiringSoon() => send(
    title: 'Premium Expiring Soon ⚠️',
    body:  'Your Premium expires tomorrow. Renew now.',
    type:  'premium_pay',
  );
  static Future<void> appUpdateAvailable({required String version, String? changelog}) => send(
    title: 'Update Available — v$version 🚀',
    body:  changelog ?? 'A new version of CleftTune is ready.',
    type:  'app_update',
  );
  static Future<void> appUpdatedSuccess({required String version}) => send(
    title: 'App Updated to v$version',
    body:  'CleftTune updated successfully. Enjoy the new features!',
    type:  'app_update',
  );
  static Future<void> syncCompleted() => send(
    title: 'Sync Complete',
    body:  'Your data has been synced to the cloud successfully.',
    type:  'sync',
  );
  static Future<void> cloudBackupDone() => send(
    title: 'Cloud Backup Done ☁️',
    body:  'Your voice model and history have been backed up securely.',
    type:  'cloud',
  );
}

// ── Screen ────────────────────────────────────────────────────────────────────
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  // ── Design tokens (matches trained_voice_screen) ────────────────────────
  static const _bg      = Color(0xFF060F1A);
  static const _surface = Color(0xFF0D1F2D);
  static const _card    = Color(0xFF112233);
  static const _teal    = Color(0xFF0ECFB0);
  static const _tealDeep = Color(0xFF0B5D5E);

  List<NotifItem> _items   = [];
  bool            _loading = true;
  String?         _error;
  String?         _filter;

  static const _filters = [
    ['All',      null],
    ['Training', 'training'],
    ['Words',    'word'],
    ['Premium',  'premium'],
    ['Updates',  'app_update'],
    ['Sync',     'sync'],
  ];

  @override
  void initState() {
    super.initState();
    _listen();
  }

  void _listen() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) { setState(() => _loading = false); return; }

    FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen(
          (snapshot) {
            debugPrint('📬 Notifications received: ${snapshot.docs.length}');
            setState(() {
              _items   = snapshot.docs.map(NotifItem.fromFirestore).toList();
              _loading = false;
              _error   = null;
            });
          },
          onError: (e) {
            debugPrint('❌ Firestore notifications error: $e');
            setState(() { _loading = false; _error = e.toString(); });
          },
        );
  }

  List<NotifItem> get _visible => _filter == null
      ? _items
      : _items.where((n) => n.type.startsWith(_filter!)).toList();

  int get _unread => _items.where((n) => !n.isRead).length;

  Future<void> _markRead(NotifItem item) async {
    if (item.isRead) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance
        .collection('users').doc(uid).collection('notifications').doc(item.id)
        .update({'isRead': true});
  }

  Future<void> _markAllRead() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final n in _items.where((n) => !n.isRead)) {
      batch.update(
        FirebaseFirestore.instance
            .collection('users').doc(uid).collection('notifications').doc(n.id),
        {'isRead': true},
      );
    }
    await batch.commit();
  }

  Future<void> _delete(NotifItem item) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance
        .collection('users').doc(uid).collection('notifications').doc(item.id)
        .delete();
  }

  Future<void> _clearAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Clear all notifications?',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
        content: const Text('All notifications will be permanently deleted.',
            style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final n in _items) {
      batch.delete(FirebaseFirestore.instance
          .collection('users').doc(uid).collection('notifications').doc(n.id));
    }
    await batch.commit();
  }

  String _time(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m ${dt.hour >= 12 ? "PM" : "AM"}';
  }

  String _dayLabel(DateTime dt) {
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d     = DateTime(dt.year, dt.month, dt.day);
    if (d == today) return 'TODAY';
    if (d == today.subtract(const Duration(days: 1))) return 'YESTERDAY';
    const mo = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${mo[dt.month]} ${dt.day}, ${dt.year}';
  }

  Map<String, List<NotifItem>> get _grouped {
    final m = <String, List<NotifItem>>{};
    for (final n in _visible) {
      m.putIfAbsent(_dayLabel(n.timestamp), () => []).add(n);
    }
    return m;
  }

  IconData _icon(String t) {
    switch (t) {
      case 'training':       return Icons.mic_rounded;
      case 'word_deleted':   return Icons.delete_rounded;
      case 'word_added':     return Icons.spellcheck_rounded;
      case 'premium_active': return Icons.star_rounded;
      case 'premium_pay':    return Icons.credit_card_rounded;
      case 'premium_cancel': return Icons.cancel_rounded;
      case 'app_update':     return Icons.system_update_rounded;
      case 'sync':           return Icons.sync_rounded;
      case 'cloud':          return Icons.cloud_done_rounded;
      default:               return Icons.notifications_rounded;
    }
  }

  Color _accentColor(String t) {
    switch (t) {
      case 'training':
      case 'word_added':
      case 'sync':           return const Color(0xFF0ECFB0);  // teal
      case 'word_deleted':
      case 'premium_cancel': return const Color(0xFFFF6B6B);  // red
      case 'premium_active':
      case 'premium_pay':    return const Color(0xFFFFB74D);  // amber
      case 'app_update':
      case 'cloud':          return const Color(0xFF64B5F6);  // blue
      default:               return const Color(0xFFFF8A65);  // orange
    }
  }

  Color _iconBg(String t) {
    switch (t) {
      case 'training':
      case 'word_added':
      case 'sync':           return const Color(0xFF0B2A20);
      case 'word_deleted':
      case 'premium_cancel': return const Color(0xFF2A0C0C);
      case 'premium_active':
      case 'premium_pay':    return const Color(0xFF2A1C06);
      case 'app_update':
      case 'cloud':          return const Color(0xFF081828);
      default:               return const Color(0xFF241008);
    }
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        children: [
          _buildHeader(),
          _buildFilterRow(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _teal, strokeWidth: 2))
                : _error != null
                    ? _buildErrorView()
                    : _visible.isEmpty
                        ? _buildEmpty()
                        : _buildList(),
          ),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      color: _surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: top),
          SizedBox(
            height: 64,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: [
                  // Back button
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                        color: _card,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 15),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Notifications',
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                        Text('Activity & alerts',
                            style: TextStyle(color: Colors.white38, fontSize: 11)),
                      ],
                    ),
                  ),
                  if (_unread > 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _teal,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('$_unread new',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _markAllRead,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _teal.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _teal.withOpacity(0.25)),
                        ),
                        child: const Text('Read all',
                            style: TextStyle(color: _teal, fontSize: 11, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (_items.isNotEmpty)
                    GestureDetector(
                      onTap: _clearAll,
                      child: Container(
                        width: 38, height: 38,
                        decoration: BoxDecoration(
                          color: _card,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: const Icon(Icons.delete_outline_rounded, color: Colors.white38, size: 18),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const Divider(color: Colors.white10, thickness: 0.8, height: 0.8),
        ],
      ),
    );
  }

  // ── Filter row ────────────────────────────────────────────────────────────
  Widget _buildFilterRow() {
    return Container(
      height: 52,
      color: _surface,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final label    = _filters[i][0] as String;
          final val      = _filters[i][1] as String?;
          final selected = _filter == val;
          return GestureDetector(
            onTap: () => setState(() => _filter = val),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: selected ? _teal.withOpacity(0.15) : _card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected ? _teal.withOpacity(0.5) : Colors.white12,
                  width: selected ? 1.2 : 1.0,
                ),
              ),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected ? _teal : Colors.white38,
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Error view ────────────────────────────────────────────────────────────
  Widget _buildErrorView() => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: Colors.redAccent.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.redAccent.withOpacity(0.3), width: 1.5),
            ),
            child: const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 32),
          ),
          const SizedBox(height: 18),
          const Text('Could not load notifications',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text(
            'Check your Firestore security rules\nallow reads for authenticated users.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () {
              setState(() { _loading = true; _error = null; _items = []; });
              _listen();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              decoration: BoxDecoration(
                color: _teal.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _teal.withOpacity(0.3)),
              ),
              child: const Text('Retry',
                  style: TextStyle(color: _teal, fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    ),
  );

  // ── Empty state ───────────────────────────────────────────────────────────
  Widget _buildEmpty() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            color: _teal.withOpacity(0.08),
            shape: BoxShape.circle,
            border: Border.all(color: _teal.withOpacity(0.2), width: 1.5),
          ),
          child: const Icon(Icons.notifications_off_outlined, color: _teal, size: 30),
        ),
        const SizedBox(height: 18),
        const Text('No notifications',
            style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        const Text("You're all caught up!",
            style: TextStyle(color: Colors.white38, fontSize: 14)),
      ],
    ),
  );

  // ── List ──────────────────────────────────────────────────────────────────
  Widget _buildList() {
    final grouped  = _grouped;
    final sections = grouped.keys.toList();
    return ListView.builder(
      padding: const EdgeInsets.only(top: 10, bottom: 40),
      itemCount: sections.length,
      itemBuilder: (_, si) {
        final label = sections[si];
        final items = grouped[label]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _dayHeader(label, showMark: label == 'TODAY' && _unread > 0),
            ...items.map(_dismissible),
          ],
        );
      },
    );
  }

  Widget _dayHeader(String label, {bool showMark = false}) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(
              color: Colors.white24, fontSize: 10,
              fontWeight: FontWeight.w700, letterSpacing: 1.5,
            )),
        if (showMark)
          GestureDetector(
            onTap: _markAllRead,
            child: const Text('Mark all read',
                style: TextStyle(color: _teal, fontSize: 11, fontWeight: FontWeight.w600)),
          ),
      ],
    ),
  );

  Widget _dismissible(NotifItem item) => Dismissible(
    key: Key(item.id),
    direction: DismissDirection.endToStart,
    onDismissed: (_) => _delete(item),
    background: Container(
      alignment: Alignment.centerRight,
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 10),
      padding: const EdgeInsets.only(right: 24),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.85),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Icon(Icons.delete_rounded, color: Colors.white, size: 22),
    ),
    child: _buildCard(item),
  );

  // ── Notification card ─────────────────────────────────────────────────────
  Widget _buildCard(NotifItem item) {
    final accent = _accentColor(item.type);
    return GestureDetector(
      onTap: () => _markRead(item),
      child: Container(
        margin: const EdgeInsets.fromLTRB(18, 0, 18, 10),
        decoration: BoxDecoration(
          color: item.isRead ? _surface : _card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: item.isRead ? Colors.white10 : accent.withOpacity(0.2),
            width: item.isRead ? 1.0 : 1.2,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left accent bar (unread only)
                if (!item.isRead)
                  Container(width: 3, color: accent),

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Icon container
                        Container(
                          width: 42, height: 42,
                          decoration: BoxDecoration(
                            color: _iconBg(item.type),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: accent.withOpacity(0.15)),
                          ),
                          child: Icon(_icon(item.type), color: accent, size: 19),
                        ),
                        const SizedBox(width: 12),

                        // Content
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: TextStyle(
                                  color: item.isRead ? Colors.white54 : Colors.white,
                                  fontSize: 13,
                                  fontWeight: item.isRead ? FontWeight.w500 : FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                item.body,
                                style: const TextStyle(
                                  color: Colors.white38, fontSize: 12, height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Timestamp + unread dot
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(_time(item.timestamp),
                                style: const TextStyle(color: Colors.white24, fontSize: 10)),
                            const SizedBox(height: 8),
                            AnimatedOpacity(
                              duration: const Duration(milliseconds: 300),
                              opacity: item.isRead ? 0 : 1,
                              child: Container(
                                width: 7, height: 7,
                                decoration: BoxDecoration(
                                  color: accent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}