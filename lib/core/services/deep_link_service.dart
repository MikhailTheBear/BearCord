import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

import '../../features/auth/screens/service_auth_screen.dart';

class DeepLinkService {
  final AppLinks _appLinks = AppLinks();

  StreamSubscription<Uri>? _subscription;

  bool _initialized = false;

  /// NavigatorKey BearCord.
  final GlobalKey<NavigatorState> navigatorKey;

  DeepLinkService({
    required this.navigatorKey,
  });

  // ============================================================
  // INIT
  // ============================================================

  Future<void> init() async {
    if (_initialized) {
      return;
    }

    _initialized = true;

    // ----------------------------------------------------------
    // Если BearCord был полностью закрыт
    // ----------------------------------------------------------

    try {
      final initialUri = await _appLinks.getInitialLink();

      if (initialUri != null) {
        await _handleUri(initialUri);
      }
    } catch (e) {
      debugPrint(
        '❌ DeepLink initial error: $e',
      );
    }

    // ----------------------------------------------------------
    // Если BearCord уже запущен
    // ----------------------------------------------------------

    _subscription = _appLinks.uriLinkStream.listen(
          (uri) {
        _handleUri(uri);
      },
      onError: (error) {
        debugPrint(
          '❌ DeepLink stream error: $error',
        );
      },
    );

    debugPrint(
      '🔗 BearCord Deep Link Service запущен',
    );
  }

  // ============================================================
  // HANDLE URI
  // ============================================================

  Future<void> _handleUri(Uri uri) async {
    debugPrint(
      '🔗 Получен Deep Link: $uri',
    );

    // ----------------------------------------------------------
    // Проверяем схему
    // ----------------------------------------------------------

    if (uri.scheme != 'bearcord') {
      debugPrint(
        '⚠️ Неизвестная схема: ${uri.scheme}',
      );

      return;
    }

    // ----------------------------------------------------------
    // Проверяем действие
    //
    // bearcord://auth?auth_data=...
    //
    // scheme = bearcord
    // host   = auth
    // ----------------------------------------------------------

    if (uri.host != 'auth') {
      debugPrint(
        '⚠️ Неизвестный BearCord Deep Link action: ${uri.host}',
      );

      return;
    }

    // ----------------------------------------------------------
    // Получаем auth_data
    // ----------------------------------------------------------

    final authDataUrl = uri.queryParameters['auth_data'];

    if (authDataUrl == null ||
        authDataUrl.trim().isEmpty) {
      debugPrint(
        '❌ Deep Link не содержит auth_data',
      );

      return;
    }

    debugPrint(
      '🐻 BearCord Auth URL: $authDataUrl',
    );

    // ----------------------------------------------------------
    // Небольшая задержка нужна при cold start,
    // чтобы Navigator уже существовал.
    // ----------------------------------------------------------

    await Future.delayed(
      const Duration(milliseconds: 300),
    );

    if (navigatorKey.currentState == null) {
      debugPrint(
        '❌ Navigator ещё не готов',
      );

      return;
    }

    // ----------------------------------------------------------
    // Получаем текущий аккаунт BearCord
    //
    // ЗДЕСЬ нужно использовать твой AuthProvider.
    // Пока оставляем получение через context.
    // ----------------------------------------------------------

    final context = navigatorKey.currentContext;

    if (context == null) {
      debugPrint(
        '❌ BuildContext отсутствует',
      );

      return;
    }

    /*
     * ВАЖНО:
     *
     * Здесь нужно получить:
     *
     * user.id
     * user.username
     * user.avatar
     *
     * из твоего AuthProvider.
     *
     * Я ниже сделал временную передачу через
     * отдельный callback, чтобы DeepLinkService
     * не был жёстко связан с Riverpod.
     */

    if (onAuthRequest == null) {
      debugPrint(
        '❌ DeepLinkService: onAuthRequest не установлен',
      );

      return;
    }

    await onAuthRequest!(
      authDataUrl,
    );
  }

  // ============================================================
  // AUTH CALLBACK
  // ============================================================

  Future<void> Function(String authDataUrl)? onAuthRequest;

  // ============================================================
  // DISPOSE
  // ============================================================

  Future<void> dispose() async {
    await _subscription?.cancel();

    _subscription = null;

    _initialized = false;

    debugPrint(
      '🔗 BearCord Deep Link Service остановлен',
    );
  }
}