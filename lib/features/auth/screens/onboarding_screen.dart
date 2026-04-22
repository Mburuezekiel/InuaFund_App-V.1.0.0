import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

// ── Colors ────────────────────────────────────────────────────────────────────
class _C {
  static const green      = Color(0xFF1DB954);
  static const greenDark  = Color(0xFF158A3E);
  static const greenLight = Color(0xFF4ADE80);
  static const gold       = Color(0xFFF5A623);
  static const goldLight  = Color(0xFFFFD166);
  static const dark       = Color(0xFF0A0F0D);
  static const muted      = Color(0x88FFFFFF);
  static const border     = Color(0x401DB954);
  static const error      = Color(0xFFEF4444);
}

// ── Duration helpers ──────────────────────────────────────────────────────────
extension _Dur on int {
  Duration get ms => Duration(milliseconds: this);
  Duration get s  => Duration(seconds: this);
}

// ─────────────────────────────────────────────────────────────────────────────
// SLIDE MODEL
// ─────────────────────────────────────────────────────────────────────────────
class _Slide {
  final String tag, title, accent, subtitle, cta;
  final String? imagePath;
  final Widget illustration;
  /// When true the visual area gets a white/light background (official look)
  final bool whiteBackground;

  const _Slide({
    required this.tag, required this.title, required this.accent,
    required this.subtitle, required this.cta,
    required this.illustration,
    this.imagePath,
    this.whiteBackground = false,
  });
}

final _slides = <_Slide>[
  _Slide(
    tag: 'FUNDRAISING', title: 'Inua Ndoto', accent: 'Zako',
    subtitle: 'Start a campaign for medical bills, school fees, emergencies '
        'or community projects — trusted by thousands of Kenyans.',
    cta: 'Continue',
    imagePath: 'assets/images/welcome.png',
    illustration: const _CoinsIllustration(),
    whiteBackground: true,   // ← white background on slide 1
  ),
  _Slide(
    tag: 'DONATIONS', title: 'Donate Fast &', accent: 'Securely',
    subtitle: 'Donate via M-Pesa, Airtel Money, credit/debit card and more. '
        'Every shilling reaches the right person — instantly & safely.',
    cta: 'Continue',
    imagePath: 'assets/images/SuccessDonation.jpeg',
    illustration: const _PayIllustration(),
    whiteBackground: false,  // ← keep original dark sky on slide 2
  ),
  _Slide(
    tag: 'COMMUNITY', title: 'Pamoja', accent: 'Tunaweza',
    subtitle: 'Join a growing community of Kenyans making a real difference '
        'in their neighbourhoods every single day.',
    imagePath: 'assets/images/inuafundCover.png',
    cta: 'Get Started',
    illustration: const _CommunityIllustration(),
    whiteBackground: true,   // ← white background on slide 3
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// ONBOARDING SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override State<OnboardingScreen> createState() => _State();
}

class _State extends State<OnboardingScreen> with SingleTickerProviderStateMixin {
  final _ctrl = PageController();
  int _page = 0;
  late final AnimationController _fade =
      AnimationController(vsync: this, duration: 300.ms);
  late final Animation<double> _anim =
      CurvedAnimation(parent: _fade, curve: Curves.easeOut);

  static const _sky = [
    [Color(0xFF0D2B1A), Color(0xFF061409)],
    [Color(0xFF0A1A2E), Color(0xFF061020)],
    [Color(0xFF1A0D2B), Color(0xFF0D0614)],
  ];

  @override void initState() { super.initState(); _fade.forward(); }
  @override void dispose()   { _ctrl.dispose(); _fade.dispose(); super.dispose(); }

  void _go(int i) => _fade.reverse().then((_) {
    setState(() => _page = i);
    _ctrl.animateToPage(i, duration: 380.ms, curve: Curves.easeInOut);
    _fade.forward();
  });

  void _next() => _page < _slides.length - 1 ? _go(_page + 1) : context.go('/login');

  @override
  Widget build(BuildContext context) {
    final s   = _slides[_page];
    final sky = _sky[_page];
    final h   = MediaQuery.of(context).size.height;
    final w   = MediaQuery.of(context).size.width;
    final isWhiteBg = s.whiteBackground;

    return Scaffold(
      backgroundColor: _C.dark,
      body: Stack(children: [

        // ── Background: white for slides 1 & 3, animated sky for slide 2 ──
        AnimatedContainer(
          duration: 700.ms,
          decoration: BoxDecoration(
            gradient: isWhiteBg
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFFFFFFF), Color(0xFFF2F6F3)],
                  )
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: sky,
                  ),
          ),
        ),

        // ── Stars — only on dark slides ───────────────────────────────────
        if (!isWhiteBg) const _StarField(),

        // ── Realistic City Skyline ─────────────────────────────────────────
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: CustomPaint(
            size: Size(w, h * 0.48),
            painter: _RealisticCityPainter(isLight: isWhiteBg),
          ),
        ),

        // ── Horizon glow (dark slides only) ───────────────────────────────
        if (!isWhiteBg)
          Positioned(
            bottom: h * 0.12, left: 40, right: 40,
            child: Container(height: 70, decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [_C.green.withOpacity(0.14), Colors.transparent]))),
          ),

        // ── UI ────────────────────────────────────────────────────────────
        SafeArea(child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [_Logo(darkMode: !isWhiteBg), _SkipBtn(onTap: () => context.go('/login'), darkMode: !isWhiteBg)],
            ),
          ),

          // Illustration / image area (swipeable)
          Expanded(
            flex: 5,
            child: PageView(
              controller: _ctrl,
              onPageChanged: (i) => _fade.reverse().then((_) {
                setState(() => _page = i); _fade.forward();
              }),
              children: _slides.map((sl) => _SlideVisual(slide: sl)).toList(),
            ),
          ),

          // Glass card
          Container(
            decoration: BoxDecoration(
              color: const Color(0xEA061409),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              border: Border(top: BorderSide(color: _C.border)),
            ),
            padding: const EdgeInsets.fromLTRB(28, 26, 28, 0),
            child: FadeTransition(
              opacity: _anim,
              child: SlideTransition(
                position: Tween(begin: const Offset(0,.07), end: Offset.zero).animate(_anim),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _Pill(s.tag),
                  const SizedBox(height: 12),
                  RichText(text: TextSpan(
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900,
                        fontFamily: 'Poppins', height: 1.15),
                    children: [
                      TextSpan(text: '${s.title}\n', style: const TextStyle(color: Colors.white)),
                      TextSpan(text: s.accent,        style: const TextStyle(color: _C.green)),
                    ],
                  )),
                  const SizedBox(height: 12),
                  Text(s.subtitle, style: const TextStyle(
                      color: _C.muted, fontSize: 14, fontFamily: 'Poppins', height: 1.65)),
                  const SizedBox(height: 22),
                  SmoothPageIndicator(
                    controller: _ctrl, count: _slides.length, onDotClicked: _go,
                    effect: ExpandingDotsEffect(
                      activeDotColor: _C.green, dotColor: Colors.white.withOpacity(0.18),
                      dotHeight: 7, dotWidth: 7, expansionFactor: 4, spacing: 6,
                    ),
                  ),
                  const SizedBox(height: 22),
                  _PrimaryBtn(label: s.cta, onTap: _next),
                  if (_page == _slides.length - 1) ...[
                    const SizedBox(height: 10),
                    _SecondaryBtn(label: 'I already have an account',
                        onTap: () => context.go('/login')),
                  ],
                  const SizedBox(height: 32),
                ]),
              ),
            ),
          ),
        ])),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SLIDE VISUAL — shows image if path given, else illustration
// White-background slides get a clean card-style container.
// ─────────────────────────────────────────────────────────────────────────────
class _SlideVisual extends StatelessWidget {
  final _Slide slide;
  const _SlideVisual({super.key, required this.slide});

  @override
  Widget build(BuildContext context) {
    Widget content;

    if (slide.imagePath != null) {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Image.asset(slide.imagePath!, fit: BoxFit.cover),
      );
    } else {
      content = slide.illustration;
    }

    if (slide.whiteBackground) {
      // Wrap in a clean white elevated card with subtle green border accent
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: _C.green.withOpacity(0.10),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: _C.green.withOpacity(0.18),
              width: 1.2,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: slide.imagePath != null
              ? Image.asset(slide.imagePath!, fit: BoxFit.cover,
                  width: double.infinity, height: double.infinity)
              : Padding(
                  padding: const EdgeInsets.all(12),
                  child: slide.illustration,
                ),
        ),
      );
    }

    // Dark slides: original padding
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
      child: content,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SMALL UI WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

/// Logo — always visible regardless of background colour.
/// On light screens the text uses dark ink so it's readable.
class _Logo extends StatelessWidget {
  final bool darkMode;
  const _Logo({this.darkMode = true});

  @override
  Widget build(BuildContext context) => Row(children: [
    // White background ensures the icon is visible on ANY background
    Container(
      width: 36, height: 36,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: _C.green.withOpacity(0.35),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: _C.green.withOpacity(0.30), width: 1.2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: Image.asset(
          'assets/icon.png',
          width: 36, height: 36,
          fit: BoxFit.cover,
        ),
      ),
    ),
    const SizedBox(width: 8),
    RichText(text: TextSpan(
      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, fontFamily: 'Poppins'),
      children: [
        TextSpan(text: 'Inua',
            style: TextStyle(color: darkMode ? Colors.white : const Color(0xFF0A1A0E))),
        const TextSpan(text: 'Fund',
            style: TextStyle(color: _C.green)),
      ],
    )),
  ]);
}

class _SkipBtn extends StatelessWidget {
  final VoidCallback onTap;
  final bool darkMode;
  const _SkipBtn({required this.onTap, this.darkMode = true});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: darkMode
            ? Colors.white.withOpacity(0.07)
            : _C.green.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: darkMode
              ? Colors.white.withOpacity(0.12)
              : _C.green.withOpacity(0.25),
        ),
      ),
      child: Text('Skip', style: TextStyle(
          color: darkMode ? _C.muted : _C.greenDark,
          fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'Poppins')),
    ),
  );
}

class _Pill extends StatelessWidget {
  final String text;
  const _Pill(this.text);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
    decoration: BoxDecoration(
      color: _C.green.withOpacity(0.13),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _C.green.withOpacity(0.35)),
    ),
    child: Text(text, style: const TextStyle(
        color: _C.green, fontSize: 11, fontWeight: FontWeight.w700,
        fontFamily: 'Poppins', letterSpacing: 1.2)),
  );
}

class _PrimaryBtn extends StatelessWidget {
  final String label; final VoidCallback onTap;
  const _PrimaryBtn({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity, height: 54,
    child: ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: _C.green, foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 8, shadowColor: _C.green.withOpacity(0.45),
      ),
      child: Text(label, style: const TextStyle(
          fontFamily: 'Poppins', fontWeight: FontWeight.w800, fontSize: 16)),
    ),
  );
}

class _SecondaryBtn extends StatelessWidget {
  final String label; final VoidCallback onTap;
  const _SecondaryBtn({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity, height: 48,
    child: OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: _C.muted,
        side: BorderSide(color: Colors.white.withOpacity(0.15)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Text(label, style: const TextStyle(
          fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 14)),
    ),
  );
}

class _Badge extends StatelessWidget {
  final String text; final Color color;
  const _Badge(this.text, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: color.withOpacity(0.13),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withOpacity(0.35)),
    ),
    child: Text(text, style: TextStyle(
        color: color, fontSize: 11, fontWeight: FontWeight.w700, fontFamily: 'Poppins')),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// STAR FIELD
// ─────────────────────────────────────────────────────────────────────────────
class _StarField extends StatefulWidget {
  const _StarField();
  @override State<_StarField> createState() => _StarFieldState();
}
class _StarFieldState extends State<_StarField> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: 3.s)..repeat(reverse: true);
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, __) => CustomPaint(
        painter: _StarPainter(_c.value), size: Size.infinite),
  );
}

class _StarPainter extends CustomPainter {
  final double t;
  _StarPainter(this.t);
  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(42);
    final p = Paint();
    for (int i = 0; i < 48; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height * 0.52;
      final op = (0.2 + rng.nextDouble() * 0.45 + (i % 3 == 0 ? t * 0.3 : 0)).clamp(0.0, 1.0);
      p.color = Colors.white.withOpacity(op);
      canvas.drawCircle(Offset(x, y), 0.8 + rng.nextDouble() * 1.4, p);
    }
  }
  @override bool shouldRepaint(_StarPainter o) => o.t != t;
}

// ─────────────────────────────────────────────────────────────────────────────
// REALISTIC CITY PAINTER  v2
// High-clarity Nairobi-inspired skyline:
//   • 4 depth layers with strong tonal contrast between each
//   • Hand-crafted building shapes: flat tops, stepped crowns, pyramidal caps,
//     chamfered corners, full-height glass curtain walls
//   • Per-building facade panel lines for realism
//   • Crisp warm/cool window grids — larger windows, higher contrast
//   • Rooftop: helipads, water tanks, antenna masts, AC blocks
//   • Horizon glow + sky-to-ground gradient
//   • Ground level: road, kerb, reflection puddle strip
// ─────────────────────────────────────────────────────────────────────────────
class _RealisticCityPainter extends CustomPainter {
  final bool isLight;
  const _RealisticCityPainter({this.isLight = false});

  // ── Building shape types ──────────────────────────────────────────────────
  static const int _flat      = 0; // plain flat roof
  static const int _stepped   = 1; // two-tier setback
  static const int _pyramid   = 2; // pointed cap
  static const int _chamfer   = 3; // cut corners at top
  static const int _crown     = 4; // wide base, narrow crown slab

  // ── Draw one complete building ────────────────────────────────────────────
  void _drawBuilding({
    required Canvas canvas,
    required double x,
    required double groundY,   // y of the street level
    required double bw,
    required double bh,
    required Color body,
    required Color facade,     // slightly lighter for panel lines
    required Color windowOn,
    required Color windowOff,
    required int shape,
    required int winCols,
    required int winRows,
    required Random rng,
  }) {
    final top = groundY - bh;

    // ── Main body ─────────────────────────────────────────────────────────
    final bodyPaint = Paint()..color = body;

    switch (shape) {
      case _stepped:
        // Lower wide slab
        canvas.drawRRect(
          RRect.fromRectAndCorners(Rect.fromLTWH(x, top + bh * 0.38, bw, bh * 0.62),
              topLeft: const Radius.circular(2), topRight: const Radius.circular(2)),
          bodyPaint,
        );
        // Upper narrower slab
        final uw = bw * 0.65; final ux = x + (bw - uw) / 2;
        canvas.drawRRect(
          RRect.fromRectAndCorners(Rect.fromLTWH(ux, top, uw, bh * 0.42),
              topLeft: const Radius.circular(3), topRight: const Radius.circular(3)),
          bodyPaint,
        );
        // Setback ledge highlight
        canvas.drawRect(Rect.fromLTWH(x, top + bh * 0.38, bw, 2.5),
            Paint()..color = facade.withOpacity(0.55));
        break;

      case _pyramid:
        canvas.drawRRect(
          RRect.fromRectAndCorners(Rect.fromLTWH(x, top + bh * 0.12, bw, bh * 0.88),
              topLeft: const Radius.circular(2), topRight: const Radius.circular(2)),
          bodyPaint,
        );
        // Triangular spire
        canvas.drawPath(
          Path()
            ..moveTo(x + bw * 0.15, top + bh * 0.13)
            ..lineTo(x + bw / 2, top - bh * 0.22)
            ..lineTo(x + bw * 0.85, top + bh * 0.13)
            ..close(),
          Paint()..color = body.withOpacity(0.9),
        );
        break;

      case _chamfer:
        // Chamfered (cut-corner) top
        final path = Path()
          ..moveTo(x + bw * 0.12, top)
          ..lineTo(x + bw * 0.88, top)
          ..lineTo(x + bw, top + bh * 0.06)
          ..lineTo(x + bw, groundY)
          ..lineTo(x, groundY)
          ..lineTo(x, top + bh * 0.06)
          ..close();
        canvas.drawPath(path, bodyPaint);
        break;

      case _crown:
        // Wide lower block
        canvas.drawRect(Rect.fromLTWH(x, top + bh * 0.55, bw, bh * 0.45), bodyPaint);
        // Narrow upper crown
        final cw = bw * 0.5; final cx2 = x + (bw - cw) / 2;
        canvas.drawRRect(
          RRect.fromRectAndCorners(Rect.fromLTWH(cx2, top, cw, bh * 0.58),
              topLeft: const Radius.circular(4), topRight: const Radius.circular(4)),
          bodyPaint,
        );
        break;

      default: // _flat
        canvas.drawRRect(
          RRect.fromRectAndCorners(Rect.fromLTWH(x, top, bw, bh),
              topLeft: const Radius.circular(3), topRight: const Radius.circular(3)),
          bodyPaint,
        );
    }

    // ── Facade panel lines (vertical + 1 horizontal band) ─────────────────
    final panelPaint = Paint()
      ..color = facade.withOpacity(0.22)
      ..strokeWidth = 0.8;
    // Vertical column lines
    final cols = (bw / 14).floor().clamp(2, 8);
    for (int c = 1; c < cols; c++) {
      final lx = x + bw * c / cols;
      canvas.drawLine(Offset(lx, top + 4), Offset(lx, groundY), panelPaint);
    }
    // Horizontal spandrel band at ~1/3 height
    canvas.drawLine(Offset(x + 1, top + bh * 0.35),
        Offset(x + bw - 1, top + bh * 0.35), panelPaint);

    // ── Windows ────────────────────────────────────────────────────────────
    // Actual drawing area (avoid stepped offsets for simplicity — use bounding box)
    final winAreaTop  = top + 6.0;
    final winAreaH    = bh - 10.0;
    final cellW = bw / (winCols + 0.8);
    final cellH = winAreaH / (winRows + 0.5);
    final ww = (cellW * 0.52).clamp(3.0, 10.0);
    final wh = (cellH * 0.56).clamp(3.5, 12.0);

    for (int c = 0; c < winCols; c++) {
      for (int r = 0; r < winRows; r++) {
        final wx = x + cellW * (c + 0.4);
        final wy = winAreaTop + cellH * (r + 0.35);
        // Skip windows outside chamfer/pyramid shapes roughly
        if (wx < x || wx + ww > x + bw) continue;

        final isOn = rng.nextDouble() > 0.28;
        Color wc;
        if (!isOn) {
          wc = windowOff;
        } else {
          // Vary: warm amber, cool blue-white, pure white
          final t = rng.nextDouble();
          if (t < 0.45) {
            wc = Color.lerp(const Color(0xFFFFD080), Colors.white, 0.25)!
                .withOpacity(0.70 + rng.nextDouble() * 0.28);
          } else if (t < 0.75) {
            wc = Color.lerp(const Color(0xFF90D8FF), Colors.white, 0.35)!
                .withOpacity(0.60 + rng.nextDouble() * 0.30);
          } else {
            wc = Colors.white.withOpacity(0.55 + rng.nextDouble() * 0.35);
          }
        }
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(wx, wy, ww, wh),
              const Radius.circular(1)),
          Paint()..color = wc,
        );
      }
    }

    // ── Rooftop details ────────────────────────────────────────────────────
    final seed = rng.nextInt(4);
    if (seed == 0) {
      // Water tank: cylinder pair
      for (int t = 0; t < 2; t++) {
        final tx = x + bw * (0.2 + t * 0.42);
        final ty = top - 14.0;
        canvas.drawRect(Rect.fromLTWH(tx, ty, 8, 14),
            Paint()..color = facade.withOpacity(0.55));
        canvas.drawOval(Rect.fromCenter(center: Offset(tx + 4, ty), width: 10, height: 5),
            Paint()..color = facade.withOpacity(0.45));
      }
    } else if (seed == 1) {
      // Antenna mast
      final ax = x + bw * 0.5;
      final ap = Paint()..color = facade.withOpacity(0.70)
          ..strokeWidth = 1.5..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(ax, top), Offset(ax, top - 22), ap);
      canvas.drawLine(Offset(ax - 6, top - 8), Offset(ax + 6, top - 8), ap);
      // Red beacon
      canvas.drawCircle(Offset(ax, top - 22), 2.5,
          Paint()..color = const Color(0xFFFF3B30).withOpacity(0.85));
    } else if (seed == 2) {
      // Helipad circle
      canvas.drawCircle(Offset(x + bw / 2, top + 5), bw * 0.28,
          Paint()..color = facade.withOpacity(0.20)
              ..style = PaintingStyle.stroke..strokeWidth = 2);
      canvas.drawCircle(Offset(x + bw / 2, top + 5), 3,
          Paint()..color = _C.gold.withOpacity(0.6));
    } else {
      // AC unit blocks
      for (int a = 0; a < 3; a++) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(x + bw * 0.1 + a * bw * 0.28, top - 7, bw * 0.18, 7),
              const Radius.circular(1)),
          Paint()..color = facade.withOpacity(0.45),
        );
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final ground = h;  // street is at very bottom of canvas
    final rng = Random(31);

    // ─── Colour palettes ─────────────────────────────────────────────────
    // Each layer: body colour, facade highlight, window-on seed, window-off
    // Dark mode: rich dark greens with strong contrast
    // Light mode: desaturated blue-greys on white sky

    final layers = isLight
        ? [
            // far:  very pale grey-blue
            (body: const Color(0xFFD4DCE8), facade: const Color(0xFFE8EEF5),
             winOn: const Color(0xFFFFF5D0), winOff: const Color(0xFFBCC8D8)),
            // mid-back: medium grey-blue
            (body: const Color(0xFF8FA5BE), facade: const Color(0xFFAABFD4),
             winOn: const Color(0xFFFFF0B0), winOff: const Color(0xFF6E88A0)),
            // mid-front: slate blue
            (body: const Color(0xFF5A7A9A), facade: const Color(0xFF7294B2),
             winOn: const Color(0xFFFFE580), winOff: const Color(0xFF3F5E78)),
            // near: deep navy-teal
            (body: const Color(0xFF2C4A62), facade: const Color(0xFF3D6282),
             winOn: const Color(0xFFFFD84A), winOff: const Color(0xFF1A3248)),
          ]
        : [
            // far: very dark green-black
            (body: const Color(0xFF071410), facade: const Color(0xFF0D2018),
             winOn: const Color(0xFFFFE070), winOff: const Color(0xFF040E0A)),
            // mid-back
            (body: const Color(0xFF0A1E14), facade: const Color(0xFF122A1C),
             winOn: const Color(0xFFFFCC44), winOff: const Color(0xFF06120D)),
            // mid-front
            (body: const Color(0xFF0E2A1A), facade: const Color(0xFF1A3D26),
             winOn: const Color(0xFFFFC03A), winOff: const Color(0xFF081610)),
            // near: richest dark green
            (body: const Color(0xFF112E1C), facade: const Color(0xFF1F4A2E),
             winOn: const Color(0xFFFFB830), winOff: const Color(0xFF091810)),
          ];

    // ─── Horizon glow (dark slides only) ──────────────────────────────────
    if (!isLight) {
      final glowPaint = Paint()
        ..shader = RadialGradient(
          center: Alignment.bottomCenter,
          radius: 1.0,
          colors: [
            _C.green.withOpacity(0.18),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTWH(0, h * 0.4, w, h * 0.6));
      canvas.drawRect(Rect.fromLTWH(0, h * 0.4, w, h * 0.6), glowPaint);
    }

    // ─── Layer 0: FAR background (tiny, densely packed) ───────────────────
    final L0 = layers[0];
    final far = <(double x, double bw, double bh, int shape, int wc, int wr)>[
      (0.00, 0.06, 0.22, _flat,    2, 3), (0.05, 0.05, 0.19, _flat,    2, 3),
      (0.09, 0.07, 0.25, _flat,    2, 4), (0.15, 0.04, 0.18, _flat,    2, 3),
      (0.18, 0.06, 0.22, _stepped, 2, 4), (0.23, 0.05, 0.20, _flat,    2, 3),
      (0.27, 0.07, 0.27, _flat,    3, 4), (0.33, 0.04, 0.17, _flat,    2, 3),
      (0.36, 0.06, 0.24, _flat,    2, 4), (0.41, 0.05, 0.21, _flat,    2, 3),
      (0.45, 0.08, 0.28, _flat,    3, 4), (0.52, 0.04, 0.18, _flat,    2, 3),
      (0.55, 0.06, 0.23, _flat,    2, 4), (0.60, 0.05, 0.20, _flat,    2, 3),
      (0.64, 0.07, 0.26, _stepped, 3, 4), (0.70, 0.04, 0.17, _flat,    2, 3),
      (0.73, 0.06, 0.22, _flat,    2, 3), (0.78, 0.05, 0.19, _flat,    2, 3),
      (0.82, 0.07, 0.25, _flat,    3, 4), (0.88, 0.04, 0.18, _flat,    2, 3),
      (0.91, 0.06, 0.23, _flat,    2, 4), (0.96, 0.04, 0.20, _flat,    2, 3),
    ];
    for (final b in far) {
      _drawBuilding(canvas: canvas, x: b.$1*w, groundY: ground, bw: b.$2*w,
        bh: b.$3*h, body: L0.body, facade: L0.facade,
        windowOn: L0.winOn, windowOff: L0.winOff,
        shape: b.$4, winCols: b.$5, winRows: b.$6, rng: rng);
    }

    // ─── Layer 1: MID-BACK ────────────────────────────────────────────────
    final L1 = layers[1];
    final midBack = <(double x, double bw, double bh, int shape, int wc, int wr)>[
      (0.00, 0.08, 0.36, _flat,    3, 6), (0.07, 0.07, 0.42, _stepped, 3, 6),
      (0.13, 0.09, 0.38, _flat,    3, 5), (0.21, 0.06, 0.33, _pyramid, 3, 5),
      (0.26, 0.10, 0.48, _flat,    4, 7), (0.35, 0.07, 0.40, _chamfer, 3, 6),
      (0.41, 0.08, 0.44, _stepped, 3, 6), (0.48, 0.06, 0.35, _flat,    3, 5),
      (0.53, 0.10, 0.50, _flat,    4, 7), (0.62, 0.07, 0.39, _pyramid, 3, 6),
      (0.68, 0.08, 0.43, _flat,    3, 6), (0.75, 0.07, 0.37, _stepped, 3, 5),
      (0.81, 0.09, 0.46, _chamfer, 3, 6), (0.89, 0.06, 0.33, _flat,    3, 5),
      (0.94, 0.06, 0.38, _flat,    3, 5),
    ];
    for (final b in midBack) {
      _drawBuilding(canvas: canvas, x: b.$1*w, groundY: ground, bw: b.$2*w,
        bh: b.$3*h, body: L1.body, facade: L1.facade,
        windowOn: L1.winOn, windowOff: L1.winOff,
        shape: b.$4, winCols: b.$5, winRows: b.$6, rng: rng);
    }

    // ─── Layer 2: MID-FRONT (key character buildings) ─────────────────────
    final L2 = layers[2];
    final midFront = <(double x, double bw, double bh, int shape, int wc, int wr)>[
      (0.00, 0.09, 0.52, _flat,    4, 8 ), (0.08, 0.08, 0.60, _stepped, 4, 9 ),
      (0.15, 0.11, 0.55, _chamfer, 4, 8 ), (0.25, 0.07, 0.47, _pyramid, 3, 7 ),
      (0.31, 0.12, 0.68, _flat,    5, 10), (0.42, 0.08, 0.57, _stepped, 4, 8 ),
      (0.49, 0.10, 0.62, _crown,   4, 9 ), (0.58, 0.07, 0.50, _flat,    3, 7 ),
      (0.64, 0.11, 0.65, _chamfer, 4, 9 ), (0.74, 0.08, 0.53, _stepped, 4, 8 ),
      (0.81, 0.10, 0.59, _flat,    4, 8 ), (0.90, 0.10, 0.54, _pyramid, 4, 8 ),
    ];
    for (final b in midFront) {
      _drawBuilding(canvas: canvas, x: b.$1*w, groundY: ground, bw: b.$2*w,
        bh: b.$3*h, body: L2.body, facade: L2.facade,
        windowOn: L2.winOn, windowOff: L2.winOff,
        shape: b.$4, winCols: b.$5, winRows: b.$6, rng: rng);
    }

    // ─── Layer 3: NEAR (foreground — largest, most detailed) ──────────────
    final L3 = layers[3];
    final near = <(double x, double bw, double bh, int shape, int wc, int wr)>[
      (0.00, 0.11, 0.70, _flat,    5, 11), (0.10, 0.09, 0.82, _pyramid, 4, 12),
      (0.18, 0.13, 0.74, _stepped, 5, 11), (0.30, 0.08, 0.65, _chamfer, 4, 10),
      (0.37, 0.15, 0.94, _crown,   6, 14), // ← HERO building
      (0.51, 0.09, 0.72, _flat,    4, 11), (0.59, 0.12, 0.80, _stepped, 5, 12),
      (0.70, 0.09, 0.68, _pyramid, 4, 10), (0.78, 0.13, 0.88, _flat,    5, 13),
      (0.90, 0.10, 0.73, _chamfer, 4, 11),
    ];
    for (final b in near) {
      _drawBuilding(canvas: canvas, x: b.$1*w, groundY: ground, bw: b.$2*w,
        bh: b.$3*h, body: L3.body, facade: L3.facade,
        windowOn: L3.winOn, windowOff: L3.winOff,
        shape: b.$4, winCols: b.$5, winRows: b.$6, rng: rng);
    }

    // ─── Ground level ──────────────────────────────────────────────────────
    final gCol = isLight ? const Color(0xFF3A5A6A) : const Color(0xFF061409);

    // Pavement / kerb
    canvas.drawRect(Rect.fromLTWH(0, h - 18, w, 18),
        Paint()..color = isLight ? const Color(0xFF4A6275) : const Color(0xFF081510));

    // Road surface
    canvas.drawRect(Rect.fromLTWH(0, h - 10, w, 10),
        Paint()..color = gCol);

    // Centre-line road dashes
    final dashP = Paint()
      ..color = Colors.white.withOpacity(0.22)
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    for (double dx = 4; dx < w; dx += 26) {
      canvas.drawLine(Offset(dx, h - 5), Offset(dx + 14, h - 5), dashP);
    }

    // Reflection shimmer (dark only)
    if (!isLight) {
      final reflPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Colors.transparent, _C.green.withOpacity(0.06)],
        ).createShader(Rect.fromLTWH(0, h - 18, w, 18));
      canvas.drawRect(Rect.fromLTWH(0, h - 18, w, 18), reflPaint);
    }
  }

  @override bool shouldRepaint(_RealisticCityPainter o) => o.isLight != isLight;
}

// ─────────────────────────────────────────────────────────────────────────────
// ILLUSTRATION 1 — Coin stack (shown when imagePath is null)
// ─────────────────────────────────────────────────────────────────────────────
class _CoinsIllustration extends StatefulWidget {
  const _CoinsIllustration();
  @override State<_CoinsIllustration> createState() => _CoinsState();
}
class _CoinsState extends State<_CoinsIllustration> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: 3.s)..repeat(reverse: true);
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, __) {
      final f = Tween(begin: -10.0, end: 10.0).evaluate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
      return Stack(alignment: Alignment.center, children: [
        Container(width: 200, height: 200, decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
                colors: [_C.green.withOpacity(0.12), Colors.transparent]))),
        Transform.translate(offset: Offset(0, f),
            child: CustomPaint(size: const Size(200, 200), painter: _CoinPainter())),
        Positioned(top: 20, right: 14,
            child: Transform.translate(offset: Offset(0, f * -0.5),
                child: _Badge('🎯 Goal Reached!', _C.greenLight))),
        Positioned(bottom: 24, left: 10,
            child: Transform.translate(offset: Offset(0, f * 0.4),
                child: _Badge('+KSh 5,000', _C.goldLight))),
      ]);
    },
  );
}

class _CoinPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width/2; final cy = size.height/2;
    for (int i = 3; i >= 0; i--) {
      final y = cy + 30 - i * 20.0;
      canvas.drawOval(Rect.fromCenter(center: Offset(cx, y+7), width: 92, height: 22),
          Paint()..color = Colors.black26);
      canvas.drawOval(Rect.fromCenter(center: Offset(cx, y+4), width: 92, height: 22),
          Paint()..color = _C.gold.withOpacity(0.5));
      canvas.drawOval(Rect.fromCenter(center: Offset(cx, y), width: 92, height: 22),
          Paint()..color = i == 3 ? _C.gold : const Color(0xFFB8750A));
      if (i == 3) {
        final tp = TextPainter(
          text: const TextSpan(text: 'KSh', style: TextStyle(
              color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, fontFamily: 'Poppins')),
          textDirection: TextDirection.ltr)..layout();
        tp.paint(canvas, Offset(cx - tp.width/2, y - tp.height/2));
      }
    }
    final ap = Paint()..color=_C.green..strokeWidth=3..strokeCap=StrokeCap.round..style=PaintingStyle.stroke;
    canvas.drawPath(Path()
      ..moveTo(cx, cy-10)..lineTo(cx, cy-65)
      ..moveTo(cx-15, cy-50)..lineTo(cx, cy-67)..lineTo(cx+15, cy-50), ap);
    for (final o in [Offset(cx-72,cy-28),Offset(cx+68,cy-14),Offset(cx-52,cy+52),Offset(cx+58,cy+44)])
      canvas.drawCircle(o, 5, Paint()..color=_C.green.withOpacity(0.6));
  }
  @override bool shouldRepaint(_) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// ILLUSTRATION 2 — Multi-payment phone (shown when imagePath is null)
// ─────────────────────────────────────────────────────────────────────────────
class _PayIllustration extends StatefulWidget {
  const _PayIllustration();
  @override State<_PayIllustration> createState() => _PayState();
}
class _PayState extends State<_PayIllustration> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: 2.s)..repeat(reverse: true);
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, __) {
      final pulse = Tween(begin: 0.96, end: 1.04).evaluate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
      return Stack(alignment: Alignment.center, children: [
        for (int i = 1; i <= 3; i++) _ripple(i),
        Transform.scale(scale: pulse,
            child: CustomPaint(size: const Size(200, 215), painter: _PayPainter())),
      ]);
    },
  );

  Widget _ripple(int i) {
    final s = 120.0 + i * 42;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final p = ((_c.value + i * 0.33) % 1.0);
        return Container(width: s, height: s,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
                color: _C.green.withOpacity((0.5 - p * 0.5).clamp(0, 1)), width: 1.2)));
      },
    );
  }
}

class _PayPainter extends CustomPainter {
  static void _txt(Canvas c, String s, double cx, double y, double fs,
      FontWeight fw, Color col, {double ls = 0}) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(color: col, fontSize: fs,
          fontWeight: fw, fontFamily: 'Poppins', letterSpacing: ls)),
      textDirection: TextDirection.ltr)..layout();
    tp.paint(c, Offset(cx - tp.width/2, y - tp.height/2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width/2; final cy = size.height/2;
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx,cy), width: 112, height: 178),
        const Radius.circular(22)),
        Paint()..color = const Color(0xFF0F1F14));
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx,cy), width: 112, height: 178),
        const Radius.circular(22)),
        Paint()..color = _C.green.withOpacity(0.45)..style=PaintingStyle.stroke..strokeWidth=1.5);
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx,cy-4), width: 92, height: 147),
        const Radius.circular(13)),
        Paint()..color = const Color(0xFF0A1A0E));
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(cx-46, cy-77, 92, 30), const Radius.circular(13)),
        Paint()..color = _C.green);
    _txt(canvas, 'Choose Payment', cx, cy-61, 9, FontWeight.w700, Colors.white);
    const methods = [('M-Pesa 🟢', _C.green), ('Airtel Money 🔴', Color(0xFFFF3B30)), ('Card 💳', Color(0xFF4A90D9))];
    for (int i = 0; i < methods.length; i++) {
      final my = cy - 35 + i * 30.0;
      canvas.drawRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(cx-40, my-10, 80, 22), const Radius.circular(6)),
          Paint()..color = Colors.white.withOpacity(0.06));
      _txt(canvas, methods[i].$1, cx, my+1, 8.5, FontWeight.w600, Colors.white.withOpacity(0.88));
    }
    _txt(canvas, 'KES 500', cx, cy+62, 16, FontWeight.w800, Colors.white);
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(cx-33, cy+75, 66, 23), const Radius.circular(7)),
        Paint()..color = _C.gold);
    _txt(canvas, 'Donate', cx, cy+87, 10, FontWeight.w700, Colors.white);
    canvas.drawCircle(Offset(cx+64, cy-56), 15, Paint()..color = _C.green);
    final cp = Paint()..color=Colors.white..strokeWidth=2.2..strokeCap=StrokeCap.round
        ..strokeJoin=StrokeJoin.round..style=PaintingStyle.stroke;
    canvas.drawPath(Path()
        ..moveTo(cx+57,cy-55)..lineTo(cx+63,cy-50)..lineTo(cx+72,cy-62), cp);
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(cx-14, cy-80, 28, 7), const Radius.circular(4)),
        Paint()..color = const Color(0xFF0F1F14));
  }
  @override bool shouldRepaint(_) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// ILLUSTRATION 3 — Community
// ─────────────────────────────────────────────────────────────────────────────
class _CommunityIllustration extends StatefulWidget {
  const _CommunityIllustration();
  @override State<_CommunityIllustration> createState() => _CommState();
}
class _CommState extends State<_CommunityIllustration> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: 2.s)..repeat(reverse: true);
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, __) {
      final g = Tween(begin: 0.93, end: 1.0).evaluate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
      return Stack(alignment: Alignment.center, children: [
        Transform.scale(scale: g,
            child: CustomPaint(size: const Size(220, 210), painter: _CommPainter())),
        Positioned(top: 16, child: _Badge('🇰🇪  12,400+ Kenyans helped', _C.greenLight)),
      ]);
    },
  );
}

class _CommPainter extends CustomPainter {
  static void _t(Canvas c, String s, double cx, double cy, double fs) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(color: Colors.white, fontSize: fs,
          fontWeight: FontWeight.w800, fontFamily: 'Poppins', height: 1.3)),
      textDirection: TextDirection.ltr, textAlign: TextAlign.center)..layout(maxWidth: 50);
    tp.paint(c, Offset(cx - tp.width/2, cy - tp.height/2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width/2; final cy = size.height/2;
    canvas.drawCircle(Offset(cx,cy), 82, Paint()..color=_C.green.withOpacity(0.07));
    const people = [(dx:-62.0,col:_C.green,sc:0.8),(dx:0.0,col:_C.goldLight,sc:1.0),(dx:62.0,col:_C.greenLight,sc:0.8)];
    for (final p in people) {
      final px=cx+p.dx; final s=p.sc; final pt=Paint()..color=p.col;
      canvas.drawCircle(Offset(px, cy-42*s), 15*s, pt);
      canvas.drawRRect(RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(px,cy+4*s), width:34*s, height:52*s),
          Radius.circular(10*s)), pt);
    }
    final hx=cx; final hy=cy-88.0;
    canvas.drawPath(Path()
      ..moveTo(hx,hy+10)..cubicTo(hx,hy,hx-13,hy-7,hx-13,hy+5)
      ..cubicTo(hx-13,hy+15,hx,hy+22,hx,hy+22)
      ..cubicTo(hx,hy+22,hx+13,hy+15,hx+13,hy+5)
      ..cubicTo(hx+13,hy-7,hx,hy,hx,hy+10),
        Paint()..color=_C.error.withOpacity(0.88));
    canvas.drawCircle(Offset(cx+80,cy+10), 19, Paint()..color=_C.gold);
    canvas.drawCircle(Offset(cx-80,cy+10), 16, Paint()..color=_C.green);
    _t(canvas, '+KSh\n500', cx+80, cy+10, 7.5);
    _t(canvas, '+200',      cx-80, cy+10, 8.0);
  }
  @override bool shouldRepaint(_) => false;
}