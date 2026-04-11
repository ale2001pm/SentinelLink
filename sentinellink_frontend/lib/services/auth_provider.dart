import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/socket_message.dart';
import 'websocket_service.dart';

class AuthProvider extends ChangeNotifier {
  final WebSocketService _webSocketService = WebSocketService();

  StreamSubscription<SocketMessage>? _messagesSubscription;

  String? username;
  String? role;
  String? errorMessage;

  bool isLoading = false;
  bool isLoggedIn = false;

  String webSocketUrl = 'ws://localhost:8080/ws';

  Future<bool> login({
    required String inputUsername,
    required String inputPassword,
  }) async {
    errorMessage = null;
    isLoading = true;
    notifyListeners();

    try {
      await _webSocketService.connect(webSocketUrl);

      final Completer<bool> completer = Completer<bool>();
      await _messagesSubscription?.cancel();
      _messagesSubscription = _webSocketService.messages.listen((SocketMessage msg) {
        if (msg.type == 'LOGIN_RESPONSE') {
          final bool success = msg.data['success'] == true;
          if (success) {
            isLoggedIn = true;
            username = (msg.data['username'] ?? inputUsername).toString();
            role = (msg.data['role'] ?? '').toString();
            errorMessage = null;
          } else {
            isLoggedIn = false;
            errorMessage = (msg.data['error'] ?? 'Error de login').toString();
          }
          if (!completer.isCompleted) {
            completer.complete(success);
          }
        }
      });

      _webSocketService.send(
        SocketMessage(
          type: 'LOGIN_REQUEST',
          data: <String, dynamic>{
            'username': inputUsername,
            'password': inputPassword,
          },
        ),
      );

      final bool result = await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          errorMessage = 'Timeout esperando LOGIN_RESPONSE';
          return false;
        },
      );

      return result;
    } catch (e) {
      errorMessage = 'No se pudo conectar al backend: $e';
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _messagesSubscription?.cancel();
    _messagesSubscription = null;
    await _webSocketService.disconnect();
    username = null;
    role = null;
    isLoggedIn = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    _webSocketService.dispose();
    super.dispose();
  }
}
