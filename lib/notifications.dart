import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────────────────────────
// NOTIFICATION TYPES
// ─────────────────────────────────────────────────────────────────────────────
// 'training'       — AI voice training started / completed / improved
// 'word_deleted'   — User deleted a corrected word
// 'word_added'     — User added/corrected a word
// 'premium_pay'    — Monthly payment reminder
// 'premium_active' — Subscription confirmed / renewed
// 'premium_cancel' — Subscription cancelled
// 'app_update'     — New app version available
// 'sync'           — Cloud sync completed
// 'cloud'          — Cloud backup status
// 'reminder'       — General reminder
// ─────────────────────────────────────────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────────────────────
// NOTIFICATION HELPER — call from anywhere in the app
// ─────────────────────────────────────────────────────────────────────────────
class NotificationHelper {
  // ── Generic sender ────────────────────────────────────────────────────────
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

  // ── AI Training ───────────────────────────────────────────────────────────
  static Future<void> trainingStarted() => send(
        title: 'Voice Training Started',
        body:  'CleftTune is now learning your voice. This may take a few moments.',
        type:  'training',
      );

  static Future<void> trainingCompleted({double? accuracy}) => send(
        title: 'Training Complete ✅',
        body:  accuracy != null
            ? 'Your voice model improved to ${accuracy.toStringAsFixed(1)}% accuracy. Keep training to improve further!'
            : 'Your AI voice model has been updated successfully.',
        type:  'training',
      );

  static Future<void> trainingFailed() => send(
        title: 'Training Failed',
        body:  'Voice training encountered an issue. Please try again.',
        type:  'training',
      );

  // ── Word actions ──────────────────────────────────────────────────────────
  static Future<void> wordDeleted(String word) => send(
        title: 'Word Removed',
        body:  '"$word" has been deleted from your corrected words list.',
        type:  'word_deleted',
      );

  static Future<void> wordAdded(String word) => send(
        title: 'Word Added',
        body:  '"$word" was added to your corrected words list and will improve future translations.',
        type:  'word_added',
      );

  static Future<void> wordUpdated(String oldWord, String newWord) => send(
        title: 'Word Updated',
        body:  '"$oldWord" has been updated to "$newWord" in your vocabulary.',
        type:  'word_added',
      );

  // ── Premium payment ───────────────────────────────────────────────────────
  static Future<void> premiumPaymentReminder({int daysLeft = 3}) => send(
        title: 'Payment Due in $daysLeft Days 💳',
        body:  'Your CleftTune Premium subscription renews in $daysLeft days. Make sure your payment method is ready.',
        type:  'premium_pay',
      );

  static Future<void> premiumActivated({String method = ''}) => send(
        title: 'Premium Activated 🎉',
        body:  method.isNotEmpty
            ? 'Your Premium subscription was confirmed via $method. Enjoy all features!'
            : 'Your Premium subscription is now active. Enjoy unlimited access!',
        type:  'premium_active',
      );

  static Future<void> premiumRenewed({String method = ''}) => send(
        title: 'Subscription Renewed ✅',
        body:  'Your CleftTune Premium has been renewed successfully${method.isNotEmpty ? ' via $method' : ''}. Thank you!',
        type:  'premium_active',
      );

  static Future<void> premiumCancelled() => send(
        title: 'Subscription Cancelled',
        body:  'Your Premium subscription has been cancelled. You will lose access to Premium features at the end of your billing period.',
        type:  'premium_cancel',
      );

  static Future<void> premiumExpiringSoon() => send(
        title: 'Premium Expiring Soon ⚠️',
        body:  'Your Premium subscription expires tomorrow. Renew now to keep your access uninterrupted.',
        type:  'premium_pay',
      );

  // ── App update ────────────────────────────────────────────────────────────
  static Future<void> appUpdateAvailable({
    required String version,
    String? changelog,
  }) => send(
        title: 'Update Available — v$version 🚀',
        body:  changelog ??
            'A new version of CleftTune is ready. Update now for the latest improvements and bug fixes.',
        type:  'app_update',
      );

  static Future<void> appUpdatedSuccess({required String version}) => send(
        title: 'App Updated to v$version',
        body:  'CleftTune has been updated successfully. Enjoy the new features!',
        type:  'app_update',
      );

  // ── Cloud / Sync ──────────────────────────────────────────────────────────
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

// ─────────────────────────────────────────────────────────────────────────────
// NOTIFICATIONS SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  // ── Palette ──────────────────────────────────────────────────────────────
  static const _bg         = Color(0xFF0D1F2D);
  static const _appBar     = Color(0xFF0E2D2D);
  static const _teal       = Color(0xFF1D9E75);
  static const _tealDim    = Color(0x261D9E75);
  static const _tealBorder = Color(0x401D9E75);
  static const _white40    = Color(0x66FFFFFF);
  static const _white20    = Color(0x33FFFFFF);
  static const _white06    = Color(0x0FFFFFFF);

  List<NotifItem> _notifications = [];
  bool _isLoading = true;

  // Active filter — null means 'All'
  String? _activeFilter;

  static const _filterOptions = [
    {'label': 'All',       'value': null},
    {'label': 'Training',  'value': 'training'},
    {'label': 'Words',     'value': 'word'},
    {'label': 'Premium',   'value': 'premium'},
    {'label': 'Updates',   'value': 'app_update'},
    {'label': 'Sync',      'value': 'sync'},
  ];

  @override
  void initState() {
    super.initState();
    _listenToNotifications();
  }

  void _listenToNotifications() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }
    FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snapshot) {
      setState(() {
        _notifications = snapshot.docs.map(NotifItem.fromFirestore).toList();
        _isLoading = false;
      });
    });
  }

  List<NotifItem> get _filtered {
    if (_activeFilter == null) return _notifications;
    return _notifications
        .where((n) => n.type.startsWith(_activeFilter!))
        .toList();
  }

  Future<void> _markRead(NotifItem item) async {
    if (item.isRead) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .doc(item.id)
        .update({'isRead': true});
  }

  Future<void> _markAllRead() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final item in _notifications.where((n) => !n.isRead)) {
      batch.update(
        FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('notifications')
            .doc(item.id),
        {'isRead': true},
      );
    }
    await batch.commit();
  }

  Future<void> _deleteNotification(NotifItem item) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .doc(item.id)
        .delete();
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF112828),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Clear all notifications?',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        content: const Text('This cannot be undone.',
            style: TextStyle(color: _white40, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child:
                const Text('Cancel', style: TextStyle(color: _white40)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade800,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear all',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final item in _notifications) {
      batch.delete(FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .doc(item.id));
    }
    await batch.commit();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  int get _unreadCount => _notifications.where((n) => !n.isRead).length;

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _groupLabel(DateTime dt) {
    final now       = DateTime.now();
    final today     = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final date      = DateTime(dt.year, dt.month, dt.day);
    if (date == today)     return 'TODAY';
    if (date == yesterday) return 'YESTERDAY';
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May',
      'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month]} ${dt.day}, ${dt.year}';
  }

  Map<String, List<NotifItem>> get _grouped {
    final map = <String, List<NotifItem>>{};
    for (final item in _filtered) {
      map.putIfAbsent(_groupLabel(item.timestamp), () => []).add(item);
    }
    return map;
  }

  // ── Icon / color per type ─────────────────────────────────────────────────
  IconData _iconFor(String type) {
    switch (type) {
      case 'training':       return Icons.mic_rounded;
      case 'word_deleted':   return Icons.delete_rounded;
      case 'word_added':     return Icons.spellcheck_rounded;
      case 'premium_active': return Icons.star_rounded;
      case 'premium_pay':    return Icons.credit_card_rounded;
      case 'premium_cancel': return Icons.cancel_rounded;
      case 'app_update':     return Icons.system_update_rounded;
      case 'sync':           return Icons.sync_rounded;
      case 'cloud':          return Icons.cloud_done_rounded;
      default:               return Icons.notifications_none_rounded;
    }
  }

  Color _iconBgFor(String type) {
    switch (type) {
      case 'training':       return const Color(0x261D9E75);
      case 'word_deleted':   return const Color(0x26E53935);
      case 'word_added':     return const Color(0x261D9E75);
      case 'premium_active': return const Color(0x26EF9F27);
      case 'premium_pay':    return const Color(0x26EF9F27);
      case 'premium_cancel': return const Color(0x26E53935);
      case 'app_update':     return const Color(0x26378ADD);
      case 'sync':           return const Color(0x261D9E75);
      case 'cloud':          return const Color(0x26378ADD);
      default:               return const Color(0x26D85A30);
    }
  }

  Color _iconColorFor(String type) {
    switch (type) {
      case 'training':       return const Color(0xFF1D9E75);
      case 'word_deleted':   return const Color(0xFFE53935);
      case 'word_added':     return const Color(0xFF1D9E75);
      case 'premium_active': return const Color(0xFFEF9F27);
      case 'premium_pay':    return const Color(0xFFEF9F27);
      case 'premium_cancel': return const Color(0xFFE53935);
      case 'app_update':     return const Color(0xFF378ADD);
      case 'sync':           return const Color(0xFF1D9E75);
      case 'cloud':          return const Color(0xFF378ADD);
      default:               return const Color(0xFFD85A30);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            _buildFilterRow(),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: _teal, strokeWidth: 2))
                  : _filtered.isEmpty
                      ? _buildEmpty()
                      : _buildList(),
            ),
          ],
        ),
      ),
    );
  }

  // ── App bar ───────────────────────────────────────────────────────────────
  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: _appBar,
        border:
            Border(bottom: BorderSide(color: _tealBorder, width: 0.5)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _tealDim,
                shape: BoxShape.circle,
                border: Border.all(color: _tealBorder),
              ),
              child: const Icon(Icons.arrow_back_ios_new,
                  color: _teal, size: 15),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Notifications',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Colors.white)),
          ),
          if (_unreadCount > 0)
            Container(
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _teal,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('$_unreadCount new',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ),
          if (_unreadCount > 0)
            GestureDetector(
              onTap: _markAllRead,
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _tealDim,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _tealBorder),
                ),
                child: const Text('Read all',
                    style: TextStyle(
                        color: _teal,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          if (_notifications.isNotEmpty)
            GestureDetector(
              onTap: _clearAll,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _white06,
                  shape: BoxShape.circle,
                  border: Border.all(color: _white20),
                ),
                child: const Icon(Icons.delete_outline_rounded,
                    color: _white40, size: 17),
              ),
            ),
        ],
      ),
    );
  }

  // ── Filter chips row ──────────────────────────────────────────────────────
  Widget _buildFilterRow() {
    return Container(
      height: 44,
      color: _appBar,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        itemCount: _filterOptions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final opt      = _filterOptions[i];
          final val      = opt['value'] as String?;
          final selected = _activeFilter == val;
          return GestureDetector(
            onTap: () => setState(() => _activeFilter = val),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 0),
              decoration: BoxDecoration(
                color: selected ? _teal : _white06,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: selected ? _teal : _white20),
              ),
              child: Center(
                child: Text(opt['label'] as String,
                    style: TextStyle(
                        color: selected
                            ? Colors.white
                            : _white40,
                        fontSize: 12,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w400)),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────
  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: _tealDim,
              shape: BoxShape.circle,
              border: Border.all(color: _tealBorder),
            ),
            child: const Icon(Icons.notifications_off_outlined,
                color: _teal, size: 32),
          ),
          const SizedBox(height: 16),
          const Text('No notifications',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          const Text("You're all caught up!",
              style: TextStyle(color: _white40, fontSize: 13)),
        ],
      ),
    );
  }

  // ── Grouped list ──────────────────────────────────────────────────────────
  Widget _buildList() {
    final grouped  = _grouped;
    final sections = grouped.keys.toList();

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: sections.length,
      itemBuilder: (context, sectionIndex) {
        final label  = sections[sectionIndex];
        final items  = grouped[label]!;
        final isLast = sectionIndex == sections.length - 1;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(label,
                showMarkAll:
                    label == 'TODAY' && _unreadCount > 0),
            ...items.map(_swipeableCard),
            if (!isLast) ...[
              const SizedBox(height: 8),
              const Divider(
                  color: _white06, thickness: 0.5, height: 1),
              const SizedBox(height: 4),
            ],
          ],
        );
      },
    );
  }

  Widget _sectionHeader(String label, {bool showMarkAll = false}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  color: _white40,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.8)),
          if (showMarkAll)
            GestureDetector(
              onTap: _markAllRead,
              child: const Text('Mark all as read',
                  style: TextStyle(color: _teal, fontSize: 12)),
            ),
        ],
      ),
    );
  }

  // ── Swipe-to-delete ───────────────────────────────────────────────────────
  Widget _swipeableCard(NotifItem item) {
    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _deleteNotification(item),
      background: Container(
        alignment: Alignment.centerRight,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.shade900,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_rounded,
            color: Colors.white, size: 22),
      ),
      child: _notifCard(item),
    );
  }

  // ── Notification card ─────────────────────────────────────────────────────
  Widget _notifCard(NotifItem item) {
    final iconColor = _iconColorFor(item.type);

    return GestureDetector(
      onTap: () => _markRead(item),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: item.isRead
              ? _white06
              : const Color(0x0C1D9E75),
          borderRadius: BorderRadius.circular(16),
          border: Border(
            left: BorderSide(
              color: item.isRead ? Colors.transparent : iconColor,
              width: 2.5,
            ),
            top:    const BorderSide(color: _white20, width: 0.5),
            right:  const BorderSide(color: _white20, width: 0.5),
            bottom: const BorderSide(color: _white20, width: 0.5),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: _iconBgFor(item.type),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_iconFor(item.type),
                  color: iconColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title,
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: item.isRead
                              ? FontWeight.w400
                              : FontWeight.w600)),
                  const SizedBox(height: 3),
                  Text(item.body,
                      style: const TextStyle(
                          color: _white40,
                          fontSize: 12,
                          height: 1.5)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(_formatTime(item.timestamp),
                    style: const TextStyle(
                        color: _white40, fontSize: 11)),
                const SizedBox(height: 6),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 250),
                  opacity: item.isRead ? 0.0 : 1.0,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                        color: iconColor,
                        shape: BoxShape.circle),
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