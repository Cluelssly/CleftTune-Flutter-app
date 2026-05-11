import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
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

  bool isLoginMode        = true;
  bool isLoading          = false;
  bool isGoogleLoading    = false;
  bool obscurePassword    = true;
  bool _hasInternet       = true;
  bool _showNoInternetBanner = false;

  // Password strength: 0=empty, 1=weak, 2=fair, 3=good, 4=strong
  int    _passwordStrength      = 0;
  String _passwordStrengthLabel = '';

  final FirebaseAuth  _auth        = FirebaseAuth.instance;
  final GoogleSignIn  _googleSignIn = GoogleSignIn();
  late  StreamSubscription<List<ConnectivityResult>> _connectivitySub;

  // ── Theme constants ──────────────────────────────────────────────────────
  static const _bg          = Color(0xFF0D2B2B);
  static const _bgMid       = Color(0xFF0E2233);
  static const _bgDark      = Color(0xFF0B1A28);
  static const _card        = Color(0x0AFFFFFF);
  static const _teal        = Color(0xFF1D9E75);
  static const _tealDim     = Color(0x261D9E75);
  static const _tealBorder  = Color(0x401D9E75);
  static const _white70     = Color(0xB3FFFFFF);
  static const _white40     = Color(0x66FFFFFF);
  static const _white30     = Color(0x4DFFFFFF);
  static const _fieldBg     = Color(0x12FFFFFF);

  // Strength colors
  static const _strengthWeak   = Color(0xFFE74C3C);
  static const _strengthFair   = Color(0xFFE67E22);
  static const _strengthGood   = Color(0xFFF1C40F);
  static const _strengthStrong = Color(0xFF1D9E75);

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
        'user-not-found'                         : "No account found for this email",
        'wrong-password'                          : "Incorrect password. Please try again",
        'invalid-credential'                      : "Incorrect email or password. Please try again",
        'email-already-in-use'                    : "This email is already registered",
        'weak-password'                           : "Password is too weak. Use at least 6 characters",
        'invalid-email'                           : "Enter a valid email address",
        'too-many-requests'                       : "Too many attempts. Please try again later",
        'network-request-failed'                  : "Network error. Check your internet connection",
        'user-disabled'                           : "This account has been disabled",
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
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) { setState(() => isGoogleLoading = false); return; }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken    : googleAuth.idToken,
      );
      final UserCredential userCredential = await _auth.signInWithCredential(credential);

      if (mounted) {
        final isNewUser = userCredential.additionalUserInfo?.isNewUser ?? false;
        if (isNewUser) {
          await _showSuccessDialog(name: googleUser.displayName ?? 'there', isGoogle: true);
        }
        widget.onLogin();
      }
    } on FirebaseAuthException catch (e) {
      final msgs = {
        'account-exists-with-different-credential': "An account already exists with a different sign-in method",
        'invalid-credential'                       : "Google sign-in failed. Please try again",
        'network-request-failed'                   : "Network error. Check your internet connection",
      };
      _snack(msgs[e.code] ?? "Google sign-in failed: ${e.message}", isError: true);
    } catch (_) {
      _snack("Google sign-in failed. Please try again", isError: true);
    } finally {
      if (mounted) setState(() => isGoogleLoading = false);
    }
  }

  // ── SUCCESS DIALOG ───────────────────────────────────────────────────────
  Future<void> _showSuccessDialog({String name = 'there', bool isGoogle = false}) async {
    return showDialog<void>(
      context         : context,
      barrierDismissible: false,
      barrierColor    : Colors.black.withOpacity(0.7),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Color(0xFF0D2B2B), Color(0xFF0E2233)],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _tealBorder, width: 1.2),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: _tealDim, shape: BoxShape.circle,
                border: Border.all(color: _teal, width: 1.5),
                boxShadow: [BoxShadow(color: _teal.withOpacity(0.3), blurRadius: 20, spreadRadius: 2)],
              ),
              child: const Icon(Icons.check_rounded, color: _teal, size: 36),
            ),
            const SizedBox(height: 20),
            const Text(
              "Account Created!",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.3),
            ),
            const SizedBox(height: 8),
            Text(
              isGoogle
                  ? "Welcome, $name!\nSigned in with Google successfully."
                  : "Welcome to CleftTune Premium.\nYou're all set to get started!",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.55), height: 1.6),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity, height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _teal,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  "Get Started",
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.2),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ── FORGOT PASSWORD — opens full dedicated screen ─────────────────────────
  void _openForgotPassword() {
    // Pre-fill with whatever the user already typed in the email field
    final prefill = emailController.text.trim();
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black.withOpacity(0.6),
        pageBuilder: (_, __, ___) => _ForgotPasswordScreen(prefillEmail: prefill),
        transitionsBuilder: (_, animation, __, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end  : Offset.zero,
            ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
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
        Icon(isError ? Icons.error_outline : Icons.check_circle_outline,
            color: Colors.white, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(msg,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
        ),
      ]),
      backgroundColor: isError ? Colors.redAccent : _teal,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [_bg, _bgMid, _bgDark],
          ),
        ),
        child: SafeArea(
          child: Column(children: [
            if (_showNoInternetBanner)
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: double.infinity,
                color: const Color(0xFFE67E22).withOpacity(0.9),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(children: [
                  const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 16),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      "No internet connection. Some features may not work.",
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _showNoInternetBanner = false),
                    child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
                  ),
                ]),
              ),
            Expanded(
              child: LayoutBuilder(builder: (context, constraints) {
                return constraints.maxWidth < 800 ? _buildMobile() : _buildDesktop();
              }),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildMobile() => SingleChildScrollView(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _buildPremiumSection(),
      const SizedBox(height: 28),
      _buildLoginCard(),
      const SizedBox(height: 24),
    ]),
  );

  Widget _buildDesktop() => Row(children: [
    Expanded(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(40),
        child: _buildPremiumSection(),
      ),
    ),
    Container(width: 1, color: Colors.white.withOpacity(0.07)),
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
  ]);

  // ── PREMIUM SECTION ──────────────────────────────────────────────────────
  Widget _buildPremiumSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: _tealDim,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _tealBorder),
        ),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.star_rounded, color: _teal, size: 14),
          SizedBox(width: 5),
          Text("PREMIUM", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _teal, letterSpacing: 1.2)),
        ]),
      ),
      const SizedBox(height: 14),
      RichText(text: const TextSpan(children: [
        TextSpan(text: "Upgrade to ", style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.3)),
        TextSpan(text: "Premium",     style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: _teal,         letterSpacing: -0.3)),
      ])),
      const SizedBox(height: 6),
      const Text(
        "Unlock full features for better communication.",
        style: TextStyle(fontSize: 13, color: _white40, height: 1.6),
      ),
      const SizedBox(height: 24),
      _featureCard(Icons.closed_caption_rounded, "Unlimited Real-time Subtitles", "No time limit when translating speech"),
      _featureCard(Icons.graphic_eq_rounded,     "Voice Calibration",             "System adapts to your speech pattern"),
      _featureCard(Icons.history_rounded,         "Conversation History",           "Save and review past translations"),
      _featureCard(Icons.block_rounded,           "Ad-Free Experience",             "No interruptions while using the app"),
      const SizedBox(height: 24),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _tealDim,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _tealBorder),
        ),
        child: Column(children: [
          const Text("MONTHLY PLAN",
              style: TextStyle(fontSize: 11, color: _white40, letterSpacing: 1.2, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          RichText(text: const TextSpan(children: [
            TextSpan(text: "₱99",      style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: _teal, letterSpacing: -1)),
            TextSpan(text: " / month", style: TextStyle(fontSize: 14, color: _white40)),
          ])),
          const SizedBox(height: 6),
          const Text("Cancel anytime", style: TextStyle(fontSize: 11, color: _white30)),
        ]),
      ),
    ],
  );

  // ── LOGIN CARD ───────────────────────────────────────────────────────────
  Widget _buildLoginCard() {
    return Column(children: [
      Container(
        width: 52, height: 52,
        decoration: BoxDecoration(
          color: _tealDim,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _tealBorder),
        ),
        child: const Icon(Icons.lock_outline_rounded, color: _teal, size: 24),
      ),
      const SizedBox(height: 14),
      Text(
        isLoginMode ? "Sign In" : "Create Account",
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
      ),
      const SizedBox(height: 4),
      Text(
        isLoginMode ? "Welcome back to CleftTune" : "Join CleftTune today",
        style: const TextStyle(fontSize: 12, color: _white40),
      ),
      const SizedBox(height: 28),

      // Google button
      SizedBox(
        width: double.infinity, height: 50,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: Colors.white.withOpacity(0.18)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: Colors.white.withOpacity(0.04),
          ),
          onPressed: isGoogleLoading ? null : handleGoogleSignIn,
          child: isGoogleLoading
              ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _buildGoogleLogo(),
                  const SizedBox(width: 10),
                  Text(
                    isLoginMode ? "Continue with Google" : "Sign up with Google",
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ]),
        ),
      ),
      const SizedBox(height: 16),

      // Divider
      Row(children: [
        Expanded(child: Divider(color: Colors.white.withOpacity(0.08))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text("or use email",
              style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.3))),
        ),
        Expanded(child: Divider(color: Colors.white.withOpacity(0.08))),
      ]),
      const SizedBox(height: 16),

      // Email field
      _buildFieldLabel("Email address"),
      const SizedBox(height: 6),
      _buildTextField(
        controller: emailController,
        hint: "you@example.com",
        icon: Icons.email_outlined,
        keyboardType: TextInputType.emailAddress,
      ),
      const SizedBox(height: 14),

      // Password field
      _buildFieldLabel("Password"),
      const SizedBox(height: 6),
      _buildTextField(
        controller: passwordController,
        hint: "••••••••",
        icon: Icons.lock_outline_rounded,
        obscure: obscurePassword,
        trailing: IconButton(
          icon: Icon(
            obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: _white40, size: 18,
          ),
          onPressed: () => setState(() => obscurePassword = !obscurePassword),
        ),
      ),

      // Password strength bar (sign-up only)
      if (!isLoginMode && _passwordStrength > 0) ...[
        const SizedBox(height: 10),
        _buildPasswordStrengthBar(),
      ],

      // Forgot password link (login only)
      if (isLoginMode) ...[
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: _openForgotPassword,
            child: const Text(
              "Forgot password?",
              style: TextStyle(fontSize: 12, color: _teal, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
      const SizedBox(height: 22),

      // No internet inline warning
      if (!_hasInternet) ...[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFE67E22).withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE67E22).withOpacity(0.4)),
          ),
          child: const Row(children: [
            Icon(Icons.wifi_off_rounded, color: Color(0xFFE67E22), size: 16),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                "No internet connection. Please reconnect to continue.",
                style: TextStyle(color: Color(0xFFE67E22), fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ),
          ]),
        ),
      ],

      // Login / Create Account button
      SizedBox(
        width: double.infinity, height: 50,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _hasInternet ? _teal : Colors.grey.shade700,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          onPressed: isLoading ? null : handleAuth,
          child: isLoading
              ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(
                    isLoginMode ? "Login" : "Create Account",
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.2),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward, color: Colors.white, size: 16),
                ]),
        ),
      ),
      const SizedBox(height: 16),

      // Toggle login / sign-up
      SizedBox(
        width: double.infinity, height: 48,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: Colors.white.withOpacity(0.12)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () => setState(() {
            isLoginMode           = !isLoginMode;
            emailController.clear();
            passwordController.clear();
            _passwordStrength     = 0;
            _passwordStrengthLabel = '';
          }),
          child: Text(
            isLoginMode ? "Don't have an account? Sign up" : "Already have an account? Login",
            style: const TextStyle(fontSize: 13, color: _white70),
          ),
        ),
      ),
      const SizedBox(height: 20),

      const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.shield_outlined, size: 13, color: _white30),
        SizedBox(width: 5),
        Text("Your data is safe and private.", style: TextStyle(fontSize: 11, color: _white30)),
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
                    color: filled ? _strengthColor : Colors.white.withOpacity(0.1),
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
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _strengthColor),
        ),
      ]),
      const SizedBox(height: 8),
      _buildPasswordHints(),
    ]);
  }

  Widget _buildPasswordHints() {
    final p = passwordController.text;
    final hints = [
      (p.length >= 8,                            "8+ characters"),
      (p.contains(RegExp(r'[A-Z]')),             "Uppercase letter"),
      (p.contains(RegExp(r'[0-9]')),             "Number"),
      (p.contains(RegExp(r'[!@#\$%^&*(),.?]')), "Special character"),
    ];
    return Wrap(
      spacing: 12, runSpacing: 4,
      children: hints.map((h) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(
          h.$1 ? Icons.check_circle_rounded : Icons.circle_outlined,
          size: 12, color: h.$1 ? _teal : _white30,
        ),
        const SizedBox(width: 4),
        Text(h.$2, style: TextStyle(fontSize: 11, color: h.$1 ? _teal : _white30)),
      ])).toList(),
    );
  }

  // ── GOOGLE LOGO ──────────────────────────────────────────────────────────
  Widget _buildGoogleLogo() => SizedBox(
    width: 20, height: 20,
    child: CustomPaint(painter: _GoogleLogoPainter()),
  );

  // ── HELPERS ──────────────────────────────────────────────────────────────
  Widget _buildFieldLabel(String label) => Align(
    alignment: Alignment.centerLeft,
    child: Text(label,
        style: const TextStyle(fontSize: 11, color: _white40, fontWeight: FontWeight.w500, letterSpacing: 0.3)),
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
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: _white30, fontSize: 14),
          prefixIcon: Icon(icon, color: _white40, size: 18),
          suffixIcon: trailing,
          filled: true,
          fillColor: _fieldBg,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _teal, width: 1.2),
          ),
        ),
      );

  Widget _featureCard(IconData icon, String title, String subtitle) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _card,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _tealBorder),
    ),
    child: Row(children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(color: _tealDim, borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: _teal, size: 18),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.white)),
          const SizedBox(height: 3),
          Text(subtitle, style: const TextStyle(color: _white40, fontSize: 12, height: 1.4)),
        ]),
      ),
      const Icon(Icons.check_circle_rounded, color: _teal, size: 18),
    ]),
  );
}

// ════════════════════════════════════════════════════════════════════════════
// FORGOT PASSWORD SCREEN
// A fully self-contained screen with three states:
//   1. INPUT  — enter email
//   2. LOADING — sending the reset email
//   3. SUCCESS — confirmation with resend option
// ════════════════════════════════════════════════════════════════════════════

class _ForgotPasswordScreen extends StatefulWidget {
  final String prefillEmail;
  const _ForgotPasswordScreen({this.prefillEmail = ''});

  @override
  State<_ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<_ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _emailCtrl;
  late final AnimationController   _anim;
  late final Animation<double>     _fadeIn;

  // 'input' | 'loading' | 'success'
  String  _stage       = 'input';
  String? _errorText;
  bool    _resendCooldown = false;
  int     _cooldownSecs   = 0;
  Timer?  _cooldownTimer;

  static const _bg         = Color(0xFF0D2B2B);
  static const _bgMid      = Color(0xFF0E2233);
  static const _teal       = Color(0xFF1D9E75);
  static const _tealDim    = Color(0x261D9E75);
  static const _tealBorder = Color(0x401D9E75);
  static const _white40    = Color(0x66FFFFFF);
  static const _white20    = Color(0x33FFFFFF);
  static const _fieldBg    = Color(0x12FFFFFF);

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController(text: widget.prefillEmail);
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _fadeIn = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _anim.forward();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _anim.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  // ── Validate email ───────────────────────────────────────────────────────
  bool _isValidEmail(String e) =>
      RegExp(r'^[\w\.-]+@[\w\.-]+\.\w{2,}$').hasMatch(e);

  // ── Send reset email ─────────────────────────────────────────────────────
  Future<void> _sendReset() async {
    final email = _emailCtrl.text.trim();

    if (email.isEmpty) {
      setState(() => _errorText = "Please enter your email address.");
      return;
    }
    if (!_isValidEmail(email)) {
      setState(() => _errorText = "Enter a valid email address.");
      return;
    }
    setState(() { _errorText = null; _stage = 'loading'; });

    // Check connectivity
    final connected =
        (await Connectivity().checkConnectivity()).any((r) => r != ConnectivityResult.none);
    if (!connected) {
      setState(() {
        _stage     = 'input';
        _errorText = "No internet connection. Please check your network.";
      });
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) setState(() => _stage = 'success');
      _startCooldown();
    } on FirebaseAuthException catch (e) {
      final msgs = {
        'user-not-found'         : "No account found for this email address.",
        'invalid-email'          : "Enter a valid email address.",
        'too-many-requests'      : "Too many requests. Please wait a moment and try again.",
        'network-request-failed' : "Network error. Check your internet connection.",
      };
      if (mounted) {
        setState(() {
          _stage     = 'input';
          _errorText = msgs[e.code] ?? "Something went wrong. Please try again.";
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _stage     = 'input';
          _errorText = "Something went wrong. Please try again.";
        });
      }
    }
  }

  // ── Resend cooldown (60 s) ───────────────────────────────────────────────
  void _startCooldown() {
    setState(() { _resendCooldown = true; _cooldownSecs = 60; });
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
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
    // Small delay so the user sees the form before auto-sending again
  }

  // ── BUILD ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [_bg, _bgMid, Color(0xFF0B1A28)],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeIn,
            child: Column(children: [
              _buildTopBar(),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 350),
                        switchInCurve: Curves.easeOutCubic,
                        transitionBuilder: (child, animation) => FadeTransition(
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
      ),
    );
  }

  // ── TOP BAR ──────────────────────────────────────────────────────────────
  Widget _buildTopBar() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    child: Row(children: [
      IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
        onPressed: () => Navigator.of(context).pop(),
      ),
      const Expanded(
        child: Center(
          child: Text(
            "Forgot Password",
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white),
          ),
        ),
      ),
      // Invisible spacer to balance the back button
      const SizedBox(width: 48),
    ]),
  );

  // ── INPUT STATE ──────────────────────────────────────────────────────────
  Widget _buildInputState() {
    return Column(
      key: const ValueKey('input'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Icon
        Center(
          child: Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: _tealDim,
              shape: BoxShape.circle,
              border: Border.all(color: _tealBorder, width: 1.5),
              boxShadow: [BoxShadow(color: _teal.withOpacity(0.2), blurRadius: 24, spreadRadius: 2)],
            ),
            child: const Icon(Icons.lock_reset_rounded, color: _teal, size: 36),
          ),
        ),
        const SizedBox(height: 28),

        // Title
        const Center(
          child: Text(
            "Reset your password",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.3),
          ),
        ),
        const SizedBox(height: 8),

        // Subtitle
        Center(
          child: Text(
            "Enter the email address linked to your CleftTune account and we'll send you a reset link.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.5), height: 1.6),
          ),
        ),
        const SizedBox(height: 32),

        // Email label
        const Text(
          "EMAIL ADDRESS",
          style: TextStyle(fontSize: 10, color: _white40, fontWeight: FontWeight.w600, letterSpacing: 0.8),
        ),
        const SizedBox(height: 8),

        // Email field
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          autofocus: widget.prefillEmail.isEmpty,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          onChanged: (_) { if (_errorText != null) setState(() => _errorText = null); },
          decoration: InputDecoration(
            hintText: "you@example.com",
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14),
            prefixIcon: const Icon(Icons.email_outlined, color: _white40, size: 18),
            filled: true,
            fillColor: _fieldBg,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _errorText != null ? Colors.redAccent : Colors.white.withOpacity(0.1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: _errorText != null ? Colors.redAccent.withOpacity(0.6) : Colors.white.withOpacity(0.1),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: _errorText != null ? Colors.redAccent : _teal, width: 1.5,
              ),
            ),
          ),
        ),

        // Error text
        if (_errorText != null) ...[
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 14),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                _errorText!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ),
          ]),
        ],

        const SizedBox(height: 28),

        // Send button
        SizedBox(
          width: double.infinity, height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _teal,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            onPressed: _stage == 'loading' ? null : _sendReset,
            child: _stage == 'loading'
                ? const SizedBox(width: 22, height: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.send_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 10),
                    Text(
                      "Send Reset Link",
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.2),
                    ),
                  ]),
          ),
        ),
        const SizedBox(height: 20),

        // Back to login
        Center(
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.arrow_back, color: _white40, size: 14),
              const SizedBox(width: 5),
              Text(
                "Back to Sign In",
                style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.45), fontWeight: FontWeight.w500),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 24),

        // Info box
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _tealDim,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _tealBorder),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.info_outline_rounded, color: _teal, size: 16),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "Check your spam or junk folder if you don't see the email within a few minutes.",
                style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.5), height: 1.5),
              ),
            ),
          ]),
        ),
      ],
    );
  }

  // ── SUCCESS STATE ────────────────────────────────────────────────────────
  Widget _buildSuccessState() {
    final email = _emailCtrl.text.trim();
    return Column(
      key: const ValueKey('success'),
      children: [
        const SizedBox(height: 12),

        // Animated success icon
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.6, end: 1.0),
          duration: const Duration(milliseconds: 500),
          curve: Curves.elasticOut,
          builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
          child: Container(
            width: 96, height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _tealDim,
              border: Border.all(color: _teal, width: 2),
              boxShadow: [BoxShadow(color: _teal.withOpacity(0.35), blurRadius: 30, spreadRadius: 4)],
            ),
            child: const Icon(Icons.mark_email_read_rounded, color: _teal, size: 44),
          ),
        ),
        const SizedBox(height: 32),

        const Text(
          "Check your inbox!",
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5),
        ),
        const SizedBox(height: 12),

        Text(
          "We've sent a password reset link to",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.5)),
        ),
        const SizedBox(height: 6),

        // Email chip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: _tealDim,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: _tealBorder),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.email_rounded, color: _teal, size: 15),
            const SizedBox(width: 8),
            Text(
              email,
              style: const TextStyle(fontSize: 13, color: _teal, fontWeight: FontWeight.w600),
            ),
          ]),
        ),
        const SizedBox(height: 32),

        // Step-by-step instructions
        _instructionCard(),
        const SizedBox(height: 28),

        // Spam tip
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _white20),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFE67E22), size: 16),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "Didn't receive it? Check your spam or junk folder. The link expires in 1 hour.",
                style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.5), height: 1.5),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 28),

        // Resend button
        SizedBox(
          width: double.infinity, height: 50,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: _resendCooldown ? Colors.white.withOpacity(0.1) : _tealBorder,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              backgroundColor: _resendCooldown ? Colors.transparent : _tealDim,
            ),
            onPressed: _resendCooldown ? null : _resend,
            child: _resendCooldown
                ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.timer_outlined, color: _white40, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      "Resend in ${_cooldownSecs}s",
                      style: const TextStyle(fontSize: 14, color: _white40, fontWeight: FontWeight.w500),
                    ),
                  ])
                : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.refresh_rounded, color: _teal, size: 16),
                    SizedBox(width: 8),
                    Text(
                      "Resend Email",
                      style: TextStyle(fontSize: 14, color: _teal, fontWeight: FontWeight.w600),
                    ),
                  ]),
          ),
        ),
        const SizedBox(height: 16),

        // Back to login
        SizedBox(
          width: double.infinity, height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _teal,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            onPressed: () => Navigator.of(context).pop(),
            child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.arrow_back_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text(
                "Back to Sign In",
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ── Step-by-step instruction card ────────────────────────────────────────
  Widget _instructionCard() {
    final steps = [
      (Icons.email_outlined,    "Open the email from CleftTune"),
      (Icons.link_rounded,      "Tap the \"Reset Password\" link"),
      (Icons.lock_open_rounded, "Create a new strong password"),
      (Icons.login_rounded,     "Sign in with your new password"),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _white20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "WHAT TO DO NEXT",
            style: TextStyle(fontSize: 10, color: _white40, fontWeight: FontWeight.w700, letterSpacing: 1.0),
          ),
          const SizedBox(height: 14),
          ...steps.asMap().entries.map((entry) {
            final i    = entry.key;
            final step = entry.value;
            final isLast = i == steps.length - 1;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: _tealDim,
                      shape: BoxShape.circle,
                      border: Border.all(color: _tealBorder),
                    ),
                    child: Icon(step.$1, color: _teal, size: 15),
                  ),
                  if (!isLast)
                    Container(
                      width: 1.5, height: 24,
                      color: Colors.white.withOpacity(0.08),
                    ),
                ]),
                const SizedBox(width: 14),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      step.$2,
                      style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.65), height: 1.5),
                    ),
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
        90   * (3.14159 / 180),
        true, paint,
      );
      angle += 90;
    }
    paint.color = Colors.white;
    canvas.drawCircle(c, r * 0.55, paint);
    paint.color = const Color(0xFF4285F4);
    canvas.drawRect(Rect.fromLTWH(c.dx, c.dy - r * 0.18, r * 0.95, r * 0.36), paint);
    paint.color = Colors.white;
    canvas.drawCircle(c, r * 0.38, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}