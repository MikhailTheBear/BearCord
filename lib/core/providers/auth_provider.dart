import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../models/user.dart';

final authProvider =
StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

// ============================================================
// AUTH STATE
// ============================================================

class AuthState {
  final User? user;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.error,
  });

  bool get isAuthenticated => user != null;

  AuthState copyWith({
    User? user,
    bool? isLoading,
    String? error,
    bool clearUser = false,
    bool clearError = false,
  }) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// ============================================================
// AUTH NOTIFIER
// ============================================================

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState()) {
    checkAuth();
  }

  final ApiClient _api = ApiClient();

  // ==========================================================
  // CHECK AUTH
  // ==========================================================

  Future<void> checkAuth() async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
    );

    try {
      final token = await _api.getToken();

      if (token == null || token.isEmpty) {
        state = state.copyWith(
          isLoading: false,
          clearUser: true,
        );
        return;
      }

      final data = await _api.getMe();

      final userData = data['user'];

      if (userData is! Map<String, dynamic>) {
        await _api.deleteToken();

        state = state.copyWith(
          isLoading: false,
          clearUser: true,
        );

        return;
      }

      final user = User.fromJson(userData);

      state = state.copyWith(
        user: user,
        isLoading: false,
        clearError: true,
      );

      print('✅ Сессия восстановлена: @${user.login}');
    } catch (e) {
      print('❌ Ошибка проверки авторизации: $e');

      await _api.deleteToken();

      state = state.copyWith(
        isLoading: false,
        clearUser: true,
        error: e.toString(),
      );
    }
  }

  // ==========================================================
  // LOGIN
  // ==========================================================

  Future<bool> login(
      String login,
      String password,
      ) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
    );

    try {
      final data = await _api.login(
        login,
        password,
      );

      final userData = data['user'];

      if (userData is! Map<String, dynamic>) {
        throw Exception('Сервер не вернул данные пользователя');
      }

      final user = User.fromJson(userData);

      state = state.copyWith(
        user: user,
        isLoading: false,
        clearError: true,
      );

      print('✅ Вход выполнен: @${user.login}');

      return true;
    } catch (e) {
      print('❌ Ошибка входа: $e');

      state = state.copyWith(
        isLoading: false,
        error: _formatError(e),
      );

      return false;
    }
  }

  // ==========================================================
  // REGISTER
  // ==========================================================

  Future<bool> register({
    required String login,
    required String password,
    required String nick,
    String? avatar,
  }) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
    );

    try {
      await _api.register(
        login: login,
        password: password,
        nick: nick,
        avatar: avatar,
      );

      print('✅ Регистрация выполнена: @$login');

      // После регистрации автоматически входим,
      // потому что API регистрации не выдаёт токен.
      final loginSuccess = await this.login(
        login,
        password,
      );

      if (!loginSuccess) {
        throw Exception(
          'Регистрация выполнена, но автоматический вход не удался',
        );
      }

      print('✅ Автоматический вход выполнен: @$login');

      return true;
    } catch (e) {
      print('❌ Ошибка регистрации: $e');

      state = state.copyWith(
        isLoading: false,
        error: _formatError(e),
      );

      return false;
    }
  }

  // ==========================================================
  // LOGOUT
  // ==========================================================

  Future<void> logout() async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
    );

    try {
      await _api.logout();

      print('✅ Выход выполнен');
    } catch (e) {
      print('⚠️ Ошибка logout API: $e');

      // Даже если сервер недоступен,
      // локальную сессию всё равно удаляем.
      await _api.deleteToken();
    }

    state = const AuthState();
  }

  // ==========================================================
  // UPDATE PROFILE
  // ==========================================================

  Future<bool> updateProfile({
    String? login,
    String? nick,
    String? avatar,
    String? password,
    String? currentPassword,
  }) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
    );

    try {
      final user = await _api.updateProfile(
        login: login,
        nick: nick,
        avatar: avatar,
        password: password,
        currentPassword: currentPassword,
      );

      state = state.copyWith(
        user: user,
        isLoading: false,
        clearError: true,
      );

      print(
        '✅ Профиль обновлён: @${user.login}',
      );

      return true;
    } catch (e) {
      print(
        '❌ Ошибка обновления профиля: $e',
      );

      state = state.copyWith(
        isLoading: false,
        error: _formatError(e),
      );

      return false;
    }
  }



  // ==========================================================
  // ERROR FORMAT
  // ==========================================================

  String _formatError(Object error) {
    final message = error.toString();

    if (message.startsWith('Exception: ')) {
      return message.substring('Exception: '.length);
    }

    return message;
  }
}