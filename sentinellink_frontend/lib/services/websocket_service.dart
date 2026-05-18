import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/socket_message.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;

  final StreamController<SocketMessage> _messagesController =
      StreamController<SocketMessage>.broadcast();

  Stream<SocketMessage> get messages => _messagesController.stream;

  bool get isConnected => _channel != null;

  Future<void> connect(String url) async {
    if (isConnected) {
      return;
    }

    _channel = WebSocketChannel.connect(Uri.parse(url));
    _subscription = _channel!.stream.listen(
      (dynamic raw) {
        final dynamic decoded = jsonDecode(raw.toString());
        if (decoded is Map) {
          _messagesController.add(SocketMessage.fromJson(Map<String, dynamic>.from(decoded)));
        }
      },
      onError: (Object error) {
        _messagesController.add(
          SocketMessage(
            type: 'ERROR',
            data: <String, dynamic>{'message': error.toString()},
          ),
        );
      },
      onDone: () {
        _channel = null;
        _messagesController.add(
          SocketMessage(
            type: 'ERROR',
            data: <String, dynamic>{
              'message': 'Conexion perdida. Vuelve a iniciar sesion.',
            },
          ),
        );
      },
      cancelOnError: false,
    );
  }

  void send(SocketMessage message) {
    if (_channel == null) {
      throw StateError('WebSocket no conectado');
    }
    _channel!.sink.add(jsonEncode(message.toJson()));
  }

  Future<void> disconnect() async {
    await _subscription?.cancel();
    await _channel?.sink.close();
    _subscription = null;
    _channel = null;
  }

  Future<void> dispose() async {
    await disconnect();
    await _messagesController.close();
  }
}
