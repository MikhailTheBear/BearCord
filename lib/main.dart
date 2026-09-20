// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/app_theme.dart';
import 'core/providers/auth_provider.dart';
import 'core/services/deep_link_service.dart';

import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/register_screen.dart';
import 'features/auth/screens/service_auth_screen.dart';

import 'features/rooms/screens/rooms_screen.dart';
import 'features/chat/screens/chat_screen.dart';

// ============================================================
// GLOBAL KEYS
// ============================================================

// Глобальный ключ для показа SnackBar из любого экрана
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
GlobalKey<ScaffoldMessengerState>();

// Глобальный ключ Navigator
final GlobalKey<NavigatorState> navigatorKey =
GlobalKey<NavigatorState>();

// ============================================================
// MAIN
// ============================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    const ProviderScope(
      child: BearCordApp(),
    ),
  );
}

// ============================================================
// APP
// ============================================================

class BearCordApp extends ConsumerStatefulWidget {
  const BearCordApp({super.key});

  @override
  ConsumerState<BearCordApp> createState() => _BearCordAppState();
}

// ============================================================
// APP STATE
// ============================================================

class _BearCordAppState extends ConsumerState<BearCordApp> {
  late final DeepLinkService _deepLinkService;

  @override
  void initState() {
    super.initState();

    _deepLinkService = DeepLinkService(
      navigatorKey: navigatorKey,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initDeepLinks();
    });
  }

  // ============================================================
  // INIT DEEP LINKS
  // ============================================================

  Future<void> _initDeepLinks() async {
    _deepLinkService.onAuthRequest = _handleServiceAuth;

    await _deepLinkService.init();
  }

  // ============================================================
  // SERVICE AUTH
  // ============================================================

  Future<void> _handleServiceAuth(
      String authDataUrl,
      ) async {
    final authState = ref.read(authProvider);

    // ----------------------------------------------------------
    // Проверяем авторизацию BearCord
    // ----------------------------------------------------------

    if (!authState.isAuthenticated ||
        authState.user == null) {
      debugPrint(
        '❌ BearCord Auth: пользователь не авторизован',
      );

      navigatorKey.currentState?.pushNamed('/login');

      return;
    }

    final user = authState.user!;

    debugPrint(
      '🐻 BearCord Auth: запрос авторизации сервиса',
    );

    debugPrint(
      '👤 User ID: ${user.id}',
    );

    debugPrint(
      '👤 Login: ${user.login}',
    );

    debugPrint(
      '👤 Nick: ${user.nick}',
    );

    debugPrint(
      '🔗 Auth data: $authDataUrl',
    );

    // ----------------------------------------------------------
    // Открываем специальный экран
    // ----------------------------------------------------------

    await navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (context) => ServiceAuthScreen(
          authDataUrl: authDataUrl,

          // Уникальный ID пользователя BearCord
          userId: user.id,

          // Для авторизации сервиса используем LOGIN,
          // а не отображаемый ник.
          username: user.login,

          // Реальный аватар пользователя
          avatarUrl: user.displayAvatar,
        ),
      ),
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _deepLinkService.dispose();

    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return MaterialApp(
      title: 'BearCord',

      debugShowCheckedModeBanner: false,

      theme: AppTheme.darkTheme,

      // --------------------------------------------------------
      // GLOBAL KEYS
      // --------------------------------------------------------

      navigatorKey: navigatorKey,

      scaffoldMessengerKey: scaffoldMessengerKey,

      // --------------------------------------------------------
      // HOME
      // --------------------------------------------------------

      home: authState.isLoading
          ? const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      )
          : authState.isAuthenticated
          ? const RoomsScreen()
          : const LoginScreen(),

      // --------------------------------------------------------
      // ROUTES
      // --------------------------------------------------------

      routes: {
        '/login': (context) => const LoginScreen(),

        '/register': (context) => const RegisterScreen(),

        '/rooms': (context) => const RoomsScreen(),
      },

      // --------------------------------------------------------
      // GENERATED ROUTES
      // --------------------------------------------------------

      onGenerateRoute: (settings) {
        if (settings.name == '/chat') {
          final code =
              settings.arguments as String? ?? '';

          return MaterialPageRoute(
            builder: (context) => ChatScreen(
              code: code,
            ),
          );
        }

        return null;
      },
    );
  }
}