import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '/core/services/storage_service.dart';
import '/core/providers/auth_provider.dart'; // ← путь к вашему authProvider
import 'beardiary.dart';

/// Handles BearCord deep links:
/// - bearcord://auth?auth_data=...
/// - bearcord://beardiary
class DeepLinkService {
  final AppLinks _appLinks = AppLinks();
  final GlobalKey<NavigatorState> navigatorKey;
  final StorageService _storage;
  final ProviderContainer _container;

  StreamSubscription<Uri>? _subscription;
  bool _initialized = false;
  bool _handlingUri = false;

  /// Keep your existing authentication callback.
  Future<void> Function(String authDataUrl)? onAuthRequest;

  DeepLinkService({
    required this.navigatorKey,
    required ProviderContainer container,
    StorageService? storage,
  })  : _container = container,
        _storage = storage ?? StorageService();

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        await _handleUri(initialUri);
      }
    } catch (e) {
      debugPrint('BearCord initial deep-link error: $e');
    }

    _subscription = _appLinks.uriLinkStream.listen(
          (uri) => _handleUri(uri),
      onError: (Object error) {
        debugPrint('BearCord deep-link stream error: $error');
      },
    );

    debugPrint('BearCord DeepLinkService started');
  }

  Future<void> _handleUri(Uri uri) async {
    debugPrint('BearCord deep link received: $uri');

    if (uri.scheme != 'bearcord') {
      debugPrint('Unknown deep-link scheme: ${uri.scheme}');
      return;
    }

    // bearcord://beardiary
    if (uri.host == 'beardiary' &&
        (uri.path.isEmpty || uri.path == '/')) {
      await _openBearDiary();
      return;
    }

    // Existing authentication link.
    if (uri.host == 'auth') {
      final authDataUrl = uri.queryParameters['auth_data'];

      if (authDataUrl == null || authDataUrl.trim().isEmpty) {
        debugPrint('Auth deep link is missing auth_data');
        return;
      }

      await Future<void>.delayed(
        const Duration(milliseconds: 300),
      );

      if (navigatorKey.currentState == null ||
          navigatorKey.currentContext == null) {
        debugPrint('Navigator is not ready for auth deep link');
        return;
      }

      final callback = onAuthRequest;

      if (callback == null) {
        debugPrint('onAuthRequest is not configured');
        return;
      }

      await callback(authDataUrl);
      return;
    }

    debugPrint('Unknown BearCord deep-link action: ${uri.host}');
  }

  Future<void> _openBearDiary() async {
    if (_handlingUri) return;
    _handlingUri = true;

    try {
      await Future<void>.delayed(
        const Duration(milliseconds: 250),
      );

      final navigator = navigatorKey.currentState;

      if (navigator == null) {
        debugPrint('Navigator is not ready for BearDiary');
        return;
      }

      // Берём id пользователя BearCord из Riverpod-сессии.
      final authState = _container.read(authProvider);
      final userId = authState.user?.id ?? 0;

      debugPrint(
        'BearDiary deep link: userId=$userId, '
            'authenticated=${authState.isAuthenticated}',
      );

      if (userId <= 0) {
        debugPrint(
          'BearDiary deep link ignored: user is not authenticated',
        );
        return;
      }

      // Токен сервиса Beardiary (если есть) — из StorageService.
      // Если пусто, SchoolDiary сам подставит fallback.
      final serviceToken = await _storage.getBeardiaryServiceToken();

      debugPrint(
        'BearDiary deep link: '
            'serviceToken empty=${serviceToken == null || serviceToken.isEmpty}',
      );

      await navigator.push<void>(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: '/beardiary'),
          builder: (_) => SchoolDiary(
            bearcordUserId: userId,
            bearcordToken: serviceToken,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Could not open BearDiary: $e');
    } finally {
      _handlingUri = false;
    }
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    _initialized = false;

    debugPrint('BearCord DeepLinkService stopped');
  }
}