import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';

class SharedBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final VoidCallback onFabTap;
  final Color surface;
  final Color background;

  const SharedBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.onFabTap,
    required this.surface,
    required this.background,
    required Color border,
    required Color textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: background,
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // Pill background
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(32),
                  ),
                ),
              ),

              // Nav row
              Row(
                children: [
                  Expanded(child: _NavItem(icon: Icons.home_outlined, label: 'Home', idx: 0, cur: currentIndex, onTap: onTap)),
                  Expanded(child: _NavItem(icon: Icons.explore_outlined, label: 'Explore', idx: 1, cur: currentIndex, onTap: onTap)),

                  // FAB — lifts 10px above the bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Transform.translate(
                      offset: const Offset(0, -4),
                      child: GestureDetector(
                        onTap: onFabTap,
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: surface,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.12),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.add_box_rounded,
                            color: AppColors.forestGreen,
                            size: 26,
                          ),
                        ),
                      ),
                    ),
                  ),

                  Expanded(child: _NavItem(icon: Icons.notifications_outlined, label: 'Alerts', idx: 3, cur: currentIndex, onTap: onTap)),
                  Expanded(child: _NavItem(icon: Icons.person_outline_rounded, label: 'Profile', idx: 4, cur: currentIndex, onTap: onTap)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int idx, cur;
  final Function(int) onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.idx,
    required this.cur,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = idx == cur;
    return GestureDetector(
      onTap: () => onTap(idx),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 22,
              color: active ? AppColors.forestGreen : Colors.grey,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                color: active ? AppColors.forestGreen : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}