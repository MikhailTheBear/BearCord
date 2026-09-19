import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/models/message.dart';
import '../../../core/models/room.dart';

final chatProvider = StateNotifierProvider.family<
    ChatNotifier,
    ChatState,
    String
>((ref, roomCode) {
  final notifier = ChatNotifier(roomCode);

  ref.onDispose(() {
    notifier.dispose();
  });

  return notifier;
});

// ============================================================
// CHAT STATE
// ============================================================

class ChatState {
  final Room? room;
  final List<Message> messages;
  final bool isLoading;
  final bool isSending;
  final String? error;

  const ChatState({
    this.room,
    this.messages = const [],
    this.isLoading = false,
    this.isSending = false,
    this.error,
  });

  ChatState copyWith({
    Room? room,
    List<Message>? messages,
    bool? isLoading,
    bool? isSending,
    String? error,
    bool clearError = false,
  }) {
    return ChatState(
      room: room ?? this.room,
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// ============================================================
// CHAT NOTIFIER
// ============================================================

class ChatNotifier extends StateNotifier<ChatState> {
  final String roomCode;

  final ApiClient _api = ApiClient();

  Timer? _pollTimer;

  bool _isPolling = false;
  bool _disposed = false;

  bool _isLoadingMessages = false;

  int _operationId = 0;

  int _pollingOperationId = 0;

  ChatNotifier(this.roomCode) : super(const ChatState()) {
    loadRoomAndMessages();
    startPolling();
  }

  // ============================================================
  // SAFETY
  // ============================================================

  bool get _isAlive {
    return !_disposed && mounted;
  }

  bool _canUpdate(int operationId) {
    return _isAlive && operationId == _operationId;
  }

  bool _canUpdatePolling(int pollingId) {
    return _isAlive &&
        _isPolling &&
        pollingId == _pollingOperationId;
  }

  void _invalidateOperations() {
    _operationId++;
  }

  void _invalidatePolling() {
    _pollingOperationId++;
  }


// ============================================================
// MARK CHAT AS READ
// ============================================================

  Future<void> markMessagesRead() async {
    if (!_isAlive || roomCode.isEmpty) {
      return;
    }

    try {
      await _api.markMessagesRead(roomCode);

      print('👁️ CHAT MARKED AS READ: $roomCode');
    } catch (e) {
      print('❌ MARK READ ERROR: $e');
    }
  }


  // ============================================================
  // LOAD ROOM + MESSAGES
  // ============================================================

  Future<void> loadRoomAndMessages() async {
    if (!_isAlive || roomCode.isEmpty) {
      return;
    }

    final operationId = ++_operationId;

    state = state.copyWith(
      isLoading: true,
      clearError: true,
    );

    try {
      final rooms = await _api.getRooms();

      if (!_canUpdate(operationId)) {
        return;
      }

      Room? room;

      for (final item in rooms) {
        if (item.code == roomCode) {
          room = item;
          break;
        }
      }

      final messages = await _api.getMessages(roomCode);

      if (!_canUpdate(operationId)) {
        return;
      }

      state = state.copyWith(
        room: room,
        messages: messages,
        isLoading: false,
        clearError: true,
      );

      await markMessagesRead();

    } catch (e) {
      if (!_canUpdate(operationId)) {
        return;
      }

      state = state.copyWith(
        isLoading: false,
        error: _formatError(e),
      );
    }
  }

  // ============================================================
  // LOAD MESSAGES
  // ============================================================

  Future<void> loadMessages() async {
    if (!_isAlive ||
        roomCode.isEmpty ||
        _isLoadingMessages) {
      return;
    }

    _isLoadingMessages = true;

    final operationId = ++_operationId;

    try {
      state = state.copyWith(
        isLoading: true,
        clearError: true,
      );

      final messages = await _api.getMessages(roomCode);

      if (!_canUpdate(operationId)) {
        return;
      }

      state = state.copyWith(
        messages: messages,
        isLoading: false,
        clearError: true,
      );
    } catch (e) {
      if (!_canUpdate(operationId)) {
        return;
      }

      state = state.copyWith(
        isLoading: false,
        error: _formatError(e),
      );
    } finally {
      _isLoadingMessages = false;
    }
  }

  // ============================================================
  // POLLING
  // ============================================================

  void startPolling() {
    if (!_isAlive) {
      return;
    }

    stopPolling();

    _isPolling = true;

    final pollingId = ++_pollingOperationId;

    _pollTimer = Timer.periodic(
      const Duration(seconds: 3),
          (_) {
        if (_canUpdatePolling(pollingId)) {
          _checkMessagesUpdate(pollingId);
        }
      },
    );

    print('🔄 Polling комнат запущен');
  }

  void stopPolling() {
    _isPolling = false;

    _invalidatePolling();

    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _checkMessagesUpdate(
      int pollingId,
      ) async {
    if (!_isAlive ||
        !_isPolling ||
        roomCode.isEmpty ||
        _isLoadingMessages) {
      return;
    }

    _isLoadingMessages = true;

    try {
      final messages =
      await _api.getMessages(roomCode);

      if (!_canUpdatePolling(pollingId)) {
        return;
      }

      if (!_messagesChanged(messages)) {
        return;
      }

      state = state.copyWith(
        messages: messages,
      );
    } catch (_) {
      // Ошибки polling пользователю не показываем.
    } finally {
      _isLoadingMessages = false;
    }
  }

  // ============================================================
  // MESSAGE CHANGE DETECTION
  // ============================================================

  bool _messagesChanged(
      List<Message> newMessages,
      ) {
    final oldMessages = state.messages;

    if (oldMessages.length !=
        newMessages.length) {
      return true;
    }

    for (var i = 0;
    i < oldMessages.length;
    i++) {
      final oldMessage =
      oldMessages[i];

      final newMessage =
      newMessages[i];

      if (oldMessage.id !=
          newMessage.id ||
          oldMessage.content !=
              newMessage.content ||
          oldMessage.editedAt !=
              newMessage.editedAt ||
          oldMessage.isDeleted !=
              newMessage.isDeleted ||
          oldMessage.fileUrl !=
              newMessage.fileUrl ||
          oldMessage.fileName !=
              newMessage.fileName ||
          oldMessage.fileSize !=
              newMessage.fileSize ||
          !_reactionsEqual(
            oldMessage.reactions,
            newMessage.reactions,
          )) {
        return true;
      }
    }

    return false;
  }

  // ============================================================
  // REACTIONS COMPARISON
  // ============================================================

  bool _reactionsEqual(
      List<MessageReaction> a,
      List<MessageReaction> b,
      ) {
    if (a.length != b.length) {
      return false;
    }

    for (var i = 0; i < a.length; i++) {
      final first = a[i];
      final second = b[i];

      if (first.reaction !=
          second.reaction ||
          first.userId !=
              second.userId ||
          first.nick !=
              second.nick) {
        return false;
      }
    }

    return true;
  }

  // ============================================================
  // SEND TEXT
  // ============================================================

  Future<bool> sendMessage(
      String content, {
        int? repliedTo,
      }) async {
    final text = content.trim();

    if (!_isAlive || text.isEmpty) {
      return false;
    }

    final operationId = ++_operationId;

    state = state.copyWith(
      isSending: true,
      clearError: true,
    );

    try {
      await _api.sendTextMessage(
        roomCode,
        text,
        repliedTo: repliedTo,
      );

      if (!_canUpdate(operationId)) {
        return false;
      }

      final messages =
      await _api.getMessages(roomCode);

      if (!_canUpdate(operationId)) {
        return false;
      }

      state = state.copyWith(
        messages: messages,
        isSending: false,
      );

      return true;
    } catch (e) {
      if (!_canUpdate(operationId)) {
        return false;
      }

      state = state.copyWith(
        isSending: false,
        error: _formatError(e),
      );

      return false;
    }
  }

  // ============================================================
  // SEND GIF
  // ============================================================

  Future<bool> sendGif(
      String url, {
        int? repliedTo,
      }) async {
    final gifUrl = url.trim();

    if (!_isAlive || gifUrl.isEmpty) {
      return false;
    }

    final operationId = ++_operationId;

    state = state.copyWith(
      isSending: true,
      clearError: true,
    );

    try {
      await _api.sendGifMessage(
        roomCode,
        gifUrl,
        repliedTo: repliedTo,
      );

      if (!_canUpdate(operationId)) {
        return false;
      }

      final messages =
      await _api.getMessages(roomCode);

      if (!_canUpdate(operationId)) {
        return false;
      }

      state = state.copyWith(
        messages: messages,
        isSending: false,
      );

      return true;
    } catch (e) {
      if (!_canUpdate(operationId)) {
        return false;
      }

      state = state.copyWith(
        isSending: false,
        error: _formatError(e),
      );

      return false;
    }
  }

  // ============================================================
  // CLEAR CHAT
  // ============================================================

  Future<void> clearMessages() async {
    if (!_isAlive || roomCode.isEmpty) {
      return;
    }

    final operationId = ++_operationId;

    _isLoadingMessages = true;

    try {
      print('🧹 CLEAR CHAT START');
      print('🧹 ROOM: $roomCode');

      await _api.clearMessages(roomCode);

      if (!_canUpdate(operationId)) {
        return;
      }

      state = state.copyWith(
        messages: [],
        clearError: true,
      );

      print('✅ CHAT CLEARED');
    } catch (e) {
      print('❌ CLEAR CHAT ERROR: $e');

      if (!_canUpdate(operationId)) {
        return;
      }

      state = state.copyWith(
        error: _formatError(e),
      );

      rethrow;
    } finally {
      _isLoadingMessages = false;
    }
  }

  // ============================================================
  // SEND FILE
  // ============================================================

  Future<bool> sendFile(
      String filePath, {
        String? type,
        int? repliedTo,
      }) async {
    final path = filePath.trim();

    if (!_isAlive || path.isEmpty) {
      return false;
    }

    final file = File(path);

    final exists = await file.exists();

    if (!_isAlive) {
      return false;
    }

    if (!exists) {
      state = state.copyWith(
        error: 'Файл не найден',
      );

      return false;
    }

    final operationId = ++_operationId;

    state = state.copyWith(
      isSending: true,
      clearError: true,
    );

    try {
      print(
        '📤 Uploading file: ${file.path}',
      );

      await _api.sendFile(
        roomCode,
        file,
        type: type,
        repliedTo: repliedTo,
      );

      print('✅ File uploaded');

      if (!_canUpdate(operationId)) {
        return false;
      }

      final messages =
      await _api.getMessages(roomCode);

      if (!_canUpdate(operationId)) {
        return false;
      }

      state = state.copyWith(
        messages: messages,
        isSending: false,
      );

      return true;
    } catch (e) {
      print(
        '❌ File upload error: $e',
      );

      if (!_canUpdate(operationId)) {
        return false;
      }

      state = state.copyWith(
        isSending: false,
        error: _formatError(e),
      );

      return false;
    }
  }

  // ============================================================
  // EDIT MESSAGE
  // ============================================================

  Future<bool> editMessage(
      int messageId,
      String content,
      ) async {
    final text = content.trim();

    if (!_isAlive ||
        messageId <= 0 ||
        text.isEmpty) {
      return false;
    }

    final operationId = ++_operationId;

    try {
      await _api.editMessage(
        messageId,
        text,
      );

      if (!_canUpdate(operationId)) {
        return false;
      }

      final messages =
      await _api.getMessages(roomCode);

      if (!_canUpdate(operationId)) {
        return false;
      }

      state = state.copyWith(
        messages: messages,
        clearError: true,
      );

      return true;
    } catch (e) {
      if (!_canUpdate(operationId)) {
        return false;
      }

      state = state.copyWith(
        error: _formatError(e),
      );

      return false;
    }
  }

  // ============================================================
  // DELETE MESSAGE
  // ============================================================

  Future<bool> deleteMessage(
      int messageId,
      ) async {
    if (!_isAlive ||
        messageId <= 0) {
      return false;
    }

    final operationId = ++_operationId;

    try {
      await _api.deleteMessage(
        messageId,
      );

      if (!_canUpdate(operationId)) {
        return false;
      }

      final messages = state.messages
          .where(
            (message) =>
        message.id != messageId,
      )
          .toList();

      state = state.copyWith(
        messages: messages,
        clearError: true,
      );

      return true;
    } catch (e) {
      if (!_canUpdate(operationId)) {
        return false;
      }

      state = state.copyWith(
        error: _formatError(e),
      );

      return false;
    }
  }

  // ============================================================
  // REACTIONS
  // ============================================================

  Future<bool> toggleReaction(
      int messageId,
      String reaction,
      int currentUserId,
      ) async {
    if (!_isAlive ||
        messageId <= 0 ||
        reaction.trim().isEmpty ||
        currentUserId <= 0) {
      return false;
    }

    Message? message;

    for (final item in state.messages) {
      if (item.id == messageId) {
        message = item;
        break;
      }
    }

    if (message == null) {
      return false;
    }

    final normalizedReaction =
    reaction.trim();

    // Проверяем реакцию именно
    // текущего пользователя.
    final hasReaction =
    message.reactions.any(
          (item) =>
      item.reaction ==
          normalizedReaction &&
          item.userId ==
              currentUserId,
    );

    if (hasReaction) {
      return removeReaction(
        messageId,
        normalizedReaction,
      );
    }

    return addReaction(
      messageId,
      normalizedReaction,
    );
  }

  // ============================================================
  // ADD REACTION
  // ============================================================

  Future<bool> addReaction(
      int messageId,
      String reaction,
      ) async {
    final normalizedReaction =
    reaction.trim();

    if (!_isAlive ||
        messageId <= 0 ||
        normalizedReaction.isEmpty) {
      return false;
    }

    final operationId = ++_operationId;

    try {
      await _api.addReaction(
        messageId,
        normalizedReaction,
      );

      if (!_canUpdate(operationId)) {
        return false;
      }

      final messages =
      await _api.getMessages(roomCode);

      if (!_canUpdate(operationId)) {
        return false;
      }

      state = state.copyWith(
        messages: messages,
        clearError: true,
      );

      return true;
    } catch (e) {
      if (!_canUpdate(operationId)) {
        return false;
      }

      state = state.copyWith(
        error: _formatError(e),
      );

      return false;
    }
  }

  // ============================================================
  // REMOVE REACTION
  // ============================================================

  Future<bool> removeReaction(
      int messageId,
      String reaction,
      ) async {
    final normalizedReaction =
    reaction.trim();

    if (!_isAlive ||
        messageId <= 0 ||
        normalizedReaction.isEmpty) {
      return false;
    }

    final operationId = ++_operationId;

    try {
      await _api.removeReaction(
        messageId,
        normalizedReaction,
      );

      if (!_canUpdate(operationId)) {
        return false;
      }

      final messages =
      await _api.getMessages(roomCode);

      if (!_canUpdate(operationId)) {
        return false;
      }

      state = state.copyWith(
        messages: messages,
        clearError: true,
      );

      return true;
    } catch (e) {
      if (!_canUpdate(operationId)) {
        return false;
      }

      state = state.copyWith(
        error: _formatError(e),
      );

      return false;
    }
  }

  // ============================================================
  // ERROR
  // ============================================================

  void clearError() {
    if (!_isAlive) {
      return;
    }

    state = state.copyWith(
      clearError: true,
    );
  }

  String _formatError(Object error) {
    final message = error.toString();

    if (message.startsWith(
      'Exception: ',
    )) {
      return message.substring(
        'Exception: '.length,
      );
    }

    return message;
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    if (_disposed) {
      return;
    }

    _disposed = true;

    _invalidateOperations();
    _invalidatePolling();

    stopPolling();

    _api.dispose();

    super.dispose();
  }
}