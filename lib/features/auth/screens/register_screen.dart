// lib/features/auth/screens/register_screen.dart

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/app_theme.dart';
import '../../../core/providers/auth_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
const RegisterScreen({super.key});

@override
ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
final _loginController = TextEditingController();
final _passwordController = TextEditingController();
final _nickController = TextEditingController();

bool _isLoading = false;

Future<void> _register() async {
final login = _loginController.text.trim();
final nick = _nickController.text.trim();
final password = _passwordController.text;

if (login.isEmpty || nick.isEmpty || password.isEmpty) {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(
content: Text('Заполни все поля'),
backgroundColor: AppTheme.error,
),
);
return;
}

setState(() {
_isLoading = true;
});

try {
final auth = ref.read(authProvider.notifier);

final success = await auth.register(
login: login,
password: password,
nick: nick,
);

if (!mounted) return;

if (success) {
Navigator.pushReplacementNamed(context, '/rooms');
} else {
final error = ref.read(authProvider).error;

ScaffoldMessenger.of(context).showSnackBar(
SnackBar(
content: Text(error ?? 'Ошибка регистрации'),
backgroundColor: AppTheme.error,
),
);
}
} catch (e) {
if (!mounted) return;

ScaffoldMessenger.of(context).showSnackBar(
SnackBar(
content: Text('Ошибка регистрации: $e'),
backgroundColor: AppTheme.error,
),
);
} finally {
if (mounted) {
setState(() {
_isLoading = false;
});
}
}
}

@override
void dispose() {
_loginController.dispose();
_passwordController.dispose();
_nickController.dispose();
super.dispose();
}

@override
Widget build(BuildContext context) {
final size = MediaQuery.sizeOf(context);

// Адаптация под маленькие экраны.
final horizontalPadding = size.width < 360 ? 16.0 : 24.0;

return Scaffold(
body: Stack(
children: [
// ==========================================================
// BACKGROUND
// ==========================================================

const _AeroBackground(),

// ==========================================================
// CONTENT
// ==========================================================

SafeArea(
child: Center(
child: SingleChildScrollView(
physics: const BouncingScrollPhysics(),
padding: EdgeInsets.symmetric(
horizontal: horizontalPadding,
vertical: 24,
),
child: ConstrainedBox(
constraints: const BoxConstraints(
maxWidth: 430,
),
child: Column(
mainAxisSize: MainAxisSize.min,
children: [
// ==================================================
// LOGO
// ==================================================

Container(
width: 76,
height: 76,
decoration: BoxDecoration(
shape: BoxShape.circle,
color: Colors.white.withValues(alpha: 0.08),
border: Border.all(
color: Colors.white.withValues(alpha: 0.14),
),
boxShadow: [
BoxShadow(
color: AppTheme.primary.withValues(alpha: 0.18),
blurRadius: 30,
spreadRadius: 2,
),
],
),
child: const Center(
child: Text(
'🐻',
style: TextStyle(fontSize: 38),
),
),
),

const SizedBox(height: 18),

const Text(
'BearCord',
textAlign: TextAlign.center,
style: TextStyle(
fontSize: 32,
fontWeight: FontWeight.w700,
letterSpacing: -0.8,
color: Colors.white,
),
),

const SizedBox(height: 6),

Text(
'Создайте свой аккаунт',
textAlign: TextAlign.center,
style: TextStyle(
fontSize: 15,
color: Colors.white.withValues(alpha: 0.55),
),
),

const SizedBox(height: 28),

// ==================================================
// GLASS WRAPPER
// ==================================================

ClipRRect(
borderRadius: BorderRadius.circular(28),
child: BackdropFilter(
filter: ImageFilter.blur(
sigmaX: 22,
sigmaY: 22,
),
child: Container(
width: double.infinity,
padding: const EdgeInsets.all(20),
decoration: BoxDecoration(
color: Colors.white.withValues(alpha: 0.065),
borderRadius: BorderRadius.circular(28),
border: Border.all(
color: Colors.white.withValues(alpha: 0.12),
width: 1,
),
boxShadow: [
BoxShadow(
color: Colors.black.withValues(alpha: 0.25),
blurRadius: 35,
offset: const Offset(0, 16),
),
],
),
child: Column(
children: [
// ========================================
// LOGIN
// ========================================

TextField(
controller: _loginController,
enabled: !_isLoading,
textInputAction: TextInputAction.next,
autocorrect: false,
textCapitalization:
TextCapitalization.none,
decoration: const InputDecoration(
labelText: 'Логин',
hintText: 'Введите логин',
prefixIcon: Icon(
Icons.person_outline_rounded,
),
),
),

const SizedBox(height: 14),

// ========================================
// NICK
// ========================================

TextField(
controller: _nickController,
enabled: !_isLoading,
textInputAction: TextInputAction.next,
decoration: const InputDecoration(
labelText: 'Имя',
hintText: 'Как вас будут видеть',
prefixIcon: Icon(
Icons.badge_outlined,
),
),
),

const SizedBox(height: 14),

// ========================================
// PASSWORD
// ========================================

TextField(
controller: _passwordController,
enabled: !_isLoading,
obscureText: true,
textInputAction: TextInputAction.done,
onSubmitted: (_) {
if (!_isLoading) {
_register();
}
},
decoration: const InputDecoration(
labelText: 'Пароль',
hintText: 'Введите пароль',
prefixIcon: Icon(
Icons.lock_outline_rounded,
),
),
),

const SizedBox(height: 20),

// ========================================
// REGISTER BUTTON
// ========================================

SizedBox(
width: double.infinity,
height: 52,
child: ElevatedButton(
onPressed:
_isLoading ? null : _register,
child: AnimatedSwitcher(
duration:
const Duration(milliseconds: 180),
child: _isLoading
? const SizedBox(
key: ValueKey('loading'),
width: 22,
height: 22,
child:
CircularProgressIndicator(
strokeWidth: 2.2,
color: Colors.black,
),
)
    : const Row(
key: ValueKey('text'),
mainAxisAlignment:
MainAxisAlignment.center,
children: [
Icon(
Icons.person_add_alt_1,
size: 19,
),
SizedBox(width: 8),
Text(
'Создать аккаунт',
style: TextStyle(
fontWeight: FontWeight.w600,
),
),
],
),
),
),
),
],
),
),
),
),

const SizedBox(height: 18),

// ==================================================
// LOGIN LINK
// ==================================================

TextButton(
onPressed: _isLoading
? null
    : () {
Navigator.pushReplacementNamed(
context,
'/login',
);
},
child: const Text(
'Уже есть аккаунт? Войти',
),
),
],
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

// ======================================================================
// AERO BACKGROUND
// ======================================================================

class _AeroBackground extends StatelessWidget {
const _AeroBackground();

@override
Widget build(BuildContext context) {
return IgnorePointer(
child: Stack(
children: [
Container(
decoration: const BoxDecoration(
gradient: LinearGradient(
begin: Alignment.topLeft,
end: Alignment.bottomRight,
colors: [
Color(0xFF171717),
Color(0xFF090909),
Color(0xFF050505),
],
),
),
),

Positioned(
top: -120,
right: -90,
child: _Glow(
size: 280,
color: AppTheme.primary.withValues(alpha: 0.13),
),
),

Positioned(
bottom: -130,
left: -100,
child: _Glow(
size: 300,
color: const Color(0xFF7C3AED).withValues(alpha: 0.08),
),
),

Positioned(
top: MediaQuery.sizeOf(context).height * 0.42,
left: -100,
child: _Glow(
size: 200,
color: const Color(0xFF0EA5E9).withValues(alpha: 0.045),
),
),
],
),
);
}
}

// ======================================================================
// GLOW
// ======================================================================

class _Glow extends StatelessWidget {
final double size;
final Color color;

const _Glow({
required this.size,
required this.color,
});

@override
Widget build(BuildContext context) {
return ImageFiltered(
imageFilter: ImageFilter.blur(
sigmaX: 55,
sigmaY: 55,
),
child: Container(
width: size,
height: size,
decoration: BoxDecoration(
shape: BoxShape.circle,
color: color,
),
),
);
}
}

