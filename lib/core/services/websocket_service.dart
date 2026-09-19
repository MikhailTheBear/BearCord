
import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketService {
WebSocketChannel? _channel;
StreamSubscription? _subscription;

int? _userId;

void Function(Map<String, dynamic> event)? _onEvent;
void Function()? _onConnectionLost;
void Function()? _onConnectionRestored;

Timer? _reconnectTimer;

bool _manualDisconnect = false;
bool _isConnecting = false;

// Было ли хотя бы одно успешное подключение?
bool _hasConnectedBefore = false;

// Нужно ли показать "соединение восстановлено".
bool _wasDisconnected = false;

int _reconnectAttempt = 0;

bool get isConnected => _channel != null;

void connect({
required int userId,
required void Function(Map<String, dynamic> event) onEvent,
void Function()? onConnectionLost,
void Function()? onConnectionRestored,
}) {
if (userId <= 0) {
print('❌ Неверный userId для WebSocket: $userId');
return;
}

_userId = userId;
_onEvent = onEvent;
_onConnectionLost = onConnectionLost;
_onConnectionRestored = onConnectionRestored;

_manualDisconnect = false;

_reconnectTimer?.cancel();
_reconnectTimer = null;

if (_channel != null || _isConnecting) {
print(
'⚠️ BearCord WebSocket уже подключён или подключается',
);
return;
}

_connect();
}

Future<void> _connect() async {
if (_manualDisconnect) {
return;
}

if (_channel != null || _isConnecting) {
return;
}

final userId = _userId;

if (userId == null || userId <= 0) {
print(
'❌ Невозможно подключиться: userId отсутствует',
);
return;
}

_isConnecting = true;

print('🔌 Подключение к BearCord WebSocket...');

try {
final channel = WebSocketChannel.connect(
Uri.parse('ws://hub.tailsbear.ru:9090'),
);

_channel = channel;

await channel.ready;

// За это время соединение могло быть закрыто вручную
// или заменено другим соединением.
if (_manualDisconnect || _channel != channel) {
try {
await channel.sink.close();
} catch (_) {}

_isConnecting = false;
return;
}

_isConnecting = false;
_reconnectAttempt = 0;

if (_hasConnectedBefore && _wasDisconnected) {
print('🟢 BearCord WebSocket восстановлен');

_onConnectionRestored?.call();

_wasDisconnected = false;
} else {
print('🟢 BearCord WebSocket подключён');

_hasConnectedBefore = true;
}

// Авторизация после каждого подключения.
channel.sink.add(
jsonEncode({
'type': 'auth',
'user_id': userId,
}),
);

print('🔐 WebSocket авторизация отправлена');

_subscription = channel.stream.listen(
(data) {
try {
final decoded = jsonDecode(data.toString());

if (decoded is Map) {
final event =
Map<String, dynamic>.from(decoded);

print('📨 WebSocket event: $event');

_onEvent?.call(event);
}
} catch (error) {
print(
'❌ WebSocket JSON error: $error',
);
}
},
onError: (error) {
print('❌ WebSocket error: $error');

_handleConnectionLost(channel);
},
onDone: () {
print('🔌 WebSocket отключён');

_handleConnectionLost(channel);
},
cancelOnError: false,
);
} catch (error) {
print(
'❌ WebSocket connection error: $error',
);

_isConnecting = false;

if (_channel != null) {
_channel = null;
}

_subscription = null;

if (!_manualDisconnect) {
_handleConnectionLost(null);
}
}
}

void _handleConnectionLost(
WebSocketChannel? disconnectedChannel,
) {
// Старое соединение больше не должно влиять
// на новое подключение.
if (disconnectedChannel != null &&
_channel != disconnectedChannel) {
return;
}

if (_manualDisconnect) {
return;
}

_isConnecting = false;

_channel = null;
_subscription = null;

// Помечаем, что соединение действительно пропало.
_wasDisconnected = true;

_onConnectionLost?.call();

_scheduleReconnect();
}

void _scheduleReconnect() {
if (_manualDisconnect) {
return;
}

if (_reconnectTimer != null) {
return;
}

if (_isConnecting || _channel != null) {
return;
}

_reconnectAttempt++;

// 2 → 4 → 8 → 16 → 30 → 30 → 30...
final seconds = switch (_reconnectAttempt) {
1 => 2,
2 => 4,
3 => 8,
4 => 16,
_ => 30,
};

print(
'🔄 WebSocket: следующая попытка подключения '
'через $seconds сек. '
'(попытка $_reconnectAttempt)',
);

_reconnectTimer = Timer(
Duration(seconds: seconds),
() {
_reconnectTimer = null;

if (_manualDisconnect) {
return;
}

_connect();
},
);
}

void disconnect() {
print(
'🔌 WebSocket: ручное отключение',
);

_manualDisconnect = true;

_reconnectTimer?.cancel();
_reconnectTimer = null;

_reconnectAttempt = 0;
_isConnecting = false;

final subscription = _subscription;
final channel = _channel;

_subscription = null;
_channel = null;

subscription?.cancel();

try {
channel?.sink.close();
} catch (_) {}

print(
'🔌 WebSocket соединение закрыто',
);
}

void dispose() {
disconnect();

_userId = null;
_onEvent = null;
_onConnectionLost = null;
_onConnectionRestored = null;

_hasConnectedBefore = false;
_wasDisconnected = false;
}
}

