// lib/config/app_config.dart
class AppConfig {
  // ============================================
  // API
  // ============================================
  static const String apiBaseUrl = 'https://hub.tailsbear.ru/bearcord/api/v2.php';

  // ============================================
  // АВАТАРКИ
  // ============================================
  static const String defaultAvatar =
      'https://cdn-icons-png.flaticon.com/512/6858/6858569.png';

  // ============================================
  // ТАЙМАУТЫ
  // ============================================
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // ============================================
  // ПАГИНАЦИЯ
  // ============================================
  static const int messagesPerPage = 50;
  static const int pollInterval = 1500; // миллисекунды
}
