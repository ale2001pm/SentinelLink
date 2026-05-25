import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  final Map<int, int> _unreadCounts = <int, int>{};

  SystemMetrics? _currentMetrics;
  final List<SystemMetrics> _metricsHistory = <SystemMetrics>[];
  static const int _maxHistoryLength = 60;

  String? _systemAlertMessage;
  String _systemAlertLevel = 'warning';
  int _systemAlertVersion = 0;
  bool _isInitialAlert = true;

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
  Completer<bool>? _renameChannelCompleter;
  Completer<bool>? _deleteChannelCompleter;
  Completer<bool>? _changePasswordCompleter;
  Completer<int?>? _searchChannelCompleter;

  String webSocketUrl = 'ws://localhost:8080/ws';
  bool soundEnabled = true;

  SystemMetrics? get currentMetrics => _currentMetrics;
  List<SystemMetrics> get metricsHistory => List<SystemMetrics>.unmodifiable(_metricsHistory);
  String? get systemAlertMessage => _systemAlertMessage;
  String get systemAlertLevel => _systemAlertLevel;
  int get systemAlertVersion => _systemAlertVersion;
  bool get isAiLoading => _isAiLoading;
  Map<int, int> get unreadCounts => Map<int, int>.unmodifiable(_unreadCounts);

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

  Future<void> initPreferences() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    webSocketUrl = prefs.getString('wsUrl') ?? 'ws://localhost:8080/ws';
    soundEnabled = prefs.getBool('soundEnabled') ?? true;
  }

  Future<void> setWebSocketUrl(String url) async {
    webSocketUrl = url.trim();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('wsUrl', url.trim());
    notifyListeners();
  }

  Future<void> setSoundEnabled(bool value) async {
    soundEnabled = value;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('soundEnabled', value);
    notifyListeners();
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (!_webSocketService.isConnected) {
      errorMessage = 'No conectado al servidor';
      notifyListeners();
      return false;
    }
    errorMessage = null;
    isLoading = true;
    notifyListeners();
    try {
      final Completer<bool> completer = Completer<bool>();
      _changePasswordCompleter = completer;
      _webSocketService.send(
        SocketMessage(
          type: 'CHANGE_PASSWORD_REQUEST',
          data: <String, dynamic>{
            'currentPassword': currentPassword,
            'newPassword': newPassword,
          },
        ),
      );
      return await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          errorMessage = 'Timeout al cambiar contraseña';
          return false;
        },
      );
    } catch (e) {
      errorMessage = 'Error: $e';
      return false;
    } finally {
      _changePasswordCompleter = null;
      isLoading = false;
      notifyListeners();
    }
  }

  /// Opens (or creates) a DM with [targetUser] and sends an invite message for [channelName].
  Future<void> inviteToPrivateChannel(String channelName, String targetUser) async {
    final int? dmId = await createDm(targetUser, switchChannel: false);
    if (dmId == null) return;
    _webSocketService.send(SocketMessage(
      type: 'SEND_MESSAGE',
      data: <String, dynamic>{
        'channelId': dmId,
        'content': '\u{1F512}INVITE:$channelName\nTe han invitado al canal privado «$channelName». Pulsa Unirse para entrar.',
      },
    ));
  }

  Future<int?> searchChannel(String name) async {
    if (!_webSocketService.isConnected) return null;
    errorMessage = null;
    final Completer<int?> completer = Completer<int?>();
    _searchChannelCompleter = completer;
    _webSocketService.send(SocketMessage(
      type: 'SEARCH_CHANNEL_REQUEST',
      data: <String, dynamic>{'name': name.trim()},
    ));
    try {
      return await completer.future.timeout(const Duration(seconds: 10),
          onTimeout: () { errorMessage = 'Timeout buscando canal'; return null; });
    } finally {
      _searchChannelCompleter = null;
      notifyListeners();
    }
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
    _unreadCounts.clear();
    _currentMetrics = null;
    _metricsHistory.clear();
    _systemAlertMessage = null;
    _systemAlertVersion = 0;
    _isInitialAlert = true;
    _aiMessages.clear();
    _isAiLoading = false;
    cpuThreshold = 80.0;
    ramThreshold = 90.0;
    diskThreshold = 90.0;
    notifyListeners();
  }

  Future<void> selectChannel(int channelId) async {
    selectedChannelId = channelId;
    _unreadCounts.remove(channelId);
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

  Future<int?> createDm(String targetUser, {bool switchChannel = true}) async {
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

      if (channelId != null && channelId > 0 && switchChannel) {
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

    if (!_webSocketService.isConnected) {
      throw StateError('WebSocket no conectado');
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
          'channelId': channelId,
          'imageBase64': trimmed,
        },
      ),
    );
  }

  Future<void> sendFileMessage(String fileName, String base64Data) async {
    final String trimmed = base64Data.trim();
    if (trimmed.isEmpty || fileName.isEmpty) return;

    if (!_webSocketService.isConnected) {
      throw StateError('WebSocket no conectado');
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
          'channelId': channelId,
          'content': fileName,
          'fileBase64': trimmed,
          'fileName': fileName,
        },
      ),
    );
  }

  Future<bool> renameChannel(int channelId, String newName) async {
    if (!_webSocketService.isConnected) {
      errorMessage = 'WebSocket no conectado';
      notifyListeners();
      return false;
    }
    errorMessage = null;
    isLoading = true;
    notifyListeners();
    try {
      final Completer<bool> completer = Completer<bool>();
      _renameChannelCompleter = completer;
      _webSocketService.send(
        SocketMessage(
          type: 'RENAME_CHANNEL_REQUEST',
          data: <String, dynamic>{'channelId': channelId, 'newName': newName},
        ),
      );
      return await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          errorMessage = 'Timeout al renombrar canal';
          return false;
        },
      );
    } catch (e) {
      errorMessage = 'No se pudo renombrar el canal: $e';
      return false;
    } finally {
      _renameChannelCompleter = null;
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteChannel(int channelId) async {
    if (!_webSocketService.isConnected) {
      errorMessage = 'WebSocket no conectado';
      notifyListeners();
      return false;
    }
    errorMessage = null;
    isLoading = true;
    notifyListeners();
    try {
      final Completer<bool> completer = Completer<bool>();
      _deleteChannelCompleter = completer;
      _webSocketService.send(
        SocketMessage(
          type: 'DELETE_CHANNEL_REQUEST',
          data: <String, dynamic>{'channelId': channelId},
        ),
      );
      return await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          errorMessage = 'Timeout al eliminar canal';
          return false;
        },
      );
    } catch (e) {
      errorMessage = 'No se pudo eliminar el canal: $e';
      return false;
    } finally {
      _deleteChannelCompleter = null;
      isLoading = false;
      notifyListeners();
    }
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
          final int newChId = _readInt(msg.data['channelId']);
          final bool isPrivate = msg.data['private'] == true;
          // Private channels are not included in broadcast CHANNEL_LIST — add locally
          if (isPrivate && !channels.any((ChatChannel c) => c.id == newChId)) {
            channels.add(ChatChannel.fromJson(Map<String, dynamic>.from(
              msg.data.map((String k, dynamic v) => MapEntry(k, v)),
            )));
          }
        }
        final int channelId = _readInt(msg.data['channelId']);
        if (_createChannelCompleter != null && !_createChannelCompleter!.isCompleted) {
          _createChannelCompleter!.complete(success ? channelId : null);
        }
        break;
      case 'RENAME_CHANNEL_RESPONSE':
        final bool renameSuccess = msg.data['success'] == true;
        if (!renameSuccess) {
          errorMessage = (msg.data['error'] ?? 'Error al renombrar canal').toString();
        } else {
          errorMessage = null;
        }
        if (_renameChannelCompleter != null && !_renameChannelCompleter!.isCompleted) {
          _renameChannelCompleter!.complete(renameSuccess);
        }
        break;
      case 'DELETE_CHANNEL_RESPONSE':
        final bool deleteSuccess = msg.data['success'] == true;
        if (!deleteSuccess) {
          errorMessage = (msg.data['error'] ?? 'Error al eliminar canal').toString();
        } else {
          errorMessage = null;
          if (deleteSuccess && msg.data.containsKey('channelId')) {
            final int deletedId = _readInt(msg.data['channelId']);
            if (selectedChannelId == deletedId) selectedChannelId = null;
            channels.removeWhere((ChatChannel c) => c.id == deletedId);
            _messagesByChannel.remove(deletedId);
          }
        }
        if (_deleteChannelCompleter != null && !_deleteChannelCompleter!.isCompleted) {
          _deleteChannelCompleter!.complete(deleteSuccess);
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
        final List<ChatChannel> incoming = _readChannelList(msg.data['channels']);
        // Keep private group channels the user has already joined locally —
        // the server does not include them in broadcast CHANNEL_LIST updates.
        final List<ChatChannel> privateKept = channels
            .where((ChatChannel c) => c.isPrivate && !c.isDm)
            .toList();
        channels.clear();
        channels.addAll(privateKept);
        for (final ChatChannel ch in incoming) {
          if (!channels.any((ChatChannel c) => c.id == ch.id)) {
            channels.add(ch);
          }
        }
        if (selectedChannelId == null && channels.isNotEmpty) {
          selectedChannelId = channels.first.id;
        }
        break;
      case 'MESSAGE_HISTORY':
        final int channelId = _readInt(msg.data['channelId']);
        final List<ChatMessage> history = _readMessageList(msg.data['messages']);
        _messagesByChannel[channelId] = history;
        _unreadCounts.remove(channelId);
        selectedChannelId ??= channelId;
        break;
      case 'RECEIVE_MESSAGE':
        final ChatMessage message = ChatMessage.fromJson(msg.data);
        _messagesByChannel.putIfAbsent(message.channelId, () => <ChatMessage>[]).add(message);
        if (message.channelId != selectedChannelId) {
          _unreadCounts[message.channelId] = (_unreadCounts[message.channelId] ?? 0) + 1;
        }
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
        _systemAlertLevel = (msg.data['level'] ?? 'warning').toString();
        _systemAlertMessage = (msg.data['message'] ?? '').toString();
        if (_isInitialAlert) {
          // Suppress the alert replayed by the server on connect — it's not new
          _isInitialAlert = false;
        } else {
          _systemAlertVersion++;
        }
        break;
      case 'CHANGE_PASSWORD_RESPONSE':
        final bool pwSuccess = msg.data['success'] == true;
        if (!pwSuccess) {
          errorMessage = (msg.data['error'] ?? 'Error al cambiar contraseña').toString();
        } else {
          errorMessage = null;
        }
        if (_changePasswordCompleter != null && !_changePasswordCompleter!.isCompleted) {
          _changePasswordCompleter!.complete(pwSuccess);
        }
        break;
      case 'THRESHOLDS_RESPONSE':
        if (msg.data.containsKey('cpuThreshold')) {
          cpuThreshold = _readDouble(msg.data['cpuThreshold'], cpuThreshold);
          ramThreshold = _readDouble(msg.data['ramThreshold'], ramThreshold);
          diskThreshold = _readDouble(msg.data['diskThreshold'], diskThreshold);
        }
        break;
      case 'SEARCH_CHANNEL_RESPONSE':
        final bool found = msg.data['success'] == true;
        if (found) {
          errorMessage = null;
          final int cId = _readInt(msg.data['channelId']);
          // Add to channel list if not already present
          final bool exists = channels.any((ChatChannel c) => c.id == cId);
          if (!exists) {
            channels.add(ChatChannel.fromJson(Map<String, dynamic>.from(
              msg.data.map((String k, dynamic v) => MapEntry(k, v)),
            )));
          }
          selectedChannelId = cId;
        } else {
          errorMessage = (msg.data['error'] ?? 'Canal no encontrado').toString();
        }
        if (_searchChannelCompleter != null && !_searchChannelCompleter!.isCompleted) {
          _searchChannelCompleter!.complete(found ? _readInt(msg.data['channelId']) : null);
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

  String buildExportContent() {
    if (_messagesByChannel.isEmpty) {
      throw StateError('No hay mensajes cargados para exportar');
    }
    final StringBuffer buffer = StringBuffer();
    buffer.writeln('SentinelLink — Exportación de chats');
    buffer.writeln('Exportado: ${DateTime.now().toLocal()}');
    buffer.writeln('═' * 50);
    buffer.writeln();

    for (final ChatChannel channel in channels) {
      final List<ChatMessage>? messages = _messagesByChannel[channel.id];
      if (messages == null || messages.isEmpty) continue;
      final String title = channel.isDm ? 'DM: ${channel.name}' : 'Canal: #${channel.name}';
      buffer.writeln(title);
      buffer.writeln('─' * 40);
      for (final ChatMessage message in messages) {
        final DateTime local = message.timestamp.toLocal();
        final String time =
            '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} '
            '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
        if (message.messageType == 'IMAGE') {
          buffer.writeln('[$time] ${message.sender}: [imagen]');
        } else if (message.messageType == 'FILE') {
          buffer.writeln('[$time] ${message.sender}: [archivo: ${message.content}]');
        } else {
          buffer.writeln('[$time] ${message.sender}: ${message.content}');
        }
      }
      buffer.writeln();
    }

    return buffer.toString();
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
