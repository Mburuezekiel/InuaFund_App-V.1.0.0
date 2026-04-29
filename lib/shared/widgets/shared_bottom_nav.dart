import 'package:flutter/material.dart';

import '../../core/theme/colors.dart'; // adjust path

class SharedBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final VoidCallback onFabTap;

  final Color surface;
  final Color border;
  final Color textColor;

  const SharedBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.onFabTap,
    required this.surface,
    required this.border,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.09),
            blurRadius: 16,
            offset: const Offset(0, -3),
          )
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              Expanded(
                child: _NavItem(
                  icon: Icons.home_rounded,
                  label: 'Home',
                  idx: 0,
                  cur: currentIndex,
                  txt2: textColor,
                  onTap: onTap,
                ),
              ),
              Expanded(
                child: _NavItem(
                  icon: Icons.explore_rounded,
                  label: 'Explore',
                  idx: 1,
                  cur: currentIndex,
                  txt2: textColor,
                  onTap: onTap,
                ),
              ),

              /// 🔥 CENTER FAB
              SizedBox(
                width: 72,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      top: -8,
                      child: CustomPaint(
                        size: const Size(72, 40),
                        painter: _NavArchPainter(
                          color: surface,
                          borderColor: border,
                        ),
                      ),
                    ),
                    Positioned(
                      top: -12,
                      child: GestureDetector(
                        onTap: onFabTap,
                        child: Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [
                                AppColors.forestGreen,
                                AppColors.limeGreen
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.midGreen.withOpacity(0.45),
                                blurRadius: 16,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.add_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: _NavItem(
                  icon: Icons.notifications_outlined,
                  label: 'Alerts',
                  idx: 3,
                  cur: currentIndex,
                  txt2: textColor,
                  onTap: onTap,
                ),
              ),
              Expanded(
                child: _NavItem(
                  icon: Icons.person_outline_rounded,
                  label: 'Profile',
                  idx: 4,
                  cur: currentIndex,
                  txt2: textColor,
                  onTap: onTap,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
class _NavArchPainter extends CustomPainter {
  final Color color;
  final Color borderColor;

  const _NavArchPainter({
    required this.color,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    const r = 32.0;

    final fillPath = Path()
      ..moveTo(0, h)
      ..lineTo(0, r * 0.7)
      ..arcToPoint(
        Offset(w, r * 0.7),
        radius: const Radius.circular(r + 4),
        clockwise: false,
      )
      ..lineTo(w, h)
      ..close();

    canvas.drawPath(fillPath, Paint()..color = color);

    final borderPath = Path()
      ..moveTo(0, r * 0.7)
      ..arcToPoint(
        Offset(w, r * 0.7),
        radius: const Radius.circular(r + 4),
        clockwise: false,
      );

    canvas.drawPath(
      borderPath,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }

  @override
  bool shouldRepaint(covariant _NavArchPainter old) =>
      old.color != color || old.borderColor != borderColor;
}
class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int idx, cur;
  final Color txt2;
  final Function(int) onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.idx,
    required this.cur,
    required this.txt2,
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
            size: 22,
            color: active ? AppColors.forestGreen : txt2,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: active ? FontWeight.w700 : FontWeight.w400,
              color: active ? AppColors.forestGreen : txt2,
            ),
          ),
        ],
      ),
    );
  }
}