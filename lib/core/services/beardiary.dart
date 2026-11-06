import 'dart:convert';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../config/app_theme.dart';
import '../../core/services/storage_service.dart';

// ============================================================
// CONFIG
// ============================================================

class SchoolDiaryConfig {
  SchoolDiaryConfig._();

  static const String apiBaseUrl =
      'https://hub.tailsbear.ru/beardiary/api/school_diary_api.php';

  static const Duration requestTimeout = Duration(seconds: 20);

  static const String serviceId = 'bearcord_messenger_auth_id.beardiary';
  static const String serviceFrom = 'bearcord_beardiary';
  static const String fallbackServiceToken =
      'bearcord_messenger_auth_id.beardiary';
}

// ============================================================
// APP
// ============================================================

class SchoolDiary extends StatefulWidget {
  final int bearcordUserId;
  final String? bearcordToken;

  const SchoolDiary({
    super.key,
    required this.bearcordUserId,
    this.bearcordToken,
  });

  @override
  State<SchoolDiary> createState() => _SchoolDiaryState();
}

class _SchoolDiaryState extends State<SchoolDiary> {
  final _storage = StorageService();

  bool _sessionLoading = true;
  late int _bearcordUserId;
  late String _bearcordToken;

  @override
  void initState() {
    super.initState();
    _bearcordUserId = widget.bearcordUserId;
    _bearcordToken = widget.bearcordToken ?? '';
    _loadToken();
  }

  Future<void> _loadToken() async {
    if (_bearcordToken.isNotEmpty) {
      if (mounted) setState(() => _sessionLoading = false);
      return;
    }
    final stored = await _storage.getBeardiaryServiceToken();
    final token = (stored == null || stored.isEmpty)
        ? SchoolDiaryConfig.fallbackServiceToken
        : stored;
    if (!mounted) return;
    setState(() {
      _bearcordToken = token;
      _sessionLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Школьный дневник',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: _sessionLoading
          ? const Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(child: _LoadingIndicator()),
      )
          : _SessionGate(
        bearcordUserId: _bearcordUserId,
        bearcordToken: _bearcordToken,
      ),
    );
  }
}

// ============================================================
// API
// ============================================================

class _ApiException implements Exception {
  final String message;
  final int? statusCode;

  const _ApiException(this.message, [this.statusCode]);

  @override
  String toString() => message;
}

class _DiaryApi {
  static const _tokenKey = 'school_diary_api_token';

  final String baseUrl;

  _DiaryApi({String? baseUrl})
      : baseUrl = (baseUrl ?? SchoolDiaryConfig.apiBaseUrl)
      .replaceFirst(RegExp(r'/+$'), '');

  Future<String?> token() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> _saveToken(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, value);
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  Future<Map<String, dynamic>> request(
      String path, {
        String method = 'GET',
        Map<String, dynamic>? body,
        bool authenticated = true,
      }) async {
    final parsedPath = Uri.parse(path);
    final segments = parsedPath.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) {
      throw const _ApiException('Не указан маршрут API.');
    }
    final route = segments.first;

    final query = <String, String>{
      ...parsedPath.queryParameters,
      'route': route,
    };
    if (segments.length > 1) query['id'] = segments[1];

    final endpoint = Uri.parse(baseUrl);
    final uri = endpoint.replace(
      queryParameters: {...endpoint.queryParameters, ...query},
    );

    final headers = <String, String>{'Accept': 'application/json'};
    if (body != null) {
      headers['Content-Type'] = 'application/json; charset=utf-8';
    }
    if (authenticated) {
      final saved = await token();
      if (saved != null && saved.isNotEmpty) {
        headers['Authorization'] = 'Bearer $saved';
      }
    }

    late http.Response response;
    try {
      switch (method) {
        case 'POST':
          response = await http
              .post(uri, headers: headers, body: body == null ? null : jsonEncode(body))
              .timeout(SchoolDiaryConfig.requestTimeout);
          break;
        case 'PUT':
          response = await http
              .put(uri, headers: headers, body: body == null ? null : jsonEncode(body))
              .timeout(SchoolDiaryConfig.requestTimeout);
          break;
        case 'DELETE':
          response = await http
              .delete(uri, headers: headers, body: body == null ? null : jsonEncode(body))
              .timeout(SchoolDiaryConfig.requestTimeout);
          break;
        default:
          response = await http
              .get(uri, headers: headers)
              .timeout(SchoolDiaryConfig.requestTimeout);
      }
    } catch (_) {
      throw const _ApiException(
        'Не удалось подключиться к серверу. Проверь URL и соединение.',
      );
    }

    Map<String, dynamic> data;
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map) throw const FormatException();
      data = Map<String, dynamic>.from(decoded);
    } catch (_) {
      final preview = utf8
          .decode(response.bodyBytes, allowMalformed: true)
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      final detail = preview.isEmpty
          ? 'Пустой ответ сервера.'
          : preview.substring(0, preview.length.clamp(0, 180).toInt());
      throw _ApiException(
        'Сервер вернул не JSON (HTTP ${response.statusCode}). '
            'Проверь PHP endpoint. Ответ: $detail',
        response.statusCode,
      );
    }

    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        data['ok'] == false) {
      if (response.statusCode == 401) await clearToken();
      throw _ApiException(
        (data['error'] ?? 'Ошибка сервера').toString(),
        response.statusCode,
      );
    }

    return data;
  }

  Future<Map<String, dynamic>> login(String login, String password) async {
    final result = await request('login', method: 'POST', authenticated: false, body: {
      'login': login,
      'password': password,
    });
    final tokenValue = result['token']?.toString();
    if (tokenValue == null || tokenValue.isEmpty) {
      throw const _ApiException('API не вернул токен авторизации.');
    }
    await _saveToken(tokenValue);
    return Map<String, dynamic>.from(result['user'] as Map? ?? {});
  }

  Future<Map<String, dynamic>> me() async {
    final result = await request('me');
    return Map<String, dynamic>.from(result['user'] as Map? ?? {});
  }

  Future<void> logout() async {
    try {
      await request('logout', method: 'POST');
    } catch (_) {}
    await clearToken();
  }

  Future<Map<String, dynamic>> home({int? classId}) =>
      request('home${_query({'class_id': classId})}');

  Future<Map<String, dynamic>> schedule({int? classId, int? day}) =>
      request('schedule${_query({'class_id': classId, 'day': day})}');

  Future<Map<String, dynamic>> grades({int? studentId, int? classId}) =>
      request('grades${_query({'student_id': studentId, 'class_id': classId})}');

  Future<Map<String, dynamic>> homework({int? classId}) =>
      request('homework${_query({'class_id': classId})}');

  Future<Map<String, dynamic>> classes() => request('classes');
  Future<Map<String, dynamic>> subjects() => request('subjects');
  Future<Map<String, dynamic>> students({int? classId}) =>
      request('students${_query({'class_id': classId})}');

  Future<Map<String, dynamic>> addGrade(Map<String, dynamic> values) =>
      request('grades', method: 'POST', body: values);
  Future<Map<String, dynamic>> deleteGrade(int id) =>
      request('grades/$id', method: 'DELETE');

  Future<Map<String, dynamic>> addHomework(Map<String, dynamic> values) =>
      request('homework', method: 'POST', body: values);
  Future<Map<String, dynamic>> deleteHomework(int id) =>
      request('homework/$id', method: 'DELETE');

  Future<Map<String, dynamic>> addClass(String name) =>
      request('classes', method: 'POST', body: {'name': name});
  Future<Map<String, dynamic>> deleteClass(int id) =>
      request('classes/$id', method: 'DELETE');

  Future<Map<String, dynamic>> addSubject(String name) =>
      request('subjects', method: 'POST', body: {'name': name});
  Future<Map<String, dynamic>> deleteSubject(int id) =>
      request('subjects/$id', method: 'DELETE');

  Future<Map<String, dynamic>> addStudent(Map<String, dynamic> values) =>
      request('students', method: 'POST', body: values);
  Future<Map<String, dynamic>> updateStudent(int id, Map<String, dynamic> values) =>
      request('students/$id', method: 'PUT', body: values);
  Future<Map<String, dynamic>> deleteStudent(int id) =>
      request('students/$id', method: 'DELETE');

  String _query(Map<String, Object?> values) {
    final present = values.entries.where((e) => e.value != null).toList();
    if (present.isEmpty) return '';
    return '?${present.map((e) {
      return '${Uri.encodeQueryComponent(e.key)}='
          '${Uri.encodeQueryComponent(e.value.toString())}';
    }).join('&')}';
  }
}

// ============================================================
// SESSION
// ============================================================

class _SessionGate extends StatefulWidget {
  final int bearcordUserId;
  final String bearcordToken;

  const _SessionGate({
    required this.bearcordUserId,
    required this.bearcordToken,
  });

  @override
  State<_SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<_SessionGate> {
  final _api = _DiaryApi();

  bool _loading = true;
  Map<String, dynamic>? _user;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    try {
      if (await _api.token() != null) {
        _user = await _api.me();
      }
    } catch (_) {
      await _api.clearToken();
    }
    if (mounted) setState(() => _loading = false);
  }

  void _signedIn(Map<String, dynamic> user) {
    setState(() => _user = user);
  }

  Future<void> _signedOut() async {
    await _api.logout();
    if (mounted) setState(() => _user = null);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(child: _LoadingIndicator()),
      );
    }
    if (_user == null) {
      return _LoginScreen(api: _api, onSignedIn: _signedIn);
    }
    return _DiaryShell(
      api: _api,
      user: _user!,
      onSignOut: _signedOut,
      bearcordUserId: widget.bearcordUserId,
      bearcordToken: widget.bearcordToken,
    );
  }
}

// ============================================================
// LOGIN
// ============================================================

class _LoginScreen extends StatefulWidget {
  final _DiaryApi api;
  final ValueChanged<Map<String, dynamic>> onSignedIn;

  const _LoginScreen({required this.api, required this.onSignedIn});

  @override
  State<_LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<_LoginScreen> {
  final _login = TextEditingController();
  final _password = TextEditingController();

  bool _busy = false;
  bool _showPassword = false;
  String? _error;

  Future<void> _submit() async {
    if (_login.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'Введите логин и пароль.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final user = await widget.api.login(_login.text.trim(), _password.text);
      if (mounted) widget.onSignedIn(user);
    } on _ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _login.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          const _AmbientBackground(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(22),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: _GlassContainer(
                    radius: 30,
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 12),
                        const _HeroIcon(icon: Icons.menu_book_rounded, size: 86),
                        const SizedBox(height: 24),
                        const Text(
                          'Школьный дневник',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 25,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.7,
                          ),
                        ),
                        const SizedBox(height: 7),
                        const Text(
                          'TailsBear · Электронный дневник',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 30),
                        _GlassTextField(
                          controller: _login,
                          label: 'Логин',
                          icon: Icons.person_outline_rounded,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 14),
                        _GlassTextField(
                          controller: _password,
                          label: 'Пароль',
                          icon: Icons.lock_outline_rounded,
                          obscureText: !_showPassword,
                          onSubmitted: (_) => _submit(),
                          suffix: IconButton(
                            onPressed: () =>
                                setState(() => _showPassword = !_showPassword),
                            icon: Icon(
                              _showPassword
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 14),
                          _ErrorBanner(_error!),
                        ],
                        const SizedBox(height: 22),
                        _PrimaryButton(
                          title: 'Войти',
                          icon: Icons.login_rounded,
                          loading: _busy,
                          onTap: _submit,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// DIARY SHELL
// ============================================================

class _DiaryShell extends StatefulWidget {
  final _DiaryApi api;
  final Map<String, dynamic> user;
  final Future<void> Function() onSignOut;
  final int bearcordUserId;
  final String bearcordToken;

  const _DiaryShell({
    required this.api,
    required this.user,
    required this.onSignOut,
    required this.bearcordUserId,
    required this.bearcordToken,
  });

  @override
  State<_DiaryShell> createState() => _DiaryShellState();
}

class _DiaryShellState extends State<_DiaryShell> {
  int _index = 0;
  bool _webBusy = false;

  final _localAuth = LocalAuthentication();

  bool get _teacher => widget.user['role'] == 'teacher';

  String get _name => (widget.user['full_name'] ??
      widget.user['login'] ??
      'Пользователь')
      .toString();

  String _generatePassword(String token, int userId) {
    if (token.isEmpty) return 'bearcord-user-';
    final count = userId * 2;
    final buffer = StringBuffer();
    for (int i = 0; i < count; i++) {
      buffer.write(token[i % token.length]);
    }
    return 'bearcord-user-${buffer.toString()}';
  }

  Future<bool> _authenticateBiometrics() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      if (!canCheck || !isSupported) {
        return false;
      }
      return await _localAuth.authenticate(
        localizedReason: 'Подтвердите вход в веб-дневник',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }

  /// Запрашивает пароль у пользователя вручную.
  /// Возвращает введённый пароль или null, если пользователь отменил ввод.
  Future<String?> _askPassword() {
    return showDialog<String>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (_) => const _ManualPasswordDialog(),
    );
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppTheme.surface,
        content: Text(message),
      ),
    );
  }

  Future<void> _openWebDiary() async {
    if (_webBusy) return;
    final token = widget.bearcordToken.isEmpty
        ? SchoolDiaryConfig.fallbackServiceToken
        : widget.bearcordToken;
    if (widget.bearcordUserId <= 0) {
      _snack('Не найден ID пользователя BearCord.');
      return;
    }
    setState(() => _webBusy = true);
    try {
      // Пытаемся пройти биометрию.
      final bioOk = await _authenticateBiometrics();

      // Пароль: если биометрия пройдена — генерируем; иначе — берём введённый вручную.
      String password;
      if (bioOk) {
        password = _generatePassword(token, widget.bearcordUserId);
      } else {
        final manual = await _askPassword();
        if (manual == null) {
          // Пользователь отменил ввод.
          return;
        }
        password = manual;
      }

      if (!mounted) return;
      final username = (widget.user['login'] ?? '').toString();
      final url = Uri.https('hub.tailsbear.ru', '/beardiary/', {
        'username': username,
        'password': password,
        'token': SchoolDiaryConfig.serviceId,
        'from': SchoolDiaryConfig.serviceFrom,
      });
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => DiaryWebViewPage(url: url)),
      );
    } finally {
      if (mounted) setState(() => _webBusy = false);
    }
  }

  void _showProfileMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (sheetContext) {
        return _GlassBottomSheet(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const _HeroIcon(icon: Icons.person_rounded, size: 68),
                  const SizedBox(height: 14),
                  Text(
                    _name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _teacher ? 'Учитель' : 'Ученик',
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 24),
                  _GlassMenuButton(
                    icon: Icons.logout_rounded,
                    title: 'Выйти из аккаунта',
                    color: AppTheme.error,
                    onTap: () async {
                      Navigator.of(sheetContext).pop();
                      await widget.onSignOut();
                    },
                  ),
                  const SizedBox(height: 10),
                  _GlassMenuButton(
                    icon: Icons.close_rounded,
                    title: 'Закрыть',
                    color: AppTheme.textSecondary,
                    onTap: () => Navigator.of(sheetContext).pop(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      _HomeTab(
        api: widget.api,
        user: widget.user,
        onNavigate: (i) => setState(() => _index = i),
      ),
      _ScheduleTab(api: widget.api, user: widget.user),
      _GradesTab(api: widget.api, user: widget.user),
      _HomeworkTab(api: widget.api, user: widget.user),
      if (_teacher) _TeacherAdminTab(api: widget.api, user: widget.user),
    ];

    final titles = [
      'Главная',
      'Расписание',
      'Оценки',
      'Домашние задания',
      if (_teacher) 'Управление',
    ];

    return Scaffold(
      backgroundColor: AppTheme.background,
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 20,
        toolbarHeight: 76,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 9),
                const Text(
                  'BearDiary',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.6,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              titles[_index],
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: _showProfileMenu,
              child: const _GlassAvatar(),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          const _AmbientBackground(),
          SafeArea(
            bottom: false,
            child: IndexedStack(index: _index, children: pages),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: _GlassContainer(
          radius: 27,
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
          child: Row(
            children: [
              _NavigationItem(
                icon: Icons.home_rounded,
                label: 'Главная',
                selected: _index == 0,
                onTap: () => setState(() => _index = 0),
              ),
              _NavigationItem(
                icon: Icons.calendar_month_rounded,
                label: 'Расписание',
                selected: _index == 1,
                onTap: () => setState(() => _index = 1),
              ),
              _NavigationItem(
                icon: Icons.grade_rounded,
                label: 'Оценки',
                selected: _index == 2,
                onTap: () => setState(() => _index = 2),
              ),
              _NavigationItem(
                icon: Icons.menu_book_rounded,
                label: 'Домашка',
                selected: _index == 3,
                onTap: () => setState(() => _index = 3),
              ),
              if (_teacher)
                _NavigationItem(
                  icon: Icons.admin_panel_settings_rounded,
                  label: 'Управление',
                  selected: _index == 4,
                  onTap: () => setState(() => _index = 4),
                ),
              _NavigationItem(
                icon: Icons.web_rounded,
                label: _webBusy ? '...' : 'Веб',
                selected: false,
                onTap: _openWebDiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// HOME
// ============================================================

class _HomeTab extends StatefulWidget {
  final _DiaryApi api;
  final Map<String, dynamic> user;
  final ValueChanged<int> onNavigate;

  const _HomeTab({
    required this.api,
    required this.user,
    required this.onNavigate,
  });

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  late Future<Map<String, dynamic>> _future;

  bool get _teacher => widget.user['role'] == 'teacher';

  @override
  void initState() {
    super.initState();
    _future = widget.api.home();
  }

  Future<void> _refresh() async {
    // Важно: блочная форма setState — колбэк не возвращает Future.
    final future = widget.api.home();
    setState(() {
      _future = future;
    });
    await future;
  }

  @override
  Widget build(BuildContext context) {
    final firstName = (widget.user['full_name'] ??
        widget.user['login'] ??
        'пользователь')
        .toString()
        .split(' ')
        .first;

    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: _refresh,
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 130),
        children: [
          Text(
            'Привет, $firstName!',
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 27,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.7,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            _dateLabel(DateTime.now()),
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 22),
          FutureBuilder<Map<String, dynamic>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(45),
                  child: Center(child: _LoadingIndicator()),
                );
              }
              if (snap.hasError) {
                return _RetryCard(
                  message: _errorText(snap.error),
                  onRetry: _refresh,
                );
              }
              final data = snap.data ?? {};
              final lessons = _list(data['lessons']);
              final grades = _list(data['recent_grades']);
              final homework = _list(data['homework']);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionTitle(
                    title: 'Сегодня',
                    subtitle: data['today']?.toString() ?? 'Твои уроки',
                    action: 'Расписание',
                    onTap: () => widget.onNavigate(1),
                  ),
                  if (lessons.isEmpty)
                    const _EmptyCard(
                      icon: Icons.event_available_rounded,
                      text: 'На сегодня уроков нет или расписание не заполнено.',
                    )
                  else
                    ...lessons.take(5).map((l) => _LessonTile(item: l)),
                  const SizedBox(height: 24),
                  _SectionTitle(
                    title: 'Домашние задания',
                    subtitle: 'Что нужно сделать',
                    action: 'Все',
                    onTap: () => widget.onNavigate(3),
                  ),
                  if (homework.isEmpty)
                    const _EmptyCard(
                      icon: Icons.assignment_outlined,
                      text: 'Домашних заданий пока нет.',
                    )
                  else
                    ...homework.take(3).map((h) => _HomeworkCard(item: h)),
                  const SizedBox(height: 24),
                  _SectionTitle(
                    title:
                    _teacher ? 'Последние выставленные' : 'Последние оценки',
                    subtitle: 'Твои результаты',
                    action: 'Все',
                    onTap: () => widget.onNavigate(2),
                  ),
                  if (grades.isEmpty)
                    const _EmptyCard(
                      icon: Icons.grade_outlined,
                      text: 'Оценок пока нет.',
                    )
                  else
                    _GlassContainer(
                      radius: 22,
                      padding: const EdgeInsets.all(15),
                      child: Column(
                        children: [
                          for (int i = 0; i < grades.take(5).length; i++) ...[
                            if (i > 0) const _GlassDivider(),
                            _GradeRow(
                              item: grades[i],
                              showStudent: _teacher,
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// ============================================================
// SCHEDULE
// ============================================================

class _ScheduleTab extends StatefulWidget {
  final _DiaryApi api;
  final Map<String, dynamic> user;

  const _ScheduleTab({required this.api, required this.user});

  @override
  State<_ScheduleTab> createState() => _ScheduleTabState();
}

class _ScheduleTabState extends State<_ScheduleTab> {
  int _day = DateTime.now().weekday.clamp(1, 6).toInt();
  int? _classId;
  late Future<Map<String, dynamic>> _future;

  bool get _teacher => widget.user['role'] == 'teacher';

  @override
  void initState() {
    super.initState();
    _future = widget.api.schedule(day: _day, classId: _classId);
  }

  void _load() {
    setState(() {
      _future = widget.api.schedule(day: _day, classId: _classId);
    });
  }

  Future<void> _pickClass() async {
    try {
      final data = await widget.api.classes();
      final classes = _list(data['classes']);
      if (!mounted) return;
      final picked = await showModalBottomSheet<int?>(
        context: context,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withValues(alpha: 0.55),
        builder: (sheetContext) => _GlassBottomSheet(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Выбери класс',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _GlassMenuButton(
                    icon: Icons.clear_rounded,
                    title: 'Мой класс по умолчанию',
                    color: AppTheme.textSecondary,
                    onTap: () => Navigator.of(sheetContext).pop(-1),
                  ),
                  const SizedBox(height: 8),
                  ...classes.map(
                        (c) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _GlassMenuButton(
                        icon: Icons.class_rounded,
                        title: '${c['name']}',
                        onTap: () =>
                            Navigator.of(sheetContext).pop(_int(c['id'])),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      if (picked == null) return;
      setState(() => _classId = picked == -1 ? null : picked);
      _load();
    } catch (e) {
      _snack(_errorText(e));
    }
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: AppTheme.surface, content: Text(m)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_teacher)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: _PrimaryButton(
              title: _classId == null ? 'Выбрать класс' : 'Класс выбран',
              icon: Icons.class_rounded,
              onTap: _pickClass,
            ),
          ),
        SizedBox(
          height: 68,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            children: List.generate(6, (i) {
              final selected = _day == i + 1;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _GlassDayButton(
                  title: _weekday(i + 1),
                  selected: selected,
                  onTap: () {
                    setState(() => _day = i + 1);
                    _load();
                  },
                ),
              );
            }),
          ),
        ),
        Expanded(
          child: FutureBuilder<Map<String, dynamic>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: _LoadingIndicator());
              }
              if (snap.hasError) {
                return _RetryCard(
                  message: _errorText(snap.error),
                  onRetry: _load,
                );
              }
              final lessons = _list(snap.data?['lessons']);
              if (lessons.isEmpty) {
                return const _EmptyState(
                  icon: Icons.event_busy_rounded,
                  text: 'На этот день уроков нет.',
                );
              }
              return RefreshIndicator(
                color: AppTheme.primary,
                onRefresh: () async => _load(),
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 130),
                  children: [
                    _SectionTitle(
                      title: _weekday(_day),
                      subtitle: 'Расписание занятий',
                    ),
                    ...lessons
                        .map((l) => _LessonTile(item: l, expanded: true)),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ============================================================
// GRADES
// ============================================================

class _GradesTab extends StatefulWidget {
  final _DiaryApi api;
  final Map<String, dynamic> user;

  const _GradesTab({required this.api, required this.user});

  @override
  State<_GradesTab> createState() => _GradesTabState();
}

class _GradesTabState extends State<_GradesTab> {
  late Future<Map<String, dynamic>> _future;
  int? _classId;

  /// Выбранный ученик (только для учителя).
  Map<String, dynamic>? _selectedStudent;

  bool get _teacher => widget.user['role'] == 'teacher';

  @override
  void initState() {
    super.initState();
    if (_teacher) {
      // Учитель сначала должен выбрать ученика — не грузим оценки.
      _future = Future.value(const <String, dynamic>{});
    } else {
      _reload();
    }
  }

  void _reload() {
    setState(() {
      // Если выбран ученик — фильтруем только по нему,
      // чтобы не пересекаться с фильтром по классу (иначе можно получить пусто).
      final studentId = _selectedStudent != null
          ? _int(_selectedStudent!['id'])
          : null;
      _future = widget.api.grades(
        classId: studentId == null ? _classId : null,
        studentId: studentId,
      );
    });
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: AppTheme.surface, content: Text(value)),
    );
  }

  /// Выбор класса (фильтр списка учеников).
  Future<void> _pickClass() async {
    try {
      final data = await widget.api.classes();
      final classes = _list(data['classes']);
      if (!mounted) return;
      final picked = await showModalBottomSheet<int?>(
        context: context,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withValues(alpha: 0.55),
        builder: (sheetContext) => _GlassBottomSheet(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Выбери класс',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _GlassMenuButton(
                    icon: Icons.clear_rounded,
                    title: 'Все классы',
                    color: AppTheme.textSecondary,
                    onTap: () => Navigator.of(sheetContext).pop(-1),
                  ),
                  const SizedBox(height: 8),
                  ...classes.map(
                        (c) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _GlassMenuButton(
                        icon: Icons.class_rounded,
                        title: '${c['name']}',
                        onTap: () =>
                            Navigator.of(sheetContext).pop(_int(c['id'])),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      if (picked == null) return;
      setState(() {
        _classId = picked == -1 ? null : picked;
        // При смене класса сбрасываем выбранного ученика.
        _selectedStudent = null;
      });
      _reload();
    } catch (e) {
      _message(_errorText(e));
    }
  }

  /// Выбор ученика из списка.
  Future<void> _pickStudent() async {
    try {
      final data = await widget.api.students(classId: _classId);
      final students = _list(data['students']);
      if (!mounted) return;
      if (students.isEmpty) {
        _message('Нет учеников для выбора.');
        return;
      }
      final picked = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withValues(alpha: 0.55),
        isScrollControlled: true,
        builder: (sheetContext) {
          return _GlassBottomSheet(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Выбери ученика',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight:
                        MediaQuery.of(sheetContext).size.height * 0.6,
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const BouncingScrollPhysics(),
                        itemCount: students.length,
                        separatorBuilder: (_, __) =>
                        const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final s = students[i];
                          return _GlassMenuButton(
                            icon: Icons.person_rounded,
                            title:
                            '${s['full_name'] ?? s['login'] ?? 'Ученик'}'
                                '${s['class_name'] != null ? ' · ${s['class_name']}' : ''}',
                            onTap: () =>
                                Navigator.of(sheetContext).pop(s),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    _GlassMenuButton(
                      icon: Icons.close_rounded,
                      title: 'Закрыть',
                      color: AppTheme.textSecondary,
                      onTap: () => Navigator.of(sheetContext).pop(),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
      if (picked == null) return;
      setState(() {
        _selectedStudent = picked;
        // Сбрасываем фильтр по классу: ученик мог быть выбран не из
        // выбранного ранее класса — иначе сервер вернёт пустой список.
        _classId = null;
      });
      _reload();
    } catch (e) {
      _message(_errorText(e));
    }
  }

  /// Добавление оценки выбранному ученику.
  Future<void> _addGrade() async {
    final student = _selectedStudent;
    if (student == null) {
      _message('Сначала выберите ученика.');
      return;
    }
    try {
      final subjects = await widget.api.subjects();
      if (!mounted) return;
      final subjectList = _list(subjects['subjects']);
      if (subjectList.isEmpty) {
        _message('На сервере должны быть предметы.');
        return;
      }

      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.65),
        builder: (_) => _AddGradeDialog(
          student: student,
          subjects: subjectList,
        ),
      );
      if (result == null) return;

      await widget.api.addGrade(result);
      if (!mounted) return;
      _reload();
      _message('Оценка добавлена.');
    } catch (e) {
      if (mounted) _message(_errorText(e));
    }
  }

  Future<void> _deleteGrade(int id) async {
    try {
      await widget.api.deleteGrade(id);
      if (!mounted) return;
      _reload();
      _message('Оценка удалена.');
    } catch (e) {
      if (mounted) _message(_errorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Для учителя — отдельная ветка: требуется выбрать ученика.
    if (_teacher) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Column(
              children: [
                // Строка выбора класса + кнопка-фильтр.
                Row(
                  children: [
                    Expanded(
                      child: _PrimaryButton(
                        title: _selectedStudent == null
                            ? 'Выбрать ученика'
                            : '${_selectedStudent!['full_name'] ?? _selectedStudent!['login']}',
                        icon: Icons.person_search_rounded,
                        onTap: _pickStudent,
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 52,
                      child: _PrimaryButton(
                        title: '',
                        icon: Icons.class_rounded,
                        onTap: _pickClass,
                      ),
                    ),
                  ],
                ),
                if (_selectedStudent != null) ...[
                  const SizedBox(height: 10),
                  _PrimaryButton(
                    title: 'Выставить оценку',
                    icon: Icons.add_rounded,
                    onTap: _addGrade,
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: _selectedStudent == null
                ? const _EmptyState(
              icon: Icons.person_search_rounded,
              text:
              'Выберите ученика, чтобы просмотреть и выставить его оценки.',
            )
                : _buildGradesList(showDelete: true),
          ),
        ],
      );
    }

    // Для ученика — как было, но без кнопок управления.
    return Column(
      children: [
        Expanded(child: _buildGradesList()),
      ],
    );
  }

  Widget _buildGradesList({bool showDelete = false}) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: _LoadingIndicator());
        }
        if (snap.hasError) {
          return _RetryCard(
            message: _errorText(snap.error),
            onRetry: _reload,
          );
        }

        final grades = _list(snap.data?['grades']);
        final summary = _list(snap.data?['summary']);

        if (grades.isEmpty) {
          return const _EmptyState(
            icon: Icons.grade_outlined,
            text: 'Оценок пока нет.',
          );
        }

        final grouped = <String, List<Map<String, dynamic>>>{};
        for (final grade in grades) {
          final subject = (grade['subject'] ?? 'Без предмета').toString();
          grouped.putIfAbsent(subject, () => []).add(grade);
        }

        final summaryMap = <String, Map<String, dynamic>>{};
        for (final s in summary) {
          summaryMap['${s['subject']}'] = s;
        }

        return RefreshIndicator(
          color: AppTheme.primary,
          onRefresh: () async => _reload(),
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 130),
            children: [
              _SectionTitle(
                title: 'Успеваемость',
                subtitle: _selectedStudent != null
                    ? 'Оценки: ${_selectedStudent!['full_name'] ?? _selectedStudent!['login']}'
                    : 'Оценки по предметам',
              ),
              ...grouped.entries.map((entry) {
                final s = summaryMap[entry.key] ?? {};
                final avg = s['average'];
                final quarters = (s['quarters'] is Map)
                    ? Map<String, dynamic>.from(s['quarters'] as Map)
                    : <String, dynamic>{};
                final year = s['year'];

                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _GlassContainer(
                    radius: 22,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                entry.key,
                                style: const TextStyle(
                                  color: AppTheme.primary,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            if (avg != null)
                              _StatChip(
                                label: 'средний',
                                value: '$avg',
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'За уроки',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: entry.value
                              .where((g) => g['period'] == 'lesson')
                              .map(
                                (g) => _GradeChip(
                              item: g,
                              onDelete: showDelete
                                  ? () => _deleteGrade(_int(g['id']))
                                  : null,
                            ),
                          )
                              .toList(),
                        ),
                        if (quarters.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          const Text(
                            'За четверти',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: quarters.entries
                                .map((e) => _GradeBadge(
                              grade: '${e.value}',
                              label: '${e.key} четв.',
                            ))
                                .toList(),
                          ),
                        ],
                        if (year != null) ...[
                          const SizedBox(height: 12),
                          const Text(
                            'Годовая',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          _GradeBadge(grade: '$year', label: 'год'),
                        ],
                        if (showDelete && entry.value.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          const _GlassDivider(),
                          const SizedBox(height: 8),
                          const Text(
                            'Записи для удаления',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          ...entry.value.map(
                                (g) => Padding(
                              padding:
                              const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${_periodLabel(g['period'], g['quarter'])} · ${_displayDate(g['grade_date'])}',
                                      style: const TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () =>
                                        _deleteGrade(_int(g['id'])),
                                    icon: Icon(
                                      Icons.delete_outline_rounded,
                                      color: AppTheme.error,
                                      size: 20,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;

  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.25)),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          color: AppTheme.primary,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _GradeBadge extends StatelessWidget {
  final String grade;
  final String label;

  const _GradeBadge({required this.grade, required this.label});

  @override
  Widget build(BuildContext context) {
    final numeric = int.tryParse(grade);
    final color = _gradeColor(numeric);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            grade,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: color,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _GradeChip extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback? onDelete;

  const _GradeChip({required this.item, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final grade = '${item['grade'] ?? '—'}';
    final numeric = int.tryParse(grade);
    final color = _gradeColor(numeric);

    return InkWell(
      onLongPress: onDelete,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.45)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              grade,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: color,
                fontSize: 16,
              ),
            ),
            Text(
              _displayDate(item['grade_date']),
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Color _gradeColor(int? numeric) {
  if (numeric == 5) return const Color(0xFF6DDB6D);
  if (numeric == 4) return const Color(0xFFC8E04A);
  if (numeric != null && numeric <= 2) return AppTheme.error;
  return AppTheme.primary;
}

// ============================================================
// HOMEWORK
// ============================================================

class _HomeworkTab extends StatefulWidget {
  final _DiaryApi api;
  final Map<String, dynamic> user;

  const _HomeworkTab({required this.api, required this.user});

  @override
  State<_HomeworkTab> createState() => _HomeworkTabState();
}

class _HomeworkTabState extends State<_HomeworkTab> {
  late Future<Map<String, dynamic>> _future;
  int? _classId;

  bool get _teacher => widget.user['role'] == 'teacher';

  @override
  void initState() {
    super.initState();
    _future = widget.api.homework(classId: _classId);
  }

  void _reload() {
    setState(() {
      _future = widget.api.homework(classId: _classId);
    });
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: AppTheme.surface, content: Text(value)),
    );
  }

  Future<void> _addHomework() async {
    try {
      final classes = _list((await widget.api.classes())['classes']);
      final subjects = _list((await widget.api.subjects())['subjects']);
      if (!mounted) return;
      if (classes.isEmpty || subjects.isEmpty) {
        _message('Добавьте классы и предметы в базе данных.');
        return;
      }
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.65),
        builder: (_) => _AddHomeworkDialog(
          classes: classes,
          subjects: subjects,
        ),
      );
      if (result == null) return;
      await widget.api.addHomework(result);
      if (!mounted) return;
      _reload();
      _message('Домашнее задание добавлено.');
    } catch (e) {
      if (mounted) _message(_errorText(e));
    }
  }

  Future<void> _deleteHomework(int id) async {
    try {
      await widget.api.deleteHomework(id);
      if (!mounted) return;
      _reload();
      _message('Домашнее задание удалено.');
    } catch (e) {
      if (mounted) _message(_errorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_teacher)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: _PrimaryButton(
              title: 'Задать домашнее задание',
              icon: Icons.add_rounded,
              onTap: _addHomework,
            ),
          ),
        Expanded(
          child: FutureBuilder<Map<String, dynamic>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: _LoadingIndicator());
              }
              if (snap.hasError) {
                return _RetryCard(
                  message: _errorText(snap.error),
                  onRetry: _reload,
                );
              }
              final items = _list(snap.data?['homework']);
              if (items.isEmpty) {
                return const _EmptyState(
                  icon: Icons.assignment_outlined,
                  text: 'Домашних заданий пока нет.',
                );
              }
              return RefreshIndicator(
                color: AppTheme.primary,
                onRefresh: () async => _reload(),
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 130),
                  children: [
                    _SectionTitle(
                      title: 'Домашние задания',
                      subtitle: 'Все задания по предметам',
                    ),
                    ...items.map(
                          (item) => _HomeworkCard(
                        item: item,
                        showDelete: _teacher,
                        onDelete: () => _deleteHomework(_int(item['id'])),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ============================================================
// TEACHER ADMIN (Students, Classes, Subjects)
// ============================================================

class _TeacherAdminTab extends StatefulWidget {
  final _DiaryApi api;
  final Map<String, dynamic> user;

  const _TeacherAdminTab({required this.api, required this.user});

  @override
  State<_TeacherAdminTab> createState() => _TeacherAdminTabState();
}

class _TeacherAdminTabState extends State<_TeacherAdminTab> {
  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 130),
      children: [
        _SectionTitle(
          title: 'Управление',
          subtitle: 'Классы, предметы, ученики',
        ),
        _AdminButton(
          icon: Icons.class_rounded,
          title: 'Классы',
          subtitle: 'Создание и удаление классов',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => _ClassesPage(api: widget.api)),
          ),
        ),
        const SizedBox(height: 12),
        _AdminButton(
          icon: Icons.book_rounded,
          title: 'Предметы',
          subtitle: 'Список учебных предметов',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => _SubjectsPage(api: widget.api)),
          ),
        ),
        const SizedBox(height: 12),
        _AdminButton(
          icon: Icons.people_alt_rounded,
          title: 'Ученики',
          subtitle: 'Добавление, изменение, удаление',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => _StudentsPage(api: widget.api)),
          ),
        ),
      ],
    );
  }
}

class _AdminButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _AdminButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassContainer(
      radius: 20,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: ListTile(
          onTap: onTap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppTheme.primary),
          ),
          title: Text(
            title,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
            ),
          ),
          trailing: const Icon(
            Icons.chevron_right_rounded,
            color: AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ---------- Classes page ----------

class _ClassesPage extends StatefulWidget {
  final _DiaryApi api;
  const _ClassesPage({required this.api});

  @override
  State<_ClassesPage> createState() => _ClassesPageState();
}

class _ClassesPageState extends State<_ClassesPage> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.api.classes();
  }

  void _reload() {
    setState(() {
      _future = widget.api.classes();
    });
  }

  Future<void> _add() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (dialogContext) => _GlassDialog(
        icon: Icons.class_rounded,
        title: 'Новый класс',
        message: 'Введите название класса.',
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: const InputDecoration(labelText: 'Название'),
        ),
        actions: [
          Expanded(
            child: _DialogButton(
              title: 'Отмена',
              onTap: () => Navigator.of(dialogContext).pop(),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _DialogButton(
              title: 'Создать',
              filled: true,
              color: AppTheme.primary,
              onTap: () =>
                  Navigator.of(dialogContext).pop(controller.text.trim()),
            ),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    try {
      await widget.api.addClass(name);
      if (!mounted) return;
      _reload();
    } catch (e) {
      if (!mounted) return;
      _snack(_errorText(e));
    }
  }

  Future<void> _delete(int id) async {
    try {
      await widget.api.deleteClass(id);
      if (!mounted) return;
      _reload();
    } catch (e) {
      if (!mounted) return;
      _snack(_errorText(e));
    }
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: AppTheme.surface, content: Text(m)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppTheme.textPrimary,
        title: const Text('Классы'),
        actions: [
          IconButton(
            onPressed: _add,
            icon: const Icon(Icons.add_rounded, color: AppTheme.primary),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: _LoadingIndicator());
          }
          if (snap.hasError) {
            return _RetryCard(
              message: _errorText(snap.error),
              onRetry: _reload,
            );
          }
          final classes = _list(snap.data?['classes']);
          if (classes.isEmpty) {
            return const _EmptyState(
              icon: Icons.class_outlined,
              text: 'Классов пока нет.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
            itemCount: classes.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final c = classes[i];
              return _GlassContainer(
                radius: 18,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.class_rounded, color: AppTheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${c['name']}',
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '${c['student_count'] ?? 0} учеников',
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => _delete(_int(c['id'])),
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        color: AppTheme.error,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ---------- Subjects page ----------

class _SubjectsPage extends StatefulWidget {
  final _DiaryApi api;
  const _SubjectsPage({required this.api});

  @override
  State<_SubjectsPage> createState() => _SubjectsPageState();
}

class _SubjectsPageState extends State<_SubjectsPage> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.api.subjects();
  }

  void _reload() {
    setState(() {
      _future = widget.api.subjects();
    });
  }

  Future<void> _add() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (dialogContext) => _GlassDialog(
        icon: Icons.book_rounded,
        title: 'Новый предмет',
        message: 'Введите название предмета.',
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: const InputDecoration(labelText: 'Название'),
        ),
        actions: [
          Expanded(
            child: _DialogButton(
              title: 'Отмена',
              onTap: () => Navigator.of(dialogContext).pop(),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _DialogButton(
              title: 'Создать',
              filled: true,
              color: AppTheme.primary,
              onTap: () =>
                  Navigator.of(dialogContext).pop(controller.text.trim()),
            ),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    try {
      await widget.api.addSubject(name);
      if (!mounted) return;
      _reload();
    } catch (e) {
      if (!mounted) return;
      _snack(_errorText(e));
    }
  }

  Future<void> _delete(int id) async {
    try {
      await widget.api.deleteSubject(id);
      if (!mounted) return;
      _reload();
    } catch (e) {
      if (!mounted) return;
      _snack(_errorText(e));
    }
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: AppTheme.surface, content: Text(m)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppTheme.textPrimary,
        title: const Text('Предметы'),
        actions: [
          IconButton(
            onPressed: _add,
            icon: const Icon(Icons.add_rounded, color: AppTheme.primary),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: _LoadingIndicator());
          }
          if (snap.hasError) {
            return _RetryCard(
              message: _errorText(snap.error),
              onRetry: _reload,
            );
          }
          final subjects = _list(snap.data?['subjects']);
          if (subjects.isEmpty) {
            return const _EmptyState(
              icon: Icons.book_outlined,
              text: 'Предметов пока нет.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
            itemCount: subjects.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final s = subjects[i];
              return _GlassContainer(
                radius: 18,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.book_rounded, color: AppTheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${s['name']}',
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => _delete(_int(s['id'])),
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        color: AppTheme.error,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ---------- Students page ----------

class _StudentsPage extends StatefulWidget {
  final _DiaryApi api;
  const _StudentsPage({required this.api});

  @override
  State<_StudentsPage> createState() => _StudentsPageState();
}

class _StudentsPageState extends State<_StudentsPage> {
  late Future<Map<String, dynamic>> _future;
  int? _classId;

  @override
  void initState() {
    super.initState();
    _future = widget.api.students(classId: _classId);
  }

  void _reload() {
    setState(() {
      _future = widget.api.students(classId: _classId);
    });
  }

  // ... остальное без изменений

  Future<void> _add() async {
    try {
      final classes = _list((await widget.api.classes())['classes']);
      if (!mounted) return;
      final values = await showDialog<Map<String, dynamic>>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.65),
        builder: (_) => _StudentDialog(classes: classes),
      );
      if (values == null) return;
      await widget.api.addStudent(values);
      if (!mounted) return;
      _reload();
      _snack('Ученик добавлен.');
    } catch (e) {
      if (!mounted) return;
      _snack(_errorText(e));
    }
  }

  Future<void> _edit(Map<String, dynamic> student) async {
    try {
      final classes = _list((await widget.api.classes())['classes']);
      if (!mounted) return;
      final values = await showDialog<Map<String, dynamic>>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.65),
        builder: (_) => _StudentDialog(
          classes: classes,
          initial: student,
        ),
      );
      if (values == null) return;
      values.remove('login');
      await widget.api.updateStudent(_int(student['id']), values);
      if (!mounted) return;
      _reload();
      _snack('Сохранено.');
    } catch (e) {
      if (!mounted) return;
      _snack(_errorText(e));
    }
  }

  Future<void> _delete(int id) async {
    try {
      await widget.api.deleteStudent(id);
      if (!mounted) return;
      _reload();
      _snack('Ученик удалён.');
    } catch (e) {
      if (!mounted) return;
      _snack(_errorText(e));
    }
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: AppTheme.surface, content: Text(m)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppTheme.textPrimary,
        title: const Text('Ученики'),
        actions: [
          IconButton(
            onPressed: _add,
            icon: const Icon(
              Icons.person_add_rounded,
              color: AppTheme.primary,
            ),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: _LoadingIndicator());
          }
          if (snap.hasError) {
            return _RetryCard(
              message: _errorText(snap.error),
              onRetry: _reload,
            );
          }
          final students = _list(snap.data?['students']);
          if (students.isEmpty) {
            return const _EmptyState(
              icon: Icons.people_outline_rounded,
              text: 'Учеников пока нет.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
            itemCount: students.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final s = students[i];
              return _GlassContainer(
                radius: 18,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor:
                      AppTheme.primary.withValues(alpha: 0.2),
                      child: Text(
                        '${s['full_name']}'.isNotEmpty
                            ? '${s['full_name']}'[0]
                            : '?',
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${s['full_name']}',
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '${s['login']} · ${s['class_name'] ?? '—'}',
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => _edit(s),
                      icon: const Icon(
                        Icons.edit_rounded,
                        color: AppTheme.primary,
                      ),
                    ),
                    IconButton(
                      onPressed: () => _delete(_int(s['id'])),
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        color: AppTheme.error,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ============================================================
// ADD / EDIT DIALOGS
// ============================================================

class _StudentDialog extends StatefulWidget {
  final List<Map<String, dynamic>> classes;
  final Map<String, dynamic>? initial;

  const _StudentDialog({required this.classes, this.initial});

  @override
  State<_StudentDialog> createState() => _StudentDialogState();
}

class _StudentDialogState extends State<_StudentDialog> {
  late final _login = TextEditingController(
    text: widget.initial?['login']?.toString() ?? '',
  );
  late final _password = TextEditingController();
  late final _fullName = TextEditingController(
    text: widget.initial?['full_name']?.toString() ?? '',
  );

  int? _classId;

  @override
  void initState() {
    super.initState();
    final cls = widget.initial?['class_id'];
    if (cls != null) _classId = _int(cls);
  }

  @override
  void dispose() {
    _login.dispose();
    _password.dispose();
    _fullName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.initial != null;

    return _GlassDialog(
      icon: editing ? Icons.edit_rounded : Icons.person_add_rounded,
      title: editing ? 'Редактирование ученика' : 'Новый ученик',
      message: editing
          ? 'Обнови данные ученика. Пустой пароль — не менять.'
          : 'Заполни данные для создания аккаунта.',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!editing) ...[
            TextField(
              controller: _login,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(labelText: 'Логин'),
            ),
            const SizedBox(height: 10),
          ],
          TextField(
            controller: _fullName,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: const InputDecoration(labelText: 'ФИО'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _password,
            obscureText: true,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: InputDecoration(
              labelText: editing ? 'Новый пароль (опционально)' : 'Пароль',
            ),
          ),
          const SizedBox(height: 10),
          _GlassDropdown<int>(
            value: _classId,
            label: 'Класс',
            items: widget.classes
                .map(
                  (c) => DropdownMenuItem(
                value: _int(c['id']),
                child: Text('${c['name']}'),
              ),
            )
                .toList(),
            onChanged: (v) => setState(() => _classId = v),
          ),
        ],
      ),
      actions: [
        Expanded(
          child: _DialogButton(
            title: 'Отмена',
            onTap: () => Navigator.of(context).pop(),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _DialogButton(
            title: editing ? 'Сохранить' : 'Создать',
            filled: true,
            color: AppTheme.primary,
            onTap: () {
              final data = <String, dynamic>{
                'full_name': _fullName.text.trim(),
                'class_id': _classId,
              };
              if (!editing) {
                data['login'] = _login.text.trim();
                data['password'] = _password.text;
              } else if (_password.text.isNotEmpty) {
                data['password'] = _password.text;
              }
              Navigator.of(context).pop(data);
            },
          ),
        ),
      ],
    );
  }
}

/// Диалог добавления оценки конкретному ученику.
/// Ученик уже предустановлен, выбор ученика отсутствует.
class _AddGradeDialog extends StatefulWidget {
  final Map<String, dynamic> student;
  final List<Map<String, dynamic>> subjects;

  const _AddGradeDialog({
    required this.student,
    required this.subjects,
  });

  @override
  State<_AddGradeDialog> createState() => _AddGradeDialogState();
}

class _AddGradeDialogState extends State<_AddGradeDialog> {
  int? _subject;
  String _grade = '5';
  String _period = 'lesson';
  int _quarter = 1;
  DateTime _date = DateTime.now();

  @override
  void initState() {
    super.initState();
    _subject = _int(widget.subjects.first['id']);
  }

  @override
  Widget build(BuildContext context) {
    final studentName = (widget.student['full_name'] ??
        widget.student['login'] ??
        'Ученик')
        .toString();

    return _GlassDialog(
      icon: Icons.grade_rounded,
      title: 'Новая оценка',
      message: 'Ученик: $studentName',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _GlassDropdown<int>(
            value: _subject,
            label: 'Предмет',
            items: widget.subjects
                .map(
                  (s) => DropdownMenuItem(
                value: _int(s['id']),
                child: Text('${s['name']}'),
              ),
            )
                .toList(),
            onChanged: (v) => setState(() => _subject = v),
          ),
          const SizedBox(height: 12),
          _GlassDropdown<String>(
            value: _grade,
            label: 'Оценка',
            items: ['1', '2', '3', '4', '5', 'НВ', 'СМ', 'Н', 'АЗ']
                .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                .toList(),
            onChanged: (v) => setState(() => _grade = v ?? '5'),
          ),
          const SizedBox(height: 12),
          _GlassDropdown<String>(
            value: _period,
            label: 'Тип оценки',
            items: const [
              DropdownMenuItem(value: 'lesson', child: Text('За урок')),
              DropdownMenuItem(
                value: 'quarter',
                child: Text('За четверть'),
              ),
              DropdownMenuItem(value: 'year', child: Text('Годовая')),
            ],
            onChanged: (v) => setState(() => _period = v ?? 'lesson'),
          ),
          if (_period == 'quarter') ...[
            const SizedBox(height: 12),
            _GlassDropdown<int>(
              value: _quarter,
              label: 'Четверть',
              items: [1, 2, 3, 4]
                  .map((q) => DropdownMenuItem(
                value: q,
                child: Text('$q четверть'),
              ))
                  .toList(),
              onChanged: (v) => setState(() => _quarter = v ?? 1),
            ),
          ],
          const SizedBox(height: 8),
          _GlassMenuButton(
            icon: Icons.calendar_month_rounded,
            title: 'Дата: ${_dateLabel(_date)}',
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (date != null) setState(() => _date = date);
            },
          ),
        ],
      ),
      actions: [
        Expanded(
          child: _DialogButton(
            title: 'Отмена',
            onTap: () => Navigator.of(context).pop(),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _DialogButton(
            title: 'Сохранить',
            filled: true,
            color: AppTheme.primary,
            onTap: () {
              Navigator.of(context).pop({
                'student_id': _int(widget.student['id']),
                'subject_id': _subject,
                'grade': _grade,
                'period': _period,
                'quarter': _period == 'quarter' ? _quarter : null,
                'grade_date': _date.toIso8601String().substring(0, 10),
              });
            },
          ),
        ),
      ],
    );
  }
}

class _AddHomeworkDialog extends StatefulWidget {
  final List<Map<String, dynamic>> classes;
  final List<Map<String, dynamic>> subjects;

  const _AddHomeworkDialog({
    required this.classes,
    required this.subjects,
  });

  @override
  State<_AddHomeworkDialog> createState() => _AddHomeworkDialogState();
}

class _AddHomeworkDialogState extends State<_AddHomeworkDialog> {
  int? _classId;
  int? _subjectId;
  DateTime _date = DateTime.now();
  final _description = TextEditingController();

  @override
  void initState() {
    super.initState();
    _classId = _int(widget.classes.first['id']);
    _subjectId = _int(widget.subjects.first['id']);
  }

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _GlassDialog(
      icon: Icons.menu_book_rounded,
      title: 'Домашнее задание',
      message: 'Заполни информацию о новом задании.',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _GlassDropdown<int>(
            value: _classId,
            label: 'Класс',
            items: widget.classes
                .map(
                  (c) => DropdownMenuItem(
                value: _int(c['id']),
                child: Text('${c['name']}'),
              ),
            )
                .toList(),
            onChanged: (v) => setState(() => _classId = v),
          ),
          const SizedBox(height: 12),
          _GlassDropdown<int>(
            value: _subjectId,
            label: 'Предмет',
            items: widget.subjects
                .map(
                  (s) => DropdownMenuItem(
                value: _int(s['id']),
                child: Text('${s['name']}'),
              ),
            )
                .toList(),
            onChanged: (v) => setState(() => _subjectId = v),
          ),
          const SizedBox(height: 12),
          _GlassMenuButton(
            icon: Icons.calendar_month_rounded,
            title: 'На дату: ${_dateLabel(_date)}',
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (date != null) setState(() => _date = date);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _description,
            minLines: 3,
            maxLines: 6,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Описание задания',
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
      actions: [
        Expanded(
          child: _DialogButton(
            title: 'Отмена',
            onTap: () => Navigator.of(context).pop(),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _DialogButton(
            title: 'Создать',
            filled: true,
            color: AppTheme.primary,
            onTap: () {
              if (_description.text.trim().isEmpty) return;
              Navigator.of(context).pop({
                'class_id': _classId,
                'subject_id': _subjectId,
                'lesson_date': _date.toIso8601String().substring(0, 10),
                'description': _description.text.trim(),
              });
            },
          ),
        ),
      ],
    );
  }
}

// ============================================================
// LESSON / GRADE / HOMEWORK CARDS
// ============================================================

class _LessonTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool expanded;

  const _LessonTile({required this.item, this.expanded = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _GlassContainer(
        radius: 20,
        padding: const EdgeInsets.all(15),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.11),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: AppTheme.primary.withValues(alpha: 0.20),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                '${item['lesson_num'] ?? '—'}',
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w900,
                  fontSize: 19,
                ),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${item['subject'] ?? 'Предмет'}',
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(
                        Icons.schedule_rounded,
                        size: 14,
                        color: AppTheme.primary,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          '${item['time_start'] ?? ''}'
                              '${item['time_end'] != null ? ' – ${item['time_end']}' : ''}',
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (expanded || item['cabinet'] != null) ...[
                    const SizedBox(height: 5),
                    Text(
                      'Кабинет: ${item['cabinet'] ?? '—'}',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GradeRow extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool showStudent;

  const _GradeRow({required this.item, this.showStudent = false});

  @override
  Widget build(BuildContext context) {
    final grade = '${item['grade'] ?? '—'}';
    final numeric = int.tryParse(grade);
    final color = _gradeColor(numeric);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: color.withValues(alpha: 0.45)),
            ),
            alignment: Alignment.center,
            child: Text(
              grade,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: color,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item['subject'] ?? 'Предмет'}',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (showStudent && item['student'] != null)
                  Text(
                    '${item['student']}',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                const SizedBox(height: 3),
                Text(
                  '${_periodLabel(item['period'], item['quarter'])}'
                      ' · ${_displayDate(item['grade_date'])}',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeworkCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool showDelete;
  final VoidCallback? onDelete;

  const _HomeworkCard({
    required this.item,
    this.showDelete = false,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final files = _list(item['files']);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _GlassContainer(
        radius: 22,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.11),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.menu_book_rounded,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${item['subject'] ?? 'Предмет'}',
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'На ${_displayDate(item['lesson_date'])}'
                            '${item['teacher'] != null ? ' · ${item['teacher']}' : ''}',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                if (showDelete)
                  IconButton(
                    onPressed: onDelete,
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: AppTheme.error,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              '${item['description'] ?? ''}',
              style: const TextStyle(
                color: AppTheme.textPrimary,
                height: 1.5,
                fontSize: 13,
              ),
            ),
            if (files.isNotEmpty) ...[
              const SizedBox(height: 14),
              const _GlassDivider(),
              const SizedBox(height: 8),
              ...files.map(
                    (file) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.attach_file_rounded,
                        size: 18,
                        color: AppTheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${file['original_name'] ?? 'Файл'}',
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================
// HELPERS / UI COMPONENTS
// ============================================================

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? action;
  final VoidCallback? onTap;

  const _SectionTitle({
    required this.title,
    this.subtitle,
    this.action,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (action != null)
            TextButton(
              onPressed: onTap,
              child: Text(
                action!,
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final String text;
  final IconData icon;

  const _EmptyCard({
    required this.text,
    this.icon = Icons.info_outline_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassContainer(
      radius: 20,
      padding: const EdgeInsets.all(17),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primary, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;

  const _EmptyState({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _HeroIcon(icon: icon, size: 82),
            const SizedBox(height: 20),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RetryCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _RetryCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: _GlassContainer(
          radius: 24,
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _HeroIcon(icon: Icons.cloud_off_rounded, size: 70),
              const SizedBox(height: 18),
              const Text(
                'Не удалось загрузить данные',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              _PrimaryButton(
                title: 'Повторить',
                icon: Icons.refresh_rounded,
                onTap: onRetry,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppTheme.error.withValues(alpha: 0.10),
        border: Border.all(color: AppTheme.error.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: AppTheme.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: AppTheme.error, fontSize: 12),
            ),
          ),
        ],
      ),
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
            top: 280,
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

  const _GlowOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 65, sigmaY: 65),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}

class _GlassContainer extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;

  const _GlassContainer({
    required this.child,
    this.radius = 20,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.055),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
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

class _GlassDivider extends StatelessWidget {
  const _GlassDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      color: Colors.white.withValues(alpha: 0.075),
    );
  }
}

class _HeroIcon extends StatelessWidget {
  final IconData icon;
  final double size;

  const _HeroIcon({required this.icon, this.size = 90});

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
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.20)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.14),
            blurRadius: 45,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Icon(icon, color: AppTheme.primary, size: size * 0.40),
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
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.20)),
      ),
      child: const Padding(
        padding: EdgeInsets.all(18),
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: AppTheme.primary,
        ),
      ),
    );
  }
}

class _GlassAvatar extends StatelessWidget {
  const _GlassAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 43,
      height: 43,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.08),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.35)),
      ),
      child: const Icon(Icons.person_rounded, color: AppTheme.primary),
    );
  }
}

class _NavigationItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavigationItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(19),
          splashColor: AppTheme.primary.withValues(alpha: 0.12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 34,
                  decoration: BoxDecoration(
                    color: selected
                        ? AppTheme.primary.withValues(alpha: 0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color:
                    selected ? AppTheme.primary : AppTheme.textSecondary,
                    size: 20,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color:
                    selected ? AppTheme.primary : AppTheme.textSecondary,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
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

class _PrimaryButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final bool loading;

  const _PrimaryButton({
    required this.title,
    required this.icon,
    required this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 49,
      child: Material(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: loading ? null : onTap,
          borderRadius: BorderRadius.circular(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (loading)
                const SizedBox(
                  width: 19,
                  height: 19,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.black,
                  ),
                )
              else
                Icon(icon, color: Colors.black, size: 20),
              if (title.isNotEmpty) ...[
                const SizedBox(width: 9),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

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
        color: filled ? color : Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                color: filled ? Colors.black : color,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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
      radius: 16,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          onTap: onTap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          title: Text(
            title,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscureText;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffix;

  const _GlassTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.obscureText = false,
    this.textInputAction,
    this.onSubmitted,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      autocorrect: false,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      style: const TextStyle(color: AppTheme.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppTheme.primary),
        suffixIcon: suffix,
      ),
    );
  }
}

class _GlassDropdown<T> extends StatelessWidget {
  final T? value;
  final String label;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  const _GlassDropdown({
    required this.value,
    required this.label,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: items,
      onChanged: onChanged,
    );
  }
}

class _GlassDialog extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final Widget? content;
  final List<Widget> actions;

  const _GlassDialog({
    required this.icon,
    required this.title,
    required this.message,
    required this.actions,
    this.content,
    this.iconColor = AppTheme.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.surface.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: iconColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(icon, color: iconColor),
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
                  Row(children: actions),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ManualPasswordDialog extends StatefulWidget {
  const _ManualPasswordDialog();

  @override
  State<_ManualPasswordDialog> createState() => _ManualPasswordDialogState();
}

class _ManualPasswordDialogState extends State<_ManualPasswordDialog> {
  final _controller = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return _GlassDialog(
      icon: Icons.lock_outline_rounded,
      title: 'Вход в веб-дневник',
      message:
      'Биометрия недоступна. Введите пароль от веб-дневника вручную.',
      content: TextField(
        controller: _controller,
        autofocus: true,
        obscureText: _obscure,
        style: const TextStyle(color: AppTheme.textPrimary),
        decoration: InputDecoration(
          labelText: 'Пароль',
          suffixIcon: IconButton(
            onPressed: () => setState(() => _obscure = !_obscure),
            icon: Icon(
              _obscure
                  ? Icons.visibility_rounded
                  : Icons.visibility_off_rounded,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        Expanded(
          child: _DialogButton(
            title: 'Отмена',
            onTap: () => Navigator.of(context).pop(),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _DialogButton(
            title: 'Войти',
            filled: true,
            color: AppTheme.primary,
            onTap: _submit,
          ),
        ),
      ],
    );
  }
}

class _GlassBottomSheet extends StatelessWidget {
  final Widget child;

  const _GlassBottomSheet({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.surface.withValues(alpha: 0.92),
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _GlassDayButton extends StatelessWidget {
  final String title;
  final bool selected;
  final VoidCallback onTap;

  const _GlassDayButton({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassContainer(
      radius: 15,
      child: Material(
        color: selected
            ? AppTheme.primary.withValues(alpha: 0.15)
            : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Center(
              child: Text(
                title,
                style: TextStyle(
                  color:
                  selected ? AppTheme.primary : AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
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
// HELPERS
// ============================================================

List<Map<String, dynamic>> _list(dynamic value) {
  if (value is! List) return [];
  return value
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();
}

int _int(dynamic value) {
  return value is int ? value : int.tryParse('$value') ?? 0;
}

String _errorText(Object? error) {
  return error is _ApiException
      ? error.message
      : (error?.toString() ?? 'Неизвестная ошибка');
}

String _weekday(int day) {
  return const [
    'Понедельник',
    'Вторник',
    'Среда',
    'Четверг',
    'Пятница',
    'Суббота',
  ][day - 1];
}

String _dateLabel(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}.'
      '${date.month.toString().padLeft(2, '0')}.'
      '${date.year}';
}

String _displayDate(dynamic value) {
  if (value == null || '$value'.isEmpty) return 'дата не указана';
  final date = DateTime.tryParse('$value');
  return date == null ? '$value' : _dateLabel(date);
}

String _periodLabel(dynamic period, dynamic quarter) {
  switch (period) {
    case 'quarter':
      return 'Четверть $quarter';
    case 'year':
      return 'Годовая';
    default:
      return 'За урок';
  }
}

// ============================================================
// WEB VIEW PAGE
// ============================================================

class DiaryWebViewPage extends StatefulWidget {
  final Uri url;

  const DiaryWebViewPage({super.key, required this.url});

  @override
  State<DiaryWebViewPage> createState() => _DiaryWebViewPageState();
}

class _DiaryWebViewPageState extends State<DiaryWebViewPage> {
  late final WebViewController controller;

  @override
  void initState() {
    super.initState();

    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setOnJavaScriptAlertDialog(
            (JavaScriptAlertDialogRequest request) async {
          print('JS Alert: ${request.message}');
          await showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Сообщение с сайта'),
              content: Text(request.message),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        },
      );

    // setBackgroundColor использует setOpaque, который не реализован
    // в webview_flutter_wkwebview на macOS и вызывает UnimplementedError.
    if (defaultTargetPlatform != TargetPlatform.macOS) {
      controller.setBackgroundColor(const Color(0xFF090909));
    }

    controller.loadRequest(widget.url);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090909),
      appBar: AppBar(
        title: const Text('Школьный дневник'),
        backgroundColor: const Color(0xFF111111),
        foregroundColor: Colors.white,
      ),
      body: WebViewWidget(controller: controller),
    );
  }
}