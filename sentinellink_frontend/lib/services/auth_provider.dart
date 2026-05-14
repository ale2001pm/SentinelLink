import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/chat_channel.dart';
import '../models/chat_message.dart';
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

  final List<ChatChannel> channels = <ChatChannel>[];
  final List<String> onlineUsers = <String>[];
  final Map<int, List<ChatMessage>> _messagesByChannel = <int, List<ChatMessage>>{};

  int? selectedChannelId;
  Completer<bool>? _loginCompleter;

  String webSocketUrl = 'ws://localhost:8080/ws';

  List<ChatMessage> get selectedMessages {
    final int? channelId = selectedChannelId;
    if (channelId == null) {
      return const <ChatMessage>[];
    }
    return List<ChatMessage>.unmodifiable(_messagesByChannel[channelId] ?? const <ChatMessage>[]);
  }

  ChatChannel? get selectedChannel {
    final int? channelId = selectedChannelId;
    if (channelId == null) {
      return null;
    }
    for (final ChatChannel channel in channels) {
      if (channel.id == channelId) {
        return channel;
      }
    }
    return null;
  }

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
      _loginCompleter = completer;
      await _messagesSubscription?.cancel();
      _messagesSubscription = _webSocketService.messages.listen(_handleSocketMessage);

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
      _loginCompleter = null;
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
    selectedChannelId = null;
    channels.clear();
    onlineUsers.clear();
    _messagesByChannel.clear();
    notifyListeners();
  }

  Future<void> selectChannel(int channelId) async {
    selectedChannelId = channelId;
    notifyListeners();

    if (_webSocketService.isConnected) {
      _webSocketService.send(
        SocketMessage(
          type: 'JOIN_CHANNEL',
          data: <String, dynamic>{'channelId': channelId},
        ),
      );
    }
  }

  Future<void> sendMessage(String content) async {
    final String trimmed = content.trim();
    if (trimmed.isEmpty) {
      return;
    }

    final int? channelId = selectedChannelId ?? (channels.isNotEmpty ? channels.first.id : null);
    if (channelId == null) {
      errorMessage = 'No hay un canal activo';
      notifyListeners();
      return;
    }

    _webSocketService.send(
      SocketMessage(
        type: 'SEND_MESSAGE',
        data: <String, dynamic>{
          'content': trimmed,
          'channelId': channelId,
        },
      ),
    );
  }

  void _handleSocketMessage(SocketMessage msg) {
    switch (msg.type) {
      case 'LOGIN_RESPONSE':
        final bool success = msg.data['success'] == true;
        if (success) {
          isLoggedIn = true;
          username = (msg.data['username'] ?? username).toString();
          role = (msg.data['role'] ?? '').toString();
          errorMessage = null;
        } else {
          isLoggedIn = false;
          errorMessage = (msg.data['error'] ?? 'Error de login').toString();
        }
        if (_loginCompleter != null && !_loginCompleter!.isCompleted) {
          _loginCompleter!.complete(success);
        }
        break;
      case 'USER_LIST':
        onlineUsers
          ..clear()
          ..addAll(_readStringList(msg.data['users']));
        break;
      case 'CHANNEL_LIST':
        channels
          ..clear()
          ..addAll(_readChannelList(msg.data['channels']));
        if (selectedChannelId == null && channels.isNotEmpty) {
          selectedChannelId ??= channels.first.id;
        }
        break;
      case 'MESSAGE_HISTORY':
        final int channelId = _readInt(msg.data['channelId']);
        final List<ChatMessage> history = _readMessageList(msg.data['messages']);
        _messagesByChannel[channelId] = history;
        selectedChannelId ??= channelId;
        break;
      case 'RECEIVE_MESSAGE':
        final ChatMessage message = ChatMessage.fromJson(msg.data);
        _messagesByChannel.putIfAbsent(message.channelId, () => <ChatMessage>[]).add(message);
        selectedChannelId ??= message.channelId;
        break;
      case 'ERROR':
      case 'SYSTEM_ALERT':
        errorMessage = (msg.data['message'] ?? 'Se ha producido un error').toString();
        break;
      default:
        break;
    }

    notifyListeners();
  }

  List<String> _readStringList(dynamic rawUsers) {
    if (rawUsers is! List) {
      return <String>[];
    }
    return rawUsers.map((dynamic value) => value.toString()).toList();
  }

  List<ChatChannel> _readChannelList(dynamic rawChannels) {
    if (rawChannels is! List) {
      return <ChatChannel>[];
    }
    return rawChannels
        .whereType<Map>()
        .map((Map<dynamic, dynamic> value) => ChatChannel.fromJson(Map<String, dynamic>.from(value)))
        .toList();
  }

  List<ChatMessage> _readMessageList(dynamic rawMessages) {
    if (rawMessages is! List) {
      return <ChatMessage>[];
    }
    return rawMessages
        .whereType<Map>()
        .map((Map<dynamic, dynamic> value) => ChatMessage.fromJson(Map<String, dynamic>.from(value)))
        .toList();
  }

  int _readInt(dynamic rawValue) {
    if (rawValue is num) {
      return rawValue.toInt();
    }
    return int.tryParse(rawValue.toString()) ?? 0;
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    _webSocketService.dispose();
    super.dispose();
  }
}
