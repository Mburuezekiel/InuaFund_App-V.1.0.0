import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/network/auth_service.dart';
import 'router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Status bar styling
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Color(0xFF16A34A),
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ),
  );

  final authState = await AuthService.instance.getCurrentUser();
  final showOnboarding = await _checkOnboarding();

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

  const MyApp({
    super.key,
    required this.showOnboarding,
    required this.isLoggedIn,
  });

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    final router = createRouter(
      showOnboarding: showOnboarding,
      isLoggedIn: isLoggedIn,
      authProvider: authProvider,
    );

    return MaterialApp.router(
      title: 'InuaFund',
      theme: ThemeData.dark(),
      debugShowCheckedModeBanner: false,
      routerConfig: router,
    );
  }
}

// ✅ REAL onboarding check
Future<bool> _checkOnboarding() async {
  final prefs = await SharedPreferences.getInstance();
  return !(prefs.getBool('hasCompletedOnboarding') ?? false);
}