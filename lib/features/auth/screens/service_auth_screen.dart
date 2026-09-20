// lib/features/auth/screens/service_auth_screen.dart

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../../config/app_theme.dart';
import '../../../shared/widgets/user_avatar.dart';

class ServiceAuthData {
  final String serviceName;
  final String serviceLogo;
  final String token;
  final String urlAnswer;

  const ServiceAuthData({
    required this.serviceName,
    required this.serviceLogo,
    required this.token,
    required this.urlAnswer,
  });

  factory ServiceAuthData.fromJson(Map<String, dynamic> json) {
    return ServiceAuthData(
      serviceName: json['serviceName']?.toString() ?? '',
      serviceLogo: json['serviceLogo']?.toString() ?? '',
      token: json['token']?.toString() ?? '',
      urlAnswer: json['urlAnswer']?.toString() ?? '',
    );
  }
}

class ServiceAuthScreen extends StatefulWidget {
  final String authDataUrl;

  final int userId;

  final String username;

  final String? avatarUrl;

  const ServiceAuthScreen({
    super.key,
    required this.authDataUrl,
    required this.userId,
    required this.username,
    this.avatarUrl,
  });

  @override
  State<ServiceAuthScreen> createState() => _ServiceAuthScreenState();
}

class _ServiceAuthScreenState extends State<ServiceAuthScreen> {
  ServiceAuthData? _authData;

  bool _loading = true;
  bool _authorizing = false;

  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAuthData();
  }

  // ============================================================
  // ЗАГРУЗКА JSON
  // ============================================================

  Future<void> _loadAuthData() async {
    try {
      final uri = Uri.parse(widget.authDataUrl);

      final response = await http.get(uri);

      if (response.statusCode != 200) {
        throw Exception(
          'HTTP ${response.statusCode}',
        );
      }

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        throw Exception('Некорректный JSON');
      }

      final data = ServiceAuthData.fromJson(decoded);

      if (data.serviceName.isEmpty) {
        throw Exception('Отсутствует serviceName');
      }

      if (data.token.isEmpty) {
        throw Exception('Отсутствует token');
      }

      if (data.urlAnswer.isEmpty) {
        throw Exception('Отсутствует urlAnswer');
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _authData = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  // ============================================================
  // ГЕНЕРАЦИЯ ПАРОЛЯ
  // ============================================================

  String _generatePassword(
      String token,
      int userId,
      ) {
    if (token.isEmpty) {
      return 'bearcord-user-';
    }

    final count = userId * 2;

    final buffer = StringBuffer();

    for (int i = 0; i < count; i++) {
      buffer.write(
        token[i % token.length],
      );
    }

    return 'bearcord-user-${buffer.toString()}';
  }

  // ============================================================
  // URL АВТОРИЗАЦИИ
  // ============================================================

  String _buildAnswerUrl() {
    final data = _authData!;

    final password = _generatePassword(
      data.token,
      widget.userId,
    );

    var result = data.urlAnswer;

    result = result.replaceAll(
      '{bearcord_username}',
      Uri.encodeComponent(widget.username),
    );

    result = result.replaceAll(
      '{bearcord_user_id}',
      widget.userId.toString(),
    );

    result = result.replaceAll(
      '{bearcord_password}',
      Uri.encodeComponent(password),
    );

    result = result.replaceAll(
      '{token_from_service}',
      Uri.encodeComponent(data.token),
    );

    return result;
  }

  // ============================================================
  // АВТОРИЗАЦИЯ
  // ============================================================

  Future<void> _authorize() async {
    if (_authData == null || _authorizing) {
      return;
    }

    setState(() {
      _authorizing = true;
    });

    try {
      final answerUrl = _buildAnswerUrl();

      final uri = Uri.parse(answerUrl);

      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        throw Exception(
          'Не удалось открыть браузер',
        );
      }

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _authorizing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Не удалось открыть браузер: $e',
          ),
        ),
      );
    }
  }

  // ============================================================
  // ОТМЕНА
  // ============================================================

  void _cancel() {
    Navigator.of(context).pop();
  }

  // ============================================================
  // SERVICE LOGO
  // ============================================================

  Widget _buildServiceLogo() {
    final logo = _authData?.serviceLogo;

    if (logo == null || logo.isEmpty) {
      return Container(
        width: 84,
        height: 84,
        decoration: BoxDecoration(
          color: AppTheme.surfaceLight,
          shape: BoxShape.circle,
          border: Border.all(
            color: AppTheme.primary.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: Icon(
          Icons.apps_rounded,
          size: 40,
          color: AppTheme.textSecondary,
        ),
      );
    }

    return Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppTheme.primary.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: ClipOval(
        child: Image.network(
          logo,
          width: 84,
          height: 84,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) {
            return Container(
              color: AppTheme.surfaceLight,
              child: Icon(
                Icons.apps_rounded,
                size: 40,
                color: AppTheme.textSecondary,
              ),
            );
          },
        ),
      ),
    );
  }

  // ============================================================
  // BODY
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(
          color: AppTheme.primary,
        ),
      );
    }

    if (_error != null || _authData == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 64,
                color: Colors.redAccent,
              ),

              const SizedBox(height: 20),

              const Text(
                'Ошибка авторизации',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 10),

              Text(
                _error ?? 'Не удалось загрузить данные сервиса',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                ),
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _loadAuthData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.black,
                  ),
                  child: const Text(
                    'Повторить',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              TextButton(
                onPressed: _cancel,
                child: const Text(
                  'Закрыть',
                  style: TextStyle(
                    color: Colors.white70,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final data = _authData!;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),

            Icon(
              Icons.lock_open_rounded,
              color: AppTheme.primary,
              size: 42,
            ),

            const SizedBox(height: 24),

            const Text(
              'Связать аккаунт',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),

            const SizedBox(height: 36),

            // ==================================================
            // АККАУНТ → СЕРВИС
            // ==================================================

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Column(
                  children: [
                    UserAvatar(
                      avatarUrl: widget.avatarUrl,
                      name: widget.username,
                      size: 84,
                      showOnlineIndicator: false,
                    ),

                    const SizedBox(height: 12),

                    Text(
                      widget.username,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 4),

                    const Text(
                      'BearCord',
                      style: TextStyle(
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ),

                const SizedBox(width: 24),

                Icon(
                  Icons.link_rounded,
                  color: AppTheme.primary,
                  size: 32,
                ),

                const SizedBox(width: 24),

                Column(
                  children: [
                    _buildServiceLogo(),

                    const SizedBox(height: 12),

                    Text(
                      data.serviceName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 4),

                    const Text(
                      'Сервис',
                      style: TextStyle(
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 40),

            // ==================================================
            // INFO
            // ==================================================

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    data.serviceName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),

                  const SizedBox(height: 10),

                  const Text(
                    'запрашивает авторизацию через BearCord.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                    ),
                  ),

                  const SizedBox(height: 10),

                  const Text(
                    'После подтверждения откроется браузер '
                        'и будет выполнен вход в сервис.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // ==================================================
            // AUTHORIZE
            // ==================================================

            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _authorizing ? null : _authorize,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.black,
                  disabledBackgroundColor:
                  AppTheme.primary.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _authorizing
                    ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.black,
                  ),
                )
                    : const Text(
                  'Авторизовать',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ==================================================
            // CANCEL
            // ==================================================

            SizedBox(
              width: double.infinity,
              height: 54,
              child: TextButton(
                onPressed: _authorizing ? null : _cancel,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white70,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Отменить',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}