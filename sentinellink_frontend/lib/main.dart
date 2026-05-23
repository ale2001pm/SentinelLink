import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/login_screen.dart';
import 'services/auth_provider.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final AuthProvider authProvider = AuthProvider();
  await authProvider.initPreferences();
  runApp(SentinelLinkApp(authProvider: authProvider));
}

class SentinelLinkApp extends StatelessWidget {
  const SentinelLinkApp({super.key, required this.authProvider});

  final AuthProvider authProvider;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: <ChangeNotifierProvider<dynamic>>[
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider<ThemeController>(create: (_) => ThemeController()),
      ],
      child: Consumer<ThemeController>(
        builder: (BuildContext context, ThemeController theme, Widget? child) {
          return MaterialApp(
            title: 'SentinelLink',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme(),
            darkTheme: AppTheme.darkTheme(),
            themeMode: theme.mode,
            home: const LoginScreen(),
          );
        },
      ),
    );
  }
}
