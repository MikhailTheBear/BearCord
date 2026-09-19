// lib/features/rooms/providers/rooms_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/models/room.dart';

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
    bool clearError = false,
  }) {
    return RoomsState(
      rooms: rooms ?? this.rooms,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class RoomsNotifier extends StateNotifier<RoomsState> {
  RoomsNotifier() : super(RoomsState());

  final ApiClient _api = ApiClient();

  // ----------------------------------------------------------
  // Защита от параллельных loadRooms()
  // ----------------------------------------------------------

  bool _roomsLoadRunning = false;
  bool _roomsReloadRequested = false;
  bool _roomsShowLoadingRequested = false;

  // ----------------------------------------------------------
  // LOAD ROOMS
  // ----------------------------------------------------------

  Future<void> loadRooms({
    bool showLoading = true,
  }) async {
    if (!mounted) return;

    // Если загрузка уже идёт — не запускаем второй параллельный
    // запрос. Просто говорим, что после текущего нужен ещё один.
    if (_roomsLoadRunning) {
      _roomsReloadRequested = true;

      if (showLoading) {
        _roomsShowLoadingRequested = true;
      }

      print('🔄 loadRooms: запрос уже идёт, запланировано обновление');
      return;
    }

    _roomsLoadRunning = true;

    bool currentShowLoading = showLoading;

    try {
      do {
        _roomsReloadRequested = false;

        final bool shouldShowLoading =
            currentShowLoading || _roomsShowLoadingRequested;

        _roomsShowLoadingRequested = false;

        if (shouldShowLoading) {
          state = state.copyWith(
            isLoading: true,
            clearError: true,
          );
        }

        try {
          final rooms = await _api.getRooms();

          if (!mounted) return;

          state = state.copyWith(
            rooms: rooms,
            isLoading: false,
            clearError: true,
          );

          print(
            '✅ loadRooms: загружено ${rooms.length} комнат',
          );
        } catch (e) {
          if (!mounted) return;

          state = state.copyWith(
            error: e.toString(),
            isLoading: false,
          );

          print('❌ loadRooms: $e');
        }

        // После первого запроса дальнейшие запросы,
        // вызванные WebSocket-событиями, не показывают
        // fullscreen loading.
        currentShowLoading = false;

      } while (
      _roomsReloadRequested &&
          mounted
      );

    } finally {
      _roomsLoadRunning = false;
    }
  }

  // ----------------------------------------------------------
  // CREATE GROUP ROOM
  // ----------------------------------------------------------

  Future<void> createRoom(String code) async {
    try {
      state = state.copyWith(
        isLoading: true,
        clearError: true,
      );

      await _api.createGroupRoom(code);

      await loadRooms();
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
      );
    }
  }

  // ----------------------------------------------------------
  // GET USER ID BY LOGIN
  // ----------------------------------------------------------

  Future<int?> getUserIdByLogin(String login) async {
    try {
      if (login.isEmpty) {
        return null;
      }

      return await _api.getUserIdByLogin(login);
    } catch (e) {
      print(
        '❌ getUserIdByLogin error: $e',
      );

      return null;
    }
  }

  // ----------------------------------------------------------
  // CREATE DM
  // ----------------------------------------------------------

  Future<String?> createDMRoom(int userId) async {
    try {
      state = state.copyWith(
        isLoading: true,
        clearError: true,
      );

      if (userId <= 0) {
        state = state.copyWith(
          error: 'Неверный ID пользователя',
          isLoading: false,
        );
        return null;
      }

      final code = await _api.createDMRoom(userId);

      // Синхронизируем список комнат после создания.
      await loadRooms(showLoading: false);

      return code;
    } catch (e) {
      print('❌ createDMRoom error: $e');

      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
      );

      await loadRooms(showLoading: false);

      return null;
    }
  }

  // ----------------------------------------------------------
  // JOIN ROOM
  // ----------------------------------------------------------

  Future<void> joinRoom(String code) async {
    try {
      state = state.copyWith(
        isLoading: true,
        clearError: true,
      );

      await _api.joinRoom(code);

      await loadRooms();
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
      );
    }
  }

  // ----------------------------------------------------------
  // LEAVE ROOM
  // ----------------------------------------------------------

  Future<void> leaveRoom(String code) async {
    try {
      state = state.copyWith(
        isLoading: true,
        clearError: true,
      );

      await _api.leaveRoom(code);

      final newRooms = state.rooms
          .where((room) => room.code != code)
          .toList();

      state = state.copyWith(
        rooms: newRooms,
        isLoading: false,
        clearError: true,
      );

      print(
        '✅ Выход из комнаты $code успешен',
      );
    } catch (e) {
      print(
        '❌ Ошибка выхода из комнаты: $e',
      );

      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
      );
    }
  }

  // ----------------------------------------------------------
  // DELETE ROOM
  // ----------------------------------------------------------

  Future<void> deleteRoom(String code) async {
    try {
      state = state.copyWith(
        isLoading: true,
        clearError: true,
      );

      await _api.deleteRoom(code);

      final newRooms = state.rooms
          .where((room) => room.code != code)
          .toList();

      state = state.copyWith(
        rooms: newRooms,
        isLoading: false,
        clearError: true,
      );

      print(
        '✅ Комната $code удалена',
      );
    } catch (e) {
      print(
        '❌ Ошибка удаления комнаты: $e',
      );

      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
      );
    }
  }

  // ----------------------------------------------------------
  // DISPOSE
  // ----------------------------------------------------------

  @override
  void dispose() {
    super.dispose();
  }
}