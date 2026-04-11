import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_provider.dart';
import 'login_screen.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthProvider auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('SentinelLink - Chat'),
        actions: <Widget>[
          TextButton(
            onPressed: () async {
              await context.read<AuthProvider>().logout();
              if (!context.mounted) {
                return;
              }
              Navigator.of(context).pushReplacement(
                MaterialPageRoute<LoginScreen>(
                  builder: (BuildContext context) => const LoginScreen(),
                ),
              );
            },
            child: const Text('Salir'),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Icon(Icons.chat_bubble_outline, size: 72),
              const SizedBox(height: 16),
              Text(
                'Bienvenido, ${auth.username ?? 'usuario'}',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('Rol: ${auth.role ?? 'desconocido'}'),
              const SizedBox(height: 18),
              const Text(
                'Fase 4 completada: login funcional de extremo a extremo.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
