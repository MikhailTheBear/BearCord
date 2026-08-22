import 'dart:ui';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/app_theme.dart';
import '../../../core/models/message.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/live_activity_service.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../../rooms/providers/rooms_provider.dart';
import '../providers/chat_provider.dart';
import '../widgets/message_bubble.dart';
import '../widgets/message_input.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String code;

  const ChatScreen({
    super.key,
    required this.code,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen>
    with WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();

  final TextEditingController _inputController =
  TextEditingController();

  // ============================================================
  // SOUNDS
  // ============================================================

  final AudioPlayer _sendPlayer = AudioPlayer();
  final AudioPlayer _receivePlayer = AudioPlayer();

  // ============================================================
  // SCROLL STATE
  // ============================================================

  bool _didInitialScroll = false;

  int? _lastHandledMessageId;

  bool _scrollScheduled = false;

  // ============================================================
  // LIVE ACTIVITY
  // ============================================================

  String? _liveActivityID;

  int? _lastLiveActivityMessageID;

  String? _lastLiveActivityContent;

  bool _liveActivitySyncing = false;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _scrollController.addListener(_onScroll);
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _scrollController.removeListener(_onScroll);

    LiveActivityService.stop();

    _sendPlayer.dispose();
    _receivePlayer.dispose();

    _scrollController.dispose();
    _inputController.dispose();

    super.dispose();
  }

  // ============================================================
  // PLAY SEND SOUND
  // ============================================================

  Future<void> _playSendSound() async {
    try {
      await _sendPlayer.stop();

      await _sendPlayer.play(
        AssetSource('sounds/send.mp3'),
      );
    } catch (e) {
      debugPrint(
        '❌ Send sound error: $e',
      );
    }
  }

  // ============================================================
  // PLAY RECEIVE SOUND
  // ============================================================

  Future<void> _playReceiveSound() async {
    try {
      await _receivePlayer.stop();

      await _receivePlayer.play(
        AssetSource('sounds/receive.mp3'),
      );
    } catch (e) {
      debugPrint(
        '❌ Receive sound error: $e',
      );
    }
  }

  // ============================================================
  // SCROLL LISTENER
  // ============================================================

  void _onScroll() {
    // Зарезервировано для будущей пагинации.
  }

  // ============================================================
  // APP LIFECYCLE
  // ============================================================

  @override
  void didChangeAppLifecycleState(
      AppLifecycleState state,
      ) {
    super.didChangeAppLifecycleState(state);

    if (state != AppLifecycleState.resumed) {
      return;
    }

    if (!mounted) {
      return;
    }

    ref
        .read(
      chatProvider(widget.code).notifier,
    )
        .loadMessages();
  }

  // ============================================================
  // LIVE ACTIVITY
  // ============================================================

  Future<void> _syncLiveActivity(
      ChatState chatState,
      ) async {
    if (!mounted) {
      return;
    }

    if (_liveActivitySyncing) {
      return;
    }

    if (chatState.isLoading) {
      return;
    }

    final room = chatState.room;

    if (room == null) {
      return;
    }

    if (chatState.messages.isEmpty) {
      return;
    }

    final message = chatState.messages.last;

    final liveMessage =
    _liveActivityMessage(message);

    if (_lastLiveActivityMessageID == message.id &&
        _lastLiveActivityContent == liveMessage) {
      return;
    }

    _liveActivitySyncing = true;

    try {
      final supported =
      await LiveActivityService.isSupported();

      if (!mounted) {
        return;
      }

      if (!supported) {
        return;
      }

      final avatarURL =
      message.displayAvatar.isNotEmpty
          ? message.displayAvatar
          : null;

      if (_liveActivityID == null) {
        print(
          '🏝️ Запускаем BearCord Live Activity...',
        );

        final activityID =
        await LiveActivityService.start(
          chatID: widget.code,
          chatName: room.displayName,
          senderName: message.nick,
          message: liveMessage,
          avatarURL: avatarURL,
        );

        if (!mounted) {
          return;
        }

        if (activityID != null &&
            activityID.isNotEmpty) {
          _liveActivityID = activityID;

          _lastLiveActivityMessageID =
              message.id;

          _lastLiveActivityContent =
              liveMessage;

          print(
            '🏝️ Live Activity запущена: '
                '$activityID',
          );
        }

        return;
      }

      print(
        '🔄 Обновляем BearCord Live Activity...',
      );

      final updated =
      await LiveActivityService.update(
        activityID: _liveActivityID!,
        senderName: message.nick,
        message: liveMessage,
        avatarURL: avatarURL,
      );

      if (!mounted) {
        return;
      }

      if (updated) {
        _lastLiveActivityMessageID =
            message.id;

        _lastLiveActivityContent =
            liveMessage;

        print(
          '✅ Live Activity обновлена',
        );
      }
    } catch (e) {
      print(
        '❌ Live Activity sync error: $e',
      );
    } finally {
      _liveActivitySyncing = false;
    }
  }

  // ============================================================
  // LIVE ACTIVITY MESSAGE
  // ============================================================

  String _liveActivityMessage(
      Message message,
      ) {
    if (message.isDeleted) {
      return 'Сообщение удалено';
    }

    if (message.isGif) {
      return 'GIF';
    }

    if (message.isImage ||
        message.isImageFile) {
      return '📷 Фото';
    }

    if (message.isVideo) {
      return '🎥 Видео';
    }

    if (message.isAudio) {
      return '🎵 Аудио';
    }

    if (message.isFile) {
      final fileName =
          message.fileName?.trim() ?? '';

      if (fileName.isNotEmpty) {
        return '📎 $fileName';
      }

      return '📎 Файл';
    }

    final text =
    message.content.trim();

    if (text.isEmpty) {
      return 'Новое сообщение';
    }

    return text;
  }

  // ============================================================
  // SCROLL TO BOTTOM
  // ============================================================

  void _scrollToBottom({
    bool animated = true,
  }) {
    if (!_scrollController.hasClients) {
      return;
    }

    final position =
        _scrollController.position.maxScrollExtent;

    if (!animated) {
      _scrollController.jumpTo(position);
      return;
    }

    _scrollController.animateTo(
      position,
      duration:
      const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  // ============================================================
  // HANDLE CHAT CHANGES
  // ============================================================

  void _handleMessagesChanged(
      ChatState chatState,
      ) {
    if (!mounted) {
      return;
    }

    if (chatState.isLoading) {
      return;
    }

    if (chatState.messages.isEmpty) {
      return;
    }

    final lastMessage =
        chatState.messages.last;

    // ========================================================
    // INITIAL LOAD
    // ========================================================

    if (!_didInitialScroll) {
      _didInitialScroll = true;

      _lastHandledMessageId =
          lastMessage.id;

      _scheduleScroll(
        animated: false,
      );

      return;
    }

    // ========================================================
    // NEW MESSAGE
    // ========================================================

    if (_lastHandledMessageId !=
        lastMessage.id) {
      _lastHandledMessageId =
          lastMessage.id;

      _scheduleScroll(
        animated: true,
      );

      // ------------------------------------------------------
      // RECEIVE SOUND
      // ------------------------------------------------------
      //
      // Если последнее сообщение НЕ наше —
      // значит оно пришло от другого пользователя.
      //
      final currentUserId =
          ref.read(authProvider).user?.id;

      final isMyMessage =
          lastMessage.userId ==
              currentUserId;

      if (!isMyMessage) {
        _playReceiveSound();
      }
    }
  }

  // ============================================================
  // SCHEDULE SCROLL
  // ============================================================

  void _scheduleScroll({
    required bool animated,
  }) {
    if (_scrollScheduled) {
      return;
    }

    _scrollScheduled = true;

    WidgetsBinding.instance
        .addPostFrameCallback((_) {
      _scrollScheduled = false;

      if (!mounted) {
        return;
      }

      if (!_scrollController.hasClients) {
        return;
      }

      _scrollToBottom(
        animated: animated,
      );
    });
  }

  // ============================================================
  // CHAT MENU
  // ============================================================

  void _showChatMenu() {
    final room = ref
        .read(
      chatProvider(widget.code),
    )
        .room;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor:
      Colors.transparent,
      barrierColor:
      Colors.black.withValues(
        alpha: 0.45,
      ),
      isScrollControlled: true,
      builder: (sheetContext) {
        return _GlassBottomSheet(
          child: SafeArea(
            child: Padding(
              padding:
              const EdgeInsets.fromLTRB(
                14,
                8,
                14,
                14,
              ),
              child: Column(
                mainAxisSize:
                MainAxisSize.min,
                children: [
                  if (room?.type == 'group')
                    _MenuItem(
                      icon:
                      Icons.exit_to_app_rounded,
                      title:
                      'Выйти из чата',
                      color:
                      AppTheme.error,
                      onTap: () {
                        Navigator.pop(
                          sheetContext,
                        );

                        _showLeaveDialog();
                      },
                    ),

                  if (room?.type == 'dm')
                    _MenuItem(
                      icon:
                      Icons.cleaning_services_rounded,
                      title:
                      'Очистить переписку',
                      color:
                      AppTheme.error,
                      onTap: () {
                        Navigator.pop(
                          sheetContext,
                        );

                        _showClearDialog();
                      },
                    ),

                  if (room?.type == 'dm')
                    _MenuItem(
                      icon:
                      Icons.delete_forever_rounded,
                      title:
                      'Удалить и закрыть чат',
                      color:
                      AppTheme.error,
                      onTap: () {
                        Navigator.pop(
                          sheetContext,
                        );

                        _showDeleteDMDialog();
                      },
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // LEAVE CHAT
  // ============================================================

  void _showLeaveDialog() {
    showDialog<void>(
      context: context,
      barrierColor:
      Colors.black.withValues(
        alpha: 0.55,
      ),
      builder: (dialogContext) {
        return _ConfirmDialog(
          icon:
          Icons.exit_to_app_rounded,
          title:
          'Выйти из чата?',
          message:
          'Вы перестанете получать сообщения из этого чата.',
          confirmText:
          'Выйти',
          confirmColor:
          AppTheme.error,
          onConfirm: () async {
            Navigator.pop(
              dialogContext,
            );

            try {
              await ref
                  .read(
                roomsProvider.notifier,
              )
                  .leaveRoom(
                widget.code,
              );
            } catch (e) {
              if (!mounted) {
                return;
              }

              ScaffoldMessenger.of(
                context,
              ).showSnackBar(
                SnackBar(
                  content:
                  Text(
                    'Не удалось выйти: $e',
                  ),
                  backgroundColor:
                  AppTheme.error,
                ),
              );

              return;
            }

            if (!mounted) {
              return;
            }

            await LiveActivityService.stop();

            _liveActivityID = null;

            Navigator.popUntil(
              context,
                  (route) => route.isFirst,
            );

            Navigator.pushReplacementNamed(
              context,
              '/rooms',
            );
          },
        );
      },
    );
  }

  // ============================================================
  // CLEAR CHAT
  // ============================================================

  void _showClearDialog() {
    showDialog<void>(
      context: context,
      barrierColor:
      Colors.black.withValues(
        alpha: 0.55,
      ),
      builder: (dialogContext) {
        return _ConfirmDialog(
          icon:
          Icons.cleaning_services_rounded,
          title:
          'Очистить переписку?',
          message:
          'Все сообщения будут удалены безвозвратно.',
          confirmText:
          'Очистить',
          confirmColor:
          AppTheme.error,
          onConfirm: () async {
            Navigator.pop(
              dialogContext,
            );

            try {
              await ref
                  .read(
                chatProvider(
                  widget.code,
                ).notifier,
              )
                  .clearMessages();

              if (!mounted) {
                return;
              }

              _lastHandledMessageId = null;
              _didInitialScroll = false;

              ScaffoldMessenger.of(
                context,
              ).showSnackBar(
                const SnackBar(
                  content:
                  Text(
                    'Переписка очищена',
                  ),
                  backgroundColor:
                  AppTheme.success,
                ),
              );
            } catch (e) {
              if (!mounted) {
                return;
              }

              ScaffoldMessenger.of(
                context,
              ).showSnackBar(
                SnackBar(
                  content:
                  Text(
                    'Не удалось очистить переписку: $e',
                  ),
                  backgroundColor:
                  AppTheme.error,
                ),
              );
            }
          },
        );
      },
    );
  }

  // ============================================================
  // DELETE DM
  // ============================================================

  void _showDeleteDMDialog() {
    showDialog<void>(
      context: context,
      barrierColor:
      Colors.black.withValues(
        alpha: 0.55,
      ),
      builder: (dialogContext) {
        return _ConfirmDialog(
          icon:
          Icons.delete_forever_rounded,
          title:
          'Удалить и закрыть чат?',
          message:
          'Чат будет полностью удалён, включая все сообщения.',
          confirmText:
          'Удалить',
          confirmColor:
          AppTheme.error,
          onConfirm: () async {
            Navigator.pop(
              dialogContext,
            );

            try {
              await ref
                  .read(
                roomsProvider.notifier,
              )
                  .deleteRoom(
                widget.code,
              );
            } catch (e) {
              if (!mounted) {
                return;
              }

              ScaffoldMessenger.of(
                context,
              ).showSnackBar(
                SnackBar(
                  content:
                  Text(
                    'Не удалось удалить чат: $e',
                  ),
                  backgroundColor:
                  AppTheme.error,
                ),
              );

              return;
            }

            if (!mounted) {
              return;
            }

            await LiveActivityService.stop();

            _liveActivityID = null;

            Navigator.popUntil(
              context,
                  (route) => route.isFirst,
            );

            Navigator.pushReplacementNamed(
              context,
              '/rooms',
            );
          },
        );
      },
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    final authState =
    ref.watch(authProvider);

    final chatState =
    ref.watch(
      chatProvider(widget.code),
    );

    ref.listen<ChatState>(
      chatProvider(widget.code),
          (previous, next) {
        _handleMessagesChanged(next);

        _syncLiveActivity(next);
      },
    );

    final currentUser =
        authState.user;

    final room =
        chatState.room;

    final chatName =
        room?.displayName ??
            'Загрузка...';

    final chatAvatar =
        room?.displayAvatar;

    final isDm =
        room?.isDm ?? false;

    final isOnline =
        room?.isOnline ?? false;

    return Scaffold(
      extendBodyBehindAppBar:
      true,
      resizeToAvoidBottomInset:
      true,
      backgroundColor:
      AppTheme.background,

      appBar:
      _buildAppBar(
        chatName:
        chatName,
        chatAvatar:
        chatAvatar,
        isDm:
        isDm,
        isOnline:
        isOnline,
      ),

      body: Stack(
        children: [
          const _AeroBackground(),

          SafeArea(
            bottom: false,
            child: Column(
              children: [
                Expanded(
                  child:
                  _buildMessageArea(
                    chatState:
                    chatState,
                    currentUserId:
                    currentUser?.id,
                  ),
                ),

                MessageInput(
                  controller:
                  _inputController,

                  // ==================================================
                  // SEND MESSAGE
                  // ==================================================

                  onSend: (text) async {
                    try {
                      await ref
                          .read(
                        chatProvider(
                          widget.code,
                        ).notifier,
                      )
                          .sendMessage(
                        text,
                      );

                      await _playSendSound();
                    } catch (e) {
                      debugPrint(
                        '❌ Send message error: $e',
                      );
                    }
                  },

                  // ==================================================
                  // SEND GIF
                  // ==================================================

                  onSendGif: (gifUrl) async {
                    try {
                      await ref
                          .read(
                        chatProvider(
                          widget.code,
                        ).notifier,
                      )
                          .sendGif(
                        gifUrl,
                      );

                      await _playSendSound();
                    } catch (e) {
                      debugPrint(
                        '❌ Send GIF error: $e',
                      );
                    }
                  },

                  // ==================================================
                  // SEND FILE
                  // ==================================================

                  onSendFile: (filePath) async {
                    try {
                      await ref
                          .read(
                        chatProvider(
                          widget.code,
                        ).notifier,
                      )
                          .sendFile(
                        filePath,
                      );

                      await _playSendSound();
                    } catch (e) {
                      debugPrint(
                        '❌ Send file error: $e',
                      );
                    }
                  },

                  roomCode:
                  widget.code,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // APP BAR
  // ============================================================

  PreferredSizeWidget _buildAppBar({
    required String chatName,
    required String? chatAvatar,
    required bool isDm,
    required bool isOnline,
  }) {
    return PreferredSize(
      preferredSize:
      const Size.fromHeight(78),

      child: ClipRect(
        child: BackdropFilter(
          filter:
          ImageFilter.blur(
            sigmaX: 22,
            sigmaY: 22,
          ),

          child: Container(
            decoration:
            BoxDecoration(
              color:
              AppTheme.surface
                  .withValues(
                alpha: 0.76,
              ),

              border:
              Border(
                bottom:
                BorderSide(
                  color:
                  Colors.white
                      .withValues(
                    alpha: 0.08,
                  ),
                ),
              ),
            ),

            child: SafeArea(
              bottom: false,

              child: AppBar(
                elevation: 0,
                scrolledUnderElevation: 0,
                backgroundColor:
                Colors.transparent,
                surfaceTintColor:
                Colors.transparent,

                titleSpacing: 4,

                title: Row(
                  children: [
                    Hero(
                      tag:
                      'chat-avatar-${widget.code}',

                      child:
                      UserAvatar(
                        avatarUrl:
                        chatAvatar,
                        name:
                        chatName,
                        size:
                        44,
                        isOnline:
                        isOnline,
                      ),
                    ),

                    const SizedBox(
                      width: 11,
                    ),

                    Expanded(
                      child:
                      Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        mainAxisSize:
                        MainAxisSize.min,
                        children: [
                          Text(
                            chatName,
                            maxLines: 1,
                            overflow:
                            TextOverflow.ellipsis,
                            style:
                            const TextStyle(
                              color:
                              AppTheme.textPrimary,
                              fontSize:
                              16,
                              fontWeight:
                              FontWeight.w700,
                            ),
                          ),

                          const SizedBox(
                            height: 4,
                          ),

                          Row(
                            children: [
                              if (isDm) ...[
                                AnimatedContainer(
                                  duration:
                                  const Duration(
                                    milliseconds: 250,
                                  ),
                                  width: 7,
                                  height: 7,
                                  margin:
                                  const EdgeInsets.only(
                                    right: 6,
                                  ),
                                  decoration:
                                  BoxDecoration(
                                    color:
                                    isOnline
                                        ? AppTheme.online
                                        : AppTheme.offline,
                                    shape:
                                    BoxShape.circle,
                                  ),
                                ),

                                Text(
                                  isOnline
                                      ? 'В сети'
                                      : 'Не в сети',
                                  style:
                                  TextStyle(
                                    color:
                                    isOnline
                                        ? AppTheme.online
                                        : AppTheme.textMuted,
                                    fontSize:
                                    11,
                                    fontWeight:
                                    FontWeight.w500,
                                  ),
                                ),
                              ] else ...[
                                const Icon(
                                  Icons.groups_rounded,
                                  size: 13,
                                  color:
                                  AppTheme.textMuted,
                                ),

                                const SizedBox(
                                  width: 5,
                                ),

                                const Text(
                                  'Групповой чат',
                                  style:
                                  TextStyle(
                                    color:
                                    AppTheme.textMuted,
                                    fontSize:
                                    11,
                                    fontWeight:
                                    FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                actions: [
                  Padding(
                    padding:
                    const EdgeInsets.only(
                      right: 8,
                    ),

                    child:
                    _GlassIconButton(
                      icon:
                      Icons.more_horiz_rounded,
                      onPressed:
                      _showChatMenu,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // MESSAGE AREA
  // ============================================================

  Widget _buildMessageArea({
    required ChatState chatState,
    required int? currentUserId,
  }) {
    if (chatState.isLoading &&
        chatState.messages.isEmpty) {
      return const Center(
        child:
        _GlassLoading(),
      );
    }

    if (chatState.error != null &&
        chatState.messages.isEmpty) {
      return _ErrorState(
        message:
        chatState.error!,
        onRetry: () {
          ref
              .read(
            chatProvider(
              widget.code,
            ).notifier,
          )
              .loadMessages();
        },
      );
    }

    if (chatState.messages.isEmpty) {
      return const _EmptyChatState();
    }

    return ListView.builder(
      controller:
      _scrollController,

      physics:
      const BouncingScrollPhysics(),

      padding:
      const EdgeInsets.fromLTRB(
        12,
        96,
        12,
        20,
      ),

      itemCount:
      chatState.messages.length,

      itemBuilder:
          (
          context,
          index,
          ) {
        final message =
        chatState.messages[index];

        final isMyMessage =
            message.userId ==
                currentUserId;

        return Padding(
          padding:
          const EdgeInsets.only(
            bottom: 6,
          ),

          child:
          MessageBubble(
            message:
            message,

            isMy:
            isMyMessage,

            onEdit:
                (newText) {
              ref
                  .read(
                chatProvider(
                  widget.code,
                ).notifier,
              )
                  .editMessage(
                message.id,
                newText,
              );
            },

            onDelete: () {
              ref
                  .read(
                chatProvider(
                  widget.code,
                ).notifier,
              )
                  .deleteMessage(
                message.id,
              );
            },

            onReaction:
                (reaction) {
              ref
                  .read(
                chatProvider(
                  widget.code,
                ).notifier,
              )
                  .toggleReaction(
                message.id,
                reaction,
              );
            },
          ),
        );
      },
    );
  }
}

// ============================================================
// AERO BACKGROUND
// ============================================================

class _AeroBackground
    extends StatelessWidget {
  const _AeroBackground();

  @override
  Widget build(
      BuildContext context,
      ) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: 100,
            left: -100,
            child:
            _GlowOrb(
              size: 240,
              color:
              AppTheme.primary,
              opacity:
              0.055,
            ),
          ),

          Positioned(
            top: 420,
            right: -130,
            child:
            _GlowOrb(
              size: 300,
              color:
              Colors.white,
              opacity:
              0.025,
            ),
          ),

          Positioned(
            bottom: -140,
            left: 40,
            child:
            _GlowOrb(
              size: 280,
              color:
              AppTheme.primary,
              opacity:
              0.035,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowOrb
    extends StatelessWidget {
  final double size;
  final Color color;
  final double opacity;

  const _GlowOrb({
    required this.size,
    required this.color,
    required this.opacity,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return ImageFiltered(
      imageFilter:
      ImageFilter.blur(
        sigmaX: 55,
        sigmaY: 55,
      ),

      child: Container(
        width: size,
        height: size,

        decoration:
        BoxDecoration(
          color:
          color.withValues(
            alpha: opacity,
          ),
          shape:
          BoxShape.circle,
        ),
      ),
    );
  }
}

// ============================================================
// GLASS BOTTOM SHEET
// ============================================================

class _GlassBottomSheet
    extends StatelessWidget {
  final Widget child;

  const _GlassBottomSheet({
    required this.child,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return ClipRRect(
      borderRadius:
      const BorderRadius.vertical(
        top:
        Radius.circular(30),
      ),

      child:
      BackdropFilter(
        filter:
        ImageFilter.blur(
          sigmaX: 25,
          sigmaY: 25,
        ),

        child: Container(
          decoration:
          BoxDecoration(
            color:
            AppTheme.surface
                .withValues(
              alpha: 0.82,
            ),

            border:
            Border(
              top:
              BorderSide(
                color:
                Colors.white
                    .withValues(
                  alpha: 0.10,
                ),
              ),
            ),
          ),

          child:
          child,
        ),
      ),
    );
  }
}

// ============================================================
// GLASS ICON BUTTON
// ============================================================

class _GlassIconButton
    extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _GlassIconButton({
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return ClipRRect(
      borderRadius:
      BorderRadius.circular(
        15,
      ),

      child:
      BackdropFilter(
        filter:
        ImageFilter.blur(
          sigmaX: 12,
          sigmaY: 12,
        ),

        child: Material(
          color:
          Colors.white
              .withValues(
            alpha: 0.07,
          ),

          child:
          InkWell(
            onTap:
            onPressed,

            borderRadius:
            BorderRadius.circular(
              15,
            ),

            child:
            const SizedBox(
              width: 44,
              height: 44,

              child:
              Icon(
                Icons.more_horiz_rounded,
                color:
                AppTheme.textPrimary,
                size:
                24,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// MENU ITEM
// ============================================================

class _MenuItem
    extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Padding(
      padding:
      const EdgeInsets.symmetric(
        vertical: 4,
      ),

      child:
      ClipRRect(
        borderRadius:
        BorderRadius.circular(
          18,
        ),

        child: Material(
          color:
          Colors.white
              .withValues(
            alpha: 0.045,
          ),

          child:
          InkWell(
            onTap:
            onTap,

            borderRadius:
            BorderRadius.circular(
              18,
            ),

            child:
            Padding(
              padding:
              const EdgeInsets.all(
                10,
              ),

              child:
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,

                    decoration:
                    BoxDecoration(
                      color:
                      color.withValues(
                        alpha: 0.12,
                      ),

                      borderRadius:
                      BorderRadius.circular(
                        14,
                      ),

                      border:
                      Border.all(
                        color:
                        color.withValues(
                          alpha: 0.10,
                        ),
                      ),
                    ),

                    child:
                    Icon(
                      icon,
                      color:
                      color,
                      size:
                      22,
                    ),
                  ),

                  const SizedBox(
                    width: 14,
                  ),

                  Expanded(
                    child:
                    Text(
                      title,
                      style:
                      TextStyle(
                        color:
                        color,
                        fontSize:
                        15,
                        fontWeight:
                        FontWeight.w600,
                      ),
                    ),
                  ),

                  Icon(
                    Icons
                        .chevron_right_rounded,
                    color:
                    color.withValues(
                      alpha: 0.45,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// CONFIRM DIALOG
// ============================================================

class _ConfirmDialog
    extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String confirmText;
  final Color confirmColor;
  final VoidCallback onConfirm;

  const _ConfirmDialog({
    required this.icon,
    required this.title,
    required this.message,
    required this.confirmText,
    required this.confirmColor,
    required this.onConfirm,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Dialog(
      backgroundColor:
      Colors.transparent,

      insetPadding:
      const EdgeInsets.symmetric(
        horizontal: 24,
      ),

      child:
      ClipRRect(
        borderRadius:
        BorderRadius.circular(
          28,
        ),

        child:
        BackdropFilter(
          filter:
          ImageFilter.blur(
            sigmaX: 25,
            sigmaY: 25,
          ),

          child: Container(
            padding:
            const EdgeInsets.all(
              22,
            ),

            decoration:
            BoxDecoration(
              color:
              AppTheme.surface
                  .withValues(
                alpha: 0.88,
              ),

              borderRadius:
              BorderRadius.circular(
                28,
              ),

              border:
              Border.all(
                color:
                Colors.white
                    .withValues(
                  alpha: 0.10,
                ),
              ),

              boxShadow: [
                BoxShadow(
                  color:
                  Colors.black
                      .withValues(
                    alpha: 0.35,
                  ),
                  blurRadius:
                  40,
                  spreadRadius:
                  2,
                ),
              ],
            ),

            child:
            Column(
              mainAxisSize:
              MainAxisSize.min,

              children: [
                Container(
                  width: 64,
                  height: 64,

                  decoration:
                  BoxDecoration(
                    color:
                    confirmColor
                        .withValues(
                      alpha: 0.12,
                    ),

                    shape:
                    BoxShape.circle,

                    border:
                    Border.all(
                      color:
                      confirmColor
                          .withValues(
                        alpha: 0.12,
                      ),
                    ),
                  ),

                  child:
                  Icon(
                    icon,
                    color:
                    confirmColor,
                    size:
                    30,
                  ),
                ),

                const SizedBox(
                  height: 18,
                ),

                Text(
                  title,
                  textAlign:
                  TextAlign.center,

                  style:
                  const TextStyle(
                    color:
                    AppTheme.textPrimary,
                    fontSize:
                    19,
                    fontWeight:
                    FontWeight.w700,
                  ),
                ),

                const SizedBox(
                  height: 10,
                ),

                Text(
                  message,
                  textAlign:
                  TextAlign.center,

                  style:
                  const TextStyle(
                    color:
                    AppTheme.textSecondary,
                    fontSize:
                    14,
                    height:
                    1.45,
                  ),
                ),

                const SizedBox(
                  height: 22,
                ),

                Row(
                  children: [
                    Expanded(
                      child:
                      _DialogButton(
                        text:
                        'Отмена',
                        onPressed: () {
                          Navigator.pop(
                            context,
                          );
                        },
                      ),
                    ),

                    const SizedBox(
                      width: 10,
                    ),

                    Expanded(
                      child:
                      _DialogButton(
                        text:
                        confirmText,
                        color:
                        confirmColor,
                        onPressed:
                        onConfirm,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// DIALOG BUTTON
// ============================================================

class _DialogButton
    extends StatelessWidget {
  final String text;
  final Color? color;
  final VoidCallback onPressed;

  const _DialogButton({
    required this.text,
    required this.onPressed,
    this.color,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    final buttonColor =
        color ?? Colors.white;

    return ClipRRect(
      borderRadius:
      BorderRadius.circular(
        15,
      ),

      child:
      Material(
        color:
        color != null
            ? color!.withValues(
          alpha: 0.14,
        )
            : Colors.white
            .withValues(
          alpha: 0.06,
        ),

        child:
        InkWell(
          onTap:
          onPressed,

          child:
          SizedBox(
            height: 48,

            child:
            Center(
              child:
              Text(
                text,

                style:
                TextStyle(
                  color:
                  buttonColor,
                  fontSize:
                  14,
                  fontWeight:
                  FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// LOADING
// ============================================================

class _GlassLoading
    extends StatelessWidget {
  const _GlassLoading();

  @override
  Widget build(
      BuildContext context,
      ) {
    return ClipRRect(
      borderRadius:
      BorderRadius.circular(
        22,
      ),

      child:
      BackdropFilter(
        filter:
        ImageFilter.blur(
          sigmaX: 15,
          sigmaY: 15,
        ),

        child: Container(
          width: 72,
          height: 72,

          decoration:
          BoxDecoration(
            color:
            Colors.white
                .withValues(
              alpha: 0.06,
            ),

            borderRadius:
            BorderRadius.circular(
              22,
            ),

            border:
            Border.all(
              color:
              Colors.white
                  .withValues(
                alpha: 0.08,
              ),
            ),
          ),

          child:
          const Center(
            child:
            SizedBox(
              width: 26,
              height: 26,

              child:
              CircularProgressIndicator(
                strokeWidth:
                2.5,
                color:
                AppTheme.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// EMPTY CHAT
// ============================================================

class _EmptyChatState
    extends StatelessWidget {
  const _EmptyChatState();

  @override
  Widget build(
      BuildContext context,
      ) {
    return Center(
      child:
      SingleChildScrollView(
        padding:
        const EdgeInsets.symmetric(
          horizontal: 32,
          vertical: 100,
        ),

        child:
        Column(
          mainAxisAlignment:
          MainAxisAlignment.center,

          children: [
            ClipRRect(
              borderRadius:
              BorderRadius.circular(
                30,
              ),

              child:
              BackdropFilter(
                filter:
                ImageFilter.blur(
                  sigmaX: 15,
                  sigmaY: 15,
                ),

                child:
                Container(
                  width: 96,
                  height: 96,

                  decoration:
                  BoxDecoration(
                    color:
                    AppTheme.primary
                        .withValues(
                      alpha: 0.08,
                    ),

                    shape:
                    BoxShape.circle,

                    border:
                    Border.all(
                      color:
                      AppTheme.primary
                          .withValues(
                        alpha: 0.12,
                      ),
                    ),

                    boxShadow: [
                      BoxShadow(
                        color:
                        AppTheme.primary
                            .withValues(
                          alpha: 0.08,
                        ),
                        blurRadius:
                        30,
                      ),
                    ],
                  ),

                  child:
                  const Icon(
                    Icons
                        .chat_bubble_outline_rounded,
                    size:
                    42,
                    color:
                    AppTheme.primary,
                  ),
                ),
              ),
            ),

            const SizedBox(
              height: 26,
            ),

            const Text(
              'Пока здесь тихо',
              textAlign:
              TextAlign.center,

              style:
              TextStyle(
                color:
                AppTheme.textPrimary,
                fontSize:
                21,
                fontWeight:
                FontWeight.w700,
              ),
            ),

            const SizedBox(
              height: 9,
            ),

            const Text(
              'Напишите первое сообщение\n'
                  'и начните общение 🐻',
              textAlign:
              TextAlign.center,

              style:
              TextStyle(
                color:
                AppTheme.textMuted,
                fontSize:
                14,
                height:
                1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// ERROR
// ============================================================

class _ErrorState
    extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Center(
      child:
      SingleChildScrollView(
        padding:
        const EdgeInsets.all(
          32,
        ),

        child:
        Column(
          mainAxisAlignment:
          MainAxisAlignment.center,

          children: [
            ClipRRect(
              borderRadius:
              BorderRadius.circular(
                26,
              ),

              child:
              BackdropFilter(
                filter:
                ImageFilter.blur(
                  sigmaX: 15,
                  sigmaY: 15,
                ),

                child:
                Container(
                  width: 82,
                  height: 82,

                  decoration:
                  BoxDecoration(
                    color:
                    AppTheme.error
                        .withValues(
                      alpha: 0.09,
                    ),

                    shape:
                    BoxShape.circle,

                    border:
                    Border.all(
                      color:
                      AppTheme.error
                          .withValues(
                        alpha: 0.12,
                      ),
                    ),
                  ),

                  child:
                  const Icon(
                    Icons
                        .cloud_off_rounded,
                    size:
                    38,
                    color:
                    AppTheme.error,
                  ),
                ),
              ),
            ),

            const SizedBox(
              height: 22,
            ),

            const Text(
              'Не удалось загрузить чат',
              textAlign:
              TextAlign.center,

              style:
              TextStyle(
                color:
                AppTheme.textPrimary,
                fontSize:
                18,
                fontWeight:
                FontWeight.w700,
              ),
            ),

            const SizedBox(
              height: 9,
            ),

            Text(
              message,
              textAlign:
              TextAlign.center,

              style:
              const TextStyle(
                color:
                AppTheme.textMuted,
                fontSize:
                13,
                height:
                1.4,
              ),
            ),

            const SizedBox(
              height: 22,
            ),

            ClipRRect(
              borderRadius:
              BorderRadius.circular(
                16,
              ),

              child:
              Material(
                color:
                AppTheme.primary
                    .withValues(
                  alpha: 0.12,
                ),

                child:
                InkWell(
                  onTap:
                  onRetry,

                  child:
                  Padding(
                    padding:
                    const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 13,
                    ),

                    child:
                    Row(
                      mainAxisSize:
                      MainAxisSize.min,

                      children: const [
                        Icon(
                          Icons
                              .refresh_rounded,
                          color:
                          AppTheme.primary,
                          size:
                          20,
                        ),

                        SizedBox(
                          width: 8,
                        ),

                        Text(
                          'Повторить',
                          style:
                          TextStyle(
                            color:
                            AppTheme.primary,
                            fontWeight:
                            FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}