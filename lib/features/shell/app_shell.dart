// lib/features/shell/app_shell.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../shared/widgets/shared_bottom_nav.dart';
import '../../core/theme/colors.dart';

class AppShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

  void _onTap(int index) {
  // index 2 is the FAB — handled by onFabTap, never reaches here
  final branchIndex = index > 2 ? index - 1 : index;
  navigationShell.goBranch(branchIndex,
    initialLocation: branchIndex == navigationShell.currentIndex);
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: SharedBottomNav(
        currentIndex: navigationShell.currentIndex,
        onTap: _onTap,
        onFabTap: () => context.push('/start-campaign'),
        surface: AppColors.white,
        border: AppColors.cloud,
        textColor: AppColors.mist,
        background: AppColors.white,
      ),
    );
  }
}