// lib/core/services/storage_service.dart
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const _tokenKey = 'token';
  static const _userKey = 'user';
  static const _bearcordUserIdKey = 'bearcord_user_id';

  /// Токен сервиса Beardiary (поле `token` из auth-data JSON).
  /// Используется для генерации пароля веб-дневника
  /// вместе с bearcordUserId.
  static const _beardiaryServiceTokenKey = 'beardiary_service_token';

  // ============================================
  // ТОКЕН (Bearer-токен авторизации BearCord)
  // ============================================
  Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  Future<String?> getToken() async {
    return _storage.read(key: _tokenKey);
  }

  Future<void> deleteToken() async {
    await _storage.delete(key: _tokenKey);
  }

  Future<bool> hasToken() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  // ============================================
  // ПОЛЬЗОВАТЕЛЬ
  // ============================================
  Future<void> saveUser(Map<String, dynamic> user) async {
    await _storage.write(
      key: _userKey,
      value: jsonEncode(user),
    );
  }

  Future<Map<String, dynamic>?> getUser() async {
    final raw = await _storage.read(key: _userKey);

    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);

      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      // повреждённые данные — лучше удалить
    }

    return null;
  }

  Future<void> deleteUser() async {
    await _storage.delete(key: _userKey);
  }

  // ============================================
  // BEARCORD USER ID
  // ============================================
  Future<void> saveBearcordUserId(int userId) async {
    await _storage.write(
      key: _bearcordUserIdKey,
      value: userId.toString(),
    );
  }

  Future<int?> getBearcordUserId() async {
    final raw = await _storage.read(key: _bearcordUserIdKey);

    if (raw == null || raw.isEmpty) return null;

    return int.tryParse(raw);
  }

  Future<void> deleteBearcordUserId() async {
    await _storage.delete(key: _bearcordUserIdKey);
  }

  // ============================================
  // ТОКЕН СЕРВИСА BEARDIARY
  // ============================================
  Future<void> saveBeardiaryServiceToken(String token) async {
    await _storage.write(
      key: _beardiaryServiceTokenKey,
      value: token,
    );
  }

  Future<String?> getBeardiaryServiceToken() async {
    return _storage.read(key: _beardiaryServiceTokenKey);
  }

  Future<void> deleteBeardiaryServiceToken() async {
    await _storage.delete(key: _beardiaryServiceTokenKey);
  }

  Future<bool> hasBeardiaryServiceToken() async {
    final token = await getBeardiaryServiceToken();
    return token != null && token.isNotEmpty;
  }

  // ============================================
  // ОЧИСТКА
  // ============================================
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}