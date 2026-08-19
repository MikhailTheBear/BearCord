
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/app_theme.dart';
import '../../../core/providers/auth_provider.dart';

class PasswordScreen extends ConsumerStatefulWidget {
const PasswordScreen({
super.key,
});

@override
ConsumerState<PasswordScreen> createState() =>
_PasswordScreenState();
}

class _PasswordScreenState
extends ConsumerState<PasswordScreen> {
late final TextEditingController _currentPasswordController;
late final TextEditingController _newPasswordController;
late final TextEditingController _confirmPasswordController;

bool _saving = false;

bool _showCurrentPassword = false;
bool _showNewPassword = false;
bool _showConfirmPassword = false;

@override
void initState() {
super.initState();

_currentPasswordController =
TextEditingController();

_newPasswordController =
TextEditingController();

_confirmPasswordController =
TextEditingController();
}

@override
void dispose() {
_currentPasswordController.dispose();
_newPasswordController.dispose();
_confirmPasswordController.dispose();

super.dispose();
}

// ============================================================
// CHANGE PASSWORD
// ============================================================

Future<void> _changePassword() async {
if (_saving) return;

final currentPassword =
_currentPasswordController.text;

final newPassword =
_newPasswordController.text;

final confirmPassword =
_confirmPasswordController.text;

// ----------------------------------------------------------
// VALIDATION
// ----------------------------------------------------------

if (currentPassword.isEmpty) {
_showError(
'Введите текущий пароль',
);
return;
}

if (newPassword.isEmpty) {
_showError(
'Введите новый пароль',
);
return;
}

if (newPassword.length < 6) {
_showError(
'Новый пароль должен содержать минимум 6 символов',
);
return;
}

if (newPassword.length > 128) {
_showError(
'Новый пароль не должен быть длиннее 128 символов',
);
return;
}

if (newPassword != confirmPassword) {
_showError(
'Пароли не совпадают',
);
return;
}

if (currentPassword == newPassword) {
_showError(
'Новый пароль должен отличаться от текущего',
);
return;
}

setState(() {
_saving = true;
});

try {
// ========================================================
// UPDATE PASSWORD
// ========================================================

  final success =
  await ref
      .read(authProvider.notifier)
      .updateProfile(
    password: newPassword,
    currentPassword: currentPassword,
  );

if (!mounted) return;

if (!success) {
final error =
ref.read(authProvider).error;

_showError(
error ??
'Не удалось изменить пароль',
);

return;
}

// ========================================================
// SUCCESS
// ========================================================

_showSuccess(
'Пароль успешно изменён',
);

await Future.delayed(
const Duration(milliseconds: 700),
);

if (!mounted) return;

Navigator.pop(context);
} catch (e) {
if (!mounted) return;

_showError(
e.toString().replaceFirst(
'Exception: ',
'',
),
);
} finally {
if (mounted) {
setState(() {
_saving = false;
});
}
}
}

// ============================================================
// ERROR
// ============================================================

void _showError(String text) {
if (!mounted) return;

ScaffoldMessenger.of(context)
..hideCurrentSnackBar()
..showSnackBar(
SnackBar(
content: Row(
children: [
const Icon(
Icons.error_outline_rounded,
color: Colors.white,
size: 20,
),
const SizedBox(width: 10),
Expanded(
child: Text(text),
),
],
),
backgroundColor:
AppTheme.error,
behavior:
SnackBarBehavior.floating,
margin:
const EdgeInsets.all(16),
duration:
const Duration(seconds: 3),
shape:
RoundedRectangleBorder(
borderRadius:
BorderRadius.circular(14),
),
),
);
}

// ============================================================
// SUCCESS
// ============================================================

void _showSuccess(String text) {
if (!mounted) return;

ScaffoldMessenger.of(context)
..hideCurrentSnackBar()
..showSnackBar(
SnackBar(
content: Row(
children: [
const Icon(
Icons.check_circle_outline_rounded,
color: Colors.black,
size: 20,
),
const SizedBox(width: 10),
Expanded(
child: Text(text),
),
],
),
backgroundColor:
AppTheme.primary,
behavior:
SnackBarBehavior.floating,
margin:
const EdgeInsets.all(16),
duration:
const Duration(seconds: 2),
shape:
RoundedRectangleBorder(
borderRadius:
BorderRadius.circular(14),
),
),
);
}

// ============================================================
// BUILD
// ============================================================

@override
Widget build(BuildContext context) {
return Scaffold(
backgroundColor:
AppTheme.background,

// ========================================================
// APP BAR
// ========================================================

appBar: AppBar(
backgroundColor:
AppTheme.background,
elevation: 0,
centerTitle: false,

leading: IconButton(
onPressed: _saving
? null
    : () {
Navigator.pop(context);
},
icon: const Icon(
Icons.arrow_back_rounded,
color:
AppTheme.textPrimary,
),
),

title: const Text(
'Изменение пароля',
style: TextStyle(
color:
AppTheme.textPrimary,
fontSize: 19,
fontWeight:
FontWeight.w800,
),
),
),

// ========================================================
// BODY
// ========================================================

body: SafeArea(
child: SingleChildScrollView(
padding:
const EdgeInsets.fromLTRB(
20,
12,
20,
30,
),
child: Column(
crossAxisAlignment:
CrossAxisAlignment.stretch,
children: [
// ==================================================
// HEADER
// ==================================================

Container(
padding:
const EdgeInsets.all(18),
decoration:
BoxDecoration(
color:
AppTheme.surface,
borderRadius:
BorderRadius.circular(
20,
),
),
child: Row(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
Container(
width: 46,
height: 46,
decoration:
BoxDecoration(
color: AppTheme
    .primary
    .withValues(
alpha: 0.12,
),
shape:
BoxShape.circle,
),
child: const Icon(
Icons
    .lock_outline_rounded,
color:
AppTheme.primary,
size: 23,
),
),
const SizedBox(
width: 14,
),
const Expanded(
child: Column(
crossAxisAlignment:
CrossAxisAlignment
    .start,
children: [
Text(
'Безопасность',
style:
TextStyle(
color: AppTheme
    .textPrimary,
fontSize: 16,
fontWeight:
FontWeight
    .w800,
),
),
SizedBox(
height: 5,
),
Text(
'Придумайте новый пароль для защиты аккаунта.',
style:
TextStyle(
color: AppTheme
    .textMuted,
fontSize: 12,
height: 1.35,
),
),
],
),
),
],
),
),

const SizedBox(
height: 28,
),

// ==================================================
// CURRENT PASSWORD
// ==================================================

_buildLabel(
'Текущий пароль',
),

const SizedBox(
height: 8,
),

_buildPasswordField(
controller:
_currentPasswordController,
hint:
'Введите текущий пароль',
obscureText:
!_showCurrentPassword,
onToggle: () {
setState(() {
_showCurrentPassword =
!_showCurrentPassword;
});
},
),

const SizedBox(
height: 22,
),

// ==================================================
// NEW PASSWORD
// ==================================================

_buildLabel(
'Новый пароль',
),

const SizedBox(
height: 8,
),

_buildPasswordField(
controller:
_newPasswordController,
hint:
'Введите новый пароль',
obscureText:
!_showNewPassword,
onToggle: () {
setState(() {
_showNewPassword =
!_showNewPassword;
});
},
),

const SizedBox(
height: 8,
),

const Text(
'Минимум 6 символов',
style: TextStyle(
color:
AppTheme.textMuted,
fontSize: 11,
),
),

const SizedBox(
height: 22,
),

// ==================================================
// CONFIRM PASSWORD
// ==================================================

_buildLabel(
'Повторите новый пароль',
),

const SizedBox(
height: 8,
),

_buildPasswordField(
controller:
_confirmPasswordController,
hint:
'Повторите новый пароль',
obscureText:
!_showConfirmPassword,
onToggle: () {
setState(() {
_showConfirmPassword =
!_showConfirmPassword;
});
},
),

const SizedBox(
height: 30,
),

// ==================================================
// SAVE
// ==================================================

SizedBox(
height: 54,
child: ElevatedButton(
onPressed:
_saving
? null
    : _changePassword,

style:
ElevatedButton.styleFrom(
backgroundColor:
AppTheme.primary,
foregroundColor:
Colors.black,
disabledBackgroundColor:
AppTheme.primary
    .withValues(
alpha: 0.35,
),
elevation: 0,
shape:
RoundedRectangleBorder(
borderRadius:
BorderRadius.circular(
17,
),
),
),

child: _saving
? const SizedBox(
width: 22,
height: 22,
child:
CircularProgressIndicator(
strokeWidth: 2.5,
color:
Colors.black,
),
)
    : const Text(
'Изменить пароль',
style: TextStyle(
fontSize: 15,
fontWeight:
FontWeight.w800,
),
),
),
),
],
),
),
),
);
}

// ============================================================
// LABEL
// ============================================================

Widget _buildLabel(String text) {
return Text(
text,
style: const TextStyle(
color:
AppTheme.textSecondary,
fontSize: 13,
fontWeight:
FontWeight.w700,
),
);
}

// ============================================================
// PASSWORD FIELD
// ============================================================

Widget _buildPasswordField({
required TextEditingController
controller,
required String hint,
required bool obscureText,
required VoidCallback onToggle,
}) {
return TextField(
controller: controller,
obscureText: obscureText,
enabled: !_saving,

style: const TextStyle(
color:
AppTheme.textPrimary,
fontSize: 15,
),

decoration:
InputDecoration(
hintText: hint,

hintStyle:
const TextStyle(
color:
AppTheme.textMuted,
),

prefixIcon:
const Padding(
padding:
EdgeInsets.only(
left: 13,
right: 8,
),
child: Icon(
Icons.lock_outline_rounded,
color:
AppTheme.textMuted,
size: 21,
),
),

prefixIconConstraints:
const BoxConstraints(
minWidth: 48,
minHeight: 48,
),

suffixIcon:
IconButton(
onPressed:
_saving
? null
    : onToggle,
icon: Icon(
obscureText
? Icons
    .visibility_off_outlined
    : Icons
    .visibility_outlined,
color:
AppTheme.textMuted,
size: 21,
),
),

filled: true,

fillColor:
AppTheme.surface,

contentPadding:
const EdgeInsets
    .symmetric(
horizontal: 16,
vertical: 15,
),

border:
OutlineInputBorder(
borderRadius:
BorderRadius.circular(
17,
),
borderSide:
BorderSide.none,
),

enabledBorder:
OutlineInputBorder(
borderRadius:
BorderRadius.circular(
17,
),
borderSide:
BorderSide.none,
),

focusedBorder:
OutlineInputBorder(
borderRadius:
BorderRadius.circular(
17,
),
borderSide:
BorderSide(
color: AppTheme.primary
    .withValues(
alpha: 0.55,
),
width: 1.3,
),
),
),
);
}
}
