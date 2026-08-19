// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/app_theme.dart';
import 'core/providers/auth_provider.dart';
import 'features/rooms/providers/rooms_provider.dart'; // ← правильный импорт
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/register_screen.dart';
import 'features/rooms/screens/rooms_screen.dart';
import 'features/chat/screens/chat_screen.dart';

void main() {
  runApp(
    const ProviderScope(
      child: BearCordApp(),
    ),
  );
}

class BearCordApp extends ConsumerWidget {
  const BearCordApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    // Запускаем polling для комнат, если пользователь авторизован
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (authState.isAuthenticated) {
        ref.read(roomsProvider.notifier).startPolling();
      } else {
        ref.read(roomsProvider.notifier).stopPolling();
      }
    });

    return MaterialApp(
      title: 'BearCord',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: authState.isLoading
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : authState.isAuthenticated
          ? const RoomsScreen()
          : const LoginScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/rooms': (context) => const RoomsScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/chat') {
          final code = settings.arguments as String? ?? '';
          return MaterialPageRoute(
            builder: (context) => ChatScreen(code: code),
          );
        }
        return null;
      },
    );
  }
}