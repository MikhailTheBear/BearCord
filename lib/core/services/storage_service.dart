// lib/core/services/storage_service.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // ============================================
  // ТОКЕН
  // ============================================
  Future<void> saveToken(String token) async {
    await _storage.write(key: 'token', value: token);
  }

  Future<String?> getToken() async {
    return await _storage.read(key: 'token');
  }

  Future<void> deleteToken() async {
    await _storage.delete(key: 'token');
  }

  Future<bool> hasToken() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  // ============================================
  // ПОЛЬЗОВАТЕЛЬ
  // ============================================
  Future<void> saveUser(Map<String, dynamic> user) async {
    await _storage.write(key: 'user', value: user.toString());
  }

  Future<void> deleteUser() async {
    await _storage.delete(key: 'user');
  }

  // ============================================
  // ОЧИСТКА
  // ============================================
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}