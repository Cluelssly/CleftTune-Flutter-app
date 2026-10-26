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
      title: 'VoiceMate',
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
// ─────────────────────────────────────────────────────────────────────────────

class RootRouter extends StatelessWidget {
  const RootRouter({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFFEAF4FB),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF0077B6)),
            ),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          return const AppShell();
        }

        return LandingPage(
          onContinue: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PremiumScreen(
                  onBack: () => Navigator.of(context).pop(),
                  onLogin: () {
                    Navigator.of(context).pop();
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

  static const double _railReferenceWidth = 1200.0;
  static const double _minRailScale = 1.0;
  static const double _maxRailScale = 2.6;

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
        final bool isWide =
            constraints.maxWidth >= 800 && constraints.maxHeight >= 500;

        final double railScale = isWide
            ? (constraints.maxWidth / _railReferenceWidth)
                .clamp(_minRailScale, _maxRailScale)
            : 1.0;

        if (isWide) {
          final double iconSize      = 24 * railScale;
          final double labelFontSize = 12 * railScale;
          final double railMinWidth  = 72 * railScale;
          final double avatarSize    = 36 * railScale;
          final double avatarIcon    = 18 * railScale;
          final double dividerWidth  = (0.5 * railScale).clamp(0.5, 2.0);

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
                    minWidth: railMinWidth,
                    minExtendedWidth: railMinWidth * 2,
                    selectedIconTheme:
                        IconThemeData(color: _accent, size: iconSize),
                    unselectedIconTheme:
                        IconThemeData(color: const Color(0xFF5A7A96), size: iconSize),
                    selectedLabelTextStyle: TextStyle(
                        color: _accent,
                        fontSize: labelFontSize,
                        fontWeight: FontWeight.w600),
                    unselectedLabelTextStyle: TextStyle(
                        color: const Color(0xFF5A7A96), fontSize: labelFontSize),
                    leading: Padding(
                      padding: EdgeInsets.symmetric(vertical: 16 * railScale),
                      child: Container(
                        width: avatarSize,
                        height: avatarSize,
                        decoration: BoxDecoration(
                          color: _accentTint,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: const Color(0x400077B6)),
                        ),
                        child: Icon(Icons.graphic_eq_rounded,
                            color: _accent, size: avatarIcon),
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
                                      size: iconSize,
                                    )
                                  : Icon(e.value.icon),
                              selectedIcon: e.value.showBadge
                                  ? _BadgeIcon(
                                      icon: e.value.selectedIcon,
                                      selected: true,
                                      size: iconSize,
                                    )
                                  : Icon(e.value.selectedIcon),
                              label: Text(e.value.label),
                            ))
                        .toList(),
                  ),
                ),
                Container(
                    width: dividerWidth, color: const Color(0x400077B6)),
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
            child: constraints.maxWidth < 600
                ? _buildCompactNavigation(_bottomScale(constraints.maxWidth))
                : BottomNavigationBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              selectedItemColor: _accent,
              unselectedItemColor: const Color(0xFF5A7A96),
              currentIndex: _currentIndex,
              onTap: _switchPage,
              type: BottomNavigationBarType.fixed,
              iconSize: 24 * _bottomScale(constraints.maxWidth),
              selectedLabelStyle: TextStyle(
                  fontSize: 10 * _bottomScale(constraints.maxWidth),
                  fontWeight: FontWeight.w600),
              unselectedLabelStyle: TextStyle(
                  fontSize: 10 * _bottomScale(constraints.maxWidth)),
              items: _items
                  .asMap()
                  .entries
                  .map((e) => BottomNavigationBarItem(
                        icon: e.value.showBadge
                            ? _BadgeIcon(
                                icon: e.value.icon,
                                selected: e.key == _currentIndex,
                                size: 24 * _bottomScale(constraints.maxWidth),
                              )
                            : Icon(e.value.icon),
                        activeIcon: e.value.showBadge
                            ? _BadgeIcon(
                                icon: e.value.selectedIcon,
                                selected: true,
                                size: 24 * _bottomScale(constraints.maxWidth),
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

  // Scales bottom-bar icons/labels with screen width (1.0 at ≤400px, up to 1.6).
  double _bottomScale(double width) => (width / 400).clamp(1.0, 1.6);

  Widget _buildCompactNavigation(double scale) {
    const visibleIndices = [0, 1, 3, 5];
    final selectedIndex = switch (_currentIndex) {
      0 => 0,
      1 => 1,
      3 => 2,
      5 => 3,
      _ => 4,
    };
    final visibleItems = visibleIndices
        .map((index) => _items[index])
        .toList(growable: false);

    return BottomNavigationBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      selectedItemColor: _accent,
      unselectedItemColor: const Color(0xFF5A7A96),
      currentIndex: selectedIndex,
      onTap: (index) {
        if (index == visibleIndices.length) {
          _showMoreDestinations();
        } else {
          _switchPage(visibleIndices[index]);
        }
      },
      type: BottomNavigationBarType.fixed,
      iconSize: 24 * scale,
      selectedLabelStyle: TextStyle(
          fontSize: 10 * scale, fontWeight: FontWeight.w600),
      unselectedLabelStyle: TextStyle(fontSize: 10 * scale),
      items: [
        ...visibleItems.map((item) => BottomNavigationBarItem(
              icon: Icon(item.icon),
              activeIcon: Icon(item.selectedIcon),
              label: item.label,
            )),
        BottomNavigationBarItem(
          icon: _BadgeIcon(
              icon: Icons.more_horiz_rounded,
              selected: false,
              size: 24 * scale),
          activeIcon: _BadgeIcon(
              icon: Icons.more_horiz_rounded,
              selected: true,
              size: 24 * scale),
          label: 'More',
        ),
      ],
    );
  }

  void _showMoreDestinations() {
    const hiddenIndices = [2, 4, 6];
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final index in hiddenIndices)
              ListTile(
                leading: Icon(_items[index].icon, color: _accent),
                title: Text(_items[index].label),
                selected: _currentIndex == index,
                onTap: () {
                  Navigator.pop(context);
                  _switchPage(index);
                },
              ),
          ],
        ),
      ),
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
  final double size;

  const _BadgeIcon({required this.icon, required this.selected, this.size = 24});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    final double scale       = size / 24.0;
    final double badgeFont   = (9 * scale).clamp(9, 26);
    final double badgePadH   = 5 * scale;
    final double badgePadV   = 2 * scale;
    final double badgeBorder = (1.5 * scale).clamp(1.5, 4);
    final double badgeTop    = -4 * scale;
    final double badgeRight  = -6 * scale;

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
            Icon(icon, size: size),
            if (unread > 0)
              Positioned(
                top: badgeTop,
                right: badgeRight,
                child: Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: badgePadH, vertical: badgePadV),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0077B6),
                    borderRadius: BorderRadius.circular(10 * scale),
                    border: Border.all(
                        color: const Color(0xFFDAEEFA), width: badgeBorder),
                  ),
                  child: Text(
                    '$unread',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: badgeFont,
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
          const Text('VoiceMate',
              style: TextStyle(
                  color: _accent,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  letterSpacing: 0.5)),
        ]),
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProfileScreen()),
          ),
          child: Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: _accentTint,
              shape: BoxShape.circle,
              border: Border.all(color: _accentBorder),
            ),
            child: const Icon(Icons.person, color: _accent, size: 18),
          ),
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
          final error = snapshot.error;
          final permissionDenied =
              error is FirebaseException && error.code == 'permission-denied';
          return _emptyState(
            icon: Icons.error_outline,
            message: 'Failed to load history',
            subtitle: permissionDenied
                ? 'Firestore denied access. Deploy the project Firestore rules with: firebase deploy --only firestore:rules'
                : error.toString(),
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
// PROGRESS / GAMIFICATION SCREEN
// Connected to the admin panel: badge tiers + their 5 tasks come live from the
// Firestore `badges` collection. User progress is saved on users/{uid}:
//   badgeProgress : { badgeId: [completed task indexes] }
//   level         : total completed tasks (admin reads this)
//   streak        : mirrors trainingStreak (admin reads this)
//   badgeId / badgeName / badgeEmoji : highest badge earned
// ─────────────────────────────────────────────────────────────────────────────

/// Badge tier as defined by the admin.
class _BadgeInfo {
  final String id;
  final String emoji;
  final String label;
  final int minLevel;
  final Color color;
  final List<String> tasks;

  /// Exact rules saved by the admin form (`task_defs`), one per task slot.
  /// null = older badge that only has plain text.
  final List<Map<String, dynamic>?> taskDefs;

  const _BadgeInfo({
    required this.id,
    required this.emoji,
    required this.label,
    required this.minLevel,
    required this.color,
    required this.tasks,
    this.taskDefs = const [],
  });

  /// Indexes of tasks the admin actually filled in.
  List<int> get activeTaskIndexes => [
        for (int i = 0; i < tasks.length; i++)
          if (tasks[i].trim().isNotEmpty) i
      ];
}

/// Which activity counter a task reads, and how many are needed.
class _TaskRule {
  final String key;
  final int target;
  const _TaskRule(this.key, this.target);
}

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
  static const _gold         = Color(0xFFF5A623);
  static const _green        = Color(0xFF27AE60);

  // ── Parse admin badges ─────────────────────────────────────────────────────
  List<_BadgeInfo> _parseBadges(QuerySnapshot<Map<String, dynamic>> snap) {
    final list = snap.docs.map((doc) {
      final data = doc.data();
      final rawTasks = data['tasks'];
      final tasks = rawTasks is List
          ? rawTasks.map((t) => t.toString()).toList()
          : (data['badge_description'] ?? '')
              .toString()
              .split(' | ')
              .where((t) => t.trim().isNotEmpty)
              .toList();
      while (tasks.length < 5) {
        tasks.add('');
      }
      final rawDefs = data['task_defs'];
      final defs = <Map<String, dynamic>?>[
        if (rawDefs is List)
          for (final d in rawDefs)
            d is Map ? Map<String, dynamic>.from(d) : null,
      ];
      while (defs.length < 5) {
        defs.add(null);
      }
      final rawColor = data['color'];
      final colorValue = rawColor is num ? rawColor.toInt() : _accent.value;
      return _BadgeInfo(
        id:       doc.id,
        emoji:    (data['emoji'] ?? '🏅').toString(),
        label:    (data['badge_name'] ?? 'Unnamed Badge').toString(),
        minLevel: (data['min_level'] as num?)?.toInt() ?? 0,
        color:    Color(colorValue),
        tasks:    tasks.take(5).toList(),
        taskDefs: defs.take(5).toList(),
      );
    }).toList();
    list.sort((a, b) => a.minLevel.compareTo(b.minLevel));
    return list;
  }

  Map<String, Set<int>> _parseProgress(Map<String, dynamic> userData) {
    final raw = userData['badgeProgress'];
    final result = <String, Set<int>>{};
    if (raw is Map) {
      raw.forEach((k, v) {
        if (v is List) {
          result[k.toString()] =
              v.whereType<num>().map((n) => n.toInt()).toSet();
        }
      });
    }
    return result;
  }

  // Only count tasks that still exist (admin may edit/remove them).
  Set<int> _validDone(_BadgeInfo b, Map<String, Set<int>> progress) {
    final active = b.activeTaskIndexes.toSet();
    return (progress[b.id] ?? <int>{}).where(active.contains).toSet();
  }

  bool _isEarned(_BadgeInfo b, Map<String, Set<int>> progress, int level) {
    final active = b.activeTaskIndexes;
    if (active.isEmpty) return false;
    return level >= b.minLevel &&
        _validDone(b, progress).length == active.length;
  }

  int _levelFrom(List<_BadgeInfo> badges, Map<String, Set<int>> progress) {
    int level = 0;
    for (final b in badges) {
      level += _validDone(b, progress).length;
    }
    return level;
  }

  _BadgeInfo? _highestEarned(
      List<_BadgeInfo> badges, Map<String, Set<int>> progress, int level) {
    _BadgeInfo? best;
    for (final b in badges) {
      if (_isEarned(b, progress, level)) {
        if (best == null || b.minLevel >= best.minLevel) best = b;
      }
    }
    return best;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // AUTOMATIC TASKS — no checkboxes. Every task is tied to a real activity
  // counter and ticks itself once the counter reaches the target.
  //
  //   Admin form (task_defs)      counter read from Firestore
  //   ─────────────────────────   ───────────────────────────────────────
  //   Maintain a streak (days)    longest of trainingStreak / longestStreak
  //   Add new words               wordsAdded (BadgeTracker.wordAdded)
  //   Training sessions           trainingSessions (BadgeTracker...)
  //   Phoneme drill score %       phonemeGe{50..100} (BadgeTracker...)
  //
  // Older badges that only have plain text are matched by keywords instead.
  //
  // Badges unlock in order: a badge is locked until the previous tier is
  // earned (see _autoProgress). The min level is also needed to EARN a badge
  // (see _isEarned) — level rises by +1 for every completed task.
  // ══════════════════════════════════════════════════════════════════════════
  bool _syncing = false;

  _TaskRule? _ruleFor(_BadgeInfo b, int i) {
    final def = i < b.taskDefs.length ? b.taskDefs[i] : null;
    if (def != null) {
      int target = (def['target'] as num?)?.toInt() ?? 1;
      if (target < 1) target = 1;
      switch (def['type']) {
        case 'streak':
          return _TaskRule('streak', target);
        case 'newWord':
          return _TaskRule('wordsAdded', target);
        case 'trainingSession':
          return _TaskRule('trainingSessions', target);
        case 'phonemeDrill':
          final min = (def['min_score'] as num?)?.toInt() ?? 70;
          return _TaskRule('phonemeGe$min', target);
      }
    }
    return _ruleFromText(b.tasks[i]);
  }

  /// Fallback for old badges: guess the counter from the task wording.
  _TaskRule? _ruleFromText(String text) {
    final s = text.toLowerCase();
    // numbers that are NOT percentages ("80%" is a score, not a count)
    final counts = RegExp(r'\d+(?!\s*%|\d)')
        .allMatches(s)
        .map((m) => int.parse(m.group(0)!))
        .toList();
    int target = counts.isEmpty ? 1 : counts.first;
    if (counts.isEmpty) {
      // number written as a word: "train ten times"
      const numberWords = {
        'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5, 'six': 6,
        'seven': 7, 'eight': 8, 'nine': 9, 'ten': 10, 'fifteen': 15,
        'twenty': 20, 'thirty': 30, 'fifty': 50, 'hundred': 100,
      };
      final w = RegExp('\\b(${numberWords.keys.join('|')})\\b').firstMatch(s);
      if (w != null) target = numberWords[w.group(1)!]!;
    }
    if (target < 1) target = 1;

    if (s.contains('phoneme') || s.contains('drill')) {
      final pct = RegExp(r'(\d+)\s*%').firstMatch(s);
      int min = pct == null ? 70 : int.parse(pct.group(1)!);
      min = BadgeTracker.phonemeThresholds
          .firstWhere((t) => t >= min, orElse: () => 100);
      return _TaskRule('phonemeGe$min', target);
    }
    if (s.contains('session')) return _TaskRule('trainingSessions', target);
    if (s.contains('streak') || s.contains('day')) {
      return _TaskRule('streak', target);
    }
    if (s.contains('word') || s.contains('vocab')) {
      return _TaskRule('wordsAdded', target);
    }
    if (s.contains('correct') || s.contains('teach')) {
      return _TaskRule('corrections', target);
    }
    if (s.contains('translat') ||
        s.contains('sentence') ||
        s.contains('phrase')) {
      return _TaskRule('sentences', target);
    }
    // "Train 10 times" = 10 finished training sessions
    if (s.contains('train')) return _TaskRule('trainingSessions', target);
    return null;
  }

  bool _taskMet(_BadgeInfo b, int i, Map<String, dynamic> stats) {
    final rule = _ruleFor(b, i);
    if (rule == null) return false;
    final value = (stats[rule.key] as num?)?.toInt() ?? 0;
    return value >= rule.target;
  }

  bool _sameSet(Set<int> a, Set<int> b) =>
      a.length == b.length && a.containsAll(b);

  /// Badges unlock one after another (lowest tier first). A badge stays
  /// LOCKED — none of its tasks tick — until the badge before it is earned.
  Map<String, Set<int>> _autoProgress(
      List<_BadgeInfo> badges, Map<String, dynamic> stats) {
    final result = <String, Set<int>>{};
    bool previousEarned = true; // the first tier is always open
    for (final b in badges) {
      if (!previousEarned) {
        result[b.id] = <int>{}; // locked
        continue;
      }
      result[b.id] = <int>{
        for (final i in b.activeTaskIndexes)
          if (_taskMet(b, i, stats)) i
      };
      previousEarned = _isEarned(b, result, _levelFrom(badges, result));
    }
    return result;
  }

  /// Is this badge open? (first tier, or the previous tier is earned)
  bool _isUnlocked(List<_BadgeInfo> badges, _BadgeInfo b,
      Map<String, Set<int>> progress, int level) {
    final idx = badges.indexWhere((x) => x.id == b.id);
    if (idx <= 0) return true;
    return _isEarned(badges[idx - 1], progress, level);
  }

  bool _progressChanged(List<_BadgeInfo> badges, Map<String, Set<int>> stored,
      Map<String, Set<int>> auto) {
    for (final b in badges) {
      if (!_sameSet(_validDone(b, stored), auto[b.id] ?? <int>{})) return true;
    }
    return false;
  }

  // ── Save to Firebase automatically ─────────────────────────────────────────
  //   users/{uid}                        level, streak, badgeProgress, badge...
  //   users/{uid}/badgeRecords/{badgeId} one record per badge
  //   users/{uid}/records/progress       streak + level summary
  Future<void> _syncAuto({
    required String uid,
    required List<_BadgeInfo> badges,
    required Map<String, Set<int>> oldProgress,
    required Map<String, Set<int>> newProgress,
    required int streak,
  }) async {
    if (_syncing) return;
    _syncing = true;
    try {
      final oldLevel = _levelFrom(badges, oldProgress);
      final newLevel = _levelFrom(badges, newProgress);
      final top = _highestEarned(badges, newProgress, newLevel);

      final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
      final summaryRef = userRef.collection('records').doc('progress');
      final summarySnap = await summaryRef.get();
      final oldLongest =
          (summarySnap.data()?['longestStreak'] as num?)?.toInt() ?? 0;
      final oldHighest =
          (summarySnap.data()?['highestLevel'] as num?)?.toInt() ?? 0;

      final batch = FirebaseFirestore.instance.batch();
      _BadgeInfo? newlyEarned;
      int totalEarned = 0;

      for (final b in badges) {
        final done = newProgress[b.id] ?? <int>{};
        final nowEarned = _isEarned(b, newProgress, newLevel);
        final wasEarned = _isEarned(b, oldProgress, oldLevel);
        if (nowEarned) totalEarned++;
        if (nowEarned && !wasEarned) newlyEarned = b;

        batch.set(
          userRef.collection('badgeRecords').doc(b.id),
          {
            'badgeId':        b.id,
            'badgeName':      b.label,
            'emoji':          b.emoji,
            'minLevel':       b.minLevel,
            'completedTasks': (done.toList()..sort()),
            'totalTasks':     b.activeTaskIndexes.length,
            'isEarned':       nowEarned,
            'levelAtUpdate':  newLevel,
            'streakAtUpdate': streak,
            'updatedAt':      FieldValue.serverTimestamp(),
            if (nowEarned && !wasEarned)
              'earnedAt': FieldValue.serverTimestamp(),
            if (!nowEarned && wasEarned) 'earnedAt': FieldValue.delete(),
          },
          SetOptions(merge: true),
        );
      }

      batch.set(
        userRef,
        {
          'badgeProgress': {
            for (final b in badges)
              b.id: ((newProgress[b.id] ?? <int>{}).toList()..sort()),
          },
          'level':      newLevel,
          'streak':     streak,
          'longestStreak': streak > oldLongest ? streak : oldLongest,
          'badgeId':    top?.id ?? '',
          'badgeName':  top?.label ?? '',
          'badgeEmoji': top?.emoji ?? '',
          'updatedAt':  FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      batch.set(
        summaryRef,
        {
          'currentStreak': streak,
          'longestStreak': streak > oldLongest ? streak : oldLongest,
          'currentLevel':  newLevel,
          'highestLevel':  newLevel > oldHighest ? newLevel : oldHighest,
          'badgesEarned':  totalEarned,
          'updatedAt':     FieldValue.serverTimestamp(),
          if (!summarySnap.exists) 'createdAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      await batch.commit();

      if (mounted && newlyEarned != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${newlyEarned.emoji} Badge earned: ${newlyEarned.label}!',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700)),
          backgroundColor: newlyEarned.color,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(12),
        ));
      }
    } catch (e) {
      debugPrint('Auto progress sync failed: $e');
    } finally {
      _syncing = false;
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────
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
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('translations')
                          .where('userId', isEqualTo: user.uid)
                          .snapshots(),
                      builder: (context, sentSnap) {
                        return StreamBuilder<
                            QuerySnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance
                              .collection('users')
                              .doc(user.uid)
                              .collection('corrections')
                              .where('source', isEqualTo: 'user')
                              .snapshots(),
                          builder: (context, corrSnap) {
                            if (!sentSnap.hasData && !corrSnap.hasData) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 60),
                                  child: CircularProgressIndicator(
                                      color: _accent, strokeWidth: 2),
                                ),
                              );
                            }
                            return _buildContent(
                              user.uid,
                              sentSnap.data?.docs.length ?? 0,
                              corrSnap.data?.docs.length ?? 0,
                            );
                          },
                        );
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

  Widget _buildContent(String uid, int sentences, int corrections) {

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('badges').snapshots(),
      builder: (context, badgeSnap) {
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .snapshots(),
          builder: (context, userSnap) {
            if (badgeSnap.connectionState == ConnectionState.waiting ||
                userSnap.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: CircularProgressIndicator(
                      color: _accent, strokeWidth: 2),
                ),
              );
            }

            final badges   = badgeSnap.hasData
                ? _parseBadges(badgeSnap.data!)
                : <_BadgeInfo>[];
            final userData = userSnap.data?.data() ?? {};
            final streak =
                (userData['trainingStreak'] as num?)?.toInt() ?? 0;
            int n(String k) => (userData[k] as num?)?.toInt() ?? 0;
            final longest = n('longestStreak');
            // words taught: tracked counter, or at least one per correction
            final wordsField = n('wordsAdded');
            final wordsAdded =
                wordsField > corrections ? wordsField : corrections;
            final stats = <String, dynamic>{
              // best streak ever, so a finished streak task stays ticked
              'streak':           streak > longest ? streak : longest,
              'corrections':      corrections,
              'wordsAdded':       wordsAdded,
              'sentences':        sentences,
              'trainingSessions': n('trainingSessions'),
              'phonemeDrills':    n('phonemeDrills'),
              for (final t in BadgeTracker.phonemeThresholds)
                'phonemeGe$t': n('phonemeGe$t'),
            };
            final stored   = _parseProgress(userData);
            final progress = _autoProgress(badges, stats);
            final level    = _levelFrom(badges, progress);

            if (badges.isNotEmpty &&
                (_progressChanged(badges, stored, progress) ||
                    userData['level'] != level ||
                    userData['streak'] != streak ||
                    ((userData['longestStreak'] as num?)?.toInt() ?? 0) <
                        streak)) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                _syncAuto(
                  uid: uid,
                  badges: badges,
                  oldProgress: stored,
                  newProgress: progress,
                  streak: streak,
                );
              });
            }
            final earned   = _highestEarned(badges, progress, level);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _streakCard(streak),
                const SizedBox(height: 16),
                _levelCard(level, earned, badges, progress),
                const SizedBox(height: 20),
                _sectionLabel('YOUR TRAINING STATS'),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _statChip('$corrections', 'Corrections',
                      Icons.spellcheck_rounded, _accent)),
                  const SizedBox(width: 8),
                  Expanded(child: _statChip('$wordsAdded', 'Words Added',
                      Icons.library_add_rounded, _gold)),
                  const SizedBox(width: 8),
                  Expanded(child: _statChip('$sentences', 'Sentences',
                      Icons.record_voice_over_rounded, _green)),
                ]),
                const SizedBox(height: 24),
                Row(children: [
                  _sectionLabel('BADGES & TASKS'),
                  const Spacer(),
                  _countPill(
                    '${badges.where((b) => _isEarned(b, progress, level)).length} / ${badges.length} earned',
                  ),
                ]),
                const SizedBox(height: 10),
                if (badgeSnap.hasError)
                  _infoBox('Could not load badges. Check your Firestore rules.')
                else if (badges.isEmpty)
                  _infoBox('No badges have been set up yet. Check back soon!')
                else
                  ...badges.map((b) => _badgeCard(
                        uid: uid,
                        badge: b,
                        badges: badges,
                        progress: progress,
                        level: level,
                        streak: streak,
                      )),
                const SizedBox(height: 40),
              ],
            );
          },
        );
      },
    );
  }

  // ── Level card ─────────────────────────────────────────────────────────────
  Widget _levelCard(int level, _BadgeInfo? earned, List<_BadgeInfo> badges,
      Map<String, Set<int>> progress) {
    // Next tier the user hasn't earned yet
    _BadgeInfo? next;
    for (final b in badges) {
      if (!_isEarned(b, progress, level)) {
        next = b;
        break;
      }
    }
    final color = earned?.color ?? _accent;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(children: [
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(earned?.emoji ?? '🎯',
                style: const TextStyle(fontSize: 24)),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Level $level',
                  style: TextStyle(
                      color: color,
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(
                earned != null
                    ? 'Current badge: ${earned.label}'
                    : 'No badge yet — complete tasks below to earn one.',
                style: const TextStyle(
                    color: _textDark,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
              if (next != null) ...[
                const SizedBox(height: 2),
                Text(
                  level >= next.minLevel
                      ? 'Next: finish all tasks for ${next.emoji} ${next.label}'
                      : 'Next: reach level ${next.minLevel} for ${next.emoji} ${next.label}',
                  style: const TextStyle(color: _textSub, fontSize: 11),
                ),
              ],
            ],
          ),
        ),
      ]),
    );
  }

  // ── Badge card with admin tasks ────────────────────────────────────────────
  Widget _badgeCard({
    required String uid,
    required _BadgeInfo badge,
    required List<_BadgeInfo> badges,
    required Map<String, Set<int>> progress,
    required int level,
    required int streak,
  }) {
    final active    = badge.activeTaskIndexes;
    final done      = _validDone(badge, progress);
    final unlocked  = _isUnlocked(badges, badge, progress, level);
    final bIndex    = badges.indexWhere((x) => x.id == badge.id);
    final prevBadge = bIndex > 0 ? badges[bIndex - 1] : null;
    final earned    = _isEarned(badge, progress, level);
    final ratio     = active.isEmpty ? 0.0 : done.length / active.length;

    final card = Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: earned
            ? badge.color.withOpacity(0.08)
            : const Color(0x1A0077B6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: earned
                ? badge.color.withOpacity(0.5)
                : _accentBorder,
            width: earned ? 1.5 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: badge.color.withOpacity(unlocked ? 0.15 : 0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Opacity(
                  opacity: unlocked ? 1 : 0.4,
                  child: Text(badge.emoji,
                      style: const TextStyle(fontSize: 22)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(badge.label,
                      style: TextStyle(
                          color: unlocked ? badge.color : _textSub,
                          fontSize: 15,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(
                    unlocked
                        ? 'Min. level ${badge.minLevel}'
                        : '🔒 Earn ${prevBadge?.emoji ?? ''} ${prevBadge?.label ?? 'the previous'} badge first',
                    style: const TextStyle(color: _textSub, fontSize: 11),
                  ),
                ],
              ),
            ),
            if (earned)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badge.color,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('EARNED',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6)),
              )
            else
              _countPill('${done.length}/${active.length}'),
          ]),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 5,
              backgroundColor: badge.color.withOpacity(0.12),
              valueColor: AlwaysStoppedAnimation<Color>(badge.color),
            ),
          ),
          const SizedBox(height: 8),
          for (final i in active)
            _taskRow(
              badge: badge,
              index: i,
              checked: done.contains(i),
              enabled: false, // automatic — completed by real activity
              onTap: () {},
            ),
          if (active.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text('No tasks have been set for this badge yet.',
                  style: TextStyle(color: _textSub, fontSize: 12)),
            ),
        ],
      ),
    );
    return unlocked ? card : Opacity(opacity: 0.6, child: card);
  }

  Widget _taskRow({
    required _BadgeInfo badge,
    required int index,
    required bool checked,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Opacity(
        opacity: enabled || checked ? 1 : 0.5,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 22, height: 22,
                margin: const EdgeInsets.only(top: 1),
                decoration: BoxDecoration(
                  color: checked ? badge.color : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: checked ? badge.color : _textSub, width: 1.5),
                ),
                child: checked
                    ? const Icon(Icons.check, color: Colors.white, size: 14)
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  badge.tasks[index],
                  style: TextStyle(
                    color: _textDark,
                    fontSize: 13,
                    height: 1.4,
                    decoration:
                        checked ? TextDecoration.lineThrough : null,
                    decorationColor: _textSub,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Small widgets ──────────────────────────────────────────────────────────
  Widget _countPill(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: _accentTint,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _accentBorder),
        ),
        child: Text(text,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _accent)),
      );

  Widget _infoBox(String text) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0x1A0077B6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _accentBorder),
        ),
        child: Text(text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _textSub, fontSize: 13)),
      );

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
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                color: color, fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(label,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: _textSub, fontSize: 10, height: 1.3)),
      ]),
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
                      child: Text('Enjoying VoiceMate?',
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
              'Your feedback has been received.\nIt helps us improve VoiceMate for everyone.',
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

          const Text('How would you rate your experience?',
              style: TextStyle(
                  color: _textDark,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 14),

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