import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PremiumScreen extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onLogin;

  const PremiumScreen({super.key, required this.onBack, required this.onLogin});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool isLoginMode = true;
  bool isLoading = false;
  bool obscurePassword = true;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ── Theme constants ────────────────────────────────────────────────────────
  static const _bg = Color(0xFF0D2B2B);
  static const _bgMid = Color(0xFF0E2233);
  static const _bgDark = Color(0xFF0B1A28);
  static const _card = Color(0x0AFFFFFF);
  static const _teal = Color(0xFF1D9E75);
  static const _tealDim = Color(0x261D9E75);
  static const _tealBorder = Color(0x401D9E75);
  static const _white70 = Color(0xB3FFFFFF);
  static const _white40 = Color(0x66FFFFFF);
  static const _white30 = Color(0x4DFFFFFF);
  static const _fieldBg = Color(0x12FFFFFF);

  Future<void> handleAuth() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _snack("Please fill all fields");
      return;
    }
    if (!email.contains("@")) {
      _snack("Enter a valid email");
      return;
    }

    setState(() => isLoading = true);

    try {
      if (isLoginMode) {
        await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } else {
        await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      }
      widget.onLogin();
    } on FirebaseAuthException catch (e) {
      final msgs = {
        'user-not-found': "No account found for this email",
        'wrong-password': "Wrong password",
        'email-already-in-use': "Email already in use",
        'weak-password': "Password is too weak",
      };
      _snack(msgs[e.code] ?? "Authentication failed");
    } catch (_) {
      _snack("Something went wrong");
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_bg, _bgMid, _bgDark],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 800;
              return isMobile ? _buildMobile() : _buildDesktop();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMobile() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPremiumSection(),
          const SizedBox(height: 28),
          _buildLoginCard(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildDesktop() {
    return Row(
      children: [
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
      ],
    );
  }

  // ── PREMIUM SECTION ────────────────────────────────────────────────────────
  Widget _buildPremiumSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _tealDim,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _tealBorder),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.star_rounded, color: _teal, size: 14),
              SizedBox(width: 5),
              Text(
                "PREMIUM",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _teal,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        RichText(
          text: const TextSpan(
            children: [
              TextSpan(
                text: "Upgrade to ",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.3,
                ),
              ),
              TextSpan(
                text: "Premium",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: _teal,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 6),
        const Text(
          "Unlock full features for better communication.",
          style: TextStyle(fontSize: 13, color: _white40, height: 1.6),
        ),

        const SizedBox(height: 24),

        _featureCard(
          Icons.closed_caption_rounded,
          "Unlimited Real-time Subtitles",
          "No time limit when translating speech",
        ),
        _featureCard(
          Icons.graphic_eq_rounded,
          "Voice Calibration",
          "System adapts to your speech pattern",
        ),
        _featureCard(
          Icons.history_rounded,
          "Conversation History",
          "Save and review past translations",
        ),
        _featureCard(
          Icons.block_rounded,
          "Ad-Free Experience",
          "No interruptions while using the app",
        ),

        const SizedBox(height: 24),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _tealDim,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _tealBorder),
          ),
          child: Column(
            children: [
              const Text(
                "MONTHLY PLAN",
                style: TextStyle(
                  fontSize: 11,
                  color: _white40,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              RichText(
                text: const TextSpan(
                  children: [
                    TextSpan(
                      text: "₱99",
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: _teal,
                        letterSpacing: -1,
                      ),
                    ),
                    TextSpan(
                      text: " / month",
                      style: TextStyle(fontSize: 14, color: _white40),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                "Cancel anytime",
                style: TextStyle(fontSize: 11, color: _white30),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── LOGIN CARD ─────────────────────────────────────────────────────────────
  Widget _buildLoginCard() {
    return Column(
      children: [
        Container(
          width: 52,
          height: 52,
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
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          isLoginMode ? "Welcome back to CleftTune" : "Join CleftTune today",
          style: const TextStyle(fontSize: 12, color: _white40),
        ),

        const SizedBox(height: 28),

        _buildFieldLabel("Email address"),
        const SizedBox(height: 6),
        _buildTextField(
          controller: emailController,
          hint: "you@example.com",
          icon: Icons.email_outlined,
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
              color: _white40,
              size: 18,
            ),
            onPressed: () => setState(() => obscurePassword = !obscurePassword),
          ),
        ),

        if (isLoginMode) ...[
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              "Forgot password?",
              style: const TextStyle(fontSize: 12, color: _teal),
            ),
          ),
        ],

        const SizedBox(height: 22),

        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _teal,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            onPressed: isLoading ? null : handleAuth,
            child: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        isLoginMode ? "Login" : "Create Account",
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.arrow_forward,
                        color: Colors.white,
                        size: 16,
                      ),
                    ],
                  ),
          ),
        ),

        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(child: Divider(color: Colors.white.withOpacity(0.08))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                "or",
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withOpacity(0.3),
                ),
              ),
            ),
            Expanded(child: Divider(color: Colors.white.withOpacity(0.08))),
          ],
        ),

        const SizedBox(height: 16),

        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.white.withOpacity(0.12)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => setState(() => isLoginMode = !isLoginMode),
            child: Text(
              isLoginMode
                  ? "Don't have an account? Sign up"
                  : "Already have an account? Login",
              style: const TextStyle(fontSize: 13, color: _white70),
            ),
          ),
        ),

        const SizedBox(height: 20),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.shield_outlined, size: 13, color: _white30),
            SizedBox(width: 5),
            Text(
              "Your data is safe and private.",
              style: TextStyle(fontSize: 11, color: _white30),
            ),
          ],
        ),
      ],
    );
  }

  // ── HELPERS ────────────────────────────────────────────────────────────────

  Widget _buildFieldLabel(String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          color: _white40,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? trailing,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _white30, fontSize: 14),
        prefixIcon: Icon(icon, color: _white40, size: 18),
        suffixIcon: trailing,
        filled: true,
        fillColor: _fieldBg,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
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
  }

  Widget _featureCard(IconData icon, String title, String subtitle) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _tealBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _tealDim,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: _teal, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: _white40,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.check_circle_rounded, color: _teal, size: 18),
        ],
      ),
    );
  }
}