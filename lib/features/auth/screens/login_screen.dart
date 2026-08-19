import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../config/app_theme.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoggingIn = false;

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_isLoggingIn) return;

    final login = _loginController.text.trim();
    final password = _passwordController.text;

    if (login.isEmpty || password.isEmpty) {
      _showError('Введите логин и пароль');
      return;
    }

    setState(() {
      _isLoggingIn = true;
    });

    final auth = ref.read(authProvider.notifier);

    final success = await auth.login(
      login,
      password,
    );

    if (!mounted) return;

    setState(() {
      _isLoggingIn = false;
    });

    if (success) {
      Navigator.pushReplacementNamed(context, '/rooms');
    } else {
      _showError(
        ref.read(authProvider).error ?? 'Ошибка входа',
      );
    }
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.error.withValues(alpha: 0.95),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // ==========================================================
          // BACKGROUND
          // ==========================================================

          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF171717),
                  Color(0xFF0D0D0D),
                  Color(0xFF080808),
                ],
              ),
            ),
          ),

          // Жёлтое свечение
          Positioned(
            top: -size.width * 0.25,
            right: -size.width * 0.2,
            child: _Glow(
              size: size.width * 0.7,
              color: AppTheme.primary.withValues(alpha: 0.16),
            ),
          ),

          Positioned(
            bottom: -size.width * 0.3,
            left: -size.width * 0.25,
            child: _Glow(
              size: size.width * 0.75,
              color: AppTheme.primary.withValues(alpha: 0.08),
            ),
          ),

          // ==========================================================
          // CONTENT
          // ==========================================================

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 24,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 440,
                  ),
                  child: AnimatedPadding(
                    duration: const Duration(milliseconds: 200),
                    padding: EdgeInsets.only(
                      bottom: keyboardOpen ? 12 : 0,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ==================================================
                        // LOGO
                        // ==================================================

                        AnimatedScale(
                          scale: keyboardOpen ? 0.85 : 1,
                          duration: const Duration(milliseconds: 200),
                          child: Column(
                            children: [
                              Container(
                                width: 82,
                                height: 82,
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withValues(
                                    alpha: 0.12,
                                  ),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppTheme.primary.withValues(
                                      alpha: 0.25,
                                    ),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.primary.withValues(
                                        alpha: 0.12,
                                      ),
                                      blurRadius: 30,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: const Center(
                                  child: Text(
                                    '🐻',
                                    style: TextStyle(fontSize: 42),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                'BearCord',
                                style: TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.7,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                'Добро пожаловать обратно',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withValues(
                                    alpha: 0.55,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(
                          height: keyboardOpen ? 20 : 34,
                        ),

                        // ==================================================
                        // GLASS WRAPPER
                        // ==================================================

                        ClipRRect(
                          borderRadius: BorderRadius.circular(30),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(
                              sigmaX: 22,
                              sigmaY: 22,
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(22),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(
                                  alpha: 0.055,
                                ),
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(
                                  color: Colors.white.withValues(
                                    alpha: 0.10,
                                  ),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(
                                      alpha: 0.28,
                                    ),
                                    blurRadius: 40,
                                    offset: const Offset(0, 18),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.stretch,
                                children: [
                                  // ========================================
                                  // TITLE
                                  // ========================================

                                  const Text(
                                    'Вход',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),

                                  const SizedBox(height: 5),

                                  Text(
                                    'Войдите в свой аккаунт BearCord',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.white.withValues(
                                        alpha: 0.5,
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 22),

                                  // ========================================
                                  // LOGIN
                                  // ========================================

                                  _GlassTextField(
                                    controller: _loginController,
                                    label: 'Логин',
                                    hint: 'Введите логин',
                                    icon: Icons.person_outline_rounded,
                                    textInputAction:
                                    TextInputAction.next,
                                  ),

                                  const SizedBox(height: 13),

                                  // ========================================
                                  // PASSWORD
                                  // ========================================

                                  _GlassTextField(
                                    controller: _passwordController,
                                    label: 'Пароль',
                                    hint: 'Введите пароль',
                                    icon: Icons.lock_outline_rounded,
                                    obscureText: _obscurePassword,
                                    textInputAction:
                                    TextInputAction.done,
                                    onSubmitted: (_) => _login(),
                                    suffixIcon: IconButton(
                                      onPressed: () {
                                        setState(() {
                                          _obscurePassword =
                                          !_obscurePassword;
                                        });
                                      },
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons
                                            .visibility_outlined
                                            : Icons
                                            .visibility_off_outlined,
                                        color: Colors.white
                                            .withValues(alpha: 0.45),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 20),

                                  // ========================================
                                  // LOGIN BUTTON
                                  // ========================================

                                  _GlassButton(
                                    onPressed:
                                    _isLoggingIn ? null : _login,
                                    loading: _isLoggingIn,
                                    child: const Text(
                                      'Войти',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 14),

                                  // ========================================
                                  // REGISTER
                                  // ========================================

                                  SizedBox(
                                    height: 48,
                                    child: TextButton(
                                      onPressed: _isLoggingIn
                                          ? null
                                          : () {
                                        Navigator.pushNamed(
                                          context,
                                          '/register',
                                        );
                                      },
                                      style: TextButton.styleFrom(
                                        foregroundColor:
                                        Colors.white.withValues(
                                          alpha: 0.7,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                          BorderRadius.circular(16),
                                        ),
                                      ),
                                      child: const Text(
                                        'Создать аккаунт',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
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
                        // FOOTER
                        // ==================================================

                        Text(
                          'BearCord',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(
                              alpha: 0.25,
                            ),
                            letterSpacing: 0.5,
                          ),
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

// ========================================================================
// GLASS TEXT FIELD
// ========================================================================

class _GlassTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final TextInputAction textInputAction;
  final Widget? suffixIcon;
  final ValueChanged<String>? onSubmitted;

  const _GlassTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.obscureText = false,
    this.textInputAction = TextInputAction.next,
    this.suffixIcon,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 15,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(
          icon,
          size: 21,
          color: AppTheme.primary.withValues(alpha: 0.8),
        ),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.045),
        labelStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.55),
        ),
        hintStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.25),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 17,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: BorderSide(
            color: AppTheme.primary.withValues(alpha: 0.65),
            width: 1.5,
          ),
        ),
      ),
    );
  }
}

// ========================================================================
// GLASS BUTTON
// ========================================================================

class _GlassButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final bool loading;

  const _GlassButton({
    required this.onPressed,
    required this.child,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(17),
          gradient: LinearGradient(
            colors: [
              AppTheme.primary,
              AppTheme.primary.withValues(alpha: 0.82),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.20),
              blurRadius: 18,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.black,
            shadowColor: Colors.transparent,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(17),
            ),
          ),
          child: loading
              ? const SizedBox(
            width: 21,
            height: 21,
            child: CircularProgressIndicator(
              strokeWidth: 2.3,
              color: Colors.black,
            ),
          )
              : child,
        ),
      ),
    );
  }
}

// ========================================================================
// GLOW
// ========================================================================

class _Glow extends StatelessWidget {
  final double size;
  final Color color;

  const _Glow({
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: [
            BoxShadow(
              color: color,
              blurRadius: size * 0.45,
              spreadRadius: size * 0.12,
            ),
          ],
        ),
      ),
    );
  }
}