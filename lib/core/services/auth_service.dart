// lib/core/api/api_client.dart
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../config/app_config.dart';
import '../models/user.dart';
import '../models/room.dart';
import '../models/message.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  late Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // ============================================
  // ИНИЦИАЛИЗАЦИЯ
  // ============================================
  Future<void> init() async {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: AppConfig.connectionTimeout,
        receiveTimeout: AppConfig.receiveTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: _onRequest,
        onResponse: _onResponse,
        onError: _onError,
      ),
    );
  }

  // ============================================
  // ИНТЕРЦЕПТОРЫ
  // ============================================
  Future<void> _onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await _storage.read(key: 'token');
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    print('🌐 ${options.method} ${options.uri}');
    handler.next(options);
  }

  void _onResponse(Response response, ResponseInterceptorHandler handler) {
    print('✅ ${response.statusCode} ${response.requestOptions.uri}');
    handler.next(response);
  }

  void _onError(DioException err, ErrorInterceptorHandler handler) {
    print('❌ ${err.response?.statusCode} ${err.requestOptions.uri}');
    print('   ${err.message}');
    handler.next(err);
  }

  // ============================================
  // ПУБЛИЧНЫЕ МЕТОДЫ
  // ============================================

  // ----- AUTH -----
  Future<Map<String, dynamic>> register(String login, String password, String nick) async {
    try {
      final response = await _dio.post(
        '',
        queryParameters: {'action': 'auth', 'sub': 'register'},
        data: {'login': login, 'password': password, 'nick': nick},
      );
      return response.data['data'] ?? {};
    } on DioException catch (e) {
      if (e.response?.data != null) {
        throw Exception(e.response?.data['error']['message'] ?? 'Registration failed');
      }
      throw Exception('Network error: ${e.message}');
    }
  }

  Future<Map<String, dynamic>> login(String login, String password) async {
    try {
      final response = await _dio.post(
        '',
        queryParameters: {'action': 'auth', 'sub': 'login'},
        data: {'login': login, 'password': password},
      );
      return response.data['data'] ?? {};
    } on DioException catch (e) {
      if (e.response?.data != null) {
        throw Exception(e.response?.data['error']['message'] ?? 'Login failed');
      }
      throw Exception('Network error: ${e.message}');
    }
  }

  // ===== ИСПРАВЛЕННЫЙ LOGOUT =====
  Future<void> logout() async {
    try {
      await _dio.delete('', queryParameters: {'action': 'auth'});
    } catch (e) {
      print('Logout error: $e');
    }
  }

  // ----- USER -----
  Future<User> getMe() async {
    try {
      final response = await _dio.get('', queryParameters: {'action': 'me'});
      final userJson = response.data['data']['user'] as Map<String, dynamic>;
      return User.fromJson(userJson);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('Session expired. Please login again.');
      }
      throw Exception('Failed to load user: ${e.message}');
    }
  }

  Future<User> updateProfile({
    String? login,
    String? nick,
    String? avatar,
    String? password,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (login != null) data['login'] = login;
      if (nick != null) data['nick'] = nick;
      if (avatar != null) data['avatar'] = avatar;
      if (password != null) data['password'] = password;

      final response = await _dio.put(
        '',
        queryParameters: {'action': 'profile'},
        data: data,
      );
      final userJson = response.data['data']['user'] as Map<String, dynamic>;
      return User.fromJson(userJson);
    } on DioException catch (e) {
      throw Exception('Failed to update profile: ${e.message}');
    }
  }

  // ----- ROOMS -----
  Future<List<Room>> getRooms() async {
    try {
      final response = await _dio.get('', queryParameters: {'action': 'rooms'});
      final roomsJson = response.data['data']['rooms'] as List<dynamic>? ?? [];
      return roomsJson.map((json) => Room.fromJson(json as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw Exception('Failed to load rooms: ${e.message}');
    }
  }

  Future<Room> createDMRoom(int targetUserId) async {
    try {
      final response = await _dio.post(
        '',
        queryParameters: {'action': 'rooms'},
        data: {'user_id': targetUserId, 'type': 'dm'},
      );
      final roomJson = response.data['data'] as Map<String, dynamic>;
      return Room.fromJson(roomJson);
    } on DioException catch (e) {
      throw Exception('Failed to create room: ${e.message}');
    }
  }

  Future<void> joinRoom(String code) async {
    try {
      await _dio.put(
        '',
        queryParameters: {'action': 'rooms'},
        data: {'code': code},
      );
    } on DioException catch (e) {
      throw Exception('Failed to join room: ${e.message}');
    }
  }

  Future<void> leaveRoom(String code) async {
    try {
      await _dio.delete(
        '',
        queryParameters: {'action': 'rooms', 'code': code},
      );
    } on DioException catch (e) {
      throw Exception('Failed to leave room: ${e.message}');
    }
  }

  // ----- MESSAGES -----
  Future<List<Message>> getMessages(String code, {int limit = 50, int offset = 0}) async {
    try {
      final response = await _dio.get(
        '',
        queryParameters: {
          'action': 'messages',
          'code': code,
          'limit': limit,
          'offset': offset,
        },
      );
      final messagesJson = response.data['data']['messages'] as List<dynamic>? ?? [];
      return messagesJson.map((json) => Message.fromJson(json as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw Exception('Failed to load messages: ${e.message}');
    }
  }

  Future<int> sendMessage(String code, String content, {String type = 'text', int? repliedTo}) async {
    try {
      final response = await _dio.post(
        '',
        queryParameters: {'action': 'messages'},
        data: {
          'code': code,
          'type': type,
          'content': content,
          if (repliedTo != null) 'replied_to': repliedTo,
        },
      );
      return response.data['data']['message_id'] as int? ?? 0;
    } on DioException catch (e) {
      throw Exception('Failed to send message: ${e.message}');
    }
  }

  Future<void> editMessage(int messageId, String content) async {
    try {
      await _dio.put(
        '',
        queryParameters: {'action': 'messages'},
        data: {'message_id': messageId, 'content': content},
      );
    } on DioException catch (e) {
      throw Exception('Failed to edit message: ${e.message}');
    }
  }

  Future<void> deleteMessage(int messageId) async {
    try {
      await _dio.delete(
        '',
        queryParameters: {'action': 'messages', 'message_id': messageId},
      );
    } on DioException catch (e) {
      throw Exception('Failed to delete message: ${e.message}');
    }
  }

  // ----- REACTIONS -----
  Future<void> addReaction(int messageId, String reaction) async {
    try {
      await _dio.post(
        '',
        queryParameters: {'action': 'reactions'},
        data: {'message_id': messageId, 'reaction': reaction},
      );
    } on DioException catch (e) {
      throw Exception('Failed to add reaction: ${e.message}');
    }
  }

  Future<void> removeReaction(int messageId, String reaction) async {
    try {
      await _dio.delete(
        '',
        queryParameters: {
          'action': 'reactions',
          'message_id': messageId,
          'reaction': reaction,
        },
      );
    } on DioException catch (e) {
      throw Exception('Failed to remove reaction: ${e.message}');
    }
  }

  // ----- PRESENCE -----
  Future<void> updatePresence(String status) async {
    try {
      await _dio.post(
        '',
        queryParameters: {'action': 'presence'},
        data: {'status': status},
      );
    } catch (e) {
      print('Presence update error: $e');
    }
  }

  // ----- TOKEN -----
  Future<void> saveToken(String token) async {
    await _storage.write(key: 'token', value: token);
  }

  Future<String?> getToken() async {
    return await _storage.read(key: 'token');
  }

  Future<void> clearToken() async {
    await _storage.delete(key: 'token');
  }
}