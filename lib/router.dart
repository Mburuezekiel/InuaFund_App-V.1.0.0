import 'package:go_router/go_router.dart';
import 'features/auth/screens/onboarding_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/otp_screen.dart';
import 'features/home/screens/home_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/onboarding',
  routes: [
    GoRoute(path: '/onboarding',  builder: (_, __) => const OnboardingScreen()),
    GoRoute(path: '/login',       builder: (_, __) => const LoginScreen()),
    GoRoute(path: '/otp',         builder: (ctx, state) => OtpScreen(phone: state.extra as String)),
    GoRoute(path: '/home',        builder: (_, __) => const HomeScreen()),
    // More routes added as we build each screen
  ],
);