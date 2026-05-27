import 'package:flutter/foundation.dart';                                               // ✅ add this
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:firebase_core/firebase_core.dart';
import 'package:webview_flutter/webview_flutter.dart';                  // ✅ add this
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'profile.dart';
import 'firebase_options.dart';
import 'premium.dart';
import 'phonetic.dart';
import 'cloud.dart';
import 'notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'translator_screen.dart';
import 'landing_page.dart';
import 'package:intl/intl.dart';
import 'paymongo_service.dart';
import 'payment_webview_screen.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
 
  // ✅ Initialize Android WebView platform before anything else
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

class RootRouter extends StatefulWidget {
  const RootRouter({super.key});

  @override
  State<RootRouter> createState() => _RootRouterState();
}

class _RootRouterState extends State<RootRouter> {
  late bool _showLanding;

  @override
  void initState() {
    super.initState();
    _showLanding = FirebaseAuth.instance.currentUser == null;
  }

  void _onLandingContinue() => setState(() => _showLanding = false);

  void _onBackToLanding() => setState(() => _showLanding = true);

  @override
  Widget build(BuildContext context) {
    if (_showLanding) {
      return LandingPage(onContinue: _onLandingContinue);
    }

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

        return PremiumScreen(
          onLogin: () {},
          onBack: _onBackToLanding,
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
        Image.asset(
          'assets/images/cleft.png',
          fit: BoxFit.cover,
        ),
        ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 6.0, sigmaY: 6.0),
            child: const SizedBox.expand(),
          ),
        ),
        Container(
          color: const Color(0xE8EAF4FB),
        ),
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

  static const _accent      = Color(0xFF0077B6);
  static const _accentTint  = Color(0x260077B6);
  static const _navBg       = Color(0xFFDAEEFA);

  void _openPremium() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PremiumScreen(
          onLogin: () => Navigator.pop(context),
          onBack: ()  => Navigator.pop(context),
        ),
      ),
    );
  }

  void _switchPage(int index) => setState(() => _currentIndex = index);

  Widget get _currentScreen {
    switch (_currentIndex) {
      case 0:
        return TranslatorScreen(goToPremium: _openPremium);
      case 1:
        return const HistoryScreen();
      case 2:
        return const SettingsScreen();
      default:
        return TranslatorScreen(goToPremium: _openPremium);
    }
  }

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
                          border:
                              Border.all(color: const Color(0x400077B6)),
                        ),
                        child: const Icon(Icons.graphic_eq_rounded,
                            color: _accent, size: 18),
                      ),
                    ),
                    destinations: const [
                      NavigationRailDestination(
                        icon: Icon(Icons.mic_none_rounded),
                        selectedIcon: Icon(Icons.mic_rounded),
                        label: Text('Translate'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.history_rounded),
                        selectedIcon: Icon(Icons.history_rounded),
                        label: Text('History'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.tune_rounded),
                        selectedIcon: Icon(Icons.tune_rounded),
                        label: Text('Settings'),
                      ),
                    ],
                  ),
                ),
                Container(
                    width: 0.5, color: const Color(0x400077B6)),
                Expanded(child: ClipRect(child: _currentScreen)),
              ],
            ),
          );
        }

        // Mobile layout
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
              unselectedItemColor: Color(0xFF5A7A96),
              currentIndex: _currentIndex,
              onTap: _switchPage,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.mic_none_rounded),
                  activeIcon: Icon(Icons.mic_rounded),
                  label: 'Translate',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.history_rounded),
                  label: 'History',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.tune_rounded),
                  label: 'Settings',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HISTORY SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
 
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}
 
class _HistoryScreenState extends State<HistoryScreen> {
  // ── Theme (Sky Blue / Navy) ───────────────────────────────────────────────
  static const _accent       = Color(0xFF0077B6);
  static const _accentTint   = Color(0x260077B6);
  static const _accentBorder = Color(0x400077B6);
  static const _textSub      = Color(0xFF5A7A96);
  static const _white12      = Color(0x1A0077B6);
  static const _redDim       = Color(0x26E74C3C);
  static const _red          = Color(0xFFE74C3C);
  static const _redBorder    = Color(0x40E74C3C);
 
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();
 
  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }
 
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
        final fmt = date.year == now.year
            ? DateFormat('EEE, MMM d').format(date).toUpperCase()
            : DateFormat('EEE, MMM d, yyyy').format(date).toUpperCase();
        label = fmt;
      }
 
      grouped.putIfAbsent(label, () => []).add(doc);
    }
    return grouped;
  }
 
  Future<void> _deleteItem(QueryDocumentSnapshot doc) async {
    final confirmed = await showDialog<bool>(
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
                color: _redDim, shape: BoxShape.circle,
                border: Border.all(color: _red.withOpacity(0.5)),
              ),
              child: const Icon(Icons.delete_outline_rounded, color: _red, size: 28),
            ),
            const SizedBox(height: 16),
            const Text(
              'Delete Entry?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0D2B4E)),
            ),
            const SizedBox(height: 8),
            Text(
              'This translation will be permanently removed from your history.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF5A7A96), height: 1.5),
            ),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Color(0xFF8AAEC8)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancel',
                      style: TextStyle(color: Color(0xFF5A7A96), fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _red,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Delete',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
 
    if (confirmed == true) {
      await FirebaseFirestore.instance
          .collection('translations')
          .doc(doc.id)
          .delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Row(children: [
            Icon(Icons.check_circle_outline, color: Colors.white, size: 16),
            SizedBox(width: 8),
            Text('Entry deleted', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ]),
          backgroundColor: _red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(12),
          duration: const Duration(seconds: 2),
        ));
      }
    }
  }
 
  Future<void> _deleteAll(String uid) async {
    final confirmed = await showDialog<bool>(
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
                color: _redDim, shape: BoxShape.circle,
                border: Border.all(color: _red.withOpacity(0.5)),
              ),
              child: const Icon(Icons.delete_sweep_rounded, color: _red, size: 28),
            ),
            const SizedBox(height: 16),
            const Text(
              'Clear All History?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0D2B4E)),
            ),
            const SizedBox(height: 8),
            Text(
              'All your translation history will be permanently deleted. This cannot be undone.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF5A7A96), height: 1.5),
            ),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Color(0xFF8AAEC8)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancel',
                      style: TextStyle(color: Color(0xFF5A7A96), fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _red,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Clear All',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
 
    if (confirmed == true) {
      final batch = FirebaseFirestore.instance.batch();
      final snap  = await FirebaseFirestore.instance
          .collection('translations')
          .where('userId', isEqualTo: uid)
          .get();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Row(children: [
            Icon(Icons.check_circle_outline, color: Colors.white, size: 16),
            SizedBox(width: 8),
            Text('History cleared', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ]),
          backgroundColor: _red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(12),
          duration: const Duration(seconds: 2),
        ));
      }
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
                padding: EdgeInsets.symmetric(horizontal: padding, vertical: padding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── HEADER ────────────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(children: [
                          Container(
                            width: 32, height: 32,
                            decoration: BoxDecoration(
                              color: _accentTint, shape: BoxShape.circle,
                              border: Border.all(color: _accentBorder),
                            ),
                            child: const Icon(Icons.graphic_eq_rounded, color: _accent, size: 16),
                          ),
                          const SizedBox(width: 10),
                          const Text('CleftTune',
                              style: TextStyle(
                                  color: _accent, fontWeight: FontWeight.bold,
                                  fontSize: 16, letterSpacing: 0.5)),
                        ]),
                        InkWell(
                          borderRadius: BorderRadius.circular(30),
                          onTap: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const ProfileScreen())),
                          child: Container(
                            width: 38, height: 38,
                            decoration: BoxDecoration(
                              color: _accentTint, shape: BoxShape.circle,
                              border: Border.all(color: _accentBorder),
                            ),
                            child: const Icon(Icons.person, color: _accent, size: 18),
                          ),
                        ),
                      ],
                    ),
 
                    const SizedBox(height: 28),
 
                    // ── TITLE + CLEAR ALL ─────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(children: [
                          Container(
                            width: 4, height: 28,
                            decoration: BoxDecoration(
                              color: _accent,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text('History',
                              style: TextStyle(
                                  color: Color(0xFF0D2B4E), fontSize: 28,
                                  fontWeight: FontWeight.bold)),
                        ]),
                        if (user != null)
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
                      ],
                    ),
 
                    const SizedBox(height: 6),
                    const Padding(
                      padding: EdgeInsets.only(left: 16),
                      child: Text('Your recent vocal bridge captures.',
                          style: TextStyle(color: Color(0xFF5A7A96), fontSize: 13)),
                    ),
 
                    const SizedBox(height: 20),
 
                    // ── SEARCH BAR ────────────────────────────────────────
                    Container(
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
                            style: const TextStyle(color: Color(0xFF0D2B4E)),
                            onChanged: (v) =>
                                setState(() => _searchQuery = v.toLowerCase()),
                            decoration: const InputDecoration(
                              hintText: 'Search history...',
                              hintStyle: TextStyle(color: Color(0xFF5A7A96)),
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
                            child: const Icon(Icons.close_rounded, color: Color(0xFF5A7A96), size: 18),
                          ),
                      ]),
                    ),
 
                    const SizedBox(height: 24),
 
                    // ── LIST ──────────────────────────────────────────────
                    Expanded(
                      child: user == null
                          ? _emptyState(
                              icon: Icons.person_off_outlined,
                              message: 'Sign in to view history')
                          : StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('translations')
                                  .where('userId', isEqualTo: user.uid)
                                  .orderBy('time', descending: true)
                                  .snapshots(),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Center(
                                    child: CircularProgressIndicator(
                                        color: _accent, strokeWidth: 2),
                                  );
                                }
 
                                if (snapshot.hasError) {
                                  return _emptyState(
                                    icon: Icons.error_outline,
                                    message: 'Failed to load history',
                                  );
                                }
 
                                final allDocs =
                                    snapshot.data?.docs ?? [];
 
                                final filtered = allDocs.where((doc) {
                                  final data =
                                      doc.data() as Map<String, dynamic>;
                                  return (data['text'] ?? '')
                                      .toString()
                                      .toLowerCase()
                                      .contains(_searchQuery);
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
                                        ? 'Translated conversations will appear here.'
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
                                      ...entry.value.map((doc) =>
                                          _chatBubble(doc, user.uid)),
                                      const SizedBox(height: 20),
                                    ],
 
                                    const SizedBox(height: 8),
                                  ],
                                );
                              },
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
 
  Widget _sectionLabel(String label, int count) {
    return Row(children: [
      Container(
        width: 3, height: 14,
        decoration: BoxDecoration(
          color: const Color(0xFF0077B6).withOpacity(0.6),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 8),
      Text(label,
          style: const TextStyle(
              color: Color(0xFF5A7A96), fontSize: 11,
              fontWeight: FontWeight.w600, letterSpacing: 0.8)),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0x260077B6),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text('$count',
            style: const TextStyle(
                color: Color(0xFF0077B6), fontSize: 10, fontWeight: FontWeight.w700)),
      ),
    ]);
  }
 
  Widget _chatBubble(QueryDocumentSnapshot doc, String uid) {
    final data = doc.data() as Map<String, dynamic>;
    final text = data['text'] ?? '';
    final dt   = (data['time'] as Timestamp).toDate();
 
    final now      = DateTime.now();
    final today    = DateTime(now.year, now.month, now.day);
    final docDay   = DateTime(dt.year, dt.month, dt.day);
    final timeStr  = DateFormat('hh:mm a').format(dt);
    final dateStr  = docDay == today
        ? timeStr
        : '${DateFormat('MMM d').format(dt)} · $timeStr';
 
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
            Text('Delete', style: TextStyle(color: _red, fontWeight: FontWeight.w600, fontSize: 13)),
            SizedBox(width: 8),
            Icon(Icons.delete_outline_rounded, color: _red, size: 20),
          ],
        ),
      ),
      confirmDismiss: (_) async {
        await _deleteItem(doc);
        return false;
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFDAEEFA),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _accentBorder),
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
                    child: const Icon(Icons.translate_rounded, color: _accent, size: 17),
                  ),
                  const SizedBox(width: 12),
 
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(text,
                            style: const TextStyle(
                                color: Color(0xFF0D2B4E),
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                                height: 1.4)),
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
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
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

                            GestureDetector(
                              onTap: () => _deleteItem(doc),
                              child: Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: _redDim,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: _redBorder),
                                ),
                                child: const Icon(Icons.delete_outline_rounded,
                                    color: _red, size: 14),
                              ),
                            ),
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
      ),
    );
  }
 
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
            color: const Color(0x260077B6), shape: BoxShape.circle,
            border: Border.all(color: const Color(0x400077B6)),
          ),
          child: Icon(icon, color: const Color(0xFF0077B6), size: 30),
        ),
        const SizedBox(height: 16),
        Text(message,
            style: const TextStyle(
                color: Color(0xFF0D2B4E), fontSize: 15, fontWeight: FontWeight.w600)),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF5A7A96), fontSize: 13)),
        ],
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SETTINGS SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isPremium    = false;
  bool _isLoading    = true;
  bool _isUpgrading  = false;
  bool _isCancelling = false;

  // ── Theme (Sky Blue / Navy) ────────────────────────────────────────────────
  static const _accent       = Color(0xFF0077B6);
  static const _accentTint   = Color(0x260077B6);
  static const _accentBorder = Color(0x400077B6);
  static const _textDark     = Color(0xFF0D2B4E);
  static const _textSub      = Color(0xFF5A7A96);
  static const _cardColor    = Color(0x1A0077B6);

static const _successUrl = 'https://example.com/success';
static const _failedUrl  = 'https://example.com/failed';

  @override
  void initState() {
    super.initState();
    _loadPlanStatus();
  }

  Future<void> _loadPlanStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data            = doc.data() ?? {};
      final isPremiumByPlan = (data['plan'] ?? '') == 'premium';
      final isPremiumByFlag = data['isPremium'] == true;

      setState(() {
        _isPremium = isPremiumByPlan || isPremiumByFlag;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _upgradeToPremium(String method) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isUpgrading = true);

    try {
      final email = user.email?.isNotEmpty == true
          ? user.email!
          : 'noemail@yourapp.com';
      final name = user.displayName?.isNotEmpty == true
          ? user.displayName!
          : 'App User';

      const int amountCentavos = 9900;
      String checkoutUrl;

      if (method == 'gcash') {
        final source = await PaymongoService.createSource(
          type:           'gcash',
          amountCentavos: amountCentavos,
          successUrl:     _successUrl,
          failedUrl:      _failedUrl,
          name:           name,
          email:          email,
        );
        checkoutUrl = PaymongoService.checkoutUrlFrom(source);
      } else {
        checkoutUrl = await PaymongoService.createPaymentIntentCheckoutUrl(
          paymentMethodType: 'paymaya',
          amountCentavos:    amountCentavos,
          successUrl:        _successUrl,
          failedUrl:         _failedUrl,
          name:              name,
          email:             email,
        );
      }

      setState(() => _isUpgrading = false);

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentWebViewScreen(
            checkoutUrl: checkoutUrl,
            successUrl:  _successUrl,
            failedUrl:   _failedUrl,
            onSuccess:   () => _onPaymentSuccess(method),
            onFailed:    _onPaymentFailed,
          ),
        ),
      );
    } catch (e) {
      setState(() => _isUpgrading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Payment error: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
  }

  Future<void> _onPaymentSuccess(String method) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'plan':          'premium',
        'isPremium':     true,
        'subscription':  'premium',
        'paymentMethod': method,
        'upgradedAt':    FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await FirebaseFirestore.instance
          .collection('payments')
          .add({
        'userId':        user.uid,
        'email':         user.email ?? 'noemail@yourapp.com',
        'name':          user.displayName ?? 'App User',
        'amount':        99,
        'method':        method,
        'status':        'verified',
        'isDemo':        false,
        'plan':          'premium',
        'createdAt':     FieldValue.serverTimestamp(),
        'paidAt':        FieldValue.serverTimestamp(),
      });

      setState(() => _isPremium = true);

      await NotificationHelper.premiumActivated(method: method);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Row(children: [
            Icon(Icons.star_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Welcome to Premium! 🎉'),
          ]),
          backgroundColor: _accent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not activate premium: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  void _onPaymentFailed() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Row(children: [
        Icon(Icons.cancel_outlined, color: Colors.white, size: 18),
        SizedBox(width: 8),
        Text('Payment was not completed. Please try again.'),
      ]),
      backgroundColor: Colors.redAccent,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  Future<void> _cancelPremium() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _isCancelling = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'plan':         'free',
        'isPremium':    false,
        'subscription': 'free',
        'cancelledAt':  FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      setState(() {
        _isPremium    = false;
        _isCancelling = false;
      });

      await NotificationHelper.premiumCancelled();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Row(children: [
            Icon(Icons.cancel_outlined, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Premium subscription cancelled.'),
          ]),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (e) {
      setState(() => _isCancelling = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Cancellation failed: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  void _showPaymentMethodDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFFEAF4FB),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.payment_rounded, color: _accent, size: 22),
          SizedBox(width: 8),
          Text('Choose Payment Method',
              style: TextStyle(
                  color: _textDark,
                  fontSize: 17,
                  fontWeight: FontWeight.bold)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Select how you'd like to pay for Premium:",
                style: TextStyle(color: _textSub, fontSize: 13)),
            const SizedBox(height: 20),
            _paymentMethodTile(
              label:     'GCash',
              subtitle:  'Opens the GCash app to pay ₱99',
              icon:      Icons.account_balance_wallet_rounded,
              iconColor: const Color(0xFF007DFF),
              onTap: () {
                Navigator.pop(context);
                _confirmPayment('gcash', 'GCash');
              },
            ),
            const SizedBox(height: 10),
            _paymentMethodTile(
              label:     'Maya',
              subtitle:  'Opens the Maya app to pay ₱99',
              icon:      Icons.credit_card_rounded,
              iconColor: const Color(0xFF6C3BE8),
              onTap: () {
                Navigator.pop(context);
                _confirmPayment('maya', 'Maya');
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: _textSub)),
          ),
        ],
      ),
    );
  }

  void _confirmPayment(String method, String label) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFFEAF4FB),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Icon(Icons.star_rounded, color: _accent, size: 22),
          const SizedBox(width: 8),
          Text('Pay with $label',
              style: const TextStyle(
                  color: _textDark,
                  fontSize: 17,
                  fontWeight: FontWeight.bold)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _dialogFeature('Real-time Translation'),
            _dialogFeature('Noise Cancellation'),
            _dialogFeature('Unlimited Words'),
            _dialogFeature('Ad-free experience'),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _accentTint,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _accentBorder),
              ),
              child: const Column(children: [
                Text('₱99 / month',
                    style: TextStyle(
                        color: _accent,
                        fontSize: 20,
                        fontWeight: FontWeight.w800)),
                Text('Cancel anytime',
                    style: TextStyle(color: _textSub, fontSize: 11)),
              ]),
            ),
            const SizedBox(height: 12),
            Text(
              'Tapping "Pay with $label" will open a secure checkout page. '
              "You'll then be redirected to $label to confirm payment.",
              style: const TextStyle(color: _textSub, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Back', style: TextStyle(color: _textSub)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            onPressed: () async {
              Navigator.pop(context);
              await _upgradeToPremium(method);
            },
            child: Text('Pay with $label →',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showCancelWarningDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFFEAF4FB),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded,
              color: Colors.orangeAccent, size: 24),
          SizedBox(width: 8),
          Text('Cancel Premium?',
              style: TextStyle(
                  color: _textDark,
                  fontSize: 17,
                  fontWeight: FontWeight.bold)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to cancel your Premium subscription?',
              style: TextStyle(
                  color: _textSub, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 14),
            _lossItem('Real-time Translation'),
            _lossItem('Noise Cancellation'),
            _lossItem('Unlimited Words'),
            _lossItem('Ad-free experience'),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.07),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.withOpacity(0.25)),
              ),
              child: const Row(children: [
                Icon(Icons.info_outline_rounded,
                    color: Colors.redAccent, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'You will lose access to all Premium features immediately after cancellation.',
                    style: TextStyle(
                        color: Colors.redAccent, fontSize: 11, height: 1.4),
                  ),
                ),
              ]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep Premium',
                style: TextStyle(
                    color: _accent, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            onPressed: () async {
              Navigator.pop(context);
              await _cancelPremium();
            },
            child: const Text('Yes, Cancel',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _lossItem(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          const Icon(Icons.remove_circle_outline_rounded,
              color: Colors.redAccent, size: 15),
          const SizedBox(width: 8),
          Text(text,
              style: const TextStyle(color: _textSub, fontSize: 12)),
        ]),
      );

  Widget _paymentMethodTile({
    required String label,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFDAEEFA),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _accentBorder),
        ),
        child: Row(children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: _textDark,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                Text(subtitle,
                    style: const TextStyle(color: _textSub, fontSize: 11)),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios_rounded,
              color: _textSub, size: 13),
        ]),
      ),
    );
  }

  Widget _dialogFeature(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          const Icon(Icons.check_circle_rounded, color: _accent, size: 16),
          const SizedBox(width: 8),
          Text(text,
              style: const TextStyle(color: _textSub, fontSize: 13)),
        ]),
      );

  Widget _notificationsTile() {
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
        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const NotificationsScreen()),
          ),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _accentBorder),
            ),
            child: Row(children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _accentTint,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.notifications_none_rounded,
                    color: _accent, size: 17),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Notifications',
                    style: TextStyle(color: _textDark, fontSize: 14)),
              ),
              if (unread > 0)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: _accent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('$unread',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ),
              const Icon(Icons.arrow_forward_ios,
                  size: 13, color: _textSub),
            ]),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CleftBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width        = constraints.maxWidth;
              final padding      = width < 800 ? 16.0 : 40.0;
              final contentWidth = width < 1000 ? width : 900.0;

              return Center(
                child: Container(
                  width: contentWidth,
                  padding: EdgeInsets.all(padding),
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: _accent, strokeWidth: 2))
                      : ListView(children: [
                          // ── HEADER ──────────────────────────────────────
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Settings',
                                  style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: _textDark)),
                              GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const ProfileScreen()),
                                ),
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: _accentTint,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: _accentBorder),
                                  ),
                                  child: const Icon(Icons.person,
                                      color: _accent, size: 18),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          _isPremium
                              ? _buildPremiumActiveCard()
                              : _buildUpgradeCard(),

                          const SizedBox(height: 28),

                          _sectionLabel('GENERAL'),
                          const SizedBox(height: 10),
                          _optionTile(
                              'Trained Voice', Icons.graphic_eq_rounded),
                          _optionTile(
                              'Cloud Based', Icons.cloud_outlined),
                          _notificationsTile(),

                          const SizedBox(height: 28),

                          _sectionLabel('ABOUT'),
                          const SizedBox(height: 10),
                          _card(
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Row(children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: _accentTint,
                                      borderRadius:
                                          BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                        Icons.info_outline_rounded,
                                        color: _accent,
                                        size: 16),
                                  ),
                                  const SizedBox(width: 12),
                                  const Text('App Version',
                                      style: TextStyle(
                                          color: _textDark,
                                          fontSize: 14)),
                                ]),
                                const Text('v1.0.0',
                                    style: TextStyle(
                                        color: _textSub,
                                        fontSize: 13)),
                              ],
                            ),
                          ),

                          const SizedBox(height: 40),
                        ]),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumActiveCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF005F8E), Color(0xFF0077B6)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF0077B6).withOpacity(0.3),
              blurRadius: 20,
              spreadRadius: 1),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(children: [
                Icon(Icons.star_rounded, color: Colors.white, size: 13),
                SizedBox(width: 4),
                Text('PREMIUM ACTIVE',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8)),
              ]),
            ),
            const Spacer(),
            const Icon(Icons.verified_rounded,
                color: Colors.white, size: 22),
          ]),

          const SizedBox(height: 16),

          const Text("You're a Premium\nMember! 🎉",
              style: TextStyle(
                  fontSize: 22,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  height: 1.25)),

          const SizedBox(height: 10),

          const Text(
              'Enjoy unlimited words, Noise Cancellation\nand Real-time Translation.',
              style: TextStyle(
                  color: Colors.white70, fontSize: 13, height: 1.5)),

          const SizedBox(height: 16),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _premiumChip('Real-time Translation'),
              _premiumChip('Noise Cancellation'),
              _premiumChip('Ad-Free'),
              _premiumChip('Unlimited Words'),
            ],
          ),

          const SizedBox(height: 16),

          const Row(children: [
            Icon(Icons.check_circle_rounded,
                color: Colors.white70, size: 14),
            SizedBox(width: 6),
            Text('₱99 / month · Cancel anytime',
                style: TextStyle(color: Colors.white70, fontSize: 12)),
          ]),

          const SizedBox(height: 18),

          GestureDetector(
            onTap: _showCancelWarningDialog,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: Colors.redAccent.withOpacity(0.5)),
              ),
              child: _isCancelling
                  ? const Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.redAccent, strokeWidth: 2),
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.cancel_outlined,
                            color: Colors.redAccent, size: 16),
                        SizedBox(width: 6),
                        Text('Cancel Subscription',
                            style: TextStyle(
                                color: Colors.redAccent,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _premiumChip(String label) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.25)),
        ),
        child: Text(label,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w500)),
      );

  Widget _buildUpgradeCard() {
    return GestureDetector(
      onTap: _showPaymentMethodDialog,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _accentTint,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _accentBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _accentTint,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _accentBorder),
              ),
              child: const Text('PREMIUM',
                  style: TextStyle(
                      color: _accent,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8)),
            ),
            const SizedBox(height: 12),
            const Text('Upgrade to\nPremium',
                style: TextStyle(
                    fontSize: 24,
                    color: _textDark,
                    fontWeight: FontWeight.bold,
                    height: 1.2)),
            const SizedBox(height: 8),
            const Text(
                'Unlimited Words\nand Realtime Experience',
                style: TextStyle(
                    color: _textSub, fontSize: 13, height: 1.5)),
            const SizedBox(height: 16),

            Row(children: [
              _miniPayBadge(Icons.account_balance_wallet_rounded,
                  const Color(0xFF007DFF), 'GCash'),
              const SizedBox(width: 8),
              _miniPayBadge(Icons.credit_card_rounded,
                  const Color(0xFF6C3BE8), 'Maya'),
            ]),

            const SizedBox(height: 16),

            Align(
              alignment: Alignment.centerRight,
              child: _isUpgrading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          color: _accent, strokeWidth: 2))
                  : Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: _accent,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Text('Upgrade Now →',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniPayBadge(IconData icon, Color color, String label) =>
      Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w600)),
        ]),
      );

  Widget _sectionLabel(String label) => Row(children: [
        Container(
          width: 3,
          height: 14,
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

  Widget _card({required Widget child}) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _accentBorder),
        ),
        child: child,
      );

  Widget _optionTile(String title, IconData icon) {
    return GestureDetector(
      onTap: () {
        if (title == 'Trained Voice') {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const TrainedVoiceScreen()));
        } else if (title == 'Cloud Based') {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const Cloud()));
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _accentBorder),
        ),
        child: Row(children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _accentTint,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: _accent, size: 17),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(title,
                style: const TextStyle(
                    color: _textDark, fontSize: 14)),
          ),
          const Icon(Icons.arrow_forward_ios,
              size: 13, color: _textSub),
        ]),
      ),
    );
  }
}