import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../models/message.dart';
import '../models/room.dart';
import '../models/user.dart';

class ApiClient {
static const String baseUrl =
'https://hub.tailsbear.ru/bearcord/api/v2.php';

final http.Client _client = http.Client();

final FlutterSecureStorage _storage =
const FlutterSecureStorage();

// ============================================================
// TOKEN
// ============================================================

Future<String?> getToken() async {
return _storage.read(
key: 'bearcord_token',
);
}

Future<void> saveToken(String token) async {
await _storage.write(
key: 'bearcord_token',
value: token,
);
}

Future<void> deleteToken() async {
await _storage.delete(
key: 'bearcord_token',
);
}

// ============================================================
// HEADERS
// ============================================================

Future<Map<String, String>> _headers() async {
final token = await getToken();

return {
'Content-Type': 'application/json',
'Accept': 'application/json',
if (token != null && token.isNotEmpty)
'Authorization': 'Bearer $token',
};
}

// ============================================================
// REQUEST
// ============================================================

Future<Map<String, dynamic>> _request(
String method,
Uri uri, {
Map<String, dynamic>? body,
}) async {
final headers = await _headers();

late final http.Response response;

switch (method) {
case 'GET':
response = await _client.get(
uri,
headers: headers,
);
break;

case 'POST':
response = await _client.post(
uri,
headers: headers,
body: body == null ? null : jsonEncode(body),
);
break;

case 'PUT':
response = await _client.put(
uri,
headers: headers,
body: body == null ? null : jsonEncode(body),
);
break;

case 'DELETE':
response = await _client.delete(
uri,
headers: headers,
body: body == null ? null : jsonEncode(body),
);
break;

default:
throw Exception(
'Unsupported HTTP method: $method',
);
}

return _parseResponse(response);
}

// ============================================================
// RESPONSE
// ============================================================

Map<String, dynamic> _parseResponse(
http.Response response,
) {
Map<String, dynamic> data;

try {
final decoded = jsonDecode(response.body);

if (decoded is! Map<String, dynamic>) {
throw const FormatException();
}

data = decoded;
} catch (_) {
print(
'❌ INVALID JSON '
'[${response.statusCode}]: ${response.body}',
);

throw Exception(
'Сервер вернул некорректный JSON '
'(${response.statusCode})',
);
}

if (data['success'] != true) {
final error = data['error'];

if (error is Map<String, dynamic>) {
final message =
error['message'] ?? 'Неизвестная ошибка';

final code = error['code'];

throw Exception(
code != null
? '$message [$code]'
    : message.toString(),
);
}

throw Exception(
'Ошибка API (${response.statusCode})',
);
}

final result = data['data'];

if (result is Map<String, dynamic>) {
return result;
}

return {};
}

// ============================================================
// AUTH
// ============================================================

Future<Map<String, dynamic>> login(
String login,
String password,
) async {
final uri = Uri.parse(
'$baseUrl?action=auth&sub=login',
);

final data = await _request(
'POST',
uri,
body: {
'login': login,
'password': password,
},
);

final token = data['token'];

print('🔑 LOGIN TOKEN: $token');

if (token is String && token.isNotEmpty) {
await saveToken(token);

final savedToken = await getToken();

print('💾 SAVED TOKEN: $savedToken');
}

return data;
}

Future<void> register({
required String login,
required String password,
required String nick,
String? avatar,
}) async {
final uri = Uri.parse(
'$baseUrl?action=auth&sub=register',
);

await _request(
'POST',
uri,
body: {
'login': login,
'password': password,
'nick': nick,
if (avatar != null) 'avatar': avatar,
},
);
}

Future<void> logout() async {
try {
final uri = Uri.parse(
'$baseUrl?action=auth',
);

await _request(
'DELETE',
uri,
);
} finally {
await deleteToken();
}
}

Future<Map<String, dynamic>> getMe() async {
final uri = Uri.parse(
'$baseUrl?action=me',
);

return _request(
'GET',
uri,
);
}


// ============================================================
// PROFILE
// ============================================================

  Future<User> updateProfile({
    String? login,
    String? nick,
    String? avatar,
    String? password,
    String? currentPassword,
  }) async {
    final uri = Uri.parse(
      '$baseUrl?action=profile',
    );

    final body = <String, dynamic>{};

    if (login != null) {
      body['login'] = login;
    }

    if (nick != null) {
      body['nick'] = nick;
    }

    if (avatar != null) {
      body['avatar'] = avatar;
    }

    if (password != null) {
      body['password'] = password;
    }

    if (currentPassword != null) {
      body['current_password'] = currentPassword;
    }

    print('👤 UPDATE PROFILE');
    print('👤 LOGIN: $login');
    print('👤 NICK: $nick');
    print('🔐 PASSWORD CHANGE: ${password != null}');
    print('🔐 CURRENT PASSWORD: ${currentPassword != null}');

    final data = await _request(
      'PUT',
      uri,
      body: body,
    );

    final userData = data['user'];

    if (userData is! Map<String, dynamic>) {
      throw Exception(
        'Сервер не вернул пользователя',
      );
    }

    return User.fromJson(userData);
  }




// ============================================================
// USERS
// ============================================================

Future<List<User>> searchUsers(
String search,
) async {
final uri = Uri.parse(
'$baseUrl?action=users'
'&search=${Uri.encodeQueryComponent(search)}',
);

final data = await _request(
'GET',
uri,
);

final users = data['users'];

if (users is! List) {
return [];
}

return users
    .map(
(json) => User.fromJson(
json as Map<String, dynamic>,
),
)
    .toList();
}

Future<int?> getUserIdByLogin(
String login,
) async {
final users = await searchUsers(login);

for (final user in users) {
if (user.login.toLowerCase() ==
login.toLowerCase()) {
return user.id;
}
}

return null;
}

// ============================================================
// ROOMS
// ============================================================

Future<List<Room>> getRooms() async {
final uri = Uri.parse(
'$baseUrl?action=rooms',
);

final data = await _request(
'GET',
uri,
);

final rooms = data['rooms'];

if (rooms is! List) {
return [];
}

return rooms
    .map(
(json) => Room.fromJson(
json as Map<String, dynamic>,
),
)
    .toList();
}

Future<void> createGroupRoom(
String code,
) async {
final uri = Uri.parse(
'$baseUrl?action=rooms',
);

await _request(
'POST',
uri,
body: {
'type': 'group',
'code': code,
},
);
}

Future<void> createDMRoom(
int userId,
) async {
final uri = Uri.parse(
'$baseUrl?action=rooms',
);

await _request(
'POST',
uri,
body: {
'type': 'dm',
'user_id': userId,
},
);
}

Future<void> joinRoom(
String code,
) async {
final uri = Uri.parse(
'$baseUrl?action=rooms',
);

await _request(
'PUT',
uri,
body: {
'code': code,
},
);
}

Future<void> leaveRoom(
String code,
) async {
final uri = Uri.parse(
'$baseUrl?action=rooms'
'&code=${Uri.encodeQueryComponent(code)}',
);

await _request(
'DELETE',
uri,
);
}

Future<void> deleteRoom(
String code,
) async {
final uri = Uri.parse(
'$baseUrl?action=delete_room'
'&code=${Uri.encodeQueryComponent(code)}',
);

await _request(
'DELETE',
uri,
);
}

// ============================================================
// MESSAGES
// ============================================================

Future<List<Message>> getMessages(
String code, {
int limit = 50,
int offset = 0,
}) async {
final uri = Uri.parse(
'$baseUrl?action=messages'
'&code=${Uri.encodeQueryComponent(code)}'
'&limit=$limit'
'&offset=$offset',
);

final data = await _request(
'GET',
uri,
);

final messages = data['messages'];

if (messages is! List) {
return [];
}

return messages
    .map(
(json) => Message.fromJson(
json as Map<String, dynamic>,
),
)
    .toList();
}

Future<int> sendMessage(
String code,
String content, {
String type = 'text',
int? repliedTo,
String? fileUrl,
String? fileName,
int? fileSize,
}) async {
final uri = Uri.parse(
'$baseUrl?action=messages',
);

final data = await _request(
'POST',
uri,
body: {
'code': code,
'type': type,
'content': content,
if (fileUrl != null)
'file_url': fileUrl,
if (fileName != null)
'file_name': fileName,
if (fileSize != null)
'file_size': fileSize,
if (repliedTo != null)
'replied_to': repliedTo,
},
);

return data['message_id'] is int
? data['message_id'] as int
    : int.tryParse(
data['message_id']?.toString() ?? '',
) ??
0;
}

Future<int> sendTextMessage(
String code,
String content, {
int? repliedTo,
}) {
return sendMessage(
code,
content,
type: 'text',
repliedTo: repliedTo,
);
}

Future<int> sendGifMessage(
String code,
String url, {
int? repliedTo,
}) {
return sendMessage(
code,
url,
type: 'gif',
repliedTo: repliedTo,
);
}

// ============================================================
// FILE UPLOAD
// ============================================================

Future<Map<String, dynamic>> uploadFile(
File file,
) async {
if (!await file.exists()) {
throw Exception(
'Файл не найден: ${file.path}',
);
}

final token = await getToken();

final uri = Uri.parse(
'$baseUrl?action=upload',
);

final fileName = file.path.split('/').last;
final fileSize = await file.length();

print('📤 UPLOAD START');
print('📤 URL: $uri');
print('📤 FILE: $fileName');
print('📤 PATH: ${file.path}');
print('📤 SIZE: $fileSize bytes');

final request = http.MultipartRequest(
'POST',
uri,
);

request.headers.addAll({
'Accept': 'application/json',
if (token != null && token.isNotEmpty)
'Authorization': 'Bearer $token',
});

final multipartFile =
await http.MultipartFile.fromPath(
'file',
file.path,
filename: fileName,
);

request.files.add(
multipartFile,
);

print('📤 MULTIPART FILE ADDED');
print('📤 FIELD NAME: ${multipartFile.field}');
print('📤 FILENAME: ${multipartFile.filename}');
print('📤 CONTENT TYPE: ${multipartFile.contentType}');
print('📤 REQUEST FILES: ${request.files.length}');

final streamedResponse =
await _client.send(request);

print(
'📥 UPLOAD STATUS: '
'${streamedResponse.statusCode}',
);

final response =
await http.Response.fromStream(
streamedResponse,
);

print(
'📥 UPLOAD RESPONSE: '
'${response.body}',
);

final data = _parseResponse(response);

print('✅ UPLOAD SUCCESS');
print('📦 UPLOAD DATA: $data');

return data;
}

// ============================================================
// SEND FILE MESSAGE
// ============================================================

Future<int> sendFile(
String code,
File file, {
String? type,
int? repliedTo,
}) async {
print('📎 SEND FILE START');
print('📎 ROOM: $code');
print('📎 PATH: ${file.path}');

// ----------------------------------------------------------
// 1. UPLOAD FILE
// ----------------------------------------------------------

final uploadData =
await uploadFile(file);

print(
'📦 UPLOAD DATA RECEIVED: '
'$uploadData',
);

final fileUrl =
uploadData['url']?.toString();

final fileName =
uploadData['name']?.toString() ??
uploadData['file_name']?.toString() ??
file.path.split('/').last;

final fileSize =
uploadData['size'] is int
? uploadData['size'] as int
    : int.tryParse(
uploadData['size']
    ?.toString() ??
'',
) ??
await file.length();

if (fileUrl == null ||
fileUrl.isEmpty) {
print(
'❌ UPLOAD DID NOT RETURN FILE URL',
);

throw Exception(
'Сервер не вернул URL загруженного файла',
);
}

print('🔗 FILE URL: $fileUrl');
print('📄 FILE NAME: $fileName');
print('📦 FILE SIZE: $fileSize');

// ----------------------------------------------------------
// 2. DETECT TYPE
// ----------------------------------------------------------

final messageType =
type ?? _detectFileType(file);

print(
'🏷️ MESSAGE TYPE: $messageType',
);

// ----------------------------------------------------------
// 3. CREATE MESSAGE
// ----------------------------------------------------------

final messageId = await sendMessage(
code,
fileUrl,
type: messageType,
fileUrl: fileUrl,
fileName: fileName,
fileSize: fileSize,
repliedTo: repliedTo,
);

print(
'✅ FILE MESSAGE CREATED: '
'$messageId',
);

return messageId;
}

// ============================================================
// FILE TYPE
// ============================================================

String _detectFileType(
File file,
) {
final path =
file.path.toLowerCase();

if (path.endsWith('.jpg') ||
path.endsWith('.jpeg') ||
path.endsWith('.png') ||
path.endsWith('.webp') ||
path.endsWith('.bmp') ||
path.endsWith('.heic') ||
path.endsWith('.heif')) {
return 'image';
}

if (path.endsWith('.gif')) {
return 'gif';
}

if (path.endsWith('.mp4') ||
path.endsWith('.webm') ||
path.endsWith('.mov') ||
path.endsWith('.m4v')) {
return 'video';
}

if (path.endsWith('.mp3') ||
path.endsWith('.wav') ||
path.endsWith('.ogg') ||
path.endsWith('.m4a') ||
path.endsWith('.aac')) {
return 'audio';
}

if (path.endsWith('.pdf')) {
return 'file';
}

return 'file';
}

// ============================================================
// EDIT MESSAGE
// ============================================================

Future<void> editMessage(
int messageId,
String content,
) async {
final uri = Uri.parse(
'$baseUrl?action=messages',
);

await _request(
'PUT',
uri,
body: {
'message_id': messageId,
'content': content,
},
);
}

// ============================================================
// DELETE MESSAGE
// ============================================================

Future<void> deleteMessage(
int messageId,
) async {
final uri = Uri.parse(
'$baseUrl?action=messages'
'&message_id=$messageId',
);

await _request(
'DELETE',
uri,
);
}


// ============================================================
// CLEAR CHAT
// ============================================================

  Future<void> clearMessages(String code) async {
    final uri = Uri.parse(
      '$baseUrl?action=messages'
          '&code=${Uri.encodeQueryComponent(code)}',
    );

    print('🧹 CLEAR CHAT START');
    print('🧹 ROOM: $code');
    print('🧹 URL: $uri');

    await _request(
      'DELETE',
      uri,
    );

    print('✅ CHAT CLEARED');
  }

// ============================================================
// REACTIONS
// ============================================================

Future<void> addReaction(
int messageId,
String reaction,
) async {
final uri = Uri.parse(
'$baseUrl?action=reactions',
);

await _request(
'POST',
uri,
body: {
'message_id': messageId,
'reaction': reaction,
},
);
}

Future<void> removeReaction(
int messageId,
String reaction,
) async {
final uri = Uri.parse(
'$baseUrl?action=reactions'
'&message_id=$messageId'
'&reaction=${Uri.encodeQueryComponent(reaction)}',
);

await _request(
'DELETE',
uri,
);
}

// ============================================================
// PRESENCE
// ============================================================

Future<void> updatePresence(
String status,
) async {
final uri = Uri.parse(
'$baseUrl?action=presence',
);

await _request(
'POST',
uri,
body: {
'status': status,
},
);
}





// ============================================================
// CLEANUP
// ============================================================

void dispose() {
_client.close();
}
}

