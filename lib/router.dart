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
import 'features/shell/app_shell.dart';

GoRouter createRouter({required bool showOnboarding}) => GoRouter(
  initialLocation: showOnboarding ? '/onboarding' : '/home',
  routes: [

    // ── Auth routes (no nav bar) ──────────────────────────────────────────────
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
      builder: (ctx, state) => OtpScreen(phone: state.extra as String),
    ),

    // ── Full-screen campaign routes (no nav bar) ──────────────────────────────
    GoRoute(
      path: '/campaigns/:id',
      builder: (ctx, state) => SingleCampaignScreen(
        campaignId: state.pathParameters['id']!,
      ),
    ),
    GoRoute(
      path: '/start-campaign',
      builder: (_, __) => const StartCampaignScreen(),
    ),

    // ── Shell — all tabs share SharedBottomNav ────────────────────────────────
    // Branch index map:
    //   0 → /home   (Home)
    //   1 → /explore (Explore + categories)
    //   2 → /alerts  (Alerts)       ← nav item index 3
    //   3 → /profile (Profile)      ← nav item index 4
    //
    // The centre FAB (nav item index 2) is NOT a branch — AppShell
    // intercepts onFabTap and calls context.push('/start-campaign').
    StatefulShellRoute.indexedStack(
      builder: (ctx, state, shell) => AppShell(navigationShell: shell),
      branches: [

        // Branch 0 — Home (nav index 0)
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/home',
              builder: (_, __) => const HomeScreen(),
            ),
          ],
        ),

        // Branch 1 — Explore (nav index 1)
        // /categories/:category is nested here so it stays inside the shell
        // and the nav bar remains visible while browsing a category.
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/explore',
              builder: (_, __) => const ExploreScreen(),
            ),
            GoRoute(
              path: '/categories/:category',
              builder: (ctx, state) => CategoryPage(
                category: state.pathParameters['category']!,
              ),
            ),
          ],
        ),

        // Branch 2 — Alerts (nav index 3)
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/alerts',
              builder: (_, __) => const NotificationsScreen(),
            ),
          ],
        ),

        // Branch 3 — Profile (nav index 4)
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/profile',
              builder: (_, __) => const ProfileScreen(),
            ),
          ],
        ),
      ],
    ),
  ],
);