import 'package:flutter/material.dart';
import 'dart:ui'; // for ImageFilter.blur
import 'package:firebase_core/firebase_core.dart';
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
import 'package:url_launcher/url_launcher.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
      theme: ThemeData.dark().copyWith(
        primaryColor: const Color(0xFF1D9E75),
        scaffoldBackgroundColor: const Color(0xFF0A1628),
      ),
      home: const AppLayout(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED BLURRED BACKGROUND
// ClipRect confines the BackdropFilter blur strictly to this widget's bounds,
// preventing it from bleeding onto the NavigationRail.
// ─────────────────────────────────────────────────────────────────────────────

class CleftBackground extends StatelessWidget {
  final Widget child;

  const CleftBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Background image
        Image.asset(
          'assets/images/cleft.png',
          fit: BoxFit.cover,
        ),

        // 2. Blur layer — ClipRect keeps the blur strictly inside this area
        ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 6.0, sigmaY: 6.0),
            child: const SizedBox.expand(),
          ),
        ),

        // 3. Dark teal overlay — ~85% opaque dark teal
        Container(
          color: const Color(0xD80A1F2E),
        ),

        // 4. Screen content on top
        child,
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// APP LAYOUT
// NavigationRail sits in its own solid container — completely separate from
// CleftBackground. The content area is wrapped in ClipRect so the blur from
// CleftBackground cannot bleed leftward onto the rail.
// ─────────────────────────────────────────────────────────────────────────────

class AppLayout extends StatefulWidget {
  const AppLayout({super.key});

  @override
  State<AppLayout> createState() => _AppLayoutState();
}

class _AppLayoutState extends State<AppLayout> {
  int currentIndex      = 0;
  bool showLanding      = true;
  bool showPremiumLogin = false;

  static const _teal    = Color(0xFF1D9E75);
  static const _tealDim = Color(0x261D9E75);
  static const _navBg   = Color(0xFF071520); // solid dark — never blurred

  void enterAppFlow() => setState(() {
        showLanding      = false;
        showPremiumLogin = true;
      });

  Future<void> completeLogin() async {
    try {
      await FirebaseAuth.instance.signInAnonymously();
    } catch (e) {
      debugPrint('Auth error: $e');
    }
    setState(() {
      showPremiumLogin = false;
      showLanding      = false;
      currentIndex     = 0;
    });
  }

  void switchPage(int index) => setState(() => currentIndex = index);

  void openPremium() => setState(() {
        showPremiumLogin = true;
        showLanding      = false;
      });

  void backToLanding() => setState(() {
        showPremiumLogin = false;
        showLanding      = true;
      });

  @override
  Widget build(BuildContext context) {
    Widget currentScreen;

    if (showLanding) {
      currentScreen = LandingPage(onContinue: enterAppFlow);
    } else if (showPremiumLogin) {
      currentScreen = PremiumScreen(onLogin: completeLogin, onBack: backToLanding);
    } else {
      switch (currentIndex) {
        case 0:
          currentScreen = TranslatorScreen(goToPremium: openPremium);
          break;
        case 1:
          currentScreen = const HistoryScreen();
          break;
        case 2:
          currentScreen = const SettingsScreen();
          break;
        default:
          currentScreen = TranslatorScreen(goToPremium: openPremium);
      }
    }

    final bool hideNav = showLanding || showPremiumLogin;

    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final bool isWide = constraints.maxWidth >= 800;

          if (isWide && !hideNav) {
            // ── WIDE LAYOUT ─────────────────────────────────────────────────
            return Row(
              children: [
                // Solid, sharp NavigationRail — NOT inside CleftBackground
                Container(
                  color: _navBg,
                  child: NavigationRail(
                    backgroundColor: Colors.transparent,
                    selectedIndex: currentIndex,
                    onDestinationSelected: switchPage,
                    labelType: NavigationRailLabelType.all,
                    selectedIconTheme: const IconThemeData(color: _teal),
                    unselectedIconTheme:
                        const IconThemeData(color: Colors.white38),
                    selectedLabelTextStyle: const TextStyle(
                        color: _teal,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                    unselectedLabelTextStyle: const TextStyle(
                        color: Colors.white38, fontSize: 12),
                    leading: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _tealDim,
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0x401D9E75)),
                        ),
                        child: const Icon(Icons.graphic_eq_rounded,
                            color: _teal, size: 18),
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

                // Thin divider between rail and content
                Container(width: 0.5, color: const Color(0x201D9E75)),

                // Content area — ClipRect ensures blur stays inside this area
                // and does NOT bleed back onto the NavigationRail.
                Expanded(
                  child: ClipRect(
                    child: currentScreen,
                  ),
                ),
              ],
            );
          }

          // ── NARROW LAYOUT ──────────────────────────────────────────────────
          return Scaffold(
            backgroundColor: Colors.transparent,
            body: currentScreen,
            bottomNavigationBar: hideNav
                ? null
                : Container(
                    decoration: const BoxDecoration(
                      color: _navBg,
                      border: Border(
                        top: BorderSide(
                            color: Color(0x201D9E75), width: 0.5),
                      ),
                    ),
                    child: BottomNavigationBar(
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      selectedItemColor: _teal,
                      unselectedItemColor: Colors.white38,
                      currentIndex: currentIndex,
                      onTap: switchPage,
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
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HISTORY SCREEN — teal theme + cleft.png blurred background
// ─────────────────────────────────────────────────────────────────────────────

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  static const _teal       = Color(0xFF1D9E75);
  static const _tealDim    = Color(0x261D9E75);
  static const _tealBorder = Color(0x401D9E75);
  static const _white40    = Color(0x66FFFFFF);
  static const _white12    = Color(0x1FFFFFFF);

  String searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── HEADER ──────────────────────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: _tealDim,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: _tealBorder),
                                ),
                                child: const Icon(Icons.graphic_eq_rounded,
                                    color: _teal, size: 16),
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'CleftTune',
                                style: TextStyle(
                                    color: _teal,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    letterSpacing: 0.5),
                              ),
                            ],
                          ),
                          InkWell(
                            borderRadius: BorderRadius.circular(30),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const ProfileScreen()),
                            ),
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: _tealDim,
                                shape: BoxShape.circle,
                                border: Border.all(color: _tealBorder),
                              ),
                              child: const Icon(Icons.person,
                                  color: _teal, size: 18),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 28),

                      // ── TITLE ────────────────────────────────────────────
                      Row(
                        children: [
                          Container(
                            width: 4,
                            height: 28,
                            decoration: BoxDecoration(
                              color: _teal,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'History',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),

                      const SizedBox(height: 6),
                      const Padding(
                        padding: EdgeInsets.only(left: 16),
                        child: Text(
                          'Your recent vocal bridge captures.',
                          style: TextStyle(color: _white40, fontSize: 13),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ── SEARCH BAR ───────────────────────────────────────
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: _tealDim,
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: _tealBorder),
                        ),
                        child: TextField(
                          style: const TextStyle(color: Colors.white),
                          onChanged: (v) =>
                              setState(() => searchQuery = v.toLowerCase()),
                          decoration: const InputDecoration(
                            icon: Icon(Icons.search_rounded, color: _teal),
                            hintText: 'Search history...',
                            hintStyle: TextStyle(color: _white40),
                            border: InputBorder.none,
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ── LIST ─────────────────────────────────────────────
                      Expanded(
                        child: user == null
                            ? _emptyState(
                                icon: Icons.person_off_outlined,
                                message: 'User not initialized')
                            : StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('translations')
                                    .where('userId', isEqualTo: user.uid)
                                    .orderBy('time', descending: true)
                                    .snapshots(),
                                builder: (context, snapshot) {
                                  if (!snapshot.hasData) {
                                    return const Center(
                                      child: CircularProgressIndicator(
                                          color: _teal, strokeWidth: 2),
                                    );
                                  }

                                  final docs =
                                      snapshot.data!.docs.where((doc) {
                                    final data =
                                        doc.data() as Map<String, dynamic>;
                                    return (data['text'] ?? '')
                                        .toString()
                                        .toLowerCase()
                                        .contains(searchQuery);
                                  }).toList();

                                  if (docs.isEmpty) {
                                    return _emptyState(
                                        icon: Icons
                                            .history_toggle_off_rounded,
                                        message: 'No history found');
                                  }

                                  final now       = DateTime.now();
                                  final today     = DateTime(now.year, now.month, now.day);
                                  final yesterday = today.subtract(const Duration(days: 1));

                                  final Map<String, List<QueryDocumentSnapshot>> grouped = {
                                    'TODAY': [],
                                    'YESTERDAY': [],
                                  };

                                  for (final doc in docs) {
                                    final data =
                                        doc.data() as Map<String, dynamic>;
                                    final ts = data['time'];
                                    if (ts == null) continue;
                                    final dt   = (ts as Timestamp).toDate();
                                    final date = DateTime(dt.year, dt.month, dt.day);
                                    if (date == today)
                                      grouped['TODAY']!.add(doc);
                                    else if (date == yesterday)
                                      grouped['YESTERDAY']!.add(doc);
                                  }

                                  return ListView(
                                    children: [
                                      if (grouped['TODAY']!.isNotEmpty) ...[
                                        _sectionLabel('TODAY'),
                                        const SizedBox(height: 10),
                                        ...grouped['TODAY']!
                                            .map(_chatBubble),
                                        const SizedBox(height: 20),
                                      ],
                                      if (grouped['YESTERDAY']!
                                          .isNotEmpty) ...[
                                        _sectionLabel('YESTERDAY'),
                                        const SizedBox(height: 10),
                                        ...grouped['YESTERDAY']!
                                            .map(_chatBubble),
                                      ],
                                    ],
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: _teal.withOpacity(0.6),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(label,
            style: const TextStyle(
                color: _white40,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8)),
      ],
    );
  }

  Widget _chatBubble(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final text = data['text'] ?? '';
    final dt   = (data['time'] as Timestamp).toDate();
    final time =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _white12,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _tealBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _tealDim,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.translate_rounded,
                color: _teal, size: 17),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        fontSize: 14)),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Text(time,
                      style: const TextStyle(
                          color: _white40, fontSize: 11)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(
      {required IconData icon, required String message}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: _tealDim,
              shape: BoxShape.circle,
              border: Border.all(color: _tealBorder),
            ),
            child: Icon(icon, color: _teal, size: 28),
          ),
          const SizedBox(height: 14),
          Text(message,
              style: const TextStyle(
                  color: Colors.white70, fontSize: 14)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SETTINGS SCREEN — teal theme + cleft.png blurred background
// ─────────────────────────────────────────────────────────────────────────────

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isPremium   = false;
  bool _isLoading   = true;
  bool _isUpgrading = false;
  bool _isCancelling = false;

  static const _teal       = Color(0xFF1D9E75);
  static const _tealDim    = Color(0x261D9E75);
  static const _tealBorder = Color(0x401D9E75);
  static const _cardColor  = Color(0x0DFFFFFF);
  static const _white40    = Color(0x66FFFFFF);

  // ── Payment method URLs ────────────────────────────────────────────────────
  // Replace these with your actual payment links / deep links
  static const _gcashUrl =
    'https://raw.githubusercontent.com/Cluelssly/CleftTune-Flutter-app/main/QR.jpg';      // your GCash payment link
  static const _paypalUrl  = 'https://paypal.me/yourlink'; // your PayPal.me link
  static const _gotymUrl   = 'https://gotyme.com';         // your GoTyme link

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
      setState(() {
        _isPremium = (doc.data()?['plan'] ?? '') == 'premium';
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  // ── UPGRADE ────────────────────────────────────────────────────────────────
  Future<void> _upgradeToPremium(String method) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // 1. Launch the payment URL first
    String url;
    switch (method) {
      case 'gcash':
        url = _gcashUrl;
        break;
      case 'paypal':
        url = _paypalUrl;
        break;
      case 'gotyme':
        url = _gotymUrl;
        break;
      default:
        return;
    }

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }

    // 2. Mark premium in Firestore after launching payment
    setState(() => _isUpgrading = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'plan': 'premium',
        'paymentMethod': method,
        'upgradedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      setState(() {
        _isPremium   = true;
        _isUpgrading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Row(children: [
            Icon(Icons.star_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Welcome to Premium! 🎉'),
          ]),
          backgroundColor: _teal,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (e) {
      setState(() => _isUpgrading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Upgrade failed: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  // ── CANCEL PREMIUM ─────────────────────────────────────────────────────────
  Future<void> _cancelPremium() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _isCancelling = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'plan': 'free',
        'cancelledAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      setState(() {
        _isPremium    = false;
        _isCancelling = false;
      });

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

  // ── DIALOGS ────────────────────────────────────────────────────────────────

  /// Step 1 — pick payment method
  void _showPaymentMethodDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0A2020),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.payment_rounded, color: _teal, size: 22),
          SizedBox(width: 8),
          Text('Choose Payment Method',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Select how you\'d like to pay for Premium:',
                style: TextStyle(color: _white40, fontSize: 13)),
            const SizedBox(height: 20),

            // ── GCash ──────────────────────────────────────────────────────
            _paymentMethodTile(
              label: 'GCash',
              subtitle: 'Pay via GCash e-wallet',
              icon: Icons.account_balance_wallet_rounded,
              iconColor: const Color(0xFF007DFF),
              onTap: () {
                Navigator.pop(context);
                _confirmPayment('gcash', 'GCash');
              },
            ),

            const SizedBox(height: 10),

            // ── PayPal ─────────────────────────────────────────────────────
            _paymentMethodTile(
              label: 'PayPal',
              subtitle: 'Pay via PayPal',
              icon: Icons.paypal_rounded,
              iconColor: const Color(0xFF003087),
              onTap: () {
                Navigator.pop(context);
                _confirmPayment('paypal', 'PayPal');
              },
            ),

            const SizedBox(height: 10),

            // ── GoTyme ─────────────────────────────────────────────────────
            _paymentMethodTile(
              label: 'GoTyme',
              subtitle: 'Pay via GoTyme Bank',
              icon: Icons.account_balance_rounded,
              iconColor: const Color(0xFFE63946),
              onTap: () {
                Navigator.pop(context);
                _confirmPayment('gotyme', 'GoTyme');
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: _white40)),
          ),
        ],
      ),
    );
  }

  /// Step 2 — confirm and launch
  void _confirmPayment(String method, String label) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0A2020),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Icon(Icons.star_rounded, color: _teal, size: 22),
          const SizedBox(width: 8),
          Text('Pay with $label',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _dialogFeature('Unlimited real-time subtitles'),
            _dialogFeature('Voice calibration & training'),
            _dialogFeature('Conversation history'),
            _dialogFeature('Ad-free experience'),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _tealDim,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _tealBorder),
              ),
              child: const Column(children: [
                Text('₱99 / month',
                    style: TextStyle(
                        color: _teal,
                        fontSize: 20,
                        fontWeight: FontWeight.w800)),
                Text('Cancel anytime',
                    style: TextStyle(color: _white40, fontSize: 11)),
              ]),
            ),
            const SizedBox(height: 12),
            Text(
              'You will be redirected to $label to complete your payment.',
              style: const TextStyle(color: _white40, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Back',
                style: TextStyle(color: _white40)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _teal,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 12),
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

  /// Cancel premium warning dialog
  void _showCancelWarningDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A0A0A),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded,
              color: Colors.orangeAccent, size: 24),
          SizedBox(width: 8),
          Text('Cancel Premium?',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to cancel your Premium subscription?',
              style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 14),
            _lossItem('Unlimited real-time subtitles'),
            _lossItem('Voice calibration & training'),
            _lossItem('Full conversation history'),
            _lossItem('Ad-free experience'),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.08),
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
                        color: Colors.redAccent,
                        fontSize: 11,
                        height: 1.4),
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
                    color: _teal, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 12),
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
              style: const TextStyle(color: Colors.white60, fontSize: 12)),
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
          color: const Color(0x1AFFFFFF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _tealBorder),
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
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                Text(subtitle,
                    style: const TextStyle(
                        color: _white40, fontSize: 11)),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios_rounded,
              color: _white40, size: 13),
        ]),
      ),
    );
  }

  Widget _dialogFeature(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          const Icon(Icons.check_circle_rounded, color: _teal, size: 16),
          const SizedBox(width: 8),
          Text(text,
              style: const TextStyle(
                  color: Colors.white70, fontSize: 13)),
        ]),
      );

  // ── BUILD ──────────────────────────────────────────────────────────────────
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
                              color: _teal, strokeWidth: 2))
                      : ListView(children: [
                          // ── HEADER ──────────────────────────────────────
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Row(children: [
                                GestureDetector(
                                  onTap: () => Navigator.pop(context),
                                  child: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: _tealDim,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: _tealBorder),
                                    ),
                                    child: const Icon(
                                        Icons.arrow_back_ios_new,
                                        color: _teal,
                                        size: 15),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text('Settings',
                                    style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white)),
                              ]),
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: _tealDim,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: _tealBorder),
                                ),
                                child: const Icon(Icons.person,
                                    color: _teal, size: 18),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // ── PREMIUM CARD ─────────────────────────────────
                          _isPremium
                              ? _buildPremiumActiveCard()
                              : _buildUpgradeCard(),

                          const SizedBox(height: 28),

                          // ── GENERAL ──────────────────────────────────────
                          _sectionLabel('GENERAL'),
                          const SizedBox(height: 10),
                          _optionTile(
                              'Trained Voice', Icons.graphic_eq_rounded),
                          _optionTile(
                              'Cloud Based', Icons.cloud_outlined),
                          _optionTile('Notifications',
                              Icons.notifications_none_rounded),

                          const SizedBox(height: 28),

                          // ── ABOUT ─────────────────────────────────────────
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
                                    color: _tealDim,
                                    borderRadius:
                                        BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                      Icons.info_outline_rounded,
                                      color: _teal,
                                      size: 16),
                                ),
                                const SizedBox(width: 12),
                                const Text('App Version',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14)),
                              ]),
                              const Text('v1.0.0',
                                  style: TextStyle(
                                      color: _white40, fontSize: 13)),
                            ],
                          )),
                        ]),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ── PREMIUM ACTIVE CARD ───────────────────────────────────────────────────
  Widget _buildPremiumActiveCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0E5C47), Color(0xFF1D9E75)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
              color: _teal.withOpacity(0.25),
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
              'Enjoy unlimited subtitles, voice calibration,\nand an ad-free experience.',
              style: TextStyle(
                  color: Colors.white70, fontSize: 13, height: 1.5)),

          const SizedBox(height: 16),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _premiumChip('Unlimited Subtitles'),
              _premiumChip('Voice Training'),
              _premiumChip('Ad-Free'),
              _premiumChip('History'),
            ],
          ),

          const SizedBox(height: 16),

          const Row(children: [
            Icon(Icons.check_circle_rounded,
                color: Colors.white70, size: 14),
            SizedBox(width: 6),
            Text('₱99 / month · Cancel anytime',
                style:
                    TextStyle(color: Colors.white70, fontSize: 12)),
          ]),

          const SizedBox(height: 18),

          // ── CANCEL BUTTON ─────────────────────────────────────────────
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
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Text(label,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w500)),
      );

  // ── UPGRADE CARD ──────────────────────────────────────────────────────────
  Widget _buildUpgradeCard() {
    return GestureDetector(
      onTap: _showPaymentMethodDialog,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _tealDim,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _tealBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _tealDim,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _tealBorder),
              ),
              child: const Text('PREMIUM',
                  style: TextStyle(
                      color: _teal,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8)),
            ),
            const SizedBox(height: 12),
            const Text('Upgrade to\nPremium',
                style: TextStyle(
                    fontSize: 24,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    height: 1.2)),
            const SizedBox(height: 8),
            const Text(
                'Unlimited offline translations\nand ad-free experience.',
                style: TextStyle(
                    color: _white40, fontSize: 13, height: 1.5)),
            const SizedBox(height: 16),

            // Payment method icons row
            Row(children: [
              _miniPayBadge(Icons.account_balance_wallet_rounded,
                  const Color(0xFF007DFF), 'GCash'),
              const SizedBox(width: 8),
              _miniPayBadge(Icons.paypal_rounded,
                  const Color(0xFF003087), 'PayPal'),
              const SizedBox(width: 8),
              _miniPayBadge(Icons.account_balance_rounded,
                  const Color(0xFFE63946), 'GoTyme'),
            ]),

            const SizedBox(height: 16),

            Align(
              alignment: Alignment.centerRight,
              child: _isUpgrading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          color: _teal, strokeWidth: 2))
                  : Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: _teal,
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
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

  // ── HELPERS ───────────────────────────────────────────────────────────────

  Widget _sectionLabel(String label) => Row(children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: _teal.withOpacity(0.7),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(label,
            style: const TextStyle(
                color: _white40,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8)),
      ]);

  Widget _card({required Widget child}) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _tealBorder),
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
        } else if (title == 'Notifications') {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const NotificationsScreen()));
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _tealBorder),
        ),
        child: Row(children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _tealDim,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: _teal, size: 17),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(title,
                style: const TextStyle(
                    color: Colors.white, fontSize: 14)),
          ),
          const Icon(Icons.arrow_forward_ios,
              size: 13, color: _white40),
        ]),
      ),
    );
  }
}