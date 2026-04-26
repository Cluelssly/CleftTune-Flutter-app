import 'dart:math';
import 'package:flutter/material.dart';

class LandingPage extends StatefulWidget {
  final VoidCallback onContinue;

  const LandingPage({super.key, required this.onContinue});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _pulseController;
  late AnimationController _waveController;

  late Animation<double> _fadeIn;
  late Animation<Offset> _logoSlide;
  late Animation<Offset> _taglineSlide;
  late Animation<Offset> _textSlide;
  late Animation<Offset> _quoteSlide;
  late Animation<Offset> _buttonSlide;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _fadeIn = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );

    _logoSlide = Tween<Offset>(begin: const Offset(0, -0.3), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
          ),
        );

    _taglineSlide = Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.15, 0.55, curve: Curves.easeOut),
          ),
        );

    _textSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.3, 0.65, curve: Curves.easeOut),
          ),
        );

    _quoteSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.45, 0.78, curve: Curves.easeOut),
          ),
        );

    _buttonSlide = Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.65, 1.0, curve: Curves.easeOut),
          ),
        );

    _pulse = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _pulseController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0D2B2B), Color(0xFF0E2233), Color(0xFF0B1A28)],
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

  // ─── MOBILE ───────────────────────────────────────────────────────────────
  Widget _buildMobile() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SlideTransition(
              position: _logoSlide,
              child: FadeTransition(opacity: _fadeIn, child: _buildLogo(160)),
            ),
            const SizedBox(height: 24),
            SlideTransition(
              position: _taglineSlide,
              child: FadeTransition(
                opacity: _fadeIn,
                child: _buildTagline(centered: true),
              ),
            ),
            const SizedBox(height: 8),
            FadeTransition(
              opacity: _fadeIn,
              child: Text(
                "CleftTune bridges the gap —\none word at a time.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.55),
                  height: 1.6,
                ),
              ),
            ),
            const SizedBox(height: 32),
            SlideTransition(
              position: _textSlide,
              child: FadeTransition(opacity: _fadeIn, child: _buildBrandName()),
            ),
            const SizedBox(height: 6),
            FadeTransition(opacity: _fadeIn, child: _buildSubtitle()),
            const SizedBox(height: 20),
            SlideTransition(
              position: _quoteSlide,
              child: FadeTransition(opacity: _fadeIn, child: _buildQuote()),
            ),
            const SizedBox(height: 20),
            FadeTransition(opacity: _fadeIn, child: _buildFeatureRow()),
            const SizedBox(height: 32),
            SlideTransition(
              position: _buttonSlide,
              child: FadeTransition(opacity: _fadeIn, child: _buildButton()),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ─── DESKTOP ──────────────────────────────────────────────────────────────
  Widget _buildDesktop() {
    return Row(
      children: [
        // LEFT — logo + tagline
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SlideTransition(
                  position: _logoSlide,
                  child: FadeTransition(
                    opacity: _fadeIn,
                    child: _buildLogo(240),
                  ),
                ),
                const SizedBox(height: 28),
                SlideTransition(
                  position: _taglineSlide,
                  child: FadeTransition(
                    opacity: _fadeIn,
                    child: _buildTagline(centered: true),
                  ),
                ),
                const SizedBox(height: 10),
                FadeTransition(
                  opacity: _fadeIn,
                  child: Text(
                    "CleftTune bridges the gap —\none word at a time.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.white.withOpacity(0.5),
                      height: 1.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // RIGHT — brand + quote + features + button
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 56),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SlideTransition(
                  position: _textSlide,
                  child: FadeTransition(
                    opacity: _fadeIn,
                    child: _buildBrandName(),
                  ),
                ),
                const SizedBox(height: 4),
                FadeTransition(opacity: _fadeIn, child: _buildSubtitle()),
                const SizedBox(height: 24),
                SlideTransition(
                  position: _quoteSlide,
                  child: FadeTransition(opacity: _fadeIn, child: _buildQuote()),
                ),
                const SizedBox(height: 24),
                FadeTransition(opacity: _fadeIn, child: _buildFeatureRow()),
                const SizedBox(height: 36),
                SlideTransition(
                  position: _buttonSlide,
                  child: FadeTransition(
                    opacity: _fadeIn,
                    child: _buildButton(fullWidth: true),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── WIDGETS ──────────────────────────────────────────────────────────────

  /// Pulsing logo with animated glow rings
  Widget _buildLogo(double size) {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulse, _waveController]),
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Outer glow ring 2
            Transform.scale(
              scale: 1.0 + (_waveController.value * 0.08),
              child: Container(
                width: size * 1.55,
                height: size * 1.55,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(
                      0xFF1D9E75,
                    ).withOpacity(0.12 * (1 - _waveController.value)),
                    width: 1,
                  ),
                ),
              ),
            ),
            // Outer glow ring 1
            Transform.scale(
              scale: 1.0 + (_pulseController.value * 0.04),
              child: Container(
                width: size * 1.32,
                height: size * 1.32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF1D9E75).withOpacity(0.18),
                    width: 1,
                  ),
                ),
              ),
            ),
            // Waveform lines left side
            Positioned(
              left: 0,
              child: _buildWaveformSide(size * 0.38, mirrored: false),
            ),
            // Waveform lines right side
            Positioned(
              right: 0,
              child: _buildWaveformSide(size * 0.38, mirrored: true),
            ),
            // Main logo circle
            Transform.scale(
              scale: _pulse.value,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: [Color(0xFF1A3A3A), Color(0xFF0D2020)],
                    center: Alignment.topLeft,
                    radius: 1.4,
                  ),
                  border: Border.all(
                    color: const Color(0xFF1D9E75).withOpacity(0.4),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1D9E75).withOpacity(0.25),
                      blurRadius: 28,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // dashed inner ring visual
                      CustomPaint(
                        size: Size(size, size),
                        painter: _DashedCirclePainter(
                          radius: size * 0.44,
                          color: const Color(0xFF1D9E75).withOpacity(0.35),
                        ),
                      ),
                      // Logo image
                      Padding(
                        padding: EdgeInsets.all(size * 0.18),
                        child: Image.asset(
                          'assets/images/logo.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildWaveformSide(double width, {required bool mirrored}) {
    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, _) {
        final bars = [0.3, 0.6, 0.4, 0.85, 0.5, 0.7, 0.35, 0.9, 0.45, 0.65];
        return Transform(
          alignment: Alignment.center,
          transform: mirrored
              ? (Matrix4.identity()..scale(-1.0, 1.0))
              : Matrix4.identity(),
          child: SizedBox(
            width: width,
            height: 48,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: List.generate(bars.length, (i) {
                final phase = (_waveController.value + i * 0.1) % 1.0;
                final factor = 0.5 + 0.5 * sin(phase * 2 * pi);
                return Container(
                  width: 2,
                  height: 6 + bars[i] * 36 * factor,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1D9E75).withOpacity(0.55),
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
            ),
          ),
        );
      },
    );
  }

  /// "Your Voice, \nUnderstood."
  Widget _buildTagline({bool centered = false}) {
    return RichText(
      textAlign: centered ? TextAlign.center : TextAlign.left,
      text: const TextSpan(
        children: [
          TextSpan(
            text: "Your Voice,\n",
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.2,
              letterSpacing: -0.5,
            ),
          ),
          TextSpan(
            text: "Understood.",
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1D9E75),
              height: 1.2,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  /// "CleftTune" with teal "Tune"
  Widget _buildBrandName() {
    return RichText(
      text: const TextSpan(
        children: [
          TextSpan(
            text: "Cleft",
            style: TextStyle(
              fontSize: 44,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          TextSpan(
            text: "Tune",
            style: TextStyle(
              fontSize: 44,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1D9E75),
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubtitle() {
    return Text(
      "AI-powered voice support for clearer,\nmore confident communication.",
      style: TextStyle(
        fontSize: 15,
        color: Colors.white.withOpacity(0.6),
        height: 1.6,
      ),
    );
  }

  /// Quote block
  Widget _buildQuote() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quote icon badge
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF1D9E75).withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.format_quote,
              color: Color(0xFF1D9E75),
              size: 18,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Every voice deserves to be understood. CleftTune bridges the gap — one word at a time.",
            style: TextStyle(
              fontSize: 15,
              fontStyle: FontStyle.italic,
              color: Colors.white.withOpacity(0.75),
              height: 1.65,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            "— CleftTune Team",
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF1D9E75),
              letterSpacing: 0.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// Three feature chips: Voice Clarity | Private & Secure | Built for You
  Widget _buildFeatureRow() {
    final features = [
      (
        Icons.graphic_eq_rounded,
        "Voice Clarity",
        "Enhance your voice\nwith precision.",
      ),
      (
        Icons.shield_outlined,
        "Private & Secure",
        "Your data is protected\nand never shared.",
      ),
      (
        Icons.people_alt_outlined,
        "Built for You",
        "Designed with care,\ndriven by empathy.",
      ),
    ];

    return Row(
      children: features.asMap().entries.map((entry) {
        final i = entry.key;
        final f = entry.value;
        return Expanded(
          child: Row(
            children: [
              Expanded(child: _buildFeatureChip(f.$1, f.$2, f.$3)),
              if (i < features.length - 1)
                Container(
                  width: 1,
                  height: 48,
                  color: Colors.white.withOpacity(0.1),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFeatureChip(IconData icon, String title, String subtitle) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF1D9E75).withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: const Color(0xFF1D9E75), size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10,
            color: Colors.white.withOpacity(0.45),
            height: 1.5,
          ),
        ),
      ],
    );
  }

  /// "Get Started →" button
  Widget _buildButton({bool fullWidth = false}) {
    return SizedBox(
      width: fullWidth ? double.infinity : 220,
      height: 52,
      child: ElevatedButton(
        onPressed: widget.onContinue,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1D9E75),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 6,
          shadowColor: const Color(0xFF1D9E75).withOpacity(0.4),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Get Started",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.3,
              ),
            ),
            SizedBox(width: 8),
            Icon(Icons.arrow_forward, color: Colors.white, size: 18),
          ],
        ),
      ),
    );
  }
}

// ─── DASHED CIRCLE PAINTER ────────────────────────────────────────────────────
class _DashedCirclePainter extends CustomPainter {
  final double radius;
  final Color color;

  _DashedCirclePainter({required this.radius, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    const dashCount = 28;
    const dashAngle = 2 * pi / dashCount;
    const gapFraction = 0.4;
    final center = Offset(size.width / 2, size.height / 2);

    for (int i = 0; i < dashCount; i++) {
      final startAngle = i * dashAngle;
      final sweepAngle = dashAngle * (1 - gapFraction);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashedCirclePainter old) =>
      old.radius != radius || old.color != color;
}
