/// School Diary — native Flutter module for TailsBear.
///
/// Add to pubspec.yaml:
///   http: ^1.2.2
///   shared_preferences: ^2.3.2
///
/// Configure [SchoolDiaryConfig.apiBaseUrl] to the directory containing
/// school_dia
/// ry_api.php, for example https://example.com/beardiary/api.
/// This module is standalone and does not use BearCord authentication.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class SchoolDiaryConfig {
  SchoolDiaryConfig._();

  /// Set this to your server API URL. Do not put database credentials here.
  static const String apiBaseUrl = 'https://hub.tailsbear.ru/beardiary/api/school_dairy_api.php';
  static const Duration requestTimeout = Duration(seconds: 20);
}

const Color _sdBg = Color(0xFF0C0C0C);
const Color _sdPanel = Color(0xFF171710);
const Color _sdPanel2 = Color(0xFF222216);
const Color _sdLine = Color(0xFF383821);
const Color _sdYellow = Color(0xFFFFD400);
const Color _sdMuted = Color(0xFFAAA98F);

class SchoolDiary extends StatelessWidget {
  const SchoolDiary({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Школьный дневник',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: _sdBg,
      colorScheme: const ColorScheme.dark(
        primary: _sdYellow,
        secondary: _sdYellow,
        surface: _sdPanel,
        error: Color(0xFFFF6262),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: _sdBg,
        foregroundColor: _sdYellow,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: _sdPanel,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _sdLine),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _sdBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _sdLine),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _sdLine),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _sdYellow, width: 1.5),
        ),
      ),
    ),
    home: const _SessionGate(),
  );
}

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

  Future<String?> token() async =>
      (await SharedPreferences.getInstance()).getString(_tokenKey);

  Future<void> _saveToken(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, value);
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  /// Calls the single PHP file using query routing:
  /// school_dairy_api.php?route=login, ?route=home, ?route=grades&id=123.
  /// The PHP endpoint must read $_GET['route'] and optional $_GET['id'].
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
      queryParameters: {
        ...endpoint.queryParameters,
        ...query,
      },
    );

    final headers = <String, String>{
      'Accept': 'application/json',
    };
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
      if (decoded is! Map) {
        throw const FormatException('JSON root is not an object');
      }
      data = Map<String, dynamic>.from(decoded);
    } catch (_) {
      final bodyPreview = utf8.decode(response.bodyBytes, allowMalformed: true)
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      final detail = bodyPreview.isEmpty
          ? 'Пустой ответ сервера.'
          : bodyPreview.substring(0, bodyPreview.length.clamp(0, 180).toInt());
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
    final result = await request(
      'login',
      method: 'POST',
      authenticated: false,
      body: {'login': login, 'password': password},
    );
    final tokenValue = result['token']?.toString();
    if (tokenValue == null || tokenValue.isEmpty) {
      throw const _ApiException('API не вернул токен авторизации.');
    }
    await _saveToken(tokenValue);
    return Map<String, dynamic>.from(result['user'] as Map? ?? {});
  }

  Future<Map<String, dynamic>> me() async =>
      Map<String, dynamic>.from((await request('me'))['user'] as Map? ?? {});

  Future<void> logout() async {
    try {
      await request('logout', method: 'POST');
    } catch (_) {}
    await clearToken();
  }

  Future<Map<String, dynamic>> home() => request('home');

  Future<Map<String, dynamic>> schedule({int? classId, int? day}) =>
      request('schedule${_query({'class_id': classId, 'day': day})}');

  Future<Map<String, dynamic>> grades({int? studentId}) =>
      request('grades${_query({'student_id': studentId})}');

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

  String _query(Map<String, Object?> values) {
    final present = values.entries.where((e) => e.value != null).toList();
    if (present.isEmpty) return '';
    return '?${present.map((e) =>
    '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value.toString())}'
    ).join('&')}';
  }
}

class _SessionGate extends StatefulWidget {
  const _SessionGate();
  @override
  State<_SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<_SessionGate> {
  final _api = _DiaryApi();
  bool _loading = true;
  Map<String, dynamic>? _user;

  @override
  void initState() { super.initState(); _restore(); }
  Future<void> _restore() async {
    try {
      if (await _api.token() != null) _user = await _api.me();
    } catch (_) { await _api.clearToken(); }
    if (mounted) setState(() => _loading = false);
  }
  void _signedIn(Map<String, dynamic> user) => setState(() => _user = user);
  Future<void> _signedOut() async { await _api.logout(); if (mounted) setState(() => _user = null); }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: _sdYellow)));
    if (_user == null) return _LoginScreen(api: _api, onSignedIn: _signedIn);
    return _DiaryShell(api: _api, user: _user!, onSignOut: _signedOut, onUserRefresh: _signedIn);
  }
}

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
    if (_login.text.trim().isEmpty || _password.text.isEmpty) { setState(() => _error = 'Введите логин и пароль.'); return; }
    setState(() { _busy = true; _error = null; });
    try {
      final user = await widget.api.login(_login.text.trim(), _password.text);
      if (mounted) widget.onSignedIn(user);
    } on _ApiException catch (e) { if (mounted) setState(() => _error = e.message); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  @override
  void dispose() { _login.dispose(); _password.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420), child: Card(child: Padding(padding: const EdgeInsets.all(24), child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Icon(Icons.menu_book_rounded, size: 58, color: _sdYellow),
      const SizedBox(height: 12),
      const Text('Школьный дневник', textAlign: TextAlign.center, style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800, color: _sdYellow)),
      const SizedBox(height: 6),
      const Text('TailsBear · Электронный дневник', textAlign: TextAlign.center, style: TextStyle(color: _sdMuted)),
      const SizedBox(height: 28),
      TextField(controller: _login, textInputAction: TextInputAction.next, autocorrect: false, decoration: const InputDecoration(labelText: 'Логин', prefixIcon: Icon(Icons.person_outline))),
      const SizedBox(height: 14),
      TextField(controller: _password, obscureText: !_showPassword, onSubmitted: (_) => _submit(), decoration: InputDecoration(labelText: 'Пароль', prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _showPassword = !_showPassword)))),
      if (_error != null) ...[const SizedBox(height: 14), _ErrorBanner(_error!)],
      const SizedBox(height: 20),
      FilledButton(onPressed: _busy ? null : _submit, child: Padding(padding: const EdgeInsets.all(12), child: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Войти'))),
      const SizedBox(height: 14),
      const Text('Используется отдельная учётная запись дневника.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: _sdMuted)),
    ],
    ))))))),
  );
}

class _DiaryShell extends StatefulWidget {
  final _DiaryApi api;
  final Map<String, dynamic> user;

  final Future<void> Function() onSignOut;
  final ValueChanged<Map<String, dynamic>> onUserRefresh;
  const _DiaryShell({required this.api, required this.user, required this.onSignOut, required this.onUserRefresh});
  @override
  State<_DiaryShell> createState() => _DiaryShellState();
}
class _DiaryShellState extends State<_DiaryShell> {
  int _index = 0;
  bool get _teacher => widget.user['role'] == 'teacher';
  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      _HomeTab(api: widget.api, user: widget.user, onNavigate: (i) => setState(() => _index = i)),
      _ScheduleTab(api: widget.api, user: widget.user),
      _GradesTab(api: widget.api, user: widget.user),
      _HomeworkTab(api: widget.api, user: widget.user),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('TBSD  /  Дневник', style: TextStyle(fontWeight: FontWeight.w800)), actions: [
        PopupMenuButton<String>(icon: const Icon(Icons.account_circle_outlined), onSelected: (v) async { if (v == 'logout') await widget.onSignOut(); }, itemBuilder: (_) => [
          PopupMenuItem<String>(enabled: false, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text((widget.user['full_name'] ?? widget.user['login'] ?? 'Пользователь').toString(), style: const TextStyle(fontWeight: FontWeight.bold)), Text(_teacher ? 'Учитель' : 'Ученик', style: const TextStyle(color: _sdMuted))])),
          const PopupMenuDivider(), const PopupMenuItem(value: 'logout', child: Row(children: [Icon(Icons.logout), SizedBox(width: 10), Text('Выйти')]))
        ])
      ]),
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(selectedIndex: _index, onDestinationSelected: (i) => setState(() => _index = i), destinations: const [
        NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Главная'),
        NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'Расписание'),
        NavigationDestination(icon: Icon(Icons.grade_outlined), selectedIcon: Icon(Icons.grade), label: 'Оценки'),
        NavigationDestination(icon: Icon(Icons.assignment_outlined), selectedIcon: Icon(Icons.assignment), label: 'Домашка'),
      ]),
    );
  }
}

class _HomeTab extends StatefulWidget {
  final _DiaryApi api; final Map<String, dynamic> user; final ValueChanged<int> onNavigate;
  const _HomeTab({required this.api, required this.user, required this.onNavigate});
  @override State<_HomeTab> createState() => _HomeTabState();
}
class _HomeTabState extends State<_HomeTab> {
  late Future<Map<String, dynamic>> _future;
  @override void initState() { super.initState(); _future = widget.api.home(); }
  Future<void> _refresh() async { setState(() => _future = widget.api.home()); await _future; }
  @override Widget build(BuildContext context) => RefreshIndicator(color: _sdYellow, onRefresh: _refresh, child: ListView(padding: const EdgeInsets.all(16), children: [
    Text('Привет, ${(widget.user['full_name'] ?? widget.user['login'] ?? 'пользователь').toString().split(' ').first}!', style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w800)),
    const SizedBox(height: 4), Text(_dateLabel(DateTime.now()), style: const TextStyle(color: _sdMuted)),
    const SizedBox(height: 16),
    FutureBuilder<Map<String, dynamic>>(future: _future, builder: (context, snap) {
      if (snap.connectionState == ConnectionState.waiting) return const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: _sdYellow)));
      if (snap.hasError) return _RetryCard(message: _errorText(snap.error), onRetry: _refresh);
      final data = snap.data ?? {};
      final lessons = _list(data['lessons']); final grades = _list(data['recent_grades']); final homework = _list(data['homework']);
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _SectionTitle(title: 'Сегодня', action: 'Расписание', onTap: () => widget.onNavigate(1)),
        if (lessons.isEmpty) const _EmptyCard(text: 'На сегодня уроков нет или расписание не заполнено.') else ...lessons.take(5).map((l) => _LessonTile(item: l)),
        const SizedBox(height: 12),
        _SectionTitle(title: 'Ближайшие домашние задания', action: 'Все', onTap: () => widget.onNavigate(3)),
        if (homework.isEmpty) const _EmptyCard(text: 'Домашних заданий пока нет.') else ...homework.take(3).map((h) => _HomeworkCard(item: h)),
        const SizedBox(height: 12),
        _SectionTitle(title: 'Последние оценки', action: 'Все', onTap: () => widget.onNavigate(2)),
        if (grades.isEmpty) const _EmptyCard(text: 'Оценок пока нет.') else ...grades.take(5).map((g) => _GradeRow(item: g)),
      ]);
    }),
  ]));
}

class _ScheduleTab extends StatefulWidget { final _DiaryApi api; final Map<String, dynamic> user; const _ScheduleTab({required this.api, required this.user}); @override State<_ScheduleTab> createState() => _ScheduleTabState(); }
class _ScheduleTabState extends State<_ScheduleTab> {
  int _day = DateTime.now().weekday.clamp(1, 6).toInt(); late Future<Map<String, dynamic>> _future;
  @override void initState() { super.initState(); _future = widget.api.schedule(day: _day); }
  void _load() => setState(() => _future = widget.api.schedule(day: _day));
  @override Widget build(BuildContext context) => Column(children: [
    SizedBox(height: 62, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), children: List.generate(6, (i) => Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(_weekday(i + 1)), selected: _day == i + 1, onSelected: (_) { _day = i + 1; _load(); })) ))),
    Expanded(child: FutureBuilder<Map<String, dynamic>>(future: _future, builder: (context, snap) {
      if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: _sdYellow));
      if (snap.hasError) return _RetryCard(message: _errorText(snap.error), onRetry: _load);
      final lessons = _list(snap.data?['lessons']);
      if (lessons.isEmpty) return const _EmptyState(icon: Icons.event_busy, text: 'На этот день уроков нет.');
      return RefreshIndicator(color: _sdYellow, onRefresh: () async => _load(), child: ListView(padding: const EdgeInsets.all(16), children: lessons.map((l) => _LessonTile(item: l, expanded: true)).toList()));
    }))
  ]);
}

class _GradesTab extends StatefulWidget { final _DiaryApi api; final Map<String, dynamic> user; const _GradesTab({required this.api, required this.user}); @override State<_GradesTab> createState() => _GradesTabState(); }
class _GradesTabState extends State<_GradesTab> {
  late Future<Map<String, dynamic>> _future;
  @override void initState() { super.initState(); _future = widget.api.grades(); }
  void _reload() => setState(() => _future = widget.api.grades());
  bool get _teacher => widget.user['role'] == 'teacher';
  Future<void> _addGrade() async {
    final classes = await widget.api.classes(); final students = await widget.api.students(); final subjects = await widget.api.subjects();
    if (!mounted) return;
    final studentList = _list(students['students']); final subjectList = _list(subjects['subjects']);
    if (studentList.isEmpty || subjectList.isEmpty) { _message('На сервере должны быть ученики и предметы.'); return; }
    final result = await showDialog<Map<String, dynamic>>(context: context, builder: (_) => _AddGradeDialog(students: studentList, subjects: subjectList, classes: _list(classes['classes'])));
    if (result == null) return;
    try { await widget.api.addGrade(result); _reload(); if (mounted) _message('Оценка добавлена.'); }
    catch (e) { if (mounted) _message(_errorText(e)); }
  }
  void _message(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  @override Widget build(BuildContext context) => Column(children: [
    if (_teacher) Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0), child: Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: _addGrade, icon: const Icon(Icons.add), label: const Text('Выставить оценку')))),
    Expanded(child: FutureBuilder<Map<String, dynamic>>(future: _future, builder: (context, snap) {
      if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: _sdYellow));
      if (snap.hasError) return _RetryCard(message: _errorText(snap.error), onRetry: _reload);
      final grades = _list(snap.data?['grades']);
      if (grades.isEmpty) return const _EmptyState(icon: Icons.grade_outlined, text: 'Оценок пока нет.');
      final grouped = <String, List<Map<String, dynamic>>>{};
      for (final g in grades) { final subject = (g['subject'] ?? 'Без предмета').toString(); grouped.putIfAbsent(subject, () => []).add(g); }
      return RefreshIndicator(color: _sdYellow, onRefresh: () async => _reload(), child: ListView(padding: const EdgeInsets.all(16), children: grouped.entries.map((entry) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(entry.key, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _sdYellow)), const SizedBox(height: 10), ...entry.value.map((g) => _GradeRow(item: g, showStudent: _teacher))])))).toList()));
    }))
  ]);
}

class _HomeworkTab extends StatefulWidget { final _DiaryApi api; final Map<String, dynamic> user; const _HomeworkTab({required this.api, required this.user}); @override State<_HomeworkTab> createState() => _HomeworkTabState(); }
class _HomeworkTabState extends State<_HomeworkTab> {
  late Future<Map<String, dynamic>> _future;
  @override void initState() { super.initState(); _future = widget.api.homework(); }
  void _reload() => setState(() => _future = widget.api.homework());
  bool get _teacher => widget.user['role'] == 'teacher';
  Future<void> _addHomework() async {
    final classes = _list((await widget.api.classes())['classes']); final subjects = _list((await widget.api.subjects())['subjects']);
    if (!mounted) return;
    if (classes.isEmpty || subjects.isEmpty) { _message('Добавьте классы и предметы в базе данных.'); return; }
    final result = await showDialog<Map<String, dynamic>>(context: context, builder: (_) => _AddHomeworkDialog(classes: classes, subjects: subjects));
    if (result == null) return;
    try { await widget.api.addHomework(result); _reload(); if (mounted) _message('Домашнее задание добавлено.'); }
    catch (e) { if (mounted) _message(_errorText(e)); }
  }
  void _message(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  @override Widget build(BuildContext context) => Column(children: [
    if (_teacher) Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0), child: Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: _addHomework, icon: const Icon(Icons.add), label: const Text('Задать домашку')))),
    Expanded(child: FutureBuilder<Map<String, dynamic>>(future: _future, builder: (context, snap) {
      if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: _sdYellow));
      if (snap.hasError) return _RetryCard(message: _errorText(snap.error), onRetry: _reload);
      final list = _list(snap.data?['homework']);
      if (list.isEmpty) return const _EmptyState(icon: Icons.assignment_outlined, text: 'Домашних заданий пока нет.');
      return RefreshIndicator(color: _sdYellow, onRefresh: () async => _reload(), child: ListView(padding: const EdgeInsets.all(16), children: list.map((h) => _HomeworkCard(item: h, showDelete: _teacher, onDelete: () async { try { await widget.api.deleteHomework(_int(h['id'])); _reload(); } catch (e) { _message(_errorText(e)); } })).toList()));
    }))
  ]);
}

class _AddGradeDialog extends StatefulWidget { final List<Map<String, dynamic>> students, subjects, classes; const _AddGradeDialog({required this.students, required this.subjects, required this.classes}); @override State<_AddGradeDialog> createState() => _AddGradeDialogState(); }
class _AddGradeDialogState extends State<_AddGradeDialog> {
  int? _student, _subject; String _grade = '5', _period = 'lesson'; int _quarter = 1; DateTime _date = DateTime.now(); bool _busy = false;
  @override void initState() { super.initState(); _student = _int(widget.students.first['id']); _subject = _int(widget.subjects.first['id']); }
  @override Widget build(BuildContext context) => AlertDialog(title: const Text('Новая оценка'), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
    DropdownButtonFormField<int>(value: _student, isExpanded: true, decoration: const InputDecoration(labelText: 'Ученик'), items: widget.students.map((s) => DropdownMenuItem(value: _int(s['id']), child: Text('${s['full_name'] ?? s['login']}'))).toList(), onChanged: (v) => setState(() => _student = v)),
    const SizedBox(height: 12), DropdownButtonFormField<int>(value: _subject, isExpanded: true, decoration: const InputDecoration(labelText: 'Предмет'), items: widget.subjects.map((s) => DropdownMenuItem(value: _int(s['id']), child: Text('${s['name']}'))).toList(), onChanged: (v) => setState(() => _subject = v)),
    const SizedBox(height: 12), DropdownButtonFormField<String>(value: _grade, decoration: const InputDecoration(labelText: 'Оценка'), items: ['1','2','3','4','5','НВ','СМ','Н','АЗ'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: (v) => setState(() => _grade = v ?? '5')),
    const SizedBox(height: 12), DropdownButtonFormField<String>(value: _period, decoration: const InputDecoration(labelText: 'Тип'), items: const [DropdownMenuItem(value: 'lesson', child: Text('За урок')), DropdownMenuItem(value: 'quarter', child: Text('За четверть')), DropdownMenuItem(value: 'year', child: Text('Годовая'))], onChanged: (v) => setState(() => _period = v ?? 'lesson')),
    if (_period == 'quarter') DropdownButtonFormField<int>(value: _quarter, decoration: const InputDecoration(labelText: 'Четверть'), items: [1,2,3,4].map((q) => DropdownMenuItem(value: q, child: Text('$q четверть'))).toList(), onChanged: (v) => setState(() => _quarter = v ?? 1)),
    TextButton.icon(onPressed: () async { final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime(2100)); if (d != null) setState(() => _date = d); }, icon: const Icon(Icons.calendar_today), label: Text('Дата: ${_dateLabel(_date)}')),
  ])), actions: [TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Отмена')), FilledButton(onPressed: _busy ? null : () => Navigator.pop(context, {'student_id': _student, 'subject_id': _subject, 'grade': _grade, 'period': _period, 'quarter': _period == 'quarter' ? _quarter : null, 'grade_date': _date.toIso8601String().substring(0,10)}), child: const Text('Сохранить'))]);
}

class _AddHomeworkDialog extends StatefulWidget { final List<Map<String, dynamic>> classes, subjects; const _AddHomeworkDialog({required this.classes, required this.subjects}); @override State<_AddHomeworkDialog> createState() => _AddHomeworkDialogState(); }
class _AddHomeworkDialogState extends State<_AddHomeworkDialog> {
  int? _classId, _subjectId; DateTime _date = DateTime.now(); final _description = TextEditingController();
  @override void initState() { super.initState(); _classId = _int(widget.classes.first['id']); _subjectId = _int(widget.subjects.first['id']); }
  @override void dispose() { _description.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => AlertDialog(title: const Text('Домашнее задание'), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
    DropdownButtonFormField<int>(value: _classId, isExpanded: true, decoration: const InputDecoration(labelText: 'Класс'), items: widget.classes.map((c) => DropdownMenuItem(value: _int(c['id']), child: Text('${c['name']}'))).toList(), onChanged: (v) => setState(() => _classId = v)),
    const SizedBox(height: 12), DropdownButtonFormField<int>(value: _subjectId, isExpanded: true, decoration: const InputDecoration(labelText: 'Предмет'), items: widget.subjects.map((s) => DropdownMenuItem(value: _int(s['id']), child: Text('${s['name']}'))).toList(), onChanged: (v) => setState(() => _subjectId = v)),
    TextButton.icon(onPressed: () async { final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime(2100)); if (d != null) setState(() => _date = d); }, icon: const Icon(Icons.calendar_today), label: Text('На дату: ${_dateLabel(_date)}')),
    TextField(controller: _description, minLines: 3, maxLines: 6, decoration: const InputDecoration(labelText: 'Описание задания', alignLabelWithHint: true)),
  ])), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')), FilledButton(onPressed: () { if (_description.text.trim().isEmpty) return; Navigator.pop(context, {'class_id': _classId, 'subject_id': _subjectId, 'lesson_date': _date.toIso8601String().substring(0,10), 'description': _description.text.trim()}); }, child: const Text('Создать'))]);
}

class _LessonTile extends StatelessWidget { final Map<String, dynamic> item; final bool expanded; const _LessonTile({required this.item, this.expanded = false}); @override Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(14), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(width: 42, height: 42, alignment: Alignment.center, decoration: BoxDecoration(color: _sdYellow.withOpacity(.13), borderRadius: BorderRadius.circular(12)), child: Text('${item['lesson_num'] ?? '—'}', style: const TextStyle(color: _sdYellow, fontWeight: FontWeight.bold, fontSize: 18))), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${item['subject'] ?? 'Предмет'}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)), const SizedBox(height: 4), Text('${item['time_start'] ?? ''}${item['time_end'] != null ? ' – ${item['time_end']}' : ''}', style: const TextStyle(color: _sdMuted)), if (expanded || item['cabinet'] != null) Text('Кабинет: ${item['cabinet'] ?? '—'}', style: const TextStyle(color: _sdMuted, fontSize: 12))]))]))); }

class _GradeRow extends StatelessWidget { final Map<String, dynamic> item; final bool showStudent; const _GradeRow({required this.item, this.showStudent = false}); @override Widget build(BuildContext context) { final grade = '${item['grade'] ?? '—'}'; final numeric = int.tryParse(grade); final color = numeric == 5 ? const Color(0xFF6DDB6D) : (numeric == 4 ? const Color(0xFFC8E04A) : (numeric != null && numeric <= 2 ? const Color(0xFFFF6262) : _sdYellow)); return Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [Container(width: 38, height: 38, alignment: Alignment.center, decoration: BoxDecoration(color: color.withOpacity(.16), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withOpacity(.6))), child: Text(grade, style: TextStyle(fontWeight: FontWeight.w800, color: color))), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${item['subject'] ?? 'Предмет'}', style: const TextStyle(fontWeight: FontWeight.w600)), if (showStudent && item['student'] != null) Text('${item['student']}', style: const TextStyle(color: _sdMuted, fontSize: 12)), Text('${_periodLabel(item['period'], item['quarter'])} · ${_displayDate(item['grade_date'])}', style: const TextStyle(color: _sdMuted, fontSize: 12))]))])); } }


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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.menu_book, color: _sdYellow),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${item['subject'] ?? 'Предмет'}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'На ${_displayDate(item['lesson_date'])}'
                            '${item['teacher'] != null ? ' · ${item['teacher']}' : ''}',
                        style: const TextStyle(
                          color: _sdMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (showDelete)
                  IconButton(
                    onPressed: onDelete,
                    tooltip: 'Удалить',
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.redAccent,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${item['description'] ?? ''}',
              style: const TextStyle(height: 1.45),
            ),
            if (files.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...files.map(
                    (f) => Row(
                  children: [
                    const Icon(
                      Icons.attach_file,
                      size: 18,
                      color: _sdMuted,
                    ),
                    Expanded(
                      child: Text(
                        '${f['original_name'] ?? 'Файл'}',
                        style: const TextStyle(color: _sdMuted),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget { final String title; final String? action; final VoidCallback? onTap; const _SectionTitle({required this.title, this.action, this.onTap}); @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(children: [Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _sdYellow))), if (action != null) TextButton(onPressed: onTap, child: Text(action!))])); }
class _EmptyCard extends StatelessWidget { final String text; const _EmptyCard({required this.text}); @override Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(text, style: const TextStyle(color: _sdMuted)))); }
class _EmptyState extends StatelessWidget { final IconData icon; final String text; const _EmptyState({required this.icon, required this.text}); @override Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(30), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 48, color: _sdMuted), const SizedBox(height: 12), Text(text, textAlign: TextAlign.center, style: const TextStyle(color: _sdMuted))]))); }
class _ErrorBanner extends StatelessWidget { final String message; const _ErrorBanner(this.message); @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.red.withOpacity(.1), border: Border.all(color: Colors.redAccent), borderRadius: BorderRadius.circular(10)), child: Text(message, style: const TextStyle(color: Colors.redAccent))); }
class _RetryCard extends StatelessWidget { final String message; final VoidCallback onRetry; const _RetryCard({required this.message, required this.onRetry}); @override Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.cloud_off_outlined, size: 44, color: _sdMuted), const SizedBox(height: 12), Text(message, textAlign: TextAlign.center), const SizedBox(height: 12), OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Повторить'))]))); }

List<Map<String, dynamic>> _list(dynamic value) { if (value is! List) return []; return value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList(); }
int _int(dynamic value) => value is int ? value : int.tryParse('$value') ?? 0;
String _errorText(Object? e) => e is _ApiException ? e.message : (e?.toString() ?? 'Неизвестная ошибка');
String _weekday(int day) => const ['Понедельник', 'Вторник', 'Среда', 'Четверг', 'Пятница', 'Суббота'][day - 1];
String _dateLabel(DateTime d) => '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
String _displayDate(dynamic value) { if (value == null || '$value'.isEmpty) return 'дата не указана'; final d = DateTime.tryParse('$value'); return d == null ? '$value' : _dateLabel(d); }
String _periodLabel(dynamic period, dynamic quarter) { switch (period) { case 'quarter': return 'Четверть ${quarter ?? ''}'; case 'year': return 'Годовая'; default: return 'За урок'; } }

