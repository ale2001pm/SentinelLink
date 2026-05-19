import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/ai_message.dart';
import '../models/chat_channel.dart';
import '../models/chat_message.dart';
import '../models/socket_message.dart';
import '../models/system_metrics.dart';
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

  SystemMetrics? _currentMetrics;
  final List<SystemMetrics> _metricsHistory = <SystemMetrics>[];
  static const int _maxHistoryLength = 60;

  String? _systemAlertMessage;
  int _systemAlertVersion = 0;

  double cpuThreshold = 80.0;
  double ramThreshold = 90.0;
  double diskThreshold = 90.0;

  final List<AiMessage> _aiMessages = <AiMessage>[];
  bool _isAiLoading = false;

  int? selectedChannelId;
  Completer<bool>? _loginCompleter;
  Completer<bool>? _registerCompleter;
  Completer<int?>? _createChannelCompleter;
  Completer<int?>? _createDmCompleter;

  String webSocketUrl = 'ws://localhost:8080/ws';

  SystemMetrics? get currentMetrics => _currentMetrics;
  List<SystemMetrics> get metricsHistory => List<SystemMetrics>.unmodifiable(_metricsHistory);
  String? get systemAlertMessage => _systemAlertMessage;
  int get systemAlertVersion => _systemAlertVersion;
  bool get isAiLoading => _isAiLoading;

  List<AiMessage> get aiMessages => List<AiMessage>.unmodifiable(_aiMessages);

  List<ChatChannel> get groupChannels =>
      channels.where((ChatChannel c) => !c.isDm).toList();

  List<ChatChannel> get dmChannels =>
      channels.where((ChatChannel c) => c.isDm).toList();

  List<ChatMessage> get selectedMessages {
    final int? channelId = selectedChannelId;
    if (channelId == null) {
      return const <ChatMessage>[];
    }
    return List<ChatMessage>.unmodifiable(_messagesByChannel[channelId] ?? const <ChatMessage>[]);
  }

  ChatChannel? get selectedChannel {
    final int? channelId = selectedChannelId;
    if (channelId == null) return null;
    for (final ChatChannel channel in channels) {
      if (channel.id == channelId) return channel;
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

  Future<bool> register({
    required String inputUsername,
    required String inputPassword,
  }) async {
    errorMessage = null;
    isLoading = true;
    notifyListeners();

    try {
      await _webSocketService.connect(webSocketUrl);

      final Completer<bool> completer = Completer<bool>();
      _registerCompleter = completer;
      await _messagesSubscription?.cancel();
      _messagesSubscription = _webSocketService.messages.listen(_handleSocketMessage);

      _webSocketService.send(
        SocketMessage(
          type: 'REGISTER_REQUEST',
          data: <String, dynamic>{
            'username': inputUsername,
            'password': inputPassword,
          },
        ),
      );

      final bool result = await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          errorMessage = 'Timeout esperando REGISTER_RESPONSE';
          return false;
        },
      );

      return result;
    } catch (e) {
      errorMessage = 'No se pudo conectar al backend: $e';
      return false;
    } finally {
      _registerCompleter = null;
      await _messagesSubscription?.cancel();
      _messagesSubscription = null;
      await _webSocketService.disconnect();
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
    _currentMetrics = null;
    _metricsHistory.clear();
    _systemAlertMessage = null;
    _systemAlertVersion = 0;
    _aiMessages.clear();
    _isAiLoading = false;
    cpuThreshold = 80.0;
    ramThreshold = 90.0;
    diskThreshold = 90.0;
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

  Future<int?> createChannel({
    required String name,
    bool isPrivate = false,
  }) async {
    final String trimmed = name.trim();
    if (trimmed.isEmpty) {
      errorMessage = 'El nombre del canal no puede estar vacio';
      notifyListeners();
      return null;
    }
    if (!_webSocketService.isConnected) {
      errorMessage = 'WebSocket no conectado';
      notifyListeners();
      return null;
    }

    errorMessage = null;
    isLoading = true;
    notifyListeners();

    try {
      final Completer<int?> completer = Completer<int?>();
      _createChannelCompleter = completer;

      _webSocketService.send(
        SocketMessage(
          type: 'CREATE_CHANNEL_REQUEST',
          data: <String, dynamic>{
            'name': trimmed,
            'private': isPrivate,
          },
        ),
      );

      final int? channelId = await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          errorMessage = 'Timeout esperando CREATE_CHANNEL_RESPONSE';
          return null;
        },
      );

      if (channelId != null && channelId > 0) {
        await selectChannel(channelId);
      }
      return channelId;
    } catch (e) {
      errorMessage = 'No se pudo crear el canal: $e';
      return null;
    } finally {
      _createChannelCompleter = null;
      isLoading = false;
      notifyListeners();
    }
  }

  Future<int?> createDm(String targetUser) async {
    if (!_webSocketService.isConnected) {
      errorMessage = 'WebSocket no conectado';
      notifyListeners();
      return null;
    }

    errorMessage = null;
    isLoading = true;
    notifyListeners();

    try {
      final Completer<int?> completer = Completer<int?>();
      _createDmCompleter = completer;

      _webSocketService.send(
        SocketMessage(
          type: 'CREATE_DM_REQUEST',
          data: <String, dynamic>{'targetUser': targetUser},
        ),
      );

      final int? channelId = await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          errorMessage = 'Timeout creando DM';
          return null;
        },
      );

      if (channelId != null && channelId > 0) {
        await selectChannel(channelId);
      }
      return channelId;
    } catch (e) {
      errorMessage = 'No se pudo crear el DM: $e';
      return null;
    } finally {
      _createDmCompleter = null;
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> sendMessage(String content) async {
    final String trimmed = content.trim();
    if (trimmed.isEmpty) return;

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

  Future<void> sendImageMessage(String base64) async {
    final String trimmed = base64.trim();
    if (trimmed.isEmpty) return;

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
          'channelId': channelId,
          'imageBase64': trimmed,
        },
      ),
    );
  }

  void updateThresholds(double cpu, double ram, double disk) {
    if (!_webSocketService.isConnected) return;
    _webSocketService.send(
      SocketMessage(
        type: 'UPDATE_THRESHOLDS',
        data: <String, dynamic>{
          'cpuThreshold': cpu,
          'ramThreshold': ram,
          'diskThreshold': disk,
        },
      ),
    );
  }

  void sendTestAlert() {
    if (!_webSocketService.isConnected) return;
    _webSocketService.send(
      SocketMessage(type: 'TEST_ALERT', data: <String, dynamic>{}),
    );
  }

  Future<void> sendAiPrompt(String prompt) async {
    final String trimmed = prompt.trim();
    if (trimmed.isEmpty) return;

    if (!_webSocketService.isConnected) {
      errorMessage = 'WebSocket no conectado';
      notifyListeners();
      return;
    }

    _aiMessages.add(
      AiMessage(role: 'user', content: trimmed, timestamp: DateTime.now()),
    );
    _isAiLoading = true;
    notifyListeners();

    _webSocketService.send(
      SocketMessage(
        type: 'AI_REQUEST',
        data: <String, dynamic>{
          'prompt': trimmed,
          'history': _buildAiHistoryPayload(),
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
      case 'REGISTER_RESPONSE':
        final bool success = msg.data['success'] == true;
        if (!success) {
          errorMessage = (msg.data['error'] ?? 'Error de registro').toString();
        } else {
          errorMessage = null;
        }
        if (_registerCompleter != null && !_registerCompleter!.isCompleted) {
          _registerCompleter!.complete(success);
        }
        break;
      case 'CREATE_CHANNEL_RESPONSE':
        final bool success = msg.data['success'] == true;
        if (!success) {
          errorMessage = (msg.data['error'] ?? 'Error al crear canal').toString();
        } else {
          errorMessage = null;
        }
        final int channelId = _readInt(msg.data['channelId']);
        if (_createChannelCompleter != null && !_createChannelCompleter!.isCompleted) {
          _createChannelCompleter!.complete(success ? channelId : null);
        }
        break;
      case 'CREATE_DM_RESPONSE':
        final bool success = msg.data['success'] == true;
        if (!success) {
          errorMessage = (msg.data['error'] ?? 'Error al crear DM').toString();
        } else {
          errorMessage = null;
        }
        final int dmChannelId = _readInt(msg.data['channelId']);
        if (_createDmCompleter != null && !_createDmCompleter!.isCompleted) {
          _createDmCompleter!.complete(success ? dmChannelId : null);
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
      case 'SYSTEM_METRICS':
        final SystemMetrics metrics = SystemMetrics.fromJson(msg.data);
        _currentMetrics = metrics;
        _metricsHistory.add(metrics);
        if (_metricsHistory.length > _maxHistoryLength) {
          _metricsHistory.removeAt(0);
        }
        break;
      case 'SYSTEM_ALERT':
        _systemAlertMessage = (msg.data['message'] ?? '').toString();
        _systemAlertVersion++;
        break;
      case 'THRESHOLDS_RESPONSE':
        if (msg.data.containsKey('cpuThreshold')) {
          cpuThreshold = _readDouble(msg.data['cpuThreshold'], cpuThreshold);
          ramThreshold = _readDouble(msg.data['ramThreshold'], ramThreshold);
          diskThreshold = _readDouble(msg.data['diskThreshold'], diskThreshold);
        }
        break;
      case 'AI_RESPONSE':
        String response = (msg.data['response'] ?? '').toString();
        if (response.isEmpty) response = 'Respuesta vacia de la IA';
        _aiMessages.add(
          AiMessage(role: 'assistant', content: response, timestamp: DateTime.now()),
        );
        _isAiLoading = false;
        if (msg.data['error'] == true) errorMessage = response;
        break;
      case 'ERROR':
        errorMessage = (msg.data['message'] ?? 'Se ha producido un error').toString();
        if ((errorMessage ?? '').toLowerCase().contains('conexion perdida')) {
          isLoggedIn = false;
        }
        if (_isAiLoading) {
          _aiMessages.add(
            AiMessage(
              role: 'assistant',
              content: errorMessage ?? 'Se ha producido un error',
              timestamp: DateTime.now(),
            ),
          );
          _isAiLoading = false;
        }
        break;
      default:
        break;
    }

    notifyListeners();
  }

  Future<String> exportSelectedChannelToXml() async {
    final ChatChannel? channel = selectedChannel;
    final List<ChatMessage> messages = selectedMessages;
    if (channel == null || messages.isEmpty) {
      throw StateError('No hay mensajes para exportar');
    }

    final String safeChannel = _sanitizeFileName(channel.name);
    final String timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final String fileName = 'sentinellink_chat_${safeChannel}_$timestamp.xml';
    final String path = '${Directory.current.path}${Platform.pathSeparator}$fileName';

    final StringBuffer buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln('<chat channel="${_escapeXml(channel.name)}">');
    for (final ChatMessage message in messages) {
      buffer.writeln('  <message>');
      buffer.writeln('    <sender>${_escapeXml(message.sender)}</sender>');
      buffer.writeln('    <content>${_escapeXml(message.content)}</content>');
      buffer.writeln('    <timestamp>${message.timestamp.toIso8601String()}</timestamp>');
      buffer.writeln('  </message>');
    }
    buffer.writeln('</chat>');

    final File file = File(path);
    await file.writeAsString(buffer.toString());
    return path;
  }

  String _escapeXml(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  String _sanitizeFileName(String input) {
    return input.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  }

  List<Map<String, String>> _buildAiHistoryPayload() {
    final int start = _aiMessages.length > 12 ? _aiMessages.length - 12 : 0;
    return _aiMessages
        .sublist(start)
        .map((AiMessage msg) => <String, String>{'role': msg.role, 'content': msg.content})
        .toList();
  }

  List<String> _readStringList(dynamic rawUsers) {
    if (rawUsers is! List) return <String>[];
    return rawUsers.map((dynamic value) => value.toString()).toList();
  }

  List<ChatChannel> _readChannelList(dynamic rawChannels) {
    if (rawChannels is! List) return <ChatChannel>[];
    return rawChannels
        .whereType<Map>()
        .map((Map<dynamic, dynamic> value) => ChatChannel.fromJson(Map<String, dynamic>.from(value)))
        .toList();
  }

  List<ChatMessage> _readMessageList(dynamic rawMessages) {
    if (rawMessages is! List) return <ChatMessage>[];
    return rawMessages
        .whereType<Map>()
        .map((Map<dynamic, dynamic> value) => ChatMessage.fromJson(Map<String, dynamic>.from(value)))
        .toList();
  }

  int _readInt(dynamic rawValue) {
    if (rawValue is num) return rawValue.toInt();
    return int.tryParse(rawValue.toString()) ?? 0;
  }

  double _readDouble(dynamic rawValue, double fallback) {
    if (rawValue is num) return rawValue.toDouble();
    return double.tryParse(rawValue.toString()) ?? fallback;
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    _webSocketService.dispose();
    super.dispose();
  }
}
