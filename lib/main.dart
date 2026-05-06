import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/network/auth_service.dart';
import 'router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Read one-time boot flags before the provider is ready
  final authState      = await AuthService.instance.getCurrentUser();
  final showOnboarding = await _checkOnboarding(); // your existing flag logic

  runApp(
    ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: MyApp(
        showOnboarding: showOnboarding,
        isLoggedIn: authState.isAuthenticated,
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  final bool showOnboarding;
  final bool isLoggedIn;
  const MyApp({super.key, required this.showOnboarding, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    // Router is rebuilt whenever authProvider notifies (login / logout)
    final router = createRouter(
      showOnboarding: showOnboarding,
      isLoggedIn: isLoggedIn,
      authProvider: authProvider,
    );

    return MaterialApp.router(
      title: 'InuaFund',
      theme: ThemeData.dark(),
      routerConfig: router,
    );
  }
}

Future<bool> _checkOnboarding() async {
  // your SharedPreferences / secure storage check here
  return false;
}