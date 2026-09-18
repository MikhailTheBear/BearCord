// lib/features/rooms/screens/rooms_screen.dart

import 'dart:ui';
import '../../../core/api/websocket_service.dart';
import 'package:bearcord/features/profile/screens/edit_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import '../../../config/app_theme.dart';
import '../../../core/providers/auth_provider.dart';
import '../providers/rooms_provider.dart';
import '../widgets/room_item.dart';

import '../../../core/services/live_activity_service.dart';
import '../../../core/services/update_service.dart';
class RoomsScreen extends ConsumerStatefulWidget {
  const RoomsScreen({super.key});

  @override
  ConsumerState<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends ConsumerState<RoomsScreen> {
  final TextEditingController _roomCodeController =
  TextEditingController();

  final TextEditingController _dmTargetController =
  TextEditingController();


  final WebSocketService _webSocketService = WebSocketService();


  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final notifier = ref.read(roomsProvider.notifier);

      // Первичная загрузка — может показать экран загрузки
      notifier.loadRooms();

      // После входа на экран запускаем polling
      notifier.startPolling();

      _webSocketService.connect(
        userId: 1,
        onEvent: (event) {
          switch (event['type']) {
            case 'new_message':
            case 'room_added':
            case 'room_removed':
              notifier.loadRooms();
              break;
          }
        },
      );

      UpdateService.checkForUpdate(context);
    });
  }

  @override
  void dispose() {
    ref.read(roomsProvider.notifier).stopPolling();
    _webSocketService.dispose();
    _roomCodeController.dispose();
    _dmTargetController.dispose();

    super.dispose();
  }



  Future<void> _testLiveActivity() async {
    final supported = await LiveActivityService.isSupported();

    if (!supported) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Live Activities недоступны'),
        ),
      );
      return;
    }

    final id = await LiveActivityService.start(
      chatID: 'test_chat',
      chatName: 'Тестовый чат',
      senderName: 'Михаил',
      message: '🔥 Тестовая Live Activity',
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          id != null
              ? '🏝️ Live Activity запущена!'
              : '❌ Не удалось запустить',
        ),
      ),
    );
  }

// ============================================================
// PROFILE
// ============================================================

  void _showProfileMenu() {
    final user = ref.read(authProvider).user;

    if (user == null) return;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      isScrollControlled: true,
      builder: (sheetContext) {
        return _GlassBottomSheet(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
// Handle


                  const SizedBox(height: 24),

                  CircleAvatar(
                    radius: 38,
                    backgroundColor: AppTheme.surfaceLight,
                    backgroundImage: user.avatar != null
                        ? NetworkImage(user.displayAvatar)
                        : null,
                    onBackgroundImageError: (_, __) {},
                    child: user.avatar == null
                        ? Text(
                      user.displayName.isNotEmpty
                          ? user.displayName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                        : null,
                  ),

                  const SizedBox(height: 12),

                  Text(
                    user.displayName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  const SizedBox(height: 3),

                  Text(
                    '@${user.login}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                    ),
                  ),

                  const SizedBox(height: 22),

                  _GlassMenuButton(
                    icon: Icons.person_outline_rounded,
                    title: 'Редактировать профиль',
                    onTap: () {
                      Navigator.pop(sheetContext);

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const EditProfileScreen(),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 10),

                  _GlassMenuButton(
                    icon: Icons.logout_rounded,
                    title: 'Выйти',
                    color: AppTheme.error,
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _showLogoutDialog();
                    },
                  ),

                  const SizedBox(height: 10),

                  _GlassMenuButton(
                    icon: Icons.close_rounded,
                    title: 'Отмена',
                    color: AppTheme.textSecondary,
                    onTap: () {
                      Navigator.pop(sheetContext);
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
// LOGOUT
// ============================================================

  void _showLogoutDialog() {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (dialogContext) {
        return _GlassDialog(
          icon: Icons.logout_rounded,
          iconColor: AppTheme.error,
          title: 'Выйти из аккаунта?',
          message:
          'После выхода потребуется снова войти в BearCord.',
          actions: [
            Expanded(
              child: _DialogButton(
                title: 'Отмена',
                onTap: () {
                  Navigator.pop(dialogContext);
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _DialogButton(
                title: 'Выйти',
                color: AppTheme.error,
                filled: true,
                onTap: () async {
                  Navigator.pop(dialogContext);

                  await ref
                      .read(authProvider.notifier)
                      .logout();

                  if (!mounted) return;

                  Navigator.pushReplacementNamed(
                    context,
                    '/login',
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

// ============================================================
// CREATE ROOM
// ============================================================

  void _showCreateRoomDialog() {
    _roomCodeController.clear();

    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (dialogContext) {
        return _GlassDialog(
          icon: Icons.add_circle_outline_rounded,
          title: 'Создать комнату',
          message:
          'Можно указать собственный код или оставить поле пустым.',
          content: _GlassTextField(
            controller: _roomCodeController,
            label: 'Код комнаты',
            hint: 'например: myroom',
            icon: Icons.tag_rounded,
          ),
          actions: [
            Expanded(
              child: _DialogButton(
                title: 'Отмена',
                onTap: () {
                  Navigator.pop(dialogContext);
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _DialogButton(
                title: 'Создать',
                color: AppTheme.primary,
                filled: true,
                onTap: () async {
                  final code =
                  _roomCodeController.text.trim();

                  final roomCode = code.isEmpty
                      ? DateTime.now()
                      .millisecondsSinceEpoch
                      .toString()
                      .substring(6)
                      : code;

                  await ref
                      .read(roomsProvider.notifier)
                      .createRoom(roomCode);

                  _roomCodeController.clear();

                  if (!mounted) return;

                  Navigator.pop(dialogContext);
                },
              ),
            ),
          ],
        );
      },
    );
  }

// ============================================================
// JOIN ROOM
// ============================================================

  void _showJoinRoomDialog() {
    _roomCodeController.clear();

    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (dialogContext) {
        return _GlassDialog(
          icon: Icons.login_rounded,
          title: 'Присоединиться',
          message:
          'Введите код комнаты, чтобы присоединиться.',
          content: _GlassTextField(
            controller: _roomCodeController,
            label: 'Код комнаты',
            hint: 'например: myroom',
            icon: Icons.tag_rounded,
          ),
          actions: [
            Expanded(
              child: _DialogButton(
                title: 'Отмена',
                onTap: () {
                  Navigator.pop(dialogContext);
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _DialogButton(
                title: 'Войти',
                color: AppTheme.primary,
                filled: true,
                onTap: () async {
                  final code =
                  _roomCodeController.text.trim();

                  if (code.isEmpty) {
                    return;
                  }

                  await ref
                      .read(roomsProvider.notifier)
                      .joinRoom(code);

                  _roomCodeController.clear();

                  if (!mounted) return;

                  Navigator.pop(dialogContext);
                },
              ),
            ),
          ],
        );
      },
    );
  }

// ============================================================
// CREATE DM
// ============================================================

  void _showCreateDMDialog() {
    _dmTargetController.clear();

    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (dialogContext) {
        return _GlassDialog(
          icon: Icons.chat_bubble_outline_rounded,
          title: 'Новое сообщение',
          message:
          'Введите логин пользователя, которому хотите написать.',
          content: _GlassTextField(
            controller: _dmTargetController,
            label: 'Логин пользователя',
            hint: 'например: john',
            icon: Icons.person_outline_rounded,
          ),
          actions: [
            Expanded(
              child: _DialogButton(
                title: 'Отмена',
                onTap: () {
                  Navigator.pop(dialogContext);
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _DialogButton(
                title: 'Написать',
                color: AppTheme.primary,
                filled: true,
                onTap: () async {
                  final target =
                  _dmTargetController.text.trim();

                  if (target.isEmpty) {
                    return;
                  }

                  try {
                    final userId = await ref
                        .read(roomsProvider.notifier)
                        .getUserIdByLogin(target);

                    if (userId == null) {
                      if (!mounted) return;

                      ScaffoldMessenger.of(context)
                          .showSnackBar(
                        SnackBar(
                          content: Text(
                            'Пользователь "$target" не найден',
                          ),
                          backgroundColor: AppTheme.error,
                        ),
                      );

                      return;
                    }

                    await ref
                        .read(roomsProvider.notifier)
                        .createDMRoom(userId);

                    _dmTargetController.clear();

                    if (!mounted) return;

                    Navigator.pop(dialogContext);

                    ScaffoldMessenger.of(context)
                        .showSnackBar(
                      const SnackBar(
                        content: Text('Личный чат создан'),
                        backgroundColor: AppTheme.success,
                      ),
                    );
                  } catch (e) {
                    if (!mounted) return;

                    ScaffoldMessenger.of(context)
                        .showSnackBar(
                      SnackBar(
                        content: Text(
                          'Ошибка: $e',
                        ),
                        backgroundColor: AppTheme.error,
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        );
      },
    );
  }

// ============================================================
// BUILD
// ============================================================

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final roomsState = ref.watch(roomsProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(authState),
      body: Stack(
        children: [
          const _AmbientBackground(),
          SafeArea(
            bottom: false,
            child: roomsState.isLoading
                ? const Center(
              child: _LoadingIndicator(),
            )
                : roomsState.error != null
                ? _buildErrorState(roomsState.error!)
                : roomsState.rooms.isEmpty
                ? _buildEmptyState()
                : _buildRoomsList(roomsState),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(
        showButtons: roomsState.rooms.isNotEmpty,
      ),
    );
  }

// ============================================================
// APP BAR
// ============================================================

  PreferredSizeWidget _buildAppBar(
      AuthState authState,
      ) {
    return AppBar(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleSpacing: 20,
      toolbarHeight: 76,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.65),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 9),
              const Text(
                'BearCord',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.7,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          const Text(
            'Твои чаты в одном месте',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      actions: [
        if (authState.user != null)
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: _showProfileMenu,
              child: _GlassAvatar(user: authState.user!),
            ),
          ),
      ],
    );
  }

// ============================================================
// ROOMS
// ============================================================

  Widget _buildRoomsList(
      dynamic roomsState,
      ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth < 360 ? 14.0 : 18.0;

        return ListView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            12,
            horizontalPadding,
            122,
          ),
          children: [
            _RoomsHeader(count: roomsState.rooms.length),
            const SizedBox(height: 18),

            _GlassContainer(
              borderRadius: 22,
              padding: EdgeInsets.zero,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var index = 0; index < roomsState.rooms.length; index++) ...[
                    if (index > 0)
                      Padding(
                        padding: const EdgeInsets.only(left: 18),
                        child: Container(
                          height: 1,
                          color: Colors.white.withValues(alpha: 0.075),
                        ),
                      ),

                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: RoomItem(
                        room: roomsState.rooms[index],
                        onTap: () {
                          final room = roomsState.rooms[index];
                          Navigator.pushNamed(
                            context,
                            '/chat',
                            arguments: room.code,
                          );
                        },
                      ),
                    ),
                  ],],
              ),
            ),
          ],
        );
      },
    );
  }

// ============================================================
// EMPTY
// ============================================================

  Widget _buildEmptyState() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 380;

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            compact ? 20 : 28,
            30,
            compact ? 20 : 28,
            130,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight:
              constraints.maxHeight - 160,
            ),
            child: Center(
              child: Column(
                mainAxisAlignment:
                MainAxisAlignment.center,
                children: [
                  _HeroIcon(
                    icon: Icons.forum_rounded,
                    size: compact ? 78 : 94,
                  ),

                  SizedBox(
                    height: compact ? 18 : 24,
                  ),

                  const Text(
                    'Готовы к новому чату?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.6,
                    ),
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    'Создай пространство для друзей\n'
                        'или начни личный диалог.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 28),

                  _buildResponsiveActions(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

// ============================================================
// ERROR
// ============================================================

  Widget _buildErrorState(
      String error,
      ) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _GlassIcon(
              icon: Icons.cloud_off_rounded,
              size: 78,
              color: AppTheme.error,
            ),

            const SizedBox(height: 20),

            const Text(
              'Не удалось загрузить чаты',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 19,
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),

            const SizedBox(height: 22),

            _DialogButton(
              title: 'Повторить',
              color: AppTheme.primary,
              filled: true,
              onTap: () {
                ref
                    .read(roomsProvider.notifier)
                    .loadRooms();
              },
            ),
          ],
        ),
      ),
    );
  }

// ============================================================
// BOTTOM BAR
// ============================================================

  Widget _buildBottomBar({
    required bool showButtons,
  }) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 30,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: _GlassContainer(
          borderRadius: 28,
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
          child: Row(
            children: [
              Expanded(
                child: _BottomAction(
                  icon: Icons.add_rounded,
                  label: 'Создать',
                  onTap: _showCreateRoomDialog,
                ),
              ),
              Expanded(
                child: _BottomAction(
                  icon: Icons.login_rounded,
                  label: 'Войти',
                  onTap: _showJoinRoomDialog,
                ),
              ),
              Expanded(
                child: _BottomAction(
                  icon: Icons.chat_bubble_rounded,
                  label: 'DM',
                  onTap: _showCreateDMDialog,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

// ============================================================
// RESPONSIVE ACTIONS
// ============================================================

  Widget _buildResponsiveActions() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 330) {
          return Column(
            children: [
              _LargeAction(
                icon: Icons.add_rounded,
                title: 'Создать комнату',
                onTap: _showCreateRoomDialog,
              ),
              const SizedBox(height: 10),
              _LargeAction(
                icon: Icons.login_rounded,
                title: 'Присоединиться',
                onTap: _showJoinRoomDialog,
              ),
              const SizedBox(height: 10),
              _LargeAction(
                icon: Icons.chat_bubble_outline_rounded,
                title: 'Написать сообщение',
                onTap: _showCreateDMDialog,
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(
              child: _LargeAction(
                icon: Icons.add_rounded,
                title: 'Создать',
                onTap: _showCreateRoomDialog,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _LargeAction(
                icon: Icons.login_rounded,
                title: 'Войти',
                onTap: _showJoinRoomDialog,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _LargeAction(
                icon: Icons.chat_bubble_outline_rounded,
                title: 'DM',
                onTap: _showCreateDMDialog,
              ),
            ),
          ],
        );
      },
    );
  }

}
class _AmbientBackground extends StatelessWidget {
  const _AmbientBackground();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -120,
            right: -100,
            child: _GlowOrb(
              size: 320,
              color: AppTheme.primary.withValues(alpha: 0.11),
            ),
          ),
          Positioned(
            top: 260,
            left: -180,
            child: _GlowOrb(
              size: 300,
              color: AppTheme.primary.withValues(alpha: 0.045),
            ),
          ),
          Positioned(
            bottom: -170,
            right: -100,
            child: _GlowOrb(
              size: 320,
              color: Colors.white.withValues(alpha: 0.018),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowOrb({
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 65, sigmaY: 65),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
        ),
      ),
    );
  }
}

class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        shape: BoxShape.circle,
        border: Border.all(
          color: AppTheme.primary.withValues(alpha: 0.20),
        ),
      ),
      child: const Padding(
        padding: EdgeInsets.all(19),
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: AppTheme.primary,
        ),
      ),
    );
  }
}

class _HeroIcon extends StatelessWidget {
  final IconData icon;
  final double size;

  const _HeroIcon({
    required this.icon,
    this.size = 90,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            AppTheme.primary.withValues(alpha: 0.22),
            AppTheme.primary.withValues(alpha: 0.035),
          ],
        ),
        border: Border.all(
          color: AppTheme.primary.withValues(alpha: 0.20),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.14),
            blurRadius: 45,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Icon(
        icon,
        color: AppTheme.primary,
        size: size * 0.40,
      ),
    );
  }
}

// ================================================================
// GLASS CONTAINER

// ================================================================

class _GlassContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;

  const _GlassContainer({
    required this.child,
    this.borderRadius = 20,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(
        borderRadius,
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 22,
          sigmaY: 22,
        ),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(
              alpha: 0.055,
            ),
            borderRadius: BorderRadius.circular(
              borderRadius,
            ),
            border: Border.all(
              color: Colors.white.withValues(
                alpha: 0.10,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: 0.25,
                ),
                blurRadius: 25,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

// ================================================================
// GLASS ROOM
// ================================================================

class _GlassRoomCard extends StatelessWidget {
  final Widget child;

  const _GlassRoomCard({
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.035),
            blurRadius: 24,
            spreadRadius: -4,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 3,
                color: AppTheme.primary.withValues(alpha: 0.75),
              ),
            ),
            _GlassContainer(
              borderRadius: 22,
              padding: EdgeInsets.zero,
              child: Material(
                color: Colors.transparent,
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// GLASS AVATAR
// ================================================================

class _GlassAvatar extends StatelessWidget {
  final dynamic user;

  const _GlassAvatar({
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(
          alpha: 0.08,
        ),
        border: Border.all(
          color: AppTheme.primary.withValues(
            alpha: 0.35,
          ),
        ),
      ),
      child: CircleAvatar(
        backgroundColor: AppTheme.surfaceLight,
        backgroundImage: user.avatar != null
            ? NetworkImage(user.displayAvatar)
            : null,
        child: user.avatar == null
            ? Text(
          user.displayName.isNotEmpty
              ? user.displayName[0]
              .toUpperCase()
              : '?',
          style: const TextStyle(
            color: AppTheme.primary,
            fontWeight: FontWeight.w700,
          ),
        )
            : null,
      ),
    );
  }
}

// ================================================================
// GLASS ICON
// ================================================================

class _GlassIcon extends StatelessWidget {
  final IconData icon;
  final double size;
  final Color color;

  const _GlassIcon({
    required this.icon,
    this.size = 80,
    this.color = AppTheme.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(
          alpha: 0.10,
        ),
        border: Border.all(
          color: color.withValues(
            alpha: 0.20,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(
              alpha: 0.10,
            ),
            blurRadius: 30,
          ),
        ],
      ),
      child: Icon(
        icon,
        color: color,
        size: size * 0.46,
      ),
    );
  }
}

// ================================================================
// BOTTOM ACTION
// ================================================================

class _BottomAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _BottomAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        splashColor: AppTheme.primary.withValues(alpha: 0.12),
        highlightColor: AppTheme.primary.withValues(alpha: 0.06),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: AppTheme.primary,
                  size: 19,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================================================================
// // ================================================================
// LARGE ACTION
// ================================================================

class _LargeAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _LargeAction({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassContainer(
      borderRadius: 20,
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          splashColor: AppTheme.primary.withValues(alpha: 0.10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.11),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    icon,
                    color: AppTheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 9),
                Flexible(
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
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
// ROOMS HEADER
// ============================================================

class _RoomsHeader extends StatelessWidget {
  final int count;

  const _RoomsHeader({required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Твои пространства',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Выбери чат и продолжай общение',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.primary.withValues(alpha: 0.18),
            ),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              color: AppTheme.primary,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

// ================================================================
}
// GLASS MENU BUTTON
// ================================================================

class _GlassMenuButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  const _GlassMenuButton({
    required this.icon,
    required this.title,
    required this.onTap,
    this.color = AppTheme.primary,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassContainer(
      borderRadius: 16,
      padding: EdgeInsets.zero,
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withValues(
              alpha: 0.10,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: color,
            size: 21,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ================================================================
// GLASS TEXT FIELD
// ================================================================

class _GlassTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;

  const _GlassTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autocorrect: false,
      style: const TextStyle(
        color: AppTheme.textPrimary,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(
          icon,
          color: AppTheme.primary,
        ),
      ),
    );
  }
}

// ================================================================
// GLASS DIALOG
// ================================================================

class _GlassDialog extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final Widget? content;
  final List<Widget> actions;

  const _GlassDialog({
    required this.icon,
    this.iconColor = AppTheme.primary,
    required this.title,
    required this.message,
    this.content,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 24,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 25,
            sigmaY: 25,
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.surface.withValues(
                alpha: 0.88,
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Colors.white.withValues(
                  alpha: 0.12,
                ),
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: iconColor.withValues(
                            alpha: 0.12,
                          ),
                          borderRadius:
                          BorderRadius.circular(14),
                        ),
                        child: Icon(
                          icon,
                          color: iconColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Text(
                    message,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),

                  if (content != null) ...[
                    const SizedBox(height: 18),
                    content!,
                  ],

                  const SizedBox(height: 20),

                  Row(
                    children: actions,
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

// ================================================================
// DIALOG BUTTON
// ================================================================

class _DialogButton extends StatelessWidget {
  final String title;
  final Color color;
  final bool filled;
  final VoidCallback onTap;

  const _DialogButton({
    required this.title,
    required this.onTap,
    this.color = AppTheme.textSecondary,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: Material(
        color: filled
            ? color
            : Colors.white.withValues(
          alpha: 0.06,
        ),
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                color: filled
                    ? Colors.black
                    : color,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ================================================================
// GLASS BOTTOM SHEET
// ================================================================

class _GlassBottomSheet extends StatelessWidget {
  final Widget child;

  const _GlassBottomSheet({
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(30),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 25,
          sigmaY: 25,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.surface.withValues(
              alpha: 0.92,
            ),
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(
                  alpha: 0.12,
                ),
              ),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}