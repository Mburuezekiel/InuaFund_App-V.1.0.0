import 'package:go_router/go_router.dart';
import 'features/auth/screens/onboarding_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/otp_screen.dart';
import 'features/home/screens/home_screen.dart';
import 'features/campaign/screens/create_campaign.dart';
import 'features/profile/screens/profile_screen.dart';
import 'features/notifications/screens/notifications_screen.dart';


import 'features/campaign/screens/single_campaign_screen.dart'; 
import 'features/campaign/screens/explore_campaigns.dart';

GoRouter createRouter({required bool showOnboarding}) => GoRouter(
  initialLocation: showOnboarding ? '/onboarding' : '/home',
  routes: [
    // Auth routes
    GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
    GoRoute(path: '/login',      builder: (_, __) => const LoginScreen()),
    GoRoute(path: '/register',   builder: (_, __) => const RegisterScreen()),
    GoRoute(
      path: '/forgot-password',
      builder: (_, __) => const ForgotPasswordScreen(),
    ),
    GoRoute(
      path: '/otp',
      builder: (ctx, state) => OtpScreen(phone: state.extra as String),
    ),
    GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
    GoRoute(path: '/',     builder: (_, __) => const HomeScreen()),

    // Campaign routes
    GoRoute(path: '/start-campaign', builder: (_, __) => const StartCampaignScreen()),
    GoRoute(path: '/campaigns/:id', builder: (ctx, state) {
      final id = state.pathParameters['id']!;
      return SingleCampaignScreen(campaignId: id);
    }),
    GoRoute(path: '/explore', builder: (_, __) => const ExploreScreen()),    
    // Profile routes
    GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),

    // Notifications routes
    GoRoute(path: '/alerts', builder: (_, __) => const NotificationsScreen()),
  ],
);