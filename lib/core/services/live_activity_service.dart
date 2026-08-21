import 'dart:io';

import 'package:flutter/services.dart';

class LiveActivityService {
  static const MethodChannel _channel =
  MethodChannel('bearcord/live_activity');

  // ============================================================
  // SUPPORT
  // ============================================================

  static Future<bool> isSupported() async {
    if (!Platform.isIOS) {
      return false;
    }

    try {
      return await _channel.invokeMethod<bool>(
        'isSupported',
      ) ??
          false;
    } catch (e) {
      print('❌ Live Activity support error: $e');
      return false;
    }
  }

  // ============================================================
  // START
  // ============================================================

  static Future<String?> start({
    required String chatID,
    required String chatName,
    required String senderName,
    required String message,
    String? avatarURL,
  }) async {
    if (!Platform.isIOS) {
      return null;
    }

    try {
      final activityID =
      await _channel.invokeMethod<String>(
        'start',
        {
          'chatID': chatID,
          'chatName': chatName,
          'senderName': senderName,
          'message': message,
          'avatarURL': avatarURL,
        },
      );

      print(
        '🏝️ Live Activity запущена: $activityID',
      );

      return activityID;
    } on PlatformException catch (e) {
      print(
        '❌ Не удалось запустить Live Activity: '
            '${e.code} — ${e.message}',
      );

      return null;
    }
  }

  // ============================================================
  // UPDATE
  // ============================================================

  static Future<bool> update({
    required String activityID,
    required String senderName,
    required String message,
    String? avatarURL,
  }) async {
    if (!Platform.isIOS) {
      return false;
    }

    try {
      final result =
      await _channel.invokeMethod<bool>(
        'update',
        {
          'activityID': activityID,
          'senderName': senderName,
          'message': message,
          'avatarURL': avatarURL,
        },
      );

      return result ?? false;
    } on PlatformException catch (e) {
      print(
        '❌ Не удалось обновить Live Activity: '
            '${e.code} — ${e.message}',
      );

      return false;
    }
  }

  // ============================================================
  // STOP
  // ============================================================

  static Future<bool> stop() async {
    if (!Platform.isIOS) {
      return false;
    }

    try {
      final result =
      await _channel.invokeMethod<bool>('stop');

      print(
        '🛑 Live Activity остановлена',
      );

      return result ?? false;
    } on PlatformException catch (e) {
      print(
        '❌ Не удалось остановить Live Activity: '
            '${e.code} — ${e.message}',
      );

      return false;
    }
  }
}