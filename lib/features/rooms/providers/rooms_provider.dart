// lib/features/rooms/providers/rooms_provider.dart
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/room.dart';
import '../../../core/api/api_client.dart';

final roomsProvider = StateNotifierProvider<RoomsNotifier, RoomsState>((ref) {
  return RoomsNotifier();
});

class RoomsState {
  final List<Room> rooms;
  final bool isLoading;
  final String? error;

  RoomsState({
    this.rooms = const [],
    this.isLoading = false,
    this.error,
  });

  RoomsState copyWith({
    List<Room>? rooms,
    bool? isLoading,
    String? error,
  }) {
    return RoomsState(
      rooms: rooms ?? this.rooms,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

class RoomsNotifier extends StateNotifier<RoomsState> {
  RoomsNotifier() : super(RoomsState());

  final ApiClient _api = ApiClient();
  Timer? _pollTimer;
  bool _isPolling = false;

  Future<void> loadRooms() async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      final rooms = await _api.getRooms();

      state = state.copyWith(
        rooms: rooms,
        isLoading: false,
      );

      print('✅ loadRooms: загружено ${rooms.length} комнат');
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
      );
    }
  }

  // ============================================
  // ПОЛЛИНГ ДЛЯ СПИСКА КОМНАТ
  // ============================================
  void startPolling() {
    _pollTimer?.cancel();
    _isPolling = true;

    _pollTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _checkRoomsUpdate();
    });

    print('🔄 Polling комнат запущен');
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _isPolling = false;
    print('🔄 Polling комнат остановлен');
  }

  Future<void> _checkRoomsUpdate() async {
    if (!_isPolling) return;

    try {
      final rooms = await _api.getRooms();

      // Проверяем, изменилось ли количество комнат
      if (rooms.length != state.rooms.length) {
        print('📨 Обновление списка комнат!');
        state = state.copyWith(rooms: rooms);
      }
    } catch (e) {
      // Молча игнорируем ошибки
    }
  }

  Future<void> createRoom(String code) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      await _api.createGroupRoom(code);
      await loadRooms();
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
      );
    }
  }

  Future<int?> getUserIdByLogin(String login) async {
    try {
      if (login.isEmpty) return null;
      return await _api.getUserIdByLogin(login);
    } catch (e) {
      print('❌ getUserIdByLogin error: $e');
      return null;
    }
  }

  Future<void> createDMRoom(int userId) async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      if (userId <= 0) {
        state = state.copyWith(
          error: 'Неверный ID пользователя',
          isLoading: false,
        );
        return;
      }

      await _api.createDMRoom(userId);
      await loadRooms();

    } catch (e) {
      print('❌ createDMRoom error: $e');
      await loadRooms();
      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
      );
    }
  }

  Future<void> joinRoom(String code) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      await _api.joinRoom(code);
      await loadRooms();
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
      );
    }
  }

  Future<void> leaveRoom(String code) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      await _api.leaveRoom(code);

      final newRooms = state.rooms.where((r) => r.code != code).toList();
      state = state.copyWith(
        rooms: newRooms,
        isLoading: false,
      );

      print('✅ Выход из комнаты $code успешен');
    } catch (e) {
      print('❌ Ошибка выхода из комнаты: $e');
      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
      );
    }
  }

  Future<void> deleteRoom(String code) async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      await _api.deleteRoom(code);

      final newRooms = state.rooms.where((r) => r.code != code).toList();
      state = state.copyWith(
        rooms: newRooms,
        isLoading: false,
      );

      print('✅ Комната $code удалена');
    } catch (e) {
      print('❌ Ошибка удаления комнаты: $e');
      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
      );
    }
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}