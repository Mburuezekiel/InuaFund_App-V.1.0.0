import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';

class SharedBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final VoidCallback onFabTap;
  final Color surface;      // pill color    e.g. Color(0xFFF0F2F4)
  final Color background;   // outer bar bg  e.g. Color(0xFFD0DCE8)
  final Color textColor;

  const SharedBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.onFabTap,
    required this.surface,
    required this.background,
    required this.textColor, required Color border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: background,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // ── Single conjoined pill ──
              Positioned.fill(
                child: CustomPaint(
                  painter: _ConjoinedPillPainter(
                    color: surface,
                    bgColor: background,
                  ),
                ),
              ),

              // ── Nav items + FAB in a Row ──
              Row(
                children: [
                  Expanded(
                    child: _NavItem(
                      icon: Icons.home_outlined,
                      label: 'Home',
                      idx: 0,
                      cur: currentIndex,
                      textColor: textColor,
                      onTap: onTap,
                    ),
                  ),
                  Expanded(
                    child: _NavItem(
                      icon: Icons.explore_outlined,
                      label: 'Explore',
                      idx: 1,
                      cur: currentIndex,
                      textColor: textColor,
                      onTap: onTap,
                    ),
                  ),

                  // ── FAB slot ──
                  SizedBox(
                    width: 72,
                    child: Center(
                      child: GestureDetector(
                        onTap: onFabTap,
                        child: Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: surface,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.13),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.add_box_rounded,
                            color: AppColors.forestGreen,
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                  ),

                  Expanded(
                    child: _NavItem(
                      icon: Icons.notifications_outlined,
                      label: 'Alerts',
                      idx: 3,
                      cur: currentIndex,
                      textColor: textColor,
                      onTap: onTap,
                    ),
                  ),
                  Expanded(
                    child: _NavItem(
                      icon: Icons.person_outline_rounded,
                      label: 'Profile',
                      idx: 4,
                      cur: currentIndex,
                      textColor: textColor,
                      onTap: onTap,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Draws one pill with concave bites on both sides of the centre FAB slot
class _ConjoinedPillPainter extends CustomPainter {
  final Color color;
  final Color bgColor;

  const _ConjoinedPillPainter({required this.color, required this.bgColor});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final h  = size.height;
    const slotHalf  = 36.0;  // half-width of the FAB gap
    const biteDepth = 10.0;  // how deep the concave shoulder cuts in
    const r         = 28.0;  // pill corner radius

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, h),
        const Radius.circular(r),
      ));

    // Punch a concave bite into the top of the pill at the centre
    final bite = Path()
      ..moveTo(cx - slotHalf - 16, 0)
      ..quadraticBezierTo(cx - slotHalf,  0, cx - slotHalf + 10, biteDepth)
      ..quadraticBezierTo(cx, biteDepth + 4, cx + slotHalf - 10, biteDepth)
      ..quadraticBezierTo(cx + slotHalf,  0, cx + slotHalf + 16, 0)
      ..lineTo(cx + slotHalf + 16, -10)
      ..lineTo(cx - slotHalf - 16, -10)
      ..close();

    final combined = Path.combine(PathOperation.difference, path, bite);

    canvas.drawPath(combined, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _ConjoinedPillPainter old) =>
      old.color != color || old.bgColor != bgColor;
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int idx, cur;
  final Color textColor;
  final Function(int) onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.idx,
    required this.cur,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = idx == cur;
    return GestureDetector(
      onTap: () => onTap(idx),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 24,
            color: active ? AppColors.forestGreen : textColor,
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: active ? FontWeight.w700 : FontWeight.w400,
              color: active ? AppColors.forestGreen : textColor,
            ),
          ),
        ],
      ),
    );
  }
}