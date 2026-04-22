import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as p;
import 'core/theme/app_theme.dart';
import 'core/network/auth_service.dart';
import 'router.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ProviderScope(
      child: p.MultiProvider(
        providers: [
          p.ChangeNotifierProvider(create: (_) => AuthProvider()),
        ],
        child: const InuaFundApp(),
      ),
    ),
  );
}

class InuaFundApp extends StatelessWidget {
  const InuaFundApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'InuaFund',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: appRouter,
    );
  }
}
