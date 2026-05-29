import 'dart:math';
import 'package:flutter/material.dart';
import 'premium.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FONT SETUP — add these lines to pubspec.yaml under flutter → fonts:
//
//   flutter:
//     fonts:
//       - family: Syne
//         fonts:
//           - asset: assets/fonts/Syne-Bold.ttf
//             weight: 700
//           - asset: assets/fonts/Syne-ExtraBold.ttf
//             weight: 800
//       - family: DMSans
//         fonts:
//           - asset: assets/fonts/DMSans-Regular.ttf
//             weight: 400
//           - asset: assets/fonts/DMSans-Medium.ttf
//             weight: 500
//
// Then download the fonts from Google Fonts:
//   https://fonts.google.com/specimen/Syne       → download Syne
//   https://fonts.google.com/specimen/DM+Sans    → download DM Sans
//
// Place the .ttf files in:  assets/fonts/
// Run:  flutter pub get
// ─────────────────────────────────────────────────────────────────────────────

class LandingPage extends StatefulWidget {
  final VoidCallback onContinue;
  const LandingPage({super.key, required this.onContinue});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage>
    with TickerProviderStateMixin {

  // ── Controllers ──────────────────────────────────────────────────────────
  late final AnimationController _entrance;
  late final AnimationController _pulse;
  late final AnimationController _wave;
  late final AnimationController _badge;
  late final AnimationController _btnShimmer;
  late final AnimationController _orbFloat;

  // ── Hover state for CTA button ────────────────────────────────────────────
  bool _btnHovered = false;

  // ── Palette ──────────────────────────────────────────────────────────────
  static const Color _bg        = Color(0xFFE6F1F8);
  static const Color _bgDeep    = Color(0xFFBFD8F0);
  static const Color _surface   = Color(0xFFD6EEFF);
  static const Color _accent    = Color(0xFF1A8CB8);
  static const Color _accentDim = Color(0xFF0A2940);
  static const Color _green     = Color(0xFF1D9E75);
  static const Color _textDark  = Color(0xFF0A2940);
  static const Color _textSub   = Color(0xFF4A7090);

  // ── Entrance animations ───────────────────────────────────────────────────
  late final Animation<double>  _fadeIn;
  late final Animation<Offset>  _badgeSlide;
  late final Animation<Offset>  _headlineSlide;
  late final Animation<Offset>  _subSlide;
  late final Animation<Offset>  _featuresSlide;
  late final Animation<Offset>  _ctaSlide;
  late final Animation<Offset>  _trustSlide;
  late final Animation<Offset>  _poweredSlide;
  late final Animation<Offset>  _logoSlide;
  late final Animation<Offset>  _quoteSlide;

  late final Animation<double>  _pulseAnim;
  late final Animation<double>  _btnShimmerAnim;
  late final Animation<double>  _orbAnim;

  @override
  void initState() {
    super.initState();

    _entrance = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800));
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3000))
      ..repeat(reverse: true);
    _wave = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat();
    _badge = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _btnShimmer = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2400))
      ..repeat();
    _orbFloat = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 8000))
      ..repeat(reverse: true);

    _fadeIn = CurvedAnimation(
        parent: _entrance,
        curve: const Interval(0.0, 0.55, curve: Curves.easeOut));

    _badgeSlide    = _slide(0.00, 0.35);
    _headlineSlide = _slide(0.10, 0.42);
    _subSlide      = _slide(0.20, 0.50);
    _featuresSlide = _slide(0.30, 0.60);
    _ctaSlide      = _slide(0.45, 0.72);
    _trustSlide    = _slide(0.52, 0.78);
    _poweredSlide  = _slide(0.58, 0.83);
    _logoSlide     = _slide(0.08, 0.45);
    _quoteSlide    = _slide(0.50, 0.78);

    _pulseAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
    _btnShimmerAnim = Tween<double>(begin: -1.0, end: 2.0).animate(
        CurvedAnimation(parent: _btnShimmer, curve: Curves.easeInOut));
    _orbAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _orbFloat, curve: Curves.easeInOut));

    Future.delayed(const Duration(milliseconds: 80), () {
      if (mounted) _entrance.forward();
    });
  }

  Animation<Offset> _slide(double start, double end) =>
      Tween<Offset>(begin: const Offset(0, 0.22), end: Offset.zero).animate(
          CurvedAnimation(
              parent: _entrance,
              curve: Interval(start, end, curve: Curves.easeOut)));

  @override
  void dispose() {
    _entrance.dispose();
    _pulse.dispose();
    _wave.dispose();
    _badge.dispose();
    _btnShimmer.dispose();
    _orbFloat.dispose();
    super.dispose();
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Plain gradient background — no image
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFE6F1F8), Color(0xFFCCE4F5)],
              ),
            ),
          ),

          // 2. Decorative geometric boxes
          AnimatedBuilder(
            animation: _orbAnim,
            builder: (_, __) => _buildBoxShapes(),
          ),

          // 3. Content
          SafeArea(
            child: LayoutBuilder(
              builder: (ctx, c) =>
                  c.maxWidth < 800 ? _buildMobile(c) : _buildDesktop(),
            ),
          ),
        ],
      ),
    );
  }

  // ── Geometric box shapes background ──────────────────────────────────────
  Widget _buildBoxShapes() {
    final f = _orbAnim.value;
    return Stack(
      children: [
        // ── Top-right cluster ──
        _box(top: 28  - 10 * f, right: 235, size: 50,  rotate: 0.49,  color: _green.withOpacity(0.07)),
        _box(top: 78  -  6 * f, right: 172, size: 33,  rotate: -0.31, color: _accent.withOpacity(0.07)),
        _box(top: 10  +  8 * f, right: 118, size: 64,  rotate: 0.73,  color: _green.withOpacity(0.06)),
        _box(top: 68  +  5 * f, right: 68,  size: 37,  rotate: -0.52, color: _accent.withOpacity(0.08)),
        _box(top: 18  -  4 * f, right: 22,  size: 27,  rotate: 0.96,  color: _green.withOpacity(0.07)),
        // extra top-right
        _box(top: 105 +  6 * f, right: 190, size: 22,  rotate: 1.10,  color: _accent.withOpacity(0.06), outlineOnly: true),
        _box(top: 55  -  3 * f, right: 48,  size: 18,  rotate: -0.70, color: _green.withOpacity(0.09), outlineOnly: true),
        _box(top: 130 -  7 * f, right: 10,  size: 42,  rotate: 0.30,  color: _accent.withOpacity(0.05)),

        // ── Bottom-right cluster ──
        _box(bottom: 98  +  8 * f, right: 205, size: 46, rotate: -0.38, color: _accent.withOpacity(0.06)),
        _box(bottom: 48  -  6 * f, right: 132, size: 58, rotate: 0.63,  color: _green.withOpacity(0.07)),
        _box(bottom: 88  +  4 * f, right: 58,  size: 31, rotate: -0.84, color: _accent.withOpacity(0.07)),
        // extra bottom-right
        _box(bottom: 140 -  5 * f, right: 12,  size: 24, rotate: 0.55,  color: _green.withOpacity(0.08), outlineOnly: true),
        _box(bottom: 30  +  9 * f, right: 82,  size: 19, rotate: -1.20, color: _accent.withOpacity(0.07), outlineOnly: true),
        _box(bottom: 60  -  4 * f, right: 168, size: 28, rotate: 0.80,  color: _green.withOpacity(0.06)),
        _box(bottom: 175 +  3 * f, right: 240, size: 20, rotate: -0.45, color: _accent.withOpacity(0.06), outlineOnly: true),

        // ── Left-edge shapes ──
        _box(top: 138  + 10 * f, left: 8,   size: 30, rotate: 0.40,  color: _accent.withOpacity(0.05)),
        _box(bottom: 158 -  8 * f, left: 18, size: 40, rotate: -0.60, color: _green.withOpacity(0.05)),
        // extra left
        _box(top: 60   -  5 * f, left: 30,  size: 20, rotate: 1.00,  color: _green.withOpacity(0.06), outlineOnly: true),
        _box(top: 200  +  6 * f, left: 5,   size: 16, rotate: -0.80, color: _accent.withOpacity(0.06), outlineOnly: true),
        _box(bottom: 80  +  4 * f, left: 40, size: 24, rotate: 0.65,  color: _accent.withOpacity(0.05)),

        // ── Top-left corner ──
        _box(top: 20   +  4 * f, left: 60,  size: 34, rotate: -0.35, color: _green.withOpacity(0.05)),
        _box(top: 80   -  6 * f, left: 100, size: 18, rotate: 0.90,  color: _accent.withOpacity(0.05), outlineOnly: true),

        // ── Bottom-left corner ──
        _box(bottom: 30  +  5 * f, left: 65,  size: 26, rotate: 0.50,  color: _green.withOpacity(0.06), outlineOnly: true),
        _box(bottom: 90  -  4 * f, left: 110, size: 16, rotate: -1.00, color: _accent.withOpacity(0.06)),
      ],
    );
  }

  Widget _box({
    double? top, double? bottom, double? left, double? right,
    required double size,
    required double rotate,
    required Color color,
    bool outlineOnly = false,
  }) {
    return Positioned(
      top: top, bottom: bottom, left: left, right: right,
      child: Transform.rotate(
        angle: rotate,
        child: Container(
          width: size, height: size,
          decoration: BoxDecoration(
            color: outlineOnly ? Colors.transparent : color,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: outlineOnly
                  ? color.withOpacity((color.opacity * 3).clamp(0, 1))
                  : color.withOpacity((color.opacity * 2.2).clamp(0, 1)),
              width: outlineOnly ? 0.8 : 0.5,
            ),
          ),
        ),
      ),
    );
  }

  // ── MOBILE ────────────────────────────────────────────────────────────────
  Widget _buildMobile(BoxConstraints c) {
    final h = c.maxHeight;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(height: h * 0.038),
          _anim(_badgeSlide, _buildBadge()),
          SizedBox(height: h * 0.022),
          _anim(_logoSlide, _buildLogoRing((h * 0.18).clamp(90, 130))),
          SizedBox(height: h * 0.022),
          _anim(_headlineSlide,
              _buildHeadline((h * 0.042).clamp(24, 34), TextAlign.center)),
          SizedBox(height: h * 0.012),
          _anim(
            _subSlide,
            Text(
              'CleftTune uses adaptive AI to enhance voice clarity for people '
              'with cleft conditions — clear, confident communication starts here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'DMSans',
                fontSize: (h * 0.016).clamp(11, 14),
                color: _textSub,
                height: 1.65,
              ),
            ),
          ),
          SizedBox(height: h * 0.022),
          _anim(_featuresSlide, _buildFeaturesColumn()),
          SizedBox(height: h * 0.022),
          _anim(
            _ctaSlide,
            SizedBox(
              width: double.infinity,
              height: (h * 0.072).clamp(48, 56),
              child: _buildCtaButton(context),
            ),
          ),
          SizedBox(height: h * 0.012),
          _anim(_trustSlide, _buildTrustLine()),
          SizedBox(height: h * 0.010),
          _anim(_poweredSlide, _buildPoweredBy()),
          SizedBox(height: h * 0.022),
          _anim(_quoteSlide, _buildQuoteCard()),
          SizedBox(height: h * 0.034),
        ],
      ),
    );
  }

  // ── DESKTOP ───────────────────────────────────────────────────────────────
  Widget _buildDesktop() {
    return Row(
      children: [
        // LEFT
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 52, vertical: 36),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _anim(_badgeSlide, _buildBadge()),
                const SizedBox(height: 18),
                _anim(_headlineSlide, _buildHeadline(40, TextAlign.left)),
                const SizedBox(height: 14),
                _anim(
                  _subSlide,
                  Text(
                    'CleftTune uses adaptive AI to enhance voice clarity\n'
                    'for people with cleft conditions — clear, confident\n'
                    'communication starts here.',
                    style: const TextStyle(
                      fontFamily: 'DMSans',
                      fontSize: 14,
                      color: _textSub,
                      height: 1.70,
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                _anim(_featuresSlide, _buildFeaturesColumn()),
                const SizedBox(height: 22),
                _anim(
                  _ctaSlide,
                  SizedBox(
                    height: 50,
                    child: Builder(builder: (ctx) => _buildCtaButton(ctx)),
                  ),
                ),
                const SizedBox(height: 12),
                _anim(_trustSlide, _buildTrustLine()),
                const SizedBox(height: 8),
                _anim(_poweredSlide, _buildPoweredBy()),
              ],
            ),
          ),
        ),

        // RIGHT
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 36),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _anim(_logoSlide, _buildLogoRing(190)),
                const SizedBox(height: 22),
                _anim(_quoteSlide, _buildQuoteCard()),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── HELPERS ───────────────────────────────────────────────────────────────
  Widget _anim(Animation<Offset> slide, Widget child) => SlideTransition(
        position: slide,
        child: FadeTransition(opacity: _fadeIn, child: child),
      );

  // ── Badge ─────────────────────────────────────────────────────────────────
  Widget _buildBadge() {
    return AnimatedBuilder(
      animation: _badge,
      builder: (_, __) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.60),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _accent.withOpacity(0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7, height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _green.withOpacity(0.50 + 0.50 * _badge.value),
              ),
            ),
            const SizedBox(width: 7),
            Text(
              'AI VOICE SUPPORT',
              style: TextStyle(
                fontFamily: 'DMSans',
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: _accent,
                letterSpacing: 1.7,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Headline ──────────────────────────────────────────────────────────────
  Widget _buildHeadline(double fontSize, TextAlign align) {
    return RichText(
      textAlign: align,
      text: TextSpan(children: [
        TextSpan(
          text: 'Speak with confidence.\nBe ',
          style: TextStyle(
            fontFamily: 'Syne',
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            color: _textDark,
            height: 1.10,
            letterSpacing: -1.2,
          ),
        ),
        TextSpan(
          text: 'understood.',
          style: TextStyle(
            fontFamily: 'Syne',
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            color: _accent,
            height: 1.10,
            letterSpacing: -1.2,
          ),
        ),
      ]),
    );
  }

  // ── Feature cards ─────────────────────────────────────────────────────────
  Widget _buildFeaturesColumn() {
    final features = [
      (Icons.graphic_eq_rounded,  'Voice Clarity',
          'Precision AI enhancement in real time'),
      (Icons.shield_outlined,     'Private & Secure',
          'Your data is protected and never shared'),
      (Icons.people_alt_outlined, 'Built for You',
          'Designed with care, driven by empathy'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: features.map((f) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.55),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: _accent.withOpacity(0.14), width: 0.5),
          ),
          child: Row(children: [
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                color: _green.withOpacity(0.13),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(f.$1, color: _green, size: 15),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: RichText(
                text: TextSpan(children: [
                  TextSpan(
                    text: '${f.$2}  ',
                    style: const TextStyle(
                      fontFamily: 'DMSans',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: _textDark,
                    ),
                  ),
                  TextSpan(
                    text: f.$3,
                    style: const TextStyle(
                      fontFamily: 'DMSans',
                      fontSize: 11.5,
                      color: _textSub,
                      height: 1.4,
                    ),
                  ),
                ]),
              ),
            ),
          ]),
        ),
      )).toList(),
    );
  }

  // ── CTA Button with shimmer + hover ──────────────────────────────────────
  Widget _buildCtaButton(BuildContext context) {
    return AnimatedBuilder(
      animation: _btnShimmerAnim,
      builder: (_, __) {
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _btnHovered = true),
          onExit:  (_) => setState(() => _btnHovered = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            transform: _btnHovered
                ? (Matrix4.identity()..translate(0.0, -2.0))
                : Matrix4.identity(),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(100),
              boxShadow: [
                BoxShadow(
                  color: _btnHovered
                      ? _accent.withOpacity(0.38)
                      : _accentDim.withOpacity(0.22),
                  blurRadius: _btnHovered ? 22 : 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PremiumScreen(
                      onBack:  () => Navigator.pop(context),
                      onLogin: () => Navigator.pop(context),
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _btnHovered ? _accent : _textDark,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 26),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(100)),
              ).copyWith(
                // smooth color transition handled by AnimatedContainer above
                overlayColor: WidgetStateProperty.all(
                    Colors.white.withOpacity(0.08)),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Shimmer sweep
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(100),
                      child: Transform.translate(
                        offset: Offset(_btnShimmerAnim.value * 260, 0),
                        child: Container(
                          width: 60,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [
                              Colors.white.withOpacity(0.0),
                              Colors.white.withOpacity(0.14),
                              Colors.white.withOpacity(0.0),
                            ]),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Label + animated arrow
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Get started',
                        style: TextStyle(
                          fontFamily: 'DMSans',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(width: 8),
                      AnimatedSlide(
                        offset: _btnHovered
                            ? const Offset(0.25, 0)
                            : Offset.zero,
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut,
                        child: const Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Trust line ────────────────────────────────────────────────────────────
  Widget _buildTrustLine() {
    const items = ['Free to start', 'Works on any device'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: items.expand((s) => [
        Text(s,
            style: const TextStyle(
              fontFamily: 'DMSans',
              fontSize: 11,
              color: _textSub,
              fontWeight: FontWeight.w500,
            )),
        if (s != items.last)
          Container(
            width: 4, height: 4,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: const BoxDecoration(
                shape: BoxShape.circle, color: _textSub),
          ),
      ]).toList(),
    );
  }

  // ── Powered by ────────────────────────────────────────────────────────────
  Widget _buildPoweredBy() {
    return RichText(
      text: TextSpan(children: [
        const TextSpan(
          text: 'Powered by ',
          style: TextStyle(
            fontFamily: 'DMSans',
            fontSize: 11,
            color: _textSub,
            fontWeight: FontWeight.w500,
          ),
        ),
        TextSpan(
          text: 'CleftTune Team',
          style: TextStyle(
            fontFamily: 'DMSans',
            fontSize: 11,
            color: _accent,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ]),
    );
  }

  // ── Logo / orb ring ───────────────────────────────────────────────────────
  Widget _buildLogoRing(double size) {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseAnim, _wave]),
      builder: (_, __) {
        final glow = 10.0 + 18.0 * _pulseAnim.value;
        return SizedBox(
          width: size * 1.72,
          height: size * 1.72,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer ring 2
              Container(
                width: size * 1.62,
                height: size * 1.62,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _accent.withOpacity(
                        0.08 + 0.06 * _pulseAnim.value),
                  ),
                ),
              ),
              // Outer ring 1
              Container(
                width: size * 1.36,
                height: size * 1.36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _accent.withOpacity(
                        0.14 + 0.10 * _pulseAnim.value),
                  ),
                ),
              ),
              // Left wave bars
              Positioned(
                left: 0,
                child: _buildWaveBars(size * 0.34, mirrored: false),
              ),
              // Right wave bars
              Positioned(
                right: 0,
                child: _buildWaveBars(size * 0.34, mirrored: true),
              ),
              // Main circle
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [_surface, _bgDeep],
                    center: const Alignment(-0.4, -0.4),
                    radius: 1.2,
                  ),
                  border: Border.all(
                      color: _accent.withOpacity(0.35), width: 1.8),
                  boxShadow: [
                    BoxShadow(
                      color: _accent.withOpacity(
                          0.10 + 0.10 * _pulseAnim.value),
                      blurRadius: glow,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Center(
                  child: Container(
                    width: size * 0.55,
                    height: size * 0.55,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: _textDark,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            _miniBar(5,  _green),
                            const SizedBox(width: 2),
                            _miniBar(11, _green),
                            const SizedBox(width: 2),
                            _miniBar(16, Colors.white),
                            const SizedBox(width: 2),
                            _miniBar(8,  Colors.white),
                            const SizedBox(width: 2),
                            _miniBar(14, _green),
                            const SizedBox(width: 2),
                            _miniBar(6,  _green),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'CLEFTTUNE',
                          style: TextStyle(
                            fontFamily: 'Syne',
                            fontSize: (size * 0.075).clamp(6, 9),
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withOpacity(0.55),
                            letterSpacing: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _miniBar(double h, Color color) => Container(
        width: 2.5,
        height: h,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      );

  // ── Wave bars ─────────────────────────────────────────────────────────────
  Widget _buildWaveBars(double width, {required bool mirrored}) {
    const heights = [
      0.30, 0.58, 0.40, 0.82, 0.48,
      0.70, 0.34, 0.90, 0.44, 0.62,
    ];
    return AnimatedBuilder(
      animation: _wave,
      builder: (_, __) => Transform(
        alignment: Alignment.center,
        transform: mirrored
            ? (Matrix4.identity()..scale(-1.0, 1.0))
            : Matrix4.identity(),
        child: SizedBox(
          width: width,
          height: 50,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(heights.length, (i) {
              final phase = (_wave.value + i * 0.1) % 1.0;
              final factor = 0.5 + 0.5 * sin(phase * 2 * pi);
              final h = 5.0 + heights[i] * 36.0 * factor;
              return Container(
                width: 2.5,
                height: h,
                decoration: BoxDecoration(
                  color: _accent.withOpacity(0.45 + 0.25 * factor),
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  // ── Quote card ────────────────────────────────────────────────────────────
  Widget _buildQuoteCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.65),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _accent.withOpacity(0.14), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: _accent.withOpacity(0.10),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(Icons.format_quote_rounded, color: _accent, size: 16),
          ),
          const SizedBox(height: 10),
          Text(
            'Every voice deserves to be understood. '
            'CleftTune bridges the gap — one word at a time.',
            style: TextStyle(
              fontFamily: 'DMSans',
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: _textDark.withOpacity(0.72),
              height: 1.60,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            '— CleftTune Team',
            style: TextStyle(
              fontFamily: 'DMSans',
              fontSize: 11.5,
              color: _accent,
              letterSpacing: 0.3,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}