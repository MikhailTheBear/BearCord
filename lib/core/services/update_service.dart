import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';

class UpdateService {
  static const String versionUrl =
      'https://hub.tailsbear.ru/bearcord/api/v2.php?action=version';

  static const String fallbackDownloadUrl =
      'https://hub.tailsbear.ru/bearcord/get-bearcord.php';

  static Future<void> checkForUpdate(BuildContext context) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();

      final currentVersion = packageInfo.version;

      final response = await http
          .get(Uri.parse(versionUrl))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) {
        return;
      }

      final json = jsonDecode(response.body);

      if (json['success'] != true) {
        return;
      }

      final data = json['data'];

      if (data == null) {
        return;
      }

      final latestVersion = data['version']?.toString();

      if (latestVersion == null || latestVersion.isEmpty) {
        return;
      }

      final downloadUrl =
          data['download_url']?.toString() ??
              fallbackDownloadUrl;

      if (_compareVersions(
        latestVersion,
        currentVersion,
      ) <=
          0) {
        return;
      }

      if (!context.mounted) {
        return;
      }

      await _showUpdateDialog(
        context,
        currentVersion,
        latestVersion,
        downloadUrl,
      );
    } catch (e) {
      debugPrint(
        'Update check failed: $e',
      );
    }
  }

  static int _compareVersions(
      String a,
      String b,
      ) {
    final aParts = a
        .split('.')
        .map(
          (e) => int.tryParse(e) ?? 0,
    )
        .toList();

    final bParts = b
        .split('.')
        .map(
          (e) => int.tryParse(e) ?? 0,
    )
        .toList();

    final length =
    aParts.length > bParts.length
        ? aParts.length
        : bParts.length;

    for (var i = 0; i < length; i++) {
      final aValue =
      i < aParts.length
          ? aParts[i]
          : 0;

      final bValue =
      i < bParts.length
          ? bParts[i]
          : 0;

      if (aValue > bValue) {
        return 1;
      }

      if (aValue < bValue) {
        return -1;
      }
    }

    return 0;
  }

  static Future<void> _showUpdateDialog(
      BuildContext context,
      String currentVersion,
      String latestVersion,
      String downloadUrl,
      ) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Доступно обновление',
          ),
          content: Text(
            'Вышла новая версия BearCord.\n\n'
                'Текущая версия: $currentVersion\n'
                'Новая версия: $latestVersion\n\n'
                'Рекомендуем обновить приложение '
                'для получения новых функций и исправлений.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                'Нет, спасибо',
              ),
            ),
            FilledButton(
              onPressed: () async {
                final uri =
                Uri.parse(downloadUrl);

                await launchUrl(
                  uri,
                  mode:
                  LaunchMode.externalApplication,
                );

                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: const Text(
                'Обновить',
              ),
            ),
          ],
        );
      },
    );
  }
}