import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme/app_theme.dart';
import 'core/network/auth_service.dart';
import 'router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;

  runApp(
    ProviderScope(
      child: p.MultiProvider(
        providers: [
          p.ChangeNotifierProvider(create: (_) => AuthProvider()),
        ],
        child: InuaFundApp(showOnboarding: !hasSeenOnboarding),
      ),
    ),
  );
}

class InuaFundApp extends StatelessWidget {
  final bool showOnboarding;
  const InuaFundApp({super.key, required this.showOnboarding});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'InuaFund',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: createRouter(showOnboarding: showOnboarding),
    );
  }
}