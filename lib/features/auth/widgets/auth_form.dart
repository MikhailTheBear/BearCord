// lib/features/auth/widgets/auth_form.dart
import 'package:flutter/material.dart';

class AuthForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController loginController;
  final TextEditingController passwordController;
  final TextEditingController? nickController;
  final bool obscurePassword;
  final VoidCallback onToggleObscure;
  final bool isLoading;
  final VoidCallback onSubmit;
  final String submitLabel;
  final bool isLogin;

  const AuthForm({
    super.key,
    required this.formKey,
    required this.loginController,
    required this.passwordController,
    this.nickController,
    required this.obscurePassword,
    required this.onToggleObscure,
    required this.isLoading,
    required this.onSubmit,
    required this.submitLabel,
    this.isLogin = true,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        children: [
          if (!isLogin) ...[
            TextFormField(
              controller: nickController,
              decoration: const InputDecoration(
                labelText: 'Отображаемое имя',
                hintText: 'Как вас будут видеть в чате',
                prefixIcon: Icon(Icons.tag),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Введите отображаемое имя';
                }

                if (value.trim().length < 2) {
                  return 'Имя должно быть не менее 2 символов';
                }

                return null;
              },
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
          ],

          TextFormField(
            controller: loginController,
            decoration: const InputDecoration(
              labelText: 'Логин',
              hintText: 'Введите логин',
              prefixIcon: Icon(Icons.person),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Введите логин';
              }

              if (value.trim().length < 3) {
                return 'Логин должен быть не менее 3 символов';
              }

              return null;
            },
            textInputAction: TextInputAction.next,
          ),

          const SizedBox(height: 16),

          TextFormField(
            controller: passwordController,
            obscureText: obscurePassword,
            decoration: InputDecoration(
              labelText: 'Пароль',
              hintText: 'Введите пароль',
              prefixIcon: const Icon(Icons.lock),
              suffixIcon: IconButton(
                icon: Icon(
                  obscurePassword
                      ? Icons.visibility
                      : Icons.visibility_off,
                ),
                onPressed: onToggleObscure,
                tooltip: obscurePassword
                    ? 'Показать пароль'
                    : 'Скрыть пароль',
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Введите пароль';
              }

              if (value.length < 4) {
                return 'Пароль должен быть не менее 4 символов';
              }

              return null;
            },
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => onSubmit(),
          ),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: isLoading ? null : onSubmit,
              child: isLoading
                  ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.black,
                ),
              )
                  : Text(
                submitLabel,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}