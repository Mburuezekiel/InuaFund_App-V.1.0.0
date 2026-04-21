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
// Set [imagePath] to e.g. 'assets/images/slide1.png' for slides 1 & 2.
// Leave null to show the built-in illustration instead.
// ─────────────────────────────────────────────────────────────────────────────
class _Slide {
  final String tag, title, accent, subtitle, cta;
  final String? imagePath;
  final Widget illustration;
  const _Slide({
    required this.tag, required this.title, required this.accent,
    required this.subtitle, required this.cta,
    required this.illustration, this.imagePath,
  });
}

final _slides = <_Slide>[
  _Slide(
    tag: 'FUNDRAISING', title: 'Inua Ndoto', accent: 'Zako',
    subtitle: 'Start a campaign for medical bills, school fees, emergencies '
        'or community projects — trusted by thousands of Kenyans.',
    cta: 'Continue',
    // ✏️ Replace null with your asset path to show an image:
     imagePath: 'assets/images/welcome.png',
    // imagePath: null,
    illustration: const _CoinsIllustration(),
  ),
  _Slide(
    tag: 'PAYMENTS', title: 'Donate Fast &', accent: 'Securely',
    subtitle: 'Donate via M-Pesa, Airtel Money, credit/debit card and more. '
        'Every shilling reaches the right person — instantly & safely.',
    cta: 'Continue',
    // ✏️ Replace null with your asset path to show an image:
     imagePath: 'assets/images/SuccessDonation.jpeg',
   // imagePath: null,
    illustration: const _PayIllustration(),
  ),
  _Slide(
    tag: 'COMMUNITY', title: 'Pamoja', accent: 'Tunaweza',
    subtitle: 'Join a growing community of Kenyans making a real difference '
        'in their neighbourhoods every single day.',
        imagePath: 'assets/images/crowdfunding.jpeg',
    cta: 'Get Started',
    illustration: const _CommunityIllustration(),
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

    return Scaffold(
      backgroundColor: _C.dark,
      body: Stack(children: [
        // ── Sky ──────────────────────────────────────────────────────────
        AnimatedContainer(
          duration: 700.ms,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight, colors: sky),
          ),
        ),

        // ── Stars ─────────────────────────────────────────────────────────
        const _StarField(),

        // ── City silhouette ───────────────────────────────────────────────
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: CustomPaint(size: Size(w, h * 0.42), painter: _CityPainter()),
        ),

        // ── Horizon glow ──────────────────────────────────────────────────
        Positioned(
          bottom: h * 0.15, left: 40, right: 40,
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
              children: [_Logo(), _SkipBtn(onTap: () => context.go('/login'))],
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
// ─────────────────────────────────────────────────────────────────────────────
class _SlideVisual extends StatelessWidget {
  final _Slide slide;
  const _SlideVisual({super.key, required this.slide});
  @override
  Widget build(BuildContext context) {
    if (slide.imagePath != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Image.asset(slide.imagePath!, fit: BoxFit.cover),
        ),
      );
    }
    return slide.illustration;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SMALL UI WIDGETS
// ─────────────────────────────────────────────────────────────────────────────
class _Logo extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(
      width: 33, height: 33,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9),
        gradient: const LinearGradient(colors: [_C.green, _C.greenDark]),
        boxShadow: [BoxShadow(color: _C.green.withOpacity(0.45), blurRadius: 12)],
      ),
      child: const Center(child: Text('🌱', style: TextStyle(fontSize: 17))),
    ),
    const SizedBox(width: 8),
    RichText(text: const TextSpan(
      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, fontFamily: 'Poppins'),
      children: [
        TextSpan(text: 'Inua', style: TextStyle(color: Colors.white)),
        TextSpan(text: 'Fund', style: TextStyle(color: _C.green)),
      ],
    )),
  ]);
}

class _SkipBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _SkipBtn({required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: const Text('Skip', style: TextStyle(
          color: _C.muted, fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'Poppins')),
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
// CITY PAINTER
// ─────────────────────────────────────────────────────────────────────────────
class _CityPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width; final h = size.height;
    final rng = Random(99);
    // [x%, width%, height%]
    const bldgs = [
      [0.00,0.07,0.55],[0.06,0.06,0.65],[0.11,0.05,0.58],[0.15,0.08,0.72],
      [0.22,0.04,0.60],[0.26,0.09,0.82],[0.34,0.05,0.68],[0.38,0.10,0.88],
      [0.48,0.06,0.75],[0.53,0.13,0.92],[0.65,0.06,0.70],[0.70,0.10,0.85],
      [0.79,0.05,0.68],[0.83,0.08,0.60],[0.90,0.10,0.72],
    ];
    const cols = [0xFF0E1F14, 0xFF112318, 0xFF133020, 0xFF0D2B1A];
    for (int i = 0; i < bldgs.length; i++) {
      final bx=bldgs[i][0]*w; final bw=bldgs[i][1]*w; final bh=bldgs[i][2]*h;
      canvas.drawRRect(
        RRect.fromRectAndCorners(Rect.fromLTWH(bx, h-bh, bw, bh),
            topLeft: const Radius.circular(2), topRight: const Radius.circular(2)),
        Paint()..color = Color(cols[i % cols.length]),
      );
      for (int j = 0; j < 6; j++) {
        final wx = bx + 3 + rng.nextDouble() * (bw - 8).clamp(0, bw);
        final wy = (h - bh) + 6 + rng.nextDouble() * bh * 0.7;
        final wc = j % 3 == 0 ? _C.gold : j % 4 == 0 ? _C.green : Colors.white;
        canvas.drawRect(Rect.fromLTWH(wx, wy, 4, 6),
            Paint()..color = wc.withOpacity(0.4 + rng.nextDouble() * 0.35));
      }
    }
    canvas.drawRect(Rect.fromLTWH(0, h-3, w, 3), Paint()..color = const Color(0xFF061409));
  }
  @override bool shouldRepaint(_) => false;
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

    // Phone body + border
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx,cy), width: 112, height: 178),
        const Radius.circular(22)),
        Paint()..color = const Color(0xFF0F1F14));
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx,cy), width: 112, height: 178),
        const Radius.circular(22)),
        Paint()..color = _C.green.withOpacity(0.45)..style=PaintingStyle.stroke..strokeWidth=1.5);

    // Screen
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx,cy-4), width: 92, height: 147),
        const Radius.circular(13)),
        Paint()..color = const Color(0xFF0A1A0E));

    // Header bar
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(cx-46, cy-77, 92, 30), const Radius.circular(13)),
        Paint()..color = _C.green);
    _txt(canvas, 'Choose Payment', cx, cy-61, 9, FontWeight.w700, Colors.white);

    // Payment rows: M-Pesa, Airtel Money, Card
    const methods = [('M-Pesa 🟢', _C.green), ('Airtel Money 🔴', Color(0xFFFF3B30)), ('Card 💳', Color(0xFF4A90D9))];
    for (int i = 0; i < methods.length; i++) {
      final my = cy - 35 + i * 30.0;
      canvas.drawRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(cx-40, my-10, 80, 22), const Radius.circular(6)),
          Paint()..color = Colors.white.withOpacity(0.06));
      _txt(canvas, methods[i].$1, cx, my+1, 8.5, FontWeight.w600, Colors.white.withOpacity(0.88));
    }

    // Amount
    _txt(canvas, 'KES 500', cx, cy+62, 16, FontWeight.w800, Colors.white);

    // Donate button
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(cx-33, cy+75, 66, 23), const Radius.circular(7)),
        Paint()..color = _C.gold);
    _txt(canvas, 'Donate', cx, cy+87, 10, FontWeight.w700, Colors.white);

    // Success badge
    canvas.drawCircle(Offset(cx+64, cy-56), 15, Paint()..color = _C.green);
    final cp = Paint()..color=Colors.white..strokeWidth=2.2..strokeCap=StrokeCap.round
        ..strokeJoin=StrokeJoin.round..style=PaintingStyle.stroke;
    canvas.drawPath(Path()
        ..moveTo(cx+57,cy-55)..lineTo(cx+63,cy-50)..lineTo(cx+72,cy-62), cp);

    // Notch
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

    // Heart
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