import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;

  bool get isConnected => _channel != null;

  void connect({
    required int userId,
    required void Function(Map<String, dynamic> event) onEvent,
  }) {
    if (_channel != null) {
      return;
    }

    try {
      print('🔌 Подключение к BearCord WebSocket...');

      final channel = WebSocketChannel.connect(
        Uri.parse('ws://hub.tailsbear.ru:9090'),
      );

      _channel = channel;

      channel.ready.then((_) {
        print('🟢 BearCord WebSocket подключён');

        channel.sink.add(
          jsonEncode({
            'type': 'auth',
            'user_id': userId,
          }),
        );

        print('🔐 WebSocket авторизация отправлена');
      }).catchError((error) {
        print('❌ WebSocket connection error: $error');
        disconnect();
      });

      _subscription = channel.stream.listen(
            (data) {
          try {
            final event = jsonDecode(data.toString());

            if (event is Map<String, dynamic>) {
              print('📨 WebSocket event: $event');
              onEvent(event);
            }
          } catch (e) {
            print('❌ WebSocket JSON error: $e');
          }
        },
        onError: (error) {
          print('❌ WebSocket error: $error');
          disconnect();
        },
        onDone: () {
          print('🔌 WebSocket отключён');
          _channel = null;
          _subscription = null;
        },
      );
    } catch (e) {
      print('❌ Не удалось подключиться к WebSocket: $e');
      _channel = null;
    }
  }

  void disconnect() {
    _subscription?.cancel();
    _subscription = null;

    _channel?.sink.close();
    _channel = null;

    print('🔌 WebSocket соединение закрыто');
  }

  void dispose() {
    disconnect();
  }
}