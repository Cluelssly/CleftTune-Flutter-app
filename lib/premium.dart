import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:ui';
import 'dart:async';

class PremiumScreen extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onLogin;

  const PremiumScreen({super.key, required this.onBack, required this.onLogin});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  final TextEditingController emailController    = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool isLoginMode           = true;
  bool isLoading             = false;
  bool isGoogleLoading       = false;
  bool obscurePassword       = true;
  bool _hasInternet          = true;
  bool _showNoInternetBanner = false;

  // Password strength: 0=empty, 1=weak, 2=fair, 3=good, 4=strong
  int    _passwordStrength      = 0;
  String _passwordStrengthLabel = '';

  final FirebaseAuth _auth = FirebaseAuth.instance;

  late final GoogleSignIn _googleSignIn = kIsWeb
      ? GoogleSignIn(
          clientId: '756813986418-j2dgokq3hi229seu3hdhh6pn68pckint.apps.googleusercontent.com',
          scopes: ['email', 'profile'],
        )
      : GoogleSignIn(scopes: ['email', 'profile']);

  late StreamSubscription<List<ConnectivityResult>> _connectivitySub;

  // ── Theme constants (Sky Blue / Navy) ────────────────────────────────────
  static const _bg          = Color(0xFFEAF4FB);
  static const _surface     = Color(0xFFD6EEFF);
  static const _accent      = Color(0xFF0077B6);
  static const _accentDim   = Color(0xFF005F8E);
  static const _textDark    = Color(0xFF0D2B4E);
  static const _textSub     = Color(0xFF5A7A96);
  static const _label       = Color(0xFF0077B6);
  static const _bgMid       = Color(0xFFDAEEFA);
  static const _bgDark      = Color(0xFFC8E3F5);
  static const Color _card         = Color(0x1A0077B6);
  static const Color _accentBorder = Color(0x400077B6);
  static const Color _accentTint   = Color(0x260077B6);
  static const Color _white70      = Color(0xFF2C5B7E);
  static const Color _white40      = Color(0xFF5A7A96);
  static const Color _white30      = Color(0xFF8AAEC8);
  static const Color _fieldBg      = Color(0x120077B6);
  static const Color _gold         = Color(0xFFF5A623);
  static const Color _goldTint     = Color(0x1FF5A623);
  static const Color _goldBorder   = Color(0x40F5A623);
  static const Color _green        = Color(0xFF27AE60);
  static const Color _greenTint    = Color(0x1F27AE60);
  static const Color _greenBorder  = Color(0x4027AE60);

  static const _strengthWeak   = Color(0xFFE74C3C);
  static const _strengthFair   = Color(0xFFE67E22);
  static const _strengthGood   = Color(0xFFF1C40F);
  static const _strengthStrong = Color(0xFF0077B6);

  @override
  void initState() {
    super.initState();
    _initConnectivity();
    passwordController.addListener(_evaluatePasswordStrength);
  }

  // ── PASSWORD STRENGTH ────────────────────────────────────────────────────
  void _evaluatePasswordStrength() {
    final p = passwordController.text;
    if (p.isEmpty) {
      setState(() { _passwordStrength = 0; _passwordStrengthLabel = ''; });
      return;
    }
    int score = 0;
    if (p.length >= 8)  score++;
    if (p.length >= 12) score++;
    if (p.contains(RegExp(r'[A-Z]'))) score++;
    if (p.contains(RegExp(r'[a-z]'))) score++;
    if (p.contains(RegExp(r'[0-9]'))) score++;
    if (p.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'))) score++;

    if (score <= 1)      { setState(() { _passwordStrength = 1; _passwordStrengthLabel = 'Weak'; }); }
    else if (score <= 3) { setState(() { _passwordStrength = 2; _passwordStrengthLabel = 'Fair'; }); }
    else if (score <= 4) { setState(() { _passwordStrength = 3; _passwordStrengthLabel = 'Good'; }); }
    else                 { setState(() { _passwordStrength = 4; _passwordStrengthLabel = 'Strong'; }); }
  }

  Color get _strengthColor {
    switch (_passwordStrength) {
      case 1: return _strengthWeak;
      case 2: return _strengthFair;
      case 3: return _strengthGood;
      case 4: return _strengthStrong;
      default: return Colors.transparent;
    }
  }

  // ── CONNECTIVITY ─────────────────────────────────────────────────────────
  void _initConnectivity() {
    _connectivitySub = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      final connected = results.any((r) => r != ConnectivityResult.none);
      if (mounted) {
        setState(() {
          _hasInternet           = connected;
          _showNoInternetBanner  = !connected;
        });
        if (!connected) _showInternetWarningSnack();
      }
    });
    Connectivity().checkConnectivity().then((results) {
      if (mounted) {
        final connected = results.any((r) => r != ConnectivityResult.none);
        setState(() {
          _hasInternet           = connected;
          _showNoInternetBanner  = !connected;
        });
        if (!connected) _showInternetWarningSnack();
      }
    });
  }

  void _showInternetWarningSnack() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Row(children: [
        Icon(Icons.wifi_off_rounded, color: Colors.white, size: 18),
        SizedBox(width: 10),
        Expanded(child: Text(
          "No internet connection. Please check your network.",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
        )),
      ]),
      backgroundColor: const Color(0xFFE67E22),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(12),
      duration: const Duration(seconds: 4),
    ));
  }

  Future<bool> _checkInternet() async {
    final r = await Connectivity().checkConnectivity();
    return r.any((x) => x != ConnectivityResult.none);
  }

  // ── EMAIL AUTH ───────────────────────────────────────────────────────────
  Future<void> handleAuth() async {
    if (!await _checkInternet()) { _showInternetWarningSnack(); return; }

    final email    = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _snack("Please fill all fields", isError: true); return;
    }
    if (!RegExp(r'^[\w\.-]+@[\w\.-]+\.\w{2,}$').hasMatch(email)) {
      _snack("Enter a valid email address", isError: true); return;
    }
    if (password.length < 6) {
      _snack("Password must be at least 6 characters", isError: true); return;
    }
    if (!isLoginMode && _passwordStrength < 2) {
      _snack("Please use a stronger password", isError: true); return;
    }

    setState(() => isLoading = true);
    try {
      if (isLoginMode) {
        await _auth.signInWithEmailAndPassword(email: email, password: password);
        widget.onLogin();
      } else {
        await _auth.createUserWithEmailAndPassword(email: email, password: password);
        if (mounted) { await _showSuccessDialog(); widget.onLogin(); }
      }
    } on FirebaseAuthException catch (e) {
      final msgs = {
        'user-not-found'        : "No account found for this email",
        'wrong-password'        : "Incorrect password. Please try again",
        'invalid-credential'    : "Incorrect email or password. Please try again",
        'email-already-in-use'  : "This email is already registered",
        'weak-password'         : "Password is too weak. Use at least 6 characters",
        'invalid-email'         : "Enter a valid email address",
        'too-many-requests'     : "Too many attempts. Please try again later",
        'network-request-failed': "Network error. Check your internet connection",
        'user-disabled'         : "This account has been disabled",
      };
      _snack(msgs[e.code] ?? "Authentication failed: ${e.message}", isError: true);
    } catch (_) {
      _snack("Something went wrong. Please try again", isError: true);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ── GOOGLE SIGN-IN ───────────────────────────────────────────────────────
  Future<void> handleGoogleSignIn() async {
    if (!await _checkInternet()) { _showInternetWarningSnack(); return; }
    setState(() => isGoogleLoading = true);
    try {
      if (kIsWeb) {
        await _handleGoogleSignInWeb();
      } else {
        await _handleGoogleSignInMobile();
      }
    } finally {
      if (mounted) setState(() => isGoogleLoading = false);
    }
  }

  Future<void> _handleGoogleSignInWeb() async {
    try {
      final GoogleAuthProvider provider = GoogleAuthProvider();
      provider.addScope('email');
      provider.addScope('profile');
      final UserCredential userCredential =
          await _auth.signInWithPopup(provider);
      if (mounted) {
        final isNewUser = userCredential.additionalUserInfo?.isNewUser ?? false;
        final displayName = userCredential.user?.displayName ?? 'there';
        if (isNewUser) {
          await _showSuccessDialog(name: displayName, isGoogle: true);
        }
        widget.onLogin();
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'popup-closed-by-user' ||
          e.code == 'cancelled-popup-request') return;
      final msgs = {
        'account-exists-with-different-credential':
            "An account already exists with a different sign-in method",
        'invalid-credential'    : "Google sign-in failed. Please try again",
        'network-request-failed': "Network error. Check your internet connection",
        'popup-blocked'         : "Popup was blocked. Please allow popups and try again.",
      };
      _snack(msgs[e.code] ?? "Google sign-in failed: ${e.message}", isError: true);
    } catch (e) {
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('popup') || errStr.contains('cancel') ||
          errStr.contains('closed')) return;
      _snack("Google sign-in failed. Please try again", isError: true);
    }
  }

  Future<void> _handleGoogleSignInMobile() async {
    try {
      await _googleSignIn.signOut();
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      if (googleAuth.accessToken == null && googleAuth.idToken == null) {
        _snack("Google sign-in failed: could not obtain credentials",
            isError: true);
        return;
      }

      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken    : googleAuth.idToken,
      );

      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);

      if (mounted) {
        final isNewUser =
            userCredential.additionalUserInfo?.isNewUser ?? false;
        if (isNewUser) {
          await _showSuccessDialog(
              name: googleUser.displayName ?? 'there', isGoogle: true);
        }
        widget.onLogin();
      }
    } on FirebaseAuthException catch (e) {
      final msgs = {
        'account-exists-with-different-credential':
            "An account already exists with a different sign-in method",
        'invalid-credential'    : "Google sign-in failed. Please try again",
        'network-request-failed': "Network error. Check your internet connection",
      };
      _snack(msgs[e.code] ?? "Google sign-in failed: ${e.message}",
          isError: true);
    } catch (e) {
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('cancel') ||
          errStr.contains('sign_in_canceled') ||
          errStr.contains('sign_in_failed') && errStr.contains('12501')) return;
      _snack("Google sign-in failed. Please try again", isError: true);
    }
  }

  // ── SUCCESS DIALOG ───────────────────────────────────────────────────────
  Future<void> _showSuccessDialog(
      {String name = 'there', bool isGoogle = false}) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFEAF4FB), Color(0xFFD6EEFF)],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _accentBorder, width: 1.2),
            boxShadow: [
              BoxShadow(
                  color: _accent.withOpacity(0.15),
                  blurRadius: 30,
                  spreadRadius: 2),
            ],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: _accentTint,
                shape: BoxShape.circle,
                border: Border.all(color: _accent, width: 1.5),
                boxShadow: [
                  BoxShadow(
                      color: _accent.withOpacity(0.25),
                      blurRadius: 20,
                      spreadRadius: 2)
                ],
              ),
              child:
                  const Icon(Icons.check_rounded, color: _accent, size: 36),
            ),
            const SizedBox(height: 20),
            const Text(
              "Account Created!",
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: _textDark,
                  letterSpacing: -0.3),
            ),
            const SizedBox(height: 8),
            Text(
              isGoogle
                  ? "Welcome, $name!\nSigned in with Google successfully."
                  : "Welcome to CleftTune.\nYou're all set to get started!",
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 13, color: _textSub, height: 1.6),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  "Get Started",
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.2),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ── FORGOT PASSWORD ──────────────────────────────────────────────────────
  void _openForgotPassword() {
    final prefill = emailController.text.trim();
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black.withOpacity(0.4),
        pageBuilder: (_, __, ___) =>
            _ForgotPasswordScreen(prefillEmail: prefill),
        transitionsBuilder: (_, animation, __, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
            child: child,
          );
        },
      ),
    );
  }

  void _snack(String msg, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(
            isError
                ? Icons.error_outline
                : Icons.check_circle_outline,
            color: Colors.white,
            size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(msg,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14)),
        ),
      ]),
      backgroundColor: isError ? Colors.redAccent : _accent,
      behavior: SnackBarBehavior.floating,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(12),
      duration: const Duration(seconds: 3),
    ));
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    _connectivitySub.cancel();
    super.dispose();
  }

  // ── BUILD ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── 1. Background image (log.png) ──────────────────────────────
          Image.asset(
            'assets/images/log.png',
            fit: BoxFit.cover,
          ),

          // ── 2. Frosted-glass blur over the image ───────────────────────
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              color: const Color(0xAAEAF4FB), // semi-transparent sky-blue tint
            ),
          ),

          // ── 3. Gradient overlay for extra depth ────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0x55EAF4FB),
                  Color(0x44DAeefa),
                  Color(0x33C8E3F5),
                ],
              ),
            ),
          ),

          // ── 4. Actual content ──────────────────────────────────────────
          SafeArea(
            child: Column(children: [
              if (_showNoInternetBanner)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: double.infinity,
                  color: const Color(0xFFE67E22).withOpacity(0.9),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  child: Row(children: [
                    const Icon(Icons.wifi_off_rounded,
                        color: Colors.white, size: 16),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        "No internet connection. Some features may not work.",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                    GestureDetector(
                      onTap: () =>
                          setState(() => _showNoInternetBanner = false),
                      child: const Icon(Icons.close_rounded,
                          color: Colors.white, size: 16),
                    ),
                  ]),
                ),
              Expanded(
                child: LayoutBuilder(builder: (context, constraints) {
                  return constraints.maxWidth < 800
                      ? _buildMobile()
                      : _buildDesktop();
                }),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildMobile() => SingleChildScrollView(
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAboutSection(),
              const SizedBox(height: 28),
              _buildLoginCard(),
              const SizedBox(height: 24),
            ]),
      );

  // ── DESKTOP: left side is non-scrollable, fills the height ───────────────
  Widget _buildDesktop() => Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // LEFT — fixed, non-scrollable, fills full height
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: _buildAboutSection(),
            ),
          ),
          Container(width: 1, color: _accent.withOpacity(0.12)),
          // RIGHT — scrollable login card
          Expanded(
            child: Center(
              child: SizedBox(
                width: 380,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(40),
                  child: _buildLoginCard(),
                ),
              ),
            ),
          ),
        ],
      );

  // ── ABOUT / INFO SECTION — compact square cards, no scroll ───────────────
  Widget _buildAboutSection() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── App identity ─────────────────────────────────────────────────
          Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: _accent,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                      color: _accent.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4)),
                ],
              ),
              child: const Icon(Icons.graphic_eq_rounded,
                  color: Colors.white, size: 22),
            ),
            const SizedBox(width: 10),
            RichText(
              text: const TextSpan(children: [
                TextSpan(
                    text: 'Cleft',
                    style: TextStyle(
                        color: _textDark,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        letterSpacing: -0.5)),
                TextSpan(
                    text: 'Tune',
                    style: TextStyle(
                        color: _accent,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        letterSpacing: -0.5)),
              ]),
            ),
          ]),

          const SizedBox(height: 12),

          const Text(
            'Your voice, trained by you.',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: _textDark,
                height: 1.2,
                letterSpacing: -0.3),
          ),
          const SizedBox(height: 6),
          const Text(
            'A real-time speech assistant for people with cleft palate. '
            'It learns your unique voice and improves every session.',
            style: TextStyle(fontSize: 12, color: _textSub, height: 1.6),
          ),

          const SizedBox(height: 16),

          // ── 2×3 square card grid ──────────────────────────────────────────
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final cardWidth =
                    (constraints.maxWidth - 10) / 2; // 2 cols, 10px gap
                return Column(
                  children: [
                    // Row 1 — How It Works (3 cards across)
                    Row(
                      children: [
                        _squareInfoCard(
                          icon: Icons.mic_rounded,
                          title: 'Speak',
                          subtitle: 'Capture speech in real time via mic.',
                          color: _accent,
                          flex: 1,
                        ),
                        const SizedBox(width: 10),
                        _squareInfoCard(
                          icon: Icons.auto_fix_high_rounded,
                          title: 'Correct',
                          subtitle: 'Teach AI when it mishears you.',
                          color: _green,
                          flex: 1,
                        ),
                        const SizedBox(width: 10),
                        _squareInfoCard(
                          icon: Icons.trending_up_rounded,
                          title: 'Improve',
                          subtitle: 'AI learns your patterns every session.',
                          color: _gold,
                          flex: 1,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Row 2 — Streak + Tasks + Privacy
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Streak card
                        Expanded(
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [Color(0xFF005F8E), Color(0xFF0077B6)],
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                      color: _accent.withOpacity(0.22),
                                      blurRadius: 12,
                                      spreadRadius: 1),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 38, height: 38,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Center(
                                        child: Text('🔥',
                                            style: TextStyle(fontSize: 18))),
                                  ),
                                  const Spacer(),
                                  const Text('Daily Streak',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 3),
                                  const Text(
                                    'Train daily to keep it alive.',
                                    style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 10,
                                        height: 1.3),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Tasks card
                        Expanded(
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: _accentTint,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: _accentBorder),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 32, height: 32,
                                    decoration: BoxDecoration(
                                      color: _accent.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.task_alt_rounded,
                                        color: _accent, size: 16),
                                  ),
                                  const Spacer(),
                                  const Text('Daily Tasks',
                                      style: TextStyle(
                                          color: _textDark,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 6),
                                  _miniTaskRow(Icons.spellcheck_rounded,
                                      '5 corrections', _accent),
                                  const SizedBox(height: 4),
                                  _miniTaskRow(Icons.record_voice_over_rounded,
                                      '3 sentences', _green),
                                  const SizedBox(height: 4),
                                  _miniTaskRow(Icons.library_add_rounded,
                                      '10 words', _gold),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Privacy + Feedback card
                        Expanded(
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: _greenTint,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: _greenBorder),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 32, height: 32,
                                    decoration: BoxDecoration(
                                      color: _green.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.shield_outlined,
                                        color: _green, size: 16),
                                  ),
                                  const Spacer(),
                                  const Text('Private & Safe',
                                      style: TextStyle(
                                          color: _textDark,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Speech data is private and tied only to your account.',
                                    style: TextStyle(
                                        color: _green,
                                        fontSize: 10,
                                        height: 1.4,
                                        fontWeight: FontWeight.w500),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(children: [
                                    _feedbackStar(true),
                                    _feedbackStar(true),
                                    _feedbackStar(true),
                                    _feedbackStar(true),
                                    _feedbackStar(false),
                                  ]),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      );

  // ── Square info card (equal flex, aspect ratio 1) ─────────────────────────
  Widget _squareInfoCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required int flex,
  }) =>
      Expanded(
        flex: flex,
        child: AspectRatio(
          aspectRatio: 1,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withOpacity(0.07),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withOpacity(0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, color: color, size: 17),
                ),
                const Spacer(),
                Text(title,
                    style: TextStyle(
                        color: _textDark,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(subtitle,
                    style: const TextStyle(
                        color: _textSub, fontSize: 10, height: 1.3)),
              ],
            ),
          ),
        ),
      );

  Widget _miniTaskRow(IconData icon, String label, Color color) =>
      Row(children: [
        Icon(icon, color: color, size: 11),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
                color: color, fontSize: 10, fontWeight: FontWeight.w600)),
      ]);

  Widget _feedbackStar(bool filled) => Icon(
        filled ? Icons.star_rounded : Icons.star_outline_rounded,
        color: filled ? _gold : _white30,
        size: 15,
      );

  // ── LOGIN CARD ───────────────────────────────────────────────────────────
  Widget _buildLoginCard() {
    return Column(children: [
      Container(
        width: 52, height: 52,
        decoration: BoxDecoration(
          color: _accentTint,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _accentBorder),
        ),
        child: const Icon(Icons.lock_outline_rounded,
            color: _accent, size: 24),
      ),
      const SizedBox(height: 14),
      Text(
        isLoginMode ? "Sign In" : "Create Account",
        style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: _textDark),
      ),
      const SizedBox(height: 4),
      Text(
        isLoginMode
            ? "Welcome back to CleftTune"
            : "Join CleftTune today",
        style: const TextStyle(fontSize: 12, color: _textSub),
      ),
      const SizedBox(height: 28),

      // Google button
      SizedBox(
        width: double.infinity, height: 50,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: _accent.withOpacity(0.3)),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            backgroundColor: _surface,
          ),
          onPressed: isGoogleLoading ? null : handleGoogleSignIn,
          child: isGoogleLoading
              ? SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(
                      color: _accent, strokeWidth: 2))
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildGoogleLogo(),
                    const SizedBox(width: 10),
                    Text(
                      isLoginMode
                          ? "Continue with Google"
                          : "Sign up with Google",
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _textDark),
                    ),
                  ]),
        ),
      ),
      const SizedBox(height: 16),

      // Divider
      Row(children: [
        Expanded(
            child: Divider(color: _accent.withOpacity(0.15))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text("or use email",
              style: const TextStyle(fontSize: 11, color: _textSub)),
        ),
        Expanded(
            child: Divider(color: _accent.withOpacity(0.15))),
      ]),
      const SizedBox(height: 16),

      _buildFieldLabel("Email address"),
      const SizedBox(height: 6),
      _buildTextField(
        controller: emailController,
        hint: "you@example.com",
        icon: Icons.email_outlined,
        keyboardType: TextInputType.emailAddress,
      ),
      const SizedBox(height: 14),

      _buildFieldLabel("Password"),
      const SizedBox(height: 6),
      _buildTextField(
        controller: passwordController,
        hint: "••••••••",
        icon: Icons.lock_outline_rounded,
        obscure: obscurePassword,
        trailing: IconButton(
          icon: Icon(
            obscurePassword
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color: _textSub,
            size: 18,
          ),
          onPressed: () =>
              setState(() => obscurePassword = !obscurePassword),
        ),
      ),

      if (!isLoginMode && _passwordStrength > 0) ...[
        const SizedBox(height: 10),
        _buildPasswordStrengthBar(),
      ],

      if (isLoginMode) ...[
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: _openForgotPassword,
            child: const Text(
              "Forgot password?",
              style: TextStyle(
                  fontSize: 12,
                  color: _accent,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
      const SizedBox(height: 22),

      if (!_hasInternet) ...[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFE67E22).withOpacity(0.10),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: const Color(0xFFE67E22).withOpacity(0.4)),
          ),
          child: const Row(children: [
            Icon(Icons.wifi_off_rounded,
                color: Color(0xFFE67E22), size: 16),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                "No internet connection. Please reconnect to continue.",
                style: TextStyle(
                    color: Color(0xFFE67E22),
                    fontSize: 12,
                    fontWeight: FontWeight.w500),
              ),
            ),
          ]),
        ),
      ],

      SizedBox(
        width: double.infinity, height: 50,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor:
                _hasInternet ? _accent : Colors.grey.shade400,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          onPressed: isLoading ? null : handleAuth,
          child: isLoading
              ? const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isLoginMode ? "Login" : "Create Account",
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.2),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward,
                        color: Colors.white, size: 16),
                  ]),
        ),
      ),
      const SizedBox(height: 16),

      SizedBox(
        width: double.infinity, height: 48,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: _accent.withOpacity(0.25)),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            backgroundColor: _surface,
          ),
          onPressed: () => setState(() {
            isLoginMode            = !isLoginMode;
            emailController.clear();
            passwordController.clear();
            _passwordStrength      = 0;
            _passwordStrengthLabel = '';
          }),
          child: Text(
            isLoginMode
                ? "Don't have an account? Sign up"
                : "Already have an account? Login",
            style: const TextStyle(fontSize: 13, color: _textDark),
          ),
        ),
      ),
      const SizedBox(height: 20),

      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.shield_outlined, size: 13, color: _white30),
        const SizedBox(width: 5),
        const Text("Your data is safe and private.",
            style: TextStyle(fontSize: 11, color: _white30)),
      ]),
    ]);
  }

  // ── PASSWORD STRENGTH BAR ────────────────────────────────────────────────
  Widget _buildPasswordStrengthBar() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
          child: Row(
            children: List.generate(4, (index) {
              final filled = index < _passwordStrength;
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: index < 3 ? 4 : 0),
                  height: 4,
                  decoration: BoxDecoration(
                    color: filled
                        ? _strengthColor
                        : _accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          _passwordStrengthLabel,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _strengthColor),
        ),
      ]),
      const SizedBox(height: 8),
      _buildPasswordHints(),
    ]);
  }

  Widget _buildPasswordHints() {
    final p = passwordController.text;
    final hints = [
      (p.length >= 8,                             "8+ characters"),
      (p.contains(RegExp(r'[A-Z]')),              "Uppercase letter"),
      (p.contains(RegExp(r'[0-9]')),              "Number"),
      (p.contains(RegExp(r'[!@#\$%^&*(),.?]')),  "Special character"),
    ];
    return Wrap(
      spacing: 12, runSpacing: 4,
      children: hints
          .map((h) => Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(
                  h.$1
                      ? Icons.check_circle_rounded
                      : Icons.circle_outlined,
                  size: 12,
                  color: h.$1 ? _accent : _white30,
                ),
                const SizedBox(width: 4),
                Text(h.$2,
                    style: TextStyle(
                        fontSize: 11,
                        color: h.$1 ? _accent : _white30)),
              ]))
          .toList(),
    );
  }

  // ── GOOGLE LOGO ──────────────────────────────────────────────────────────
  Widget _buildGoogleLogo() => SizedBox(
        width: 20, height: 20,
        child: CustomPaint(painter: _GoogleLogoPainter()),
      );

  // ── FIELD HELPERS ────────────────────────────────────────────────────────
  Widget _buildFieldLabel(String label) => Align(
        alignment: Alignment.centerLeft,
        child: Text(label,
            style: const TextStyle(
                fontSize: 11,
                color: _label,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3)),
      );

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? trailing,
    TextInputType? keyboardType,
  }) =>
      TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        style: const TextStyle(color: _textDark, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
              const TextStyle(color: _textSub, fontSize: 14),
          prefixIcon: Icon(icon, color: _textSub, size: 18),
          suffixIcon: trailing,
          filled: true,
          fillColor: _fieldBg,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                BorderSide(color: _accent.withOpacity(0.18)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                BorderSide(color: _accent.withOpacity(0.18)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: _accent, width: 1.5),
          ),
        ),
      );
}

// ════════════════════════════════════════════════════════════════════════════
// FORGOT PASSWORD SCREEN
// ════════════════════════════════════════════════════════════════════════════

class _ForgotPasswordScreen extends StatefulWidget {
  final String prefillEmail;
  const _ForgotPasswordScreen({this.prefillEmail = ''});

  @override
  State<_ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<_ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _emailCtrl;
  late final AnimationController   _anim;
  late final Animation<double>     _fadeIn;

  String  _stage          = 'input';
  String? _errorText;
  bool    _resendCooldown = false;
  int     _cooldownSecs   = 0;
  Timer?  _cooldownTimer;

  static const _bg           = Color(0xFFEAF4FB);
  static const _bgMid        = Color(0xFFDAEEFA);
  static const _accent       = Color(0xFF0077B6);
  static const _accentTint   = Color(0x260077B6);
  static const _accentBorder = Color(0x400077B6);
  static const _textDark     = Color(0xFF0D2B4E);
  static const _textSub      = Color(0xFF5A7A96);
  static const _white20      = Color(0xFF8AAEC8);
  static const _fieldBg      = Color(0x120077B6);

  @override
  void initState() {
    super.initState();
    _emailCtrl =
        TextEditingController(text: widget.prefillEmail);
    _anim = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 400));
    _fadeIn =
        CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _anim.forward();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _anim.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  bool _isValidEmail(String e) =>
      RegExp(r'^[\w\.-]+@[\w\.-]+\.\w{2,}$').hasMatch(e);

  Future<void> _sendReset() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(
          () => _errorText = "Please enter your email address.");
      return;
    }
    if (!_isValidEmail(email)) {
      setState(
          () => _errorText = "Enter a valid email address.");
      return;
    }
    setState(() { _errorText = null; _stage = 'loading'; });

    final connected = (await Connectivity().checkConnectivity())
        .any((r) => r != ConnectivityResult.none);
    if (!connected) {
      setState(() {
        _stage = 'input';
        _errorText =
            "No internet connection. Please check your network.";
      });
      return;
    }

    try {
      await FirebaseAuth.instance
          .sendPasswordResetEmail(email: email);
      if (mounted) setState(() => _stage = 'success');
      _startCooldown();
    } on FirebaseAuthException catch (e) {
      final msgs = {
        'user-not-found':
            "No account found for this email address.",
        'invalid-email': "Enter a valid email address.",
        'too-many-requests':
            "Too many requests. Please wait and try again.",
        'network-request-failed':
            "Network error. Check your internet connection.",
      };
      if (mounted)
        setState(() {
          _stage = 'input';
          _errorText = msgs[e.code] ??
              "Something went wrong. Please try again.";
        });
    } catch (_) {
      if (mounted)
        setState(() {
          _stage = 'input';
          _errorText = "Something went wrong. Please try again.";
        });
    }
  }

  void _startCooldown() {
    setState(() { _resendCooldown = true; _cooldownSecs = 60; });
    _cooldownTimer =
        Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _cooldownSecs--);
      if (_cooldownSecs <= 0) {
        t.cancel();
        if (mounted) setState(() => _resendCooldown = false);
      }
    });
  }

  void _resend() {
    if (_resendCooldown) return;
    setState(() => _stage = 'input');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Blurred background image carried through ───────────────────
         Stack(
  fit: StackFit.expand,
  children: [

    // Background Image
    Image.asset(
      'assets/images/log.png',
      fit: BoxFit.cover,
    ),

  ],
),
          // ── Content ────────────────────────────────────────────────────
          SafeArea(
            child: FadeTransition(
              opacity: _fadeIn,
              child: Column(children: [
                _buildTopBar(),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 16),
                      child: ConstrainedBox(
                        constraints:
                            const BoxConstraints(maxWidth: 420),
                        child: AnimatedSwitcher(
                          duration:
                              const Duration(milliseconds: 350),
                          switchInCurve: Curves.easeOutCubic,
                          transitionBuilder: (child, animation) =>
                              FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.06),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          ),
                          child: _stage == 'success'
                              ? _buildSuccessState()
                              : _buildInputState(),
                        ),
                      ),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() => Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: 8, vertical: 8),
        child: Row(children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new,
                color: _textDark, size: 18),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const Expanded(
            child: Center(
              child: Text("Forgot Password",
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: _textDark)),
            ),
          ),
          const SizedBox(width: 48),
        ]),
      );

  Widget _buildInputState() {
    return Column(
      key: const ValueKey('input'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: _accentTint,
              shape: BoxShape.circle,
              border: Border.all(color: _accentBorder, width: 1.5),
              boxShadow: [
                BoxShadow(
                    color: const Color.fromARGB(255, 145, 216, 255).withOpacity(0.5),
                    blurRadius: 24,
                    spreadRadius: 2)
              ],
            ),
            child: const Icon(Icons.lock_reset_rounded,
                color: _accent, size: 36),
          ),
        ),
        const SizedBox(height: 28),
        const Center(
          child: Text("Reset your password",
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: _textDark,
                  letterSpacing: -0.3)),
        ),
        const SizedBox(height: 8),
        const Center(
          child: Text(
            "Enter the email address linked to your CleftTune account "
            "and we'll send you a reset link.",
            textAlign: TextAlign.center,
            style:
                TextStyle(fontSize: 13, color: _textSub, height: 1.6),
          ),
        ),
        const SizedBox(height: 32),
        const Text("EMAIL ADDRESS",
            style: TextStyle(
                fontSize: 10,
                color: _accent,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8)),
        const SizedBox(height: 8),
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          autofocus: widget.prefillEmail.isEmpty,
          style: const TextStyle(color: _textDark, fontSize: 14),
          onChanged: (_) {
            if (_errorText != null)
              setState(() => _errorText = null);
          },
          decoration: InputDecoration(
            hintText: "you@example.com",
            hintStyle:
                const TextStyle(color: _textSub, fontSize: 14),
            prefixIcon: const Icon(Icons.email_outlined,
                color: _textSub, size: 18),
            filled: true,
            fillColor: _fieldBg,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: _errorText != null
                      ? Colors.redAccent
                      : _accent.withOpacity(0.2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: _errorText != null
                    ? Colors.redAccent.withOpacity(0.6)
                    : _accent.withOpacity(0.2),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: _errorText != null
                      ? Colors.redAccent
                      : _accent,
                  width: 1.5),
            ),
          ),
        ),
        if (_errorText != null) ...[
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.error_outline,
                color: Colors.redAccent, size: 14),
            const SizedBox(width: 6),
            Expanded(
                child: Text(_errorText!,
                    style: const TextStyle(
                        color: Colors.redAccent, fontSize: 12))),
          ]),
        ],
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity, height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            onPressed:
                _stage == 'loading' ? null : _sendReset,
            child: _stage == 'loading'
                ? const SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5))
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.send_rounded,
                          color: Colors.white, size: 18),
                      SizedBox(width: 10),
                      Text("Send Reset Link",
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.2)),
                    ]),
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_back,
                      color: _textSub, size: 14),
                  SizedBox(width: 5),
                  Text("Back to Sign In",
                      style: TextStyle(
                          fontSize: 13,
                          color: _textSub,
                          fontWeight: FontWeight.w500)),
                ]),
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _accentTint,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _accentBorder),
          ),
          child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded,
                    color: _accent, size: 16),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Check your spam or junk folder if you don't see "
                    "the email within a few minutes.",
                    style: TextStyle(
                        fontSize: 12,
                        color: _textSub,
                        height: 1.5),
                  ),
                ),
              ]),
        ),
      ],
    );
  }

  Widget _buildSuccessState() {
    final email = _emailCtrl.text.trim();
    return Column(
      key: const ValueKey('success'),
      children: [
        const SizedBox(height: 12),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.6, end: 1.0),
          duration: const Duration(milliseconds: 500),
          curve: Curves.elasticOut,
          builder: (_, scale, child) =>
              Transform.scale(scale: scale, child: child),
          child: Container(
            width: 96, height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _accentTint,
              border: Border.all(color: _accent, width: 2),
              boxShadow: [
                BoxShadow(
                    color: _accent.withOpacity(0.28),
                    blurRadius: 30,
                    spreadRadius: 4)
              ],
            ),
            child: const Icon(Icons.mark_email_read_rounded,
                color: _accent, size: 44),
          ),
        ),
        const SizedBox(height: 32),
        const Text("Check your inbox!",
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: _textDark,
                letterSpacing: -0.5)),
        const SizedBox(height: 12),
        const Text("We've sent a password reset link to",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: _textSub)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: _accentTint,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: _accentBorder),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.email_rounded,
                color: _accent, size: 15),
            const SizedBox(width: 8),
            Text(email,
                style: const TextStyle(
                    fontSize: 13,
                    color: _accent,
                    fontWeight: FontWeight.w600)),
          ]),
        ),
        const SizedBox(height: 32),
        _instructionCard(),
        const SizedBox(height: 28),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8F0),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: const Color(0xFFE67E22).withOpacity(0.3)),
          ),
          child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: Color(0xFFE67E22), size: 16),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Didn't receive it? Check your spam or junk folder. "
                    "The link expires in 1 hour.",
                    style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFFB05E10),
                        height: 1.5),
                  ),
                ),
              ]),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity, height: 50,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                  color: _resendCooldown
                      ? _accent.withOpacity(0.15)
                      : _accentBorder),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              backgroundColor: _resendCooldown
                  ? Colors.transparent
                  : _accentTint,
            ),
            onPressed: _resendCooldown ? null : _resend,
            child: _resendCooldown
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.timer_outlined,
                          color: _textSub, size: 16),
                      const SizedBox(width: 8),
                      Text("Resend in ${_cooldownSecs}s",
                          style: const TextStyle(
                              fontSize: 14,
                              color: _textSub,
                              fontWeight: FontWeight.w500)),
                    ])
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.refresh_rounded,
                          color: _accent, size: 16),
                      SizedBox(width: 8),
                      Text("Resend Email",
                          style: TextStyle(
                              fontSize: 14,
                              color: _accent,
                              fontWeight: FontWeight.w600)),
                    ]),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity, height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            onPressed: () => Navigator.of(context).pop(),
            child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.arrow_back_rounded,
                      color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text("Back to Sign In",
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ]),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _instructionCard() {
    final steps = [
      (Icons.email_outlined,    "Open the email from CleftTune"),
      (Icons.link_rounded,      'Tap the "Reset Password" link'),
      (Icons.lock_open_rounded, "Create a new strong password"),
      (Icons.login_rounded,     "Sign in with your new password"),
    ];
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _accentTint,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accentBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("WHAT TO DO NEXT",
              style: TextStyle(
                  fontSize: 10,
                  color: _accent,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0)),
          const SizedBox(height: 14),
          ...steps.asMap().entries.map((entry) {
            final i      = entry.key;
            final step   = entry.value;
            final isLast = i == steps.length - 1;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD6EEFF),
                      shape: BoxShape.circle,
                      border: Border.all(color: _accentBorder),
                    ),
                    child: Icon(step.$1, color: _accent, size: 15),
                  ),
                  if (!isLast)
                    Container(
                        width: 1.5,
                        height: 24,
                        color: _accent.withOpacity(0.15)),
                ]),
                const SizedBox(width: 14),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(step.$2,
                        style: const TextStyle(
                            fontSize: 13,
                            color: _textSub,
                            height: 1.5)),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

// ── GOOGLE LOGO PAINTER ──────────────────────────────────────────────────────
class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c     = Offset(size.width / 2, size.height / 2);
    final r     = size.width / 2;
    final paint = Paint()..style = PaintingStyle.fill;

    final colors = [
      const Color(0xFF4285F4),
      const Color(0xFF34A853),
      const Color(0xFFFBBC05),
      const Color(0xFFEA4335),
    ];

    double angle = -90.0;
    for (int i = 0; i < 4; i++) {
      paint.color = colors[i];
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        angle * (3.14159 / 180),
        90 * (3.14159 / 180),
        true, paint,
      );
      angle += 90;
    }
    paint.color = Colors.white;
    canvas.drawCircle(c, r * 0.55, paint);
    paint.color = const Color(0xFF4285F4);
    canvas.drawRect(
        Rect.fromLTWH(c.dx, c.dy - r * 0.18, r * 0.95, r * 0.36), paint);
    paint.color = Colors.white;
    canvas.drawCircle(c, r * 0.38, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}