import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

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
  '/onboarding'
};

GoRouter createRouter({
  required bool showOnboarding,
  required bool isLoggedIn,
  required AuthProvider authProvider,
}) {
  return GoRouter(
    initialLocation:
        showOnboarding ? '/onboarding' : (isLoggedIn ? '/home' : '/login'),
    refreshListenable:
        authProvider, // ← re-runs redirect on every auth state change

    redirect: (context, state) {
      final loc = state.matchedLocation;
      final loggedIn = authProvider.isAuthenticated;
      final isAuth = _authRoutes.contains(loc);

      if (authProvider.loading) return null; // wait for init
      if (!loggedIn && !isAuth) return '/login'; // guard protected
      if (loggedIn && isAuth && loc != '/onboarding')
        return '/home'; // no back to auth
      return null;
    },

    routes: [
      // ── Auth (no bottom nav) ───────────────────────────────────────────────
      GoRoute(
          path: '/onboarding',
          name: 'onboarding',
          builder: (_, __) => const OnboardingScreen()),
      GoRoute(
          path: '/login',
          name: 'login',
          builder: (_, __) => const LoginScreen()),
      GoRoute(
          path: '/register',
          name: 'register',
          builder: (_, __) => const RegisterScreen()),
      GoRoute(
          path: '/forgot-password',
          name: 'forgotPassword',
          builder: (_, __) => const ForgotPasswordScreen()),
      GoRoute(
        path: '/otp',
        name: 'otp',
        builder: (_, state) {
          final phone = state.extra;
          return phone is String
              ? OtpScreen(phone: phone)
              : const Scaffold(
                  body: Center(child: Text('Invalid phone number')));
        },
      ),

      // ── Full-screen (no bottom nav) ────────────────────────────────────────
      GoRoute(
        path: '/campaigns/:id',
        name: 'campaignDetails',
        builder: (_, state) =>
            SingleCampaignScreen(campaignId: state.pathParameters['id']!),
      ),
      GoRoute(
          path: '/start-campaign',
          name: 'startCampaign',
          builder: (_, __) => const StartCampaignScreen()),

      // ── Shell (bottom nav) ─────────────────────────────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => AppShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/home',
                name: 'home',
                builder: (_, __) => const HomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/explore',
                name: 'explore',
                builder: (_, __) => const ExploreScreen()),
            GoRoute(
              path: '/categories/:category',
              name: 'category',
              builder: (_, state) =>
                  CategoryPage(category: state.pathParameters['category']!),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/alerts',
                name: 'alerts',
                builder: (_, __) => const NotificationsScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/profile',
                name: 'profile',
                builder: (_, __) => const ProfileScreen()),
            GoRoute(
                path: '/profile/my-campaigns',
                name: 'myCampaigns',
                builder: (_, __) => const MyCampaignsScreen()),
            GoRoute(
                path: '/profile/my-donations',
                name: 'myDonations',
                builder: (_, __) => const DonationsScreen()),
            //GoRoute(path: '/campaigns/:id/withdraw',   name: 'withdrawal',  builder: (_, __) => const WithdrawalScreen(campaignId: '')),
            GoRoute(
              path: '/profile/withdrawal/:campaignId',
              name: 'withdrawal',
              builder: (_, state) => WithdrawalScreen(
                  campaignId: state.pathParameters['campaignId'] ?? ''),
            ),
            GoRoute(
              path: '/favorites',
              name: 'favorites',
              builder: (_, __) => const FavoritesScreen(),
            ),
          ]),
        ],
      ),
    ],
  );
}
