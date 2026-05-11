import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ── Data model ───────────────────────────────────────────────────────────────
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
      id: doc.id,
      title: d['title'] ?? '',
      body: d['body'] ?? '',
      type: d['type'] ?? 'reminder',
      timestamp: (d['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: d['isRead'] ?? false,
    );
  }
}

// ── Notification Helper ──────────────────────────────────────────────────────
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
      'title': title,
      'body': body,
      'type': type,
      'isRead': false,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> trainingStarted() => send(
        title: 'Voice Training Started',
        body: 'CleftTune is now learning your voice. This may take a few moments.',
        type: 'training',
      );
  static Future<void> trainingCompleted({double? accuracy}) => send(
        title: 'Training Complete ✅',
        body: accuracy != null
            ? 'Your voice model improved to ${accuracy.toStringAsFixed(1)}% accuracy.'
            : 'Your AI voice model has been updated successfully.',
        type: 'training',
      );
  static Future<void> trainingFailed() => send(
        title: 'Training Failed',
        body: 'Voice training encountered an issue. Please try again.',
        type: 'training',
      );
  static Future<void> wordDeleted(String word) => send(
        title: 'Word Removed',
        body: '"$word" has been deleted from your corrected words list.',
        type: 'word_deleted',
      );
  static Future<void> wordAdded(String word) => send(
        title: 'Word Added',
        body: '"$word" was added to your corrected words list.',
        type: 'word_added',
      );
  static Future<void> wordUpdated(String oldWord, String newWord) => send(
        title: 'Word Updated',
        body: '"$oldWord" has been updated to "$newWord".',
        type: 'word_added',
      );
  static Future<void> premiumPaymentReminder({int daysLeft = 3}) => send(
        title: 'Payment Due in $daysLeft Days 💳',
        body: 'Your subscription renews in $daysLeft days.',
        type: 'premium_pay',
      );
  static Future<void> premiumActivated({String method = ''}) => send(
        title: 'Premium Activated 🎉',
        body: method.isNotEmpty
            ? 'Confirmed via $method. Enjoy all features!'
            : 'Your Premium subscription is now active!',
        type: 'premium_active',
      );
  static Future<void> premiumRenewed({String method = ''}) => send(
        title: 'Subscription Renewed ✅',
        body: 'CleftTune Premium renewed successfully. Thank you!',
        type: 'premium_active',
      );
  static Future<void> premiumCancelled() => send(
        title: 'Subscription Cancelled',
        body: 'Your Premium subscription has been cancelled.',
        type: 'premium_cancel',
      );
  static Future<void> premiumExpiringSoon() => send(
        title: 'Premium Expiring Soon ⚠️',
        body: 'Your Premium expires tomorrow. Renew now.',
        type: 'premium_pay',
      );
  static Future<void> appUpdateAvailable(
          {required String version, String? changelog}) =>
      send(
        title: 'Update Available — v$version 🚀',
        body: changelog ?? 'A new version of CleftTune is ready.',
        type: 'app_update',
      );
  static Future<void> appUpdatedSuccess({required String version}) => send(
        title: 'App Updated to v$version',
        body: 'CleftTune updated successfully. Enjoy the new features!',
        type: 'app_update',
      );
  static Future<void> syncCompleted() => send(
        title: 'Sync Complete',
        body: 'Your data has been synced to the cloud successfully.',
        type: 'sync',
      );
  static Future<void> cloudBackupDone() => send(
        title: 'Cloud Backup Done ☁️',
        body: 'Your voice model and history have been backed up securely.',
        type: 'cloud',
      );
}

// ── Screen ───────────────────────────────────────────────────────────────────
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  // Hard-coded fully-opaque colors — nothing can be overridden by inheritance
  static const Color kBg         = Color(0xFF0D1B2A);
  static const Color kHeader     = Color(0xFF0B2420);
  static const Color kTeal       = Color(0xFF1DB87F);
  static const Color kCardUnread = Color(0xFF112B22);
  static const Color kCardRead   = Color(0xFF0F1E28);
  static const Color kBorder     = Color(0xFF1F3C35);

  List<NotifItem> _items = [];
  bool _loading = true;
  String? _filter;

  static const _filters = [
    ['All', null],
    ['Training', 'training'],
    ['Words', 'word'],
    ['Premium', 'premium'],
    ['Updates', 'app_update'],
    ['Sync', 'sync'],
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
        .collection('users').doc(uid).collection('notifications')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((s) => setState(() {
              _items = s.docs.map(NotifItem.fromFirestore).toList();
              _loading = false;
            }));
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
        .collection('users').doc(uid).collection('notifications')
        .doc(item.id).update({'isRead': true});
  }

  Future<void> _markAllRead() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final b = FirebaseFirestore.instance.batch();
    for (final n in _items.where((n) => !n.isRead)) {
      b.update(FirebaseFirestore.instance
          .collection('users').doc(uid).collection('notifications').doc(n.id),
          {'isRead': true});
    }
    await b.commit();
  }

  Future<void> _delete(NotifItem item) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance
        .collection('users').doc(uid).collection('notifications')
        .doc(item.id).delete();
  }

  Future<void> _clearAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0C2020),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Clear all?',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
        content: const Text('All notifications will be deleted.',
            style: TextStyle(color: Color(0xFFAAC8BC), fontSize: 13)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFFAAC8BC)))),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade800),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Clear', style: TextStyle(color: Colors.white))),
        ],
      ),
    );
    if (ok != true) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final b = FirebaseFirestore.instance.batch();
    for (final n in _items) {
      b.delete(FirebaseFirestore.instance
          .collection('users').doc(uid).collection('notifications').doc(n.id));
    }
    await b.commit();
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
    const mo = ['','Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${mo[dt.month]} ${dt.day}, ${dt.year}';
  }

  Map<String, List<NotifItem>> get _grouped {
    final m = <String, List<NotifItem>>{};
    for (final n in _visible) m.putIfAbsent(_dayLabel(n.timestamp), () => []).add(n);
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

  Color _iconColor(String t) {
    switch (t) {
      case 'training':
      case 'word_added':
      case 'sync':           return const Color(0xFF2FD49A);
      case 'word_deleted':
      case 'premium_cancel': return const Color(0xFFFF6B6B);
      case 'premium_active':
      case 'premium_pay':    return const Color(0xFFFFB74D);
      case 'app_update':
      case 'cloud':          return const Color(0xFF64B5F6);
      default:               return const Color(0xFFFF8A65);
    }
  }

  Color _iconBg(String t) {
    switch (t) {
      case 'training':
      case 'word_added':
      case 'sync':           return const Color(0xFF0B3020);
      case 'word_deleted':
      case 'premium_cancel': return const Color(0xFF350C0C);
      case 'premium_active':
      case 'premium_pay':    return const Color(0xFF332808);
      case 'app_update':
      case 'cloud':          return const Color(0xFF081A35);
      default:               return const Color(0xFF2A1508);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // CRITICAL: Wrap entire screen in DefaultTextStyle with explicit white.
    // This resets any inherited text color from a parent Theme that may be
    // transparent or matching the background, which caused invisible text.
    return DefaultTextStyle(
      style: const TextStyle(
        color: Colors.white,
        decoration: TextDecoration.none,
        fontFamily: 'Roboto',
      ),
      child: Scaffold(
        backgroundColor: kBg,
        body: Column(
          children: [
            _header(context),
            _filterRow(),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF1DB87F), strokeWidth: 2))
                  : _visible.isEmpty
                      ? _empty()
                      : _list(),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _header(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      color: kHeader,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: top),
          SizedBox(
            height: 60,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // Back
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0x301DB87F),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0x551DB87F)),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Color(0xFF1DB87F), size: 15),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Title — explicit RichText to guarantee visibility
                  const Expanded(
                    child: Text(
                      'Notifications',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                  // Unread badge
                  if (_unread > 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: kTeal,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$_unread new',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _markAllRead,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0x301DB87F),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0x551DB87F)),
                        ),
                        child: const Text(
                          'Read all',
                          style: TextStyle(
                            color: Color(0xFF1DB87F),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  // Delete all
                  if (_items.isNotEmpty)
                    GestureDetector(
                      onTap: _clearAll,
                      child: Container(
                        width: 38, height: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFF102020),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF244040)),
                        ),
                        child: const Icon(Icons.delete_outline_rounded,
                            color: Color(0xFFAAC8BC), size: 18),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const Divider(color: Color(0xFF1F3C35), thickness: 0.8, height: 0.8),
        ],
      ),
    );
  }

  // ── Filter row ────────────────────────────────────────────────────────────
  Widget _filterRow() {
    return Container(
      height: 48,
      color: kHeader,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: selected ? kTeal : const Color(0xFF102020),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected ? kTeal : const Color(0xFF244040),
                ),
              ),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : const Color(0xFFAAC8BC),
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Empty ─────────────────────────────────────────────────────────────────
  Widget _empty() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: const Color(0x301DB87F),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0x551DB87F), width: 1.5),
              ),
              child: const Icon(Icons.notifications_off_outlined,
                  color: Color(0xFF1DB87F), size: 32),
            ),
            const SizedBox(height: 18),
            const Text('No notifications',
                style: TextStyle(
                    color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700,
                    decoration: TextDecoration.none)),
            const SizedBox(height: 6),
            const Text("You're all caught up!",
                style: TextStyle(
                    color: Color(0xFFAAC8BC), fontSize: 14,
                    decoration: TextDecoration.none)),
          ],
        ),
      );

  // ── List ──────────────────────────────────────────────────────────────────
  Widget _list() {
    final grouped  = _grouped;
    final sections = grouped.keys.toList();
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 32),
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
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(
                    color: Color(0xFF5E8070),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                    decoration: TextDecoration.none)),
            if (showMark)
              GestureDetector(
                onTap: _markAllRead,
                child: const Text('Mark all as read',
                    style: TextStyle(
                        color: Color(0xFF1DB87F),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.none)),
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
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          padding: const EdgeInsets.only(right: 24),
          decoration: BoxDecoration(
            color: Colors.red.shade900,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.delete_rounded, color: Colors.white, size: 24),
        ),
        child: _card(item),
      );

  // ── Card ──────────────────────────────────────────────────────────────────
  Widget _card(NotifItem item) {
    final accent = _iconColor(item.type);
    return GestureDetector(
      onTap: () => _markRead(item),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          // Fully opaque card backgrounds — the REAL fix
          color: item.isRead ? kCardRead : kCardUnread,
          borderRadius: BorderRadius.circular(16),
          border: Border(
            left: BorderSide(
              color: item.isRead ? Colors.transparent : accent,
              width: 3,
            ),
            top:    const BorderSide(color: kBorder, width: 0.8),
            right:  const BorderSide(color: kBorder, width: 0.8),
            bottom: const BorderSide(color: kBorder, width: 0.8),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon bubble
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: _iconBg(item.type),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_icon(item.type), color: accent, size: 20),
            ),
            const SizedBox(width: 12),
            // Text — wrap in DefaultTextStyle reset to guarantee visibility
            Expanded(
              child: DefaultTextStyle(
                style: const TextStyle(
                  color: Colors.white,
                  decoration: TextDecoration.none,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(
                        color: item.isRead
                            ? const Color(0xFFAAC8BC)
                            : Colors.white,
                        fontSize: 14,
                        fontWeight: item.isRead ? FontWeight.w500 : FontWeight.w700,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      item.body,
                      style: const TextStyle(
                        color: Color(0xFFAAC8BC),
                        fontSize: 12,
                        height: 1.5,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Time + dot
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _time(item.timestamp),
                  style: const TextStyle(
                    color: Color(0xFF5E8070),
                    fontSize: 11,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 8),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: item.isRead ? 0 : 1,
                  child: Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}