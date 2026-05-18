import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/login_screen.dart';
import 'services/auth_provider.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const SentinelLinkApp());
}

class SentinelLinkApp extends StatelessWidget {
  const SentinelLinkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AuthProvider>(
      create: (_) => AuthProvider(),
      child: MaterialApp(
        title: 'SentinelLink',
        theme: AppTheme.lightTheme(),
        home: const LoginScreen(),
      ),
    );
  }
}
