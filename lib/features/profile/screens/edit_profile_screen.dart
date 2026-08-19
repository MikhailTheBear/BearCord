import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'password_screen.dart';
import '../../../config/app_theme.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../shared/widgets/user_avatar.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({
    super.key,
  });

  @override
  ConsumerState<EditProfileScreen> createState() =>
      _EditProfileScreenState();
}

class _EditProfileScreenState
    extends ConsumerState<EditProfileScreen> {
  late final TextEditingController _nicknameController;
  late final TextEditingController _loginController;

  bool _saving = false;

  @override
  void initState() {
    super.initState();

    final user = ref.read(authProvider).user;

    _nicknameController = TextEditingController(
      text: user?.nick ?? '',
    );

    _loginController = TextEditingController(
      text: user?.login ?? '',
    );
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _loginController.dispose();
    super.dispose();
  }

  // ============================================================
  // SAVE PROFILE
  // ============================================================

  Future<void> _saveProfile() async {
    if (_saving) return;

    final nickname = _nicknameController.text.trim();
    final login = _loginController.text.trim();

    // ----------------------------------------------------------
    // VALIDATION
    // ----------------------------------------------------------

    if (nickname.isEmpty) {
      _showError('Введите имя пользователя');
      return;
    }

    if (nickname.length > 32) {
      _showError(
        'Имя не должно быть длиннее 32 символов',
      );
      return;
    }

    if (login.isEmpty) {
      _showError('Введите логин');
      return;
    }

    if (login.length > 32) {
      _showError(
        'Логин не должен быть длиннее 32 символов',
      );
      return;
    }

    // Логин должен состоять только из разрешённых символов.
    final loginRegex = RegExp(
      r'^[a-zA-Z0-9_.-]+$',
    );

    if (!loginRegex.hasMatch(login)) {
      _showError(
        'Логин может содержать только латинские буквы, цифры, ., _ и -',
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final success =
      await ref.read(authProvider.notifier).updateProfile(
        login: login,
        nick: nickname,
      );

      if (!mounted) return;

      if (!success) {
        final error = ref.read(authProvider).error;

        _showError(
          error ?? 'Не удалось сохранить профиль',
        );

        return;
      }

      // --------------------------------------------------------
      // SUCCESS
      // --------------------------------------------------------

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Профиль успешно обновлён',
            ),
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.all(16),
          ),
        );

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
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
  }

  // ============================================================
  // AVATAR
  // ============================================================

  void _changeAvatar() {
    if (_saving) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'Выбор аватара добавим следующим шагом 🔥',
          ),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(16),
        ),
      );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;

    return Scaffold(
      backgroundColor: AppTheme.background,

      // ========================================================
      // APP BAR
      // ========================================================

      appBar: AppBar(
        backgroundColor: AppTheme.background,
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
            color: AppTheme.textPrimary,
          ),
        ),

        title: const Text(
          'Редактирование профиля',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),

      // ========================================================
      // BODY
      // ========================================================

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
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
              // AVATAR
              // ==================================================

              Center(
                child: GestureDetector(
                  onTap:
                  _saving ? null : _changeAvatar,
                  child: Stack(
                    children: [
                      UserAvatar(
                        avatarUrl: user?.avatar,
                        name: user?.displayName ?? '',
                        size: 100,
                        showOnlineIndicator: false,
                      ),

                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color:
                            AppTheme.primary,
                            shape:
                            BoxShape.circle,
                            border: Border.all(
                              color:
                              AppTheme.background,
                              width: 3,
                            ),
                          ),
                          child: const Icon(
                            Icons
                                .camera_alt_rounded,
                            color: Colors.black,
                            size: 17,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              const Center(
                child: Text(
                  'Изменить фотографию',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // ==================================================
              // NICKNAME
              // ==================================================

              _buildLabel(
                'Имя пользователя',
              ),

              const SizedBox(height: 8),

              _buildTextField(
                controller:
                _nicknameController,
                hint: 'Введите имя',
                icon:
                Icons.person_outline_rounded,
                maxLength: 32,
                keyboardType:
                TextInputType.name,
              ),

              const SizedBox(height: 22),

              // ==================================================
              // LOGIN
              // ==================================================

              _buildLabel('Логин'),

              const SizedBox(height: 8),

              _buildTextField(
                controller:
                _loginController,
                hint: 'Введите логин',
                icon:
                Icons.alternate_email_rounded,
                maxLength: 32,
                keyboardType:
                TextInputType.text,
                capitalization:
                TextCapitalization.none,
              ),

              const SizedBox(height: 8),

              const Text(
                'Логин используется для входа в аккаунт',
                style: TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 11,
                ),
              ),

              const SizedBox(height: 30),

              // ==================================================
              // PASSWORD / SECURITY
              // ==================================================

              Container(
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius:
                  BorderRadius.circular(17),
                ),
                child: ListTile(
                  contentPadding:
                  const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),

                  leading: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppTheme.primary
                          .withValues(
                        alpha: 0.12,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock_outline_rounded,
                      color: AppTheme.primary,
                      size: 21,
                    ),
                  ),

                  title: const Text(
                    'Пароль',
                    style: TextStyle(
                      color:
                      AppTheme.textPrimary,
                      fontSize: 15,
                      fontWeight:
                      FontWeight.w700,
                    ),
                  ),

                  subtitle: const Text(
                    'Изменить пароль аккаунта',
                    style: TextStyle(
                      color:
                      AppTheme.textMuted,
                      fontSize: 12,
                    ),
                  ),

                  trailing: const Icon(
                    Icons
                        .chevron_right_rounded,
                    color:
                    AppTheme.textMuted,
                  ),

                  onTap: _saving
                      ? null
                      : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PasswordScreen(),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 30),

              // ==================================================
              // SAVE BUTTON
              // ==================================================

              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed:
                  _saving
                      ? null
                      : _saveProfile,

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
                    'Сохранить изменения',
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
  // PASSWORD COMING SOON
  // ============================================================

  void _showPasswordComingSoon() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'Изменение пароля сделаем отдельным экраном 🔐',
          ),
          behavior:
          SnackBarBehavior.floating,
          margin: EdgeInsets.all(16),
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
        color: AppTheme.textSecondary,
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  // ============================================================
  // TEXT FIELD
  // ============================================================

  Widget _buildTextField({
    required TextEditingController
    controller,
    required String hint,
    required IconData icon,
    required int maxLength,
    required TextInputType keyboardType,
    TextCapitalization capitalization =
        TextCapitalization.sentences,
  }) {
    return TextField(
      controller: controller,

      maxLength: maxLength,

      keyboardType: keyboardType,

      textCapitalization: capitalization,

      enabled: !_saving,

      style: const TextStyle(
        color: AppTheme.textPrimary,
        fontSize: 15,
      ),

      decoration: InputDecoration(
        counterStyle: const TextStyle(
          color: AppTheme.textMuted,
          fontSize: 10,
        ),

        hintText: hint,

        hintStyle: const TextStyle(
          color: AppTheme.textMuted,
        ),

        prefixIcon: Padding(
          padding: const EdgeInsets.only(
            left: 13,
            right: 8,
          ),
          child: Icon(
            icon,
            color: AppTheme.textMuted,
            size: 21,
          ),
        ),

        prefixIconConstraints:
        const BoxConstraints(
          minWidth: 48,
          minHeight: 48,
        ),

        filled: true,

        fillColor: AppTheme.surface,

        contentPadding:
        const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),

        border: OutlineInputBorder(
          borderRadius:
          BorderRadius.circular(17),
          borderSide: BorderSide.none,
        ),

        enabledBorder:
        OutlineInputBorder(
          borderRadius:
          BorderRadius.circular(17),
          borderSide: BorderSide.none,
        ),

        focusedBorder:
        OutlineInputBorder(
          borderRadius:
          BorderRadius.circular(17),
          borderSide: BorderSide(
            color:
            AppTheme.primary.withValues(
              alpha: 0.55,
            ),
            width: 1.3,
          ),
        ),
      ),
    );
  }
}