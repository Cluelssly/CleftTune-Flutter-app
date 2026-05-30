import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:firebase_core/firebase_core.dart';
import 'profile.dart';
import 'firebase_options.dart';
import 'phonetic.dart';
import 'cloud.dart';
import 'notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'translator_screen.dart';
import 'landing_page.dart';
import 'premium.dart';
import 'package:intl/intl.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    print("Running on Web");
  }

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const CleftTuneApp());
}

class CleftTuneApp extends StatelessWidget {
  const CleftTuneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CleftTune',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light().copyWith(
        primaryColor: const Color(0xFF0077B6),
        scaffoldBackgroundColor: const Color(0xFFEAF4FB),
      ),
      home: const RootRouter(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ROOT ROUTER — uses authStateChanges() as single source of truth.
// No more _showLanding bool that resets on every cold start.
// ─────────────────────────────────────────────────────────────────────────────

class RootRouter extends StatelessWidget {
  const RootRouter({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Still resolving auth state on startup
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFFEAF4FB),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF0077B6)),
            ),
          );
        }

        // Already signed in → go straight to app, skip landing
        if (snapshot.hasData && snapshot.data != null) {
          return const AppShell();
        }

        // Not signed in → show landing → login flow
        return LandingPage(
          onContinue: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PremiumScreen(
                  onBack: () => Navigator.of(context).pop(),
                  onLogin: () {
                    Navigator.of(context).pop();
                    // authStateChanges() fires automatically
                    // and rebuilds this widget to show AppShell
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED BLURRED BACKGROUND
// ─────────────────────────────────────────────────────────────────────────────

class CleftBackground extends StatelessWidget {
  final Widget child;
  const CleftBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset('assets/images/cleft.png', fit: BoxFit.cover),
        ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 6.0, sigmaY: 6.0),
            child: const SizedBox.expand(),
          ),
        ),
        Container(color: const Color(0xE8EAF4FB)),
        child,
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// APP SHELL
// ─────────────────────────────────────────────────────────────────────────────

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  static const _accent     = Color(0xFF0077B6);
  static const _accentTint = Color(0x260077B6);
  static const _navBg      = Color(0xFFDAEEFA);

  void _switchPage(int index) => setState(() => _currentIndex = index);

  Widget get _currentScreen {
    switch (_currentIndex) {
      case 0:  return const TranslatorScreen();
      case 1:  return const HistoryScreen();
      case 2:  return const TrainedVoiceScreen();
      case 3:  return const Cloud();
      case 4:  return const NotificationsScreen();
      case 5:  return const SettingsScreen();
      case 6:  return const RateUsScreen();
      default: return const TranslatorScreen();
    }
  }

  static const List<_NavItem> _items = [
    _NavItem(
      icon:         Icons.mic_none_rounded,
      selectedIcon: Icons.mic_rounded,
      label:        'Translate',
    ),
    _NavItem(
      icon:         Icons.history_rounded,
      selectedIcon: Icons.history_rounded,
      label:        'History',
    ),
    _NavItem(
      icon:         Icons.graphic_eq_rounded,
      selectedIcon: Icons.graphic_eq_rounded,
      label:        'Trained Voice',
    ),
    _NavItem(
      icon:         Icons.cloud_outlined,
      selectedIcon: Icons.cloud_rounded,
      label:        'Cloud',
    ),
    _NavItem(
      icon:         Icons.notifications_none_rounded,
      selectedIcon: Icons.notifications_rounded,
      label:        'Notifications',
      showBadge:    true,
    ),
    _NavItem(
      icon:         Icons.emoji_events_outlined,
      selectedIcon: Icons.emoji_events_rounded,
      label:        'Progress',
    ),
    _NavItem(
      icon:         Icons.star_outline_rounded,
      selectedIcon: Icons.star_rounded,
      label:        'Rate Us',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isWide = constraints.maxWidth >= 800;

        if (isWide) {
          return Scaffold(
            backgroundColor: const Color(0xFFEAF4FB),
            body: Row(
              children: [
                Container(
                  color: _navBg,
                  child: NavigationRail(
                    backgroundColor: Colors.transparent,
                    selectedIndex: _currentIndex,
                    onDestinationSelected: _switchPage,
                    labelType: NavigationRailLabelType.all,
                    selectedIconTheme:
                        const IconThemeData(color: _accent),
                    unselectedIconTheme:
                        const IconThemeData(color: Color(0xFF5A7A96)),
                    selectedLabelTextStyle: const TextStyle(
                        color: _accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                    unselectedLabelTextStyle: const TextStyle(
                        color: Color(0xFF5A7A96), fontSize: 12),
                    leading: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _accentTint,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: const Color(0x400077B6)),
                        ),
                        child: const Icon(Icons.graphic_eq_rounded,
                            color: _accent, size: 18),
                      ),
                    ),
                    destinations: _items
                        .asMap()
                        .entries
                        .map((e) => NavigationRailDestination(
                              icon: e.value.showBadge
                                  ? _BadgeIcon(
                                      icon: e.value.icon,
                                      selected: false,
                                    )
                                  : Icon(e.value.icon),
                              selectedIcon: e.value.showBadge
                                  ? _BadgeIcon(
                                      icon: e.value.selectedIcon,
                                      selected: true,
                                    )
                                  : Icon(e.value.selectedIcon),
                              label: Text(e.value.label),
                            ))
                        .toList(),
                  ),
                ),
                Container(
                    width: 0.5, color: const Color(0x400077B6)),
                Expanded(child: ClipRect(child: _currentScreen)),
              ],
            ),
          );
        }

        return Scaffold(
          backgroundColor: const Color(0xFFEAF4FB),
          body: _currentScreen,
          bottomNavigationBar: Container(
            decoration: const BoxDecoration(
              color: _navBg,
              border: Border(
                top: BorderSide(color: Color(0x400077B6), width: 0.5),
              ),
            ),
            child: BottomNavigationBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              selectedItemColor: _accent,
              unselectedItemColor: const Color(0xFF5A7A96),
              currentIndex: _currentIndex,
              onTap: _switchPage,
              type: BottomNavigationBarType.fixed,
              selectedLabelStyle: const TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w600),
              unselectedLabelStyle: const TextStyle(fontSize: 10),
              items: _items
                  .asMap()
                  .entries
                  .map((e) => BottomNavigationBarItem(
                        icon: e.value.showBadge
                            ? _BadgeIcon(
                                icon: e.value.icon,
                                selected: e.key == _currentIndex,
                              )
                            : Icon(e.value.icon),
                        activeIcon: e.value.showBadge
                            ? _BadgeIcon(
                                icon: e.value.selectedIcon,
                                selected: true,
                              )
                            : Icon(e.value.selectedIcon),
                        label: e.value.label,
                      ))
                  .toList(),
            ),
          ),
        );
      },
    );
  }
}

// ── Nav item data class ───────────────────────────────────────────────────────
class _NavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool showBadge;

  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.showBadge = false,
  });
}

// ── Live notification badge ───────────────────────────────────────────────────
class _BadgeIcon extends StatelessWidget {
  final IconData icon;
  final bool selected;

  const _BadgeIcon({required this.icon, required this.selected});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return StreamBuilder<QuerySnapshot>(
      stream: user == null
          ? const Stream.empty()
          : FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('notifications')
              .where('isRead', isEqualTo: false)
              .snapshots(),
      builder: (context, snapshot) {
        final unread = snapshot.data?.docs.length ?? 0;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(icon),
            if (unread > 0)
              Positioned(
                top: -4,
                right: -6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0077B6),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: const Color(0xFFDAEEFA), width: 1.5),
                  ),
                  child: Text(
                    '$unread',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w800),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

//HISTORY YARN EH 
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with TickerProviderStateMixin {
  // ── Palette ────────────────────────────────────────────────────────────────
  static const _accent       = Color(0xFF0077B6);
  static const _accentTint   = Color(0x260077B6);
  static const _accentBorder = Color(0x400077B6);
  static const _textDark     = Color(0xFF0D2B4E);
  static const _textSub      = Color(0xFF5A7A96);
  static const _redDim       = Color(0x26E74C3C);
  static const _red          = Color(0xFFE74C3C);
  static const _redBorder    = Color(0x40E74C3C);

  // ── State ──────────────────────────────────────────────────────────────────
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();



  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Date grouping ──────────────────────────────────────────────────────────
  Map<String, List<QueryDocumentSnapshot>> _groupByDate(
      List<QueryDocumentSnapshot> docs) {
    final now       = DateTime.now();
    final today     = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final Map<String, List<QueryDocumentSnapshot>> grouped = {};

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final ts   = data['time'];
      if (ts == null) continue;
      final dt   = (ts as Timestamp).toDate();
      final date = DateTime(dt.year, dt.month, dt.day);

      String label;
      if (date == today) {
        label = 'TODAY';
      } else if (date == yesterday) {
        label = 'YESTERDAY';
      } else {
        label = date.year == now.year
            ? DateFormat('EEE, MMM d').format(date).toUpperCase()
            : DateFormat('EEE, MMM d, yyyy').format(date).toUpperCase();
      }
      grouped.putIfAbsent(label, () => []).add(doc);
    }
    return grouped;
  }

  // ── Delete single ──────────────────────────────────────────────────────────
  Future<void> _deleteItem(QueryDocumentSnapshot doc) async {
    final confirmed = await _showConfirmDialog(
      icon: Icons.delete_outline_rounded,
      title: 'Delete Entry?',
      body: 'This translation will be permanently removed from your history.',
      confirmLabel: 'Delete',
    );
    if (confirmed == true) {
      await FirebaseFirestore.instance
          .collection('translations')
          .doc(doc.id)
          .delete();
      if (mounted) _showRedSnack('Entry deleted');
    }
  }

  // ── Delete all ─────────────────────────────────────────────────────────────
  Future<void> _deleteAll(String uid) async {
    final confirmed = await _showConfirmDialog(
      icon: Icons.delete_sweep_rounded,
      title: 'Clear All History?',
      body: 'All your translation history will be permanently deleted. This cannot be undone.',
      confirmLabel: 'Clear All',
    );
    if (confirmed == true) {
      final snap = await FirebaseFirestore.instance
          .collection('translations')
          .where('userId', isEqualTo: uid)
          .get();

      const batchSize = 500;
      for (int i = 0; i < snap.docs.length; i += batchSize) {
        final batch = FirebaseFirestore.instance.batch();
        final chunk = snap.docs.skip(i).take(batchSize);
        for (final doc in chunk) batch.delete(doc.reference);
        await batch.commit();
      }

      if (mounted) _showRedSnack('History cleared');
    }
  }

  // ── Confirm dialog ─────────────────────────────────────────────────────────
  Future<bool?> _showConfirmDialog({
    required IconData icon,
    required String title,
    required String body,
    required String confirmLabel,
  }) {
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFDAEEFA), Color(0xFFEAF4FB)],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _redBorder, width: 1.2),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 60, height: 60,
              decoration: BoxDecoration(
                color: _redDim,
                shape: BoxShape.circle,
                border: Border.all(color: _red.withOpacity(0.5)),
              ),
              child: Icon(icon, color: _red, size: 28),
            ),
            const SizedBox(height: 16),
            Text(title,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _textDark)),
            const SizedBox(height: 8),
            Text(body,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13, color: _textSub, height: 1.5)),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF8AAEC8)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancel',
                      style: TextStyle(
                          color: _textSub, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _red,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: Text(confirmLabel,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  void _showRedSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle_outline, color: Colors.white, size: 16),
        const SizedBox(width: 8),
        Text(message,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600)),
      ]),
      backgroundColor: _red,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(12),
      duration: const Duration(seconds: 2),
    ));
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFEAF4FB),
              Color(0xFFDAEEFA),
              Color(0xFFC8E3F5),
            ],
          ),
        ),
        child: StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, authSnapshot) {
            if (authSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: _accent, strokeWidth: 2),
              );
            }

            final user = authSnapshot.data;

            return SafeArea(
              child: LayoutBuilder(builder: (context, constraints) {
                final width        = constraints.maxWidth;
                final padding      = width < 800 ? 16.0 : 40.0;
                final contentWidth = width < 1000 ? width : 900.0;

                return Center(
                  child: Container(
                    width: contentWidth,
                    padding: EdgeInsets.symmetric(
                        horizontal: padding, vertical: padding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(user),
                        const SizedBox(height: 28),
                        _buildTitleRow(user),
                        const SizedBox(height: 6),
                        const Padding(
                          padding: EdgeInsets.only(left: 16),
                          child: Text(
                            'Your recent vocal bridge captures.',
                            style: TextStyle(color: _textSub, fontSize: 13),
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildSearchBar(),
                        const SizedBox(height: 24),
                        Expanded(child: _buildList(user)),
                      ],
                    ),
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader(User? user) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: _accentTint,
              shape: BoxShape.circle,
              border: Border.all(color: _accentBorder),
            ),
            child: const Icon(Icons.graphic_eq_rounded, color: _accent, size: 16),
          ),
          const SizedBox(width: 10),
          const Text('CleftTune',
              style: TextStyle(
                  color: _accent,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  letterSpacing: 0.5)),
        ]),
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: _accentTint,
            shape: BoxShape.circle,
            border: Border.all(color: _accentBorder),
          ),
          child: const Icon(Icons.person, color: _accent, size: 18),
        ),
      ],
    );
  }

  // ── Title + Clear All ──────────────────────────────────────────────────────
  Widget _buildTitleRow(User? user) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(children: [
          Container(
            width: 4, height: 28,
            decoration: BoxDecoration(
                color: _accent, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 12),
          const Text('History',
              style: TextStyle(
                  color: _textDark, fontSize: 28, fontWeight: FontWeight.bold)),
        ]),
        if (user != null)
          Row(children: [
            _liveIndicator(),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _deleteAll(user.uid),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: _redDim,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _redBorder),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.delete_sweep_rounded, color: _red, size: 14),
                  SizedBox(width: 5),
                  Text('Clear All',
                      style: TextStyle(
                          color: _red, fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ]),
      ],
    );
  }

  Widget _liveIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0x2200C853),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x6600C853)),
      ),
      child: const Row(mainAxisSize: MainAxisSize.min, children: [
        _PulsingDot(),
        SizedBox(width: 5),
        Text('LIVE',
            style: TextStyle(
                color: Color(0xFF00C853),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1)),
      ]),
    );
  }

  // ── Search bar ─────────────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _accentTint,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: _accentBorder),
      ),
      child: Row(children: [
        const Icon(Icons.search_rounded, color: _accent),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: _searchCtrl,
            style: const TextStyle(color: _textDark),
            onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
            decoration: const InputDecoration(
              hintText: 'Search history...',
              hintStyle: TextStyle(color: _textSub),
              border: InputBorder.none,
            ),
          ),
        ),
        if (_searchQuery.isNotEmpty)
          GestureDetector(
            onTap: () {
              _searchCtrl.clear();
              setState(() => _searchQuery = '');
            },
            child: const Icon(Icons.close_rounded, color: _textSub, size: 18),
          ),
      ]),
    );
  }

  // ── Main list ──────────────────────────────────────────────────────────────
  Widget _buildList(User? user) {
    if (user == null) {
      return _emptyState(
          icon: Icons.person_off_outlined,
          message: 'Sign in to view history');
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('translations')
          .where('userId', isEqualTo: user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: _accent, strokeWidth: 2),
          );
        }

        if (snapshot.hasError) {
          final err = snapshot.error.toString();
          return _emptyState(
            icon: Icons.error_outline,
            message: 'Failed to load history',
            subtitle: err,
          );
        }

        final allDocs = snapshot.data?.docs ?? [];

        allDocs.sort((a, b) {
          final aTs = (a.data() as Map<String, dynamic>)['time'] as Timestamp?;
          final bTs = (b.data() as Map<String, dynamic>)['time'] as Timestamp?;
          if (aTs == null && bTs == null) return 0;
          if (aTs == null) return 1;
          if (bTs == null) return -1;
          return bTs.compareTo(aTs);
        });

        final filtered = allDocs.where((doc) {
          final data    = doc.data() as Map<String, dynamic>;
          final text    = (data['text']    ?? '').toString().toLowerCase();
          final rawText = (data['rawText'] ?? '').toString().toLowerCase();
          return text.contains(_searchQuery) || rawText.contains(_searchQuery);
        }).toList();

        if (filtered.isEmpty) {
          return _emptyState(
            icon: _searchQuery.isNotEmpty
                ? Icons.search_off_rounded
                : Icons.history_toggle_off_rounded,
            message: _searchQuery.isNotEmpty
                ? 'No results for "$_searchQuery"'
                : 'No history yet',
            subtitle: _searchQuery.isEmpty
                ? 'Tap the mic in the Translator tab and start speaking — your words will appear here instantly.'
                : null,
          );
        }

        final grouped = _groupByDate(filtered);

        return ListView(
          physics: const BouncingScrollPhysics(),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _accentTint,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _accentBorder),
                  ),
                  child: Text(
                    '${filtered.length} ${filtered.length == 1 ? 'entry' : 'entries'}',
                    style: const TextStyle(
                        color: _accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ]),
            ),
            for (final entry in grouped.entries) ...[
              _sectionLabel(entry.key, entry.value.length),
              const SizedBox(height: 10),
              ...entry.value.map((doc) => _chatBubble(doc, user.uid)),
              const SizedBox(height: 20),
            ],
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  // ── Section label ──────────────────────────────────────────────────────────
  Widget _sectionLabel(String label, int count) {
    return Row(children: [
      Container(
        width: 3, height: 14,
        decoration: BoxDecoration(
          color: _accent.withOpacity(0.6),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 8),
      Text(label,
          style: const TextStyle(
              color: _textSub,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8)),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: _accentTint,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text('$count',
            style: const TextStyle(
                color: _accent, fontSize: 10, fontWeight: FontWeight.w700)),
      ),
    ]);
  }

  // ── Chat bubble ────────────────────────────────────────────────────────────
  Widget _chatBubble(QueryDocumentSnapshot doc, String uid) {
    final data      = doc.data() as Map<String, dynamic>;
    final text      = data['text']    ?? '';
    final rawText   = data['rawText'] ?? '';
    final mode      = data['mode']    as String? ?? 'realtime';
    final isRefined = mode == 'realtime_refined';

    final ts      = data['time'];
    final dt      = ts != null ? (ts as Timestamp).toDate() : DateTime.now();
    final now     = DateTime.now();
    final today   = DateTime(now.year, now.month, now.day);
    final docDay  = DateTime(dt.year, dt.month, dt.day);
    final timeStr = DateFormat('hh:mm a').format(dt);
    final dateStr = docDay == today
        ? timeStr
        : '${DateFormat('MMM d').format(dt)} · $timeStr';

    // Static card colours
    final bgColor     = const Color(0xFFDAEEFA);
    final borderColor = _accentBorder;

    final bubble = Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onLongPress: () => _deleteItem(doc),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: _accentTint,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.translate_rounded,
                      color: _accent, size: 17),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(text,
                          style: const TextStyle(
                              color: _textDark,
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                              height: 1.4)),
                      if (isRefined &&
                          rawText.isNotEmpty &&
                          rawText.toLowerCase() != text.toLowerCase()) ...[
                        const SizedBox(height: 4),
                        Text('heard: "$rawText"',
                            style: const TextStyle(
                                color: _textSub,
                                fontSize: 11,
                                fontStyle: FontStyle.italic)),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _accentTint,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.access_time_rounded,
                                      color: _accent, size: 11),
                                  const SizedBox(width: 4),
                                  Text(dateStr,
                                      style: const TextStyle(
                                          color: _accent,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500)),
                                ]),
                          ),
                          Row(children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: isRefined
                                    ? const Color(0x260077B6)
                                    : const Color(0x1A00C853),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isRefined ? 'refined' : 'live',
                                style: TextStyle(
                                    color: isRefined
                                        ? _accent
                                        : const Color(0xFF00A846),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () => _deleteItem(doc),
                              child: Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: _redDim,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: _redBorder),
                                ),
                                child: const Icon(
                                    Icons.delete_outline_rounded,
                                    color: _red,
                                    size: 14),
                              ),
                            ),
                          ]),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return Dismissible(
      key: Key(doc.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: _red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _redBorder),
        ),
        alignment: Alignment.centerRight,
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Delete',
                style: TextStyle(
                    color: _red, fontWeight: FontWeight.w600, fontSize: 13)),
            SizedBox(width: 8),
            Icon(Icons.delete_outline_rounded, color: _red, size: 20),
          ],
        ),
      ),
      confirmDismiss: (_) async {
        await _deleteItem(doc);
        return false;
      },
      child: bubble,
    );
  }

  // ── Empty state ────────────────────────────────────────────────────────────
  Widget _emptyState({
    required IconData icon,
    required String message,
    String? subtitle,
  }) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 70, height: 70,
          decoration: BoxDecoration(
            color: _accentTint,
            shape: BoxShape.circle,
            border: Border.all(color: _accentBorder),
          ),
          child: Icon(icon, color: _accent, size: 30),
        ),
        const SizedBox(height: 16),
        Text(message,
            style: const TextStyle(
                color: _textDark, fontSize: 15, fontWeight: FontWeight.w600)),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _textSub, fontSize: 13)),
          ),
        ],
      ]),
    );
  }
}

// ── Pulsing dot ───────────────────────────────────────────────────────────────
class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 6, height: 6,
        decoration: const BoxDecoration(
          color: Color(0xFF00C853),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
// ─────────────────────────────────────────────────────────────────────────────
// SETTINGS SCREEN  (now: Gamification / Progress only — no feedback)
// ─────────────────────────────────────────────────────────────────────────────

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _accent       = Color(0xFF0077B6);
  static const _accentTint   = Color(0x260077B6);
  static const _accentBorder = Color(0x400077B6);
  static const _textDark     = Color(0xFF0D2B4E);
  static const _textSub      = Color(0xFF5A7A96);
  static const _cardColor    = Color(0x1A0077B6);
  static const _gold         = Color(0xFFF5A623);
  static const _goldTint     = Color(0x1FF5A623);
  static const _goldBorder   = Color(0x40F5A623);
  static const _green        = Color(0xFF27AE60);
  static const _greenTint    = Color(0x1F27AE60);
  static const _greenBorder  = Color(0x4027AE60);

  Future<Map<String, dynamic>> _loadGamification(String uid) async {
    final userDoc = await FirebaseFirestore.instance
        .collection('users').doc(uid).get();
    final userData = userDoc.data() ?? {};

    final streak = (userData['trainingStreak'] as int?) ?? 0;

    final correctionsSnap = await FirebaseFirestore.instance
        .collection('users').doc(uid)
        .collection('corrections')
        .where('source', isEqualTo: 'user')
        .get();
    final corrections = correctionsSnap.docs.length;

    final wordsAdded =
        (userData['wordsAdded'] as int?) ?? (corrections * 2);

    final sentencesSnap = await FirebaseFirestore.instance
        .collection('translations')
        .where('userId', isEqualTo: uid)
        .get();
    final sentences = sentencesSnap.docs.length;

    final totalSessions =
        (userData['totalSessions'] as int?) ?? sentences;

    return {
      'streak':        streak,
      'corrections':   corrections,
      'wordsAdded':    wordsAdded,
      'sentences':     sentences,
      'totalSessions': totalSessions,
    };
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CleftBackground(
        child: SafeArea(
          child: LayoutBuilder(builder: (context, constraints) {
            final width        = constraints.maxWidth;
            final padding      = width < 800 ? 16.0 : 40.0;
            final contentWidth = width < 1000 ? width : 900.0;

            return Center(
              child: Container(
                width: contentWidth,
                padding: EdgeInsets.all(padding),
                child: ListView(children: [

                  // ── HEADER ────────────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Progress',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: _textDark)),
                      GestureDetector(
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const ProfileScreen())),
                        child: Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: _accentTint,
                            shape: BoxShape.circle,
                            border: Border.all(color: _accentBorder),
                          ),
                          child: const Icon(Icons.person,
                              color: _accent, size: 18),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  if (user == null)
                    _notSignedIn()
                  else
                    FutureBuilder<Map<String, dynamic>>(
                      future: _loadGamification(user.uid),
                      builder: (context, snap) {
                        if (snap.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: Padding(
                              padding:
                                  EdgeInsets.symmetric(vertical: 60),
                              child: CircularProgressIndicator(
                                  color: _accent, strokeWidth: 2),
                            ),
                          );
                        }
                        final data = snap.data ?? {};
                        return _buildContent(
                            context, user.uid, data);
                      },
                    ),
                ]),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildContent(
      BuildContext context, String uid, Map<String, dynamic> data) {
    final streak      = data['streak']        as int? ?? 0;
    final corrections = data['corrections']   as int? ?? 0;
    final wordsAdded  = data['wordsAdded']    as int? ?? 0;
    final sentences   = data['sentences']     as int? ?? 0;
    final sessions    = data['totalSessions'] as int? ?? 0;

    final tasks = <_Task>[
      _Task(
        icon:    Icons.spellcheck_rounded,
        title:   'Teach 5 Word Corrections',
        desc:    'Add 5 corrections to train the AI on your speech.',
        goal:    5,
        current: corrections,
        color:   _accent,
      ),
      _Task(
        icon:    Icons.record_voice_over_rounded,
        title:   'Speak 3 Full Sentences',
        desc:    'Use the mic to capture 3 or more sentences today.',
        goal:    3,
        current: sentences,
        color:   _green,
      ),
      _Task(
        icon:    Icons.library_add_rounded,
        title:   'Add 10 Words to AI',
        desc:    'Build vocabulary — reach 10 total words trained.',
        goal:    10,
        current: wordsAdded,
        color:   _gold,
      ),
      _Task(
        icon:    Icons.mic_rounded,
        title:   'Complete 5 Training Sessions',
        desc:    'Start 5 sessions to help the AI learn your voice.',
        goal:    5,
        current: sessions,
        color:   const Color(0xFF8E44AD),
      ),
      _Task(
        icon:    Icons.auto_fix_high_rounded,
        title:   'Reach 10 Corrections',
        desc:    'Teach the AI 10 of your personal speech patterns.',
        goal:    10,
        current: corrections,
        color:   _accent,
      ),
    ];

    final completedCount = tasks.where((t) => t.isDone).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _streakCard(streak),
        const SizedBox(height: 20),
        _sectionLabel('YOUR TRAINING STATS'),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _statChip(
              '$corrections', 'Corrections',
              Icons.spellcheck_rounded, _accent)),
          const SizedBox(width: 8),
          Expanded(child: _statChip(
              '$wordsAdded', 'Words Added',
              Icons.library_add_rounded, _gold)),
          const SizedBox(width: 8),
          Expanded(child: _statChip(
              '$sentences', 'Sentences',
              Icons.record_voice_over_rounded, _green)),
        ]),
        const SizedBox(height: 24),
        Row(children: [
          _sectionLabel('DAILY TASKS'),
          const Spacer(),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: completedCount == tasks.length
                  ? _greenTint
                  : _accentTint,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: completedCount == tasks.length
                      ? _greenBorder
                      : _accentBorder),
            ),
            child: Text(
              '$completedCount / ${tasks.length} done',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: completedCount == tasks.length
                      ? _green
                      : _accent),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        ...tasks.map((t) => _taskTile(t)),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _streakCard(int streak) {
    final isActive = streak > 0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isActive
              ? [const Color(0xFF005F8E), _accent]
              : [const Color(0xFF2C3E50), const Color(0xFF3D5A73)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: _accent.withOpacity(0.25),
              blurRadius: 18,
              spreadRadius: 1),
        ],
      ),
      child: Row(children: [
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              isActive ? '🔥' : '💤',
              style: const TextStyle(fontSize: 26),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isActive
                    ? '$streak-Day Training Streak!'
                    : 'No Active Streak',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                isActive
                    ? 'Keep training daily to maintain your streak.'
                    : 'Start teaching corrections to begin your streak.',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.75),
                    fontSize: 12,
                    height: 1.4),
              ),
            ],
          ),
        ),
        if (isActive)
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$streak\ndays',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  height: 1.2),
            ),
          ),
      ]),
    );
  }

  Widget _statChip(
      String value, String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 6),
        Text(value,
            style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(label,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: _textSub, fontSize: 10, height: 1.3)),
      ]),
    );
  }

  Widget _taskTile(_Task task) {
    final progress = (task.current / task.goal).clamp(0.0, 1.0);
    final done     = task.isDone;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: done ? task.color.withOpacity(0.07) : _cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color:
                done ? task.color.withOpacity(0.3) : _accentBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: task.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: done
                ? Icon(Icons.check_circle_rounded,
                    color: task.color, size: 18)
                : Icon(task.icon, color: task.color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(task.title,
                        style: TextStyle(
                            color: _textDark,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            decoration: done
                                ? TextDecoration.lineThrough
                                : null,
                            decorationColor: _textSub)),
                  ),
                  Text(
                    '${task.current.clamp(0, task.goal)}/${task.goal}',
                    style: TextStyle(
                        color: done ? task.color : _textSub,
                        fontSize: 11,
                        fontWeight: FontWeight.w700),
                  ),
                ]),
                const SizedBox(height: 4),
                Text(task.desc,
                    style: const TextStyle(
                        color: _textSub, fontSize: 11, height: 1.4)),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value:           progress,
                    minHeight:       5,
                    backgroundColor: task.color.withOpacity(0.12),
                    valueColor:
                        AlwaysStoppedAnimation<Color>(task.color),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _notSignedIn() => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 60),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 64, height: 64,
              decoration: const BoxDecoration(
                  color: _accentTint, shape: BoxShape.circle),
              child: const Icon(Icons.person_off_outlined,
                  color: _accent, size: 28),
            ),
            const SizedBox(height: 14),
            const Text('Sign in to track your progress',
                style: TextStyle(
                    color: _textDark,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
          ]),
        ),
      );

  Widget _sectionLabel(String label) => Row(children: [
        Container(
          width: 3, height: 14,
          decoration: BoxDecoration(
            color: _accent.withOpacity(0.7),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(label,
            style: const TextStyle(
                color: _textSub,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8)),
      ]);
}

// ─────────────────────────────────────────────────────────────────────────────
// RATE US SCREEN  (standalone feedback / rating screen)
// ─────────────────────────────────────────────────────────────────────────────

class RateUsScreen extends StatefulWidget {
  const RateUsScreen({super.key});

  @override
  State<RateUsScreen> createState() => _RateUsScreenState();
}

class _RateUsScreenState extends State<RateUsScreen> {
  static const _accent       = Color(0xFF0077B6);
  static const _accentTint   = Color(0x260077B6);
  static const _accentBorder = Color(0x400077B6);
  static const _textDark     = Color(0xFF0D2B4E);
  static const _textSub      = Color(0xFF5A7A96);
  static const _cardColor    = Color(0x1A0077B6);
  static const _gold         = Color(0xFFF5A623);
  static const _green        = Color(0xFF27AE60);
  static const _greenTint    = Color(0x1F27AE60);
  static const _greenBorder  = Color(0x4027AE60);

  int    _rating       = 0;
  bool   _feedbackSent = false;
  bool   _isSendingFB  = false;
  final  _feedbackCtrl = TextEditingController();

  @override
  void dispose() {
    _feedbackCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitFeedback(String uid) async {
    final text = _feedbackCtrl.text.trim();
    if (_rating == 0 && text.isEmpty) return;
    setState(() => _isSendingFB = true);
    try {
      await FirebaseFirestore.instance.collection('feedback').add({
        'userId':    uid,
        'rating':    _rating,
        'message':   text,
        'createdAt': FieldValue.serverTimestamp(),
      });
      setState(() {
        _feedbackSent = true;
        _isSendingFB  = false;
      });
    } catch (_) {
      setState(() => _isSendingFB = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CleftBackground(
        child: SafeArea(
          child: LayoutBuilder(builder: (context, constraints) {
            final width        = constraints.maxWidth;
            final padding      = width < 800 ? 16.0 : 40.0;
            final contentWidth = width < 1000 ? width : 900.0;

            return Center(
              child: Container(
                width: contentWidth,
                padding: EdgeInsets.all(padding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ── HEADER ────────────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Rate Us',
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: _textDark)),
                        GestureDetector(
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const ProfileScreen())),
                          child: Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              color: _accentTint,
                              shape: BoxShape.circle,
                              border: Border.all(color: _accentBorder),
                            ),
                            child: const Icon(Icons.person,
                                color: _accent, size: 18),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // ── HERO ILLUSTRATION ─────────────────────────────────
                    Center(
                      child: Container(
                        width: 100, height: 100,
                        decoration: BoxDecoration(
                          color: _gold.withOpacity(0.1),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: _gold.withOpacity(0.3), width: 2),
                        ),
                        child: const Center(
                          child: Text('⭐',
                              style: TextStyle(fontSize: 46)),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    const Center(
                      child: Text('Enjoying CleftTune?',
                          style: TextStyle(
                              color: _textDark,
                              fontSize: 22,
                              fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(height: 6),
                    const Center(
                      child: Text(
                        'Your feedback helps us grow and improve\nfor every user in our community.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: _textSub, fontSize: 13, height: 1.5),
                      ),
                    ),

                    const SizedBox(height: 32),

                    if (user == null)
                      _notSignedIn()
                    else if (_feedbackSent)
                      _thankYouCard()
                    else
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: _feedbackForm(user.uid),
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _thankYouCard() {
    return Expanded(
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: _greenTint,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _greenBorder),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: _green.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: _green, size: 32),
            ),
            const SizedBox(height: 16),
            const Text('Thank you!',
                style: TextStyle(
                    color: _green,
                    fontSize: 20,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text(
              'Your feedback has been received.\nIt helps us improve CleftTune for everyone.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Color(0xFF5A7A96), fontSize: 13, height: 1.5),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _feedbackForm(String uid) {
    final labels = ['Terrible', 'Bad', 'Okay', 'Good', 'Excellent'];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _accentBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // Star rating label
          const Text('How would you rate your experience?',
              style: TextStyle(
                  color: _textDark,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 14),

          // Stars row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final filled = i < _rating;
              return GestureDetector(
                onTap: () => setState(() => _rating = i + 1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(
                    filled
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: filled ? _gold : const Color(0xFF5A7A96),
                    size: 38,
                  ),
                ),
              );
            }),
          ),

          // Rating label
          if (_rating > 0) ...[
            const SizedBox(height: 8),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: _gold.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _gold.withOpacity(0.35)),
                ),
                child: Text(
                  labels[_rating - 1],
                  style: const TextStyle(
                      color: _gold,
                      fontSize: 12,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],

          const SizedBox(height: 20),

          const Text('Share your thoughts (optional)',
              style: TextStyle(
                  color: _textDark,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),

          TextField(
            controller: _feedbackCtrl,
            maxLines: 4,
            style: const TextStyle(color: _textDark, fontSize: 13),
            decoration: InputDecoration(
              hintText:
                  "What's working, what could be better, or any ideas...",
              hintStyle:
                  const TextStyle(color: _textSub, fontSize: 12),
              filled: true,
              fillColor: Colors.white.withOpacity(0.6),
              contentPadding: const EdgeInsets.all(14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _accentBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _accentBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: _accent, width: 1.5),
              ),
            ),
          ),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: _isSendingFB ? null : () => _submitFeedback(uid),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _rating == 0 && _feedbackCtrl.text.trim().isEmpty
                      ? _accent.withOpacity(0.4)
                      : _accent,
                  borderRadius: BorderRadius.circular(28),
                ),
                alignment: Alignment.center,
                child: _isSendingFB
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Submit Feedback',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _notSignedIn() => Expanded(
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 64, height: 64,
              decoration: const BoxDecoration(
                  color: _accentTint, shape: BoxShape.circle),
              child: const Icon(Icons.person_off_outlined,
                  color: _accent, size: 28),
            ),
            const SizedBox(height: 14),
            const Text('Sign in to leave a review',
                style: TextStyle(
                    color: _textDark,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
          ]),
        ),
      );
}

// ── Task data class ───────────────────────────────────────────────────────────
class _Task {
  final IconData icon;
  final String   title;
  final String   desc;
  final int      goal;
  final int      current;
  final Color    color;

  const _Task({
    required this.icon,
    required this.title,
    required this.desc,
    required this.goal,
    required this.current,
    required this.color,
  });

  bool get isDone => current >= goal;
}