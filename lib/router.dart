import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'features/auth/screens/onboarding_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/otp_screen.dart';

import 'features/home/screens/home_screen.dart';

import 'features/campaign/screens/create_campaign.dart';
import 'features/campaign/screens/single_campaign_screen.dart';
import 'features/campaign/screens/explore_campaigns.dart';
import 'features/campaign/screens/campaign_categories.dart';

import 'features/profile/screens/profile_screen.dart';
import 'features/notifications/screens/notifications_screen.dart';

import 'features/account/my_campaigns.dart';
import 'features/account/my_donations.dart';
import 'features/account/withdrwal.dart';
import 'features/account/FavoritesPage.dart';

import 'features/shell/app_shell.dart';

import 'core/network/auth_service.dart';

const _authRoutes = {
  '/login',
  '/register',
  '/forgot-password',
  '/otp',
  '/onboarding',
};

GoRouter createRouter({
  required bool showOnboarding,
  required bool isLoggedIn,
  required AuthProvider authProvider,
}) {
  return GoRouter(
    initialLocation:
        showOnboarding ? '/onboarding' : (isLoggedIn ? '/home' : '/login'),

    refreshListenable: authProvider,

    redirect: (context, state) {
      final loc = state.matchedLocation;
      final loggedIn = authProvider.isAuthenticated;
      final isAuthRoute = _authRoutes.contains(loc);

      // Wait until auth is initialized
      if (authProvider.loading) return null;

      // 🚫 Not logged in → block protected routes
      if (!loggedIn && !isAuthRoute) {
        return '/login';
      }

      // 🚫 Logged in → prevent going back to auth screens
      if (loggedIn && isAuthRoute && loc != '/onboarding') {
        return '/home';
      }

      return null;
    },

    routes: [
      // ───────── AUTH ─────────
      GoRoute(
        path: '/onboarding',
        builder: (_, __) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (_, __) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (_, __) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/otp',
        builder: (_, state) {
          final phone = state.extra;
          return phone is String
              ? OtpScreen(phone: phone)
              : const Scaffold(
                  body: Center(child: Text('Invalid phone number')),
                );
        },
      ),

      // ───────── FULL SCREEN ─────────
      GoRoute(
        path: '/campaigns/:id',
        builder: (_, state) =>
            SingleCampaignScreen(campaignId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/start-campaign',
        builder: (_, __) => const StartCampaignScreen(),
      ),

      // ───────── SHELL (BOTTOM NAV) ─────────
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => AppShell(navigationShell: shell),
        branches: [
          // HOME
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/home',
              builder: (_, __) => const HomeScreen(),
            ),
          ]),

          // EXPLORE
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/explore',
              builder: (_, __) => const ExploreScreen(),
            ),
            GoRoute(
              path: '/categories/:category',
              builder: (_, state) =>
                  CategoryPage(category: state.pathParameters['category']!),
            ),
          ]),

          // NOTIFICATIONS
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/alerts',
              builder: (_, __) => const NotificationsScreen(),
            ),
          ]),

          // PROFILE
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/profile',
              builder: (_, __) => const ProfileScreen(),
            ),
            GoRoute(
              path: '/profile/my-campaigns',
              builder: (_, __) => const MyCampaignsScreen(),
            ),
            GoRoute(
              path: '/profile/my-donations',
              builder: (_, __) => const DonationsScreen(),
            ),
            GoRoute(
              path: '/profile/withdrawal/:campaignId',
              builder: (_, state) => WithdrawalScreen(
                campaignId: state.pathParameters['campaignId'] ?? '',
              ),
            ),
            GoRoute(
              path: '/favorites',
              builder: (_, __) => const FavoritesScreen(),
            ),
          ]),
        ],
      ),
    ],
  );
}