
// lib/config/app_theme.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

/// ============================================================
/// 🐻 BEARCORD — LIQUID AERO THEME
/// ============================================================
///
/// Основная идея:
/// • Liquid Glass / Aero
/// • Чёрный полупрозрачный интерфейс
/// • BearCord Yellow как акцент
/// • Мягкие границы и большие скругления
/// • Подготовлено для Glassmorphism widgets
///
/// Важно:
/// Сам blur создаётся через BackdropFilter в reusable widgets.
/// ThemeData здесь отвечает за цвета, типографику и компоненты.
/// ============================================================

class AppTheme {
// ============================================================
// 🐻 BEARCORD COLORS
// ============================================================

/// Главный цвет BearCord.
static const Color primary = Color(0xFFFFD000);

/// Фон приложения.
static const Color background = Color(0xFF070707);

/// Основная glass-поверхность.
static const Color surface = Color(0xFF151515);

/// Более светлая поверхность.
static const Color surfaceLight = Color(0xFF202020);

/// Очень светлая поверхность для hover/pressed.
static const Color surfaceBright = Color(0xFF292929);

/// Основной текст.
static const Color textPrimary = Color(0xFFF7F7F7);

/// Вторичный текст.
static const Color textSecondary = Color(0xFFAAAAAA);

/// Приглушённый текст.
static const Color textMuted = Color(0xFF6F6F6F);

/// Стандартная glass-граница.
static const Color glassBorder = Color(0x1FFFFFFF);

/// Более заметная glass-граница.
static const Color glassBorderStrong = Color(0x33FFFFFF);

/// Старый divider — оставляем для совместимости.
static const Color divider = Color(0x26FFD000);

/// Online.
static const Color online = Color(0xFF4ADE80);

/// Offline.
static const Color offline = Color(0xFF666666);

/// Ошибка.
static const Color error = Color(0xFFFF4D5A);

/// Успех.
static const Color success = Color(0xFF4ADE80);

/// Информация.
static const Color info = Color(0xFF60A5FA);

// ============================================================
// 🫧 GLASS COLORS
// ============================================================

/// Основное стекло.
static Color get glass => Colors.white.withValues(alpha: 0.055);

/// Более яркое стекло.
static Color get glassLight => Colors.white.withValues(alpha: 0.085);

/// Стекло для активных элементов.
static Color get glassActive => primary.withValues(alpha: 0.12);

/// Очень лёгкая белая подсветка.
static Color get glassHighlight =>
Colors.white.withValues(alpha: 0.12);

// ============================================================
// 🌑 THEME
// ============================================================

static ThemeData get darkTheme {
return ThemeData(
useMaterial3: true,
brightness: Brightness.dark,

// ----------------------------------------------------------
// COLOR SCHEME
// ----------------------------------------------------------

colorScheme: const ColorScheme.dark(
primary: primary,
secondary: primary,
surface: surface,
error: error,

onPrimary: Colors.black,
onSecondary: Colors.black,
onSurface: textPrimary,
onError: Colors.white,
),

primaryColor: primary,
scaffoldBackgroundColor: background,

// ----------------------------------------------------------
// APP BAR
// ----------------------------------------------------------

appBarTheme: const AppBarTheme(
backgroundColor: Colors.transparent,
surfaceTintColor: Colors.transparent,
foregroundColor: textPrimary,
elevation: 0,
scrolledUnderElevation: 0,
centerTitle: false,

titleTextStyle: TextStyle(
color: textPrimary,
fontSize: 20,
fontWeight: FontWeight.w700,
letterSpacing: -0.3,
),

iconTheme: IconThemeData(
color: textPrimary,
size: 22,
),
),

// ----------------------------------------------------------
// CARDS
// ----------------------------------------------------------

cardTheme: CardThemeData(
color: glass,
surfaceTintColor: Colors.transparent,
elevation: 0,

margin: EdgeInsets.zero,

shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(22),

side: BorderSide(
color: glassBorder,
width: 1,
),
),
),

// ----------------------------------------------------------
// ELEVATED BUTTON
// ----------------------------------------------------------

elevatedButtonTheme: ElevatedButtonThemeData(
style: ElevatedButton.styleFrom(
backgroundColor: primary,
foregroundColor: Colors.black,

elevation: 0,
shadowColor: Colors.transparent,

minimumSize: const Size(0, 50),

padding: const EdgeInsets.symmetric(
horizontal: 22,
vertical: 14,
),

shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(16),
),

textStyle: const TextStyle(
fontSize: 15,
fontWeight: FontWeight.w700,
),
),
),

// ----------------------------------------------------------
// OUTLINED BUTTON
// ----------------------------------------------------------

outlinedButtonTheme: OutlinedButtonThemeData(
style: OutlinedButton.styleFrom(
foregroundColor: textPrimary,

minimumSize: const Size(0, 48),

padding: const EdgeInsets.symmetric(
horizontal: 20,
vertical: 13,
),

side: const BorderSide(
color: glassBorderStrong,
width: 1,
),

shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(16),
),

textStyle: const TextStyle(
fontSize: 15,
fontWeight: FontWeight.w600,
),
),
),

// ----------------------------------------------------------
// TEXT BUTTON
// ----------------------------------------------------------

textButtonTheme: TextButtonThemeData(
style: TextButton.styleFrom(
foregroundColor: primary,

padding: const EdgeInsets.symmetric(
horizontal: 14,
vertical: 10,
),

shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(14),
),

textStyle: const TextStyle(
fontSize: 14,
fontWeight: FontWeight.w600,
),
),
),

// ----------------------------------------------------------
// INPUT FIELDS
// ----------------------------------------------------------

inputDecorationTheme: InputDecorationTheme(
filled: true,

fillColor: glass,

contentPadding: const EdgeInsets.symmetric(
horizontal: 18,
vertical: 16,
),

hintStyle: const TextStyle(
color: textMuted,
fontSize: 15,
),

labelStyle: const TextStyle(
color: textSecondary,
fontSize: 14,
),

floatingLabelStyle: const TextStyle(
color: primary,
fontWeight: FontWeight.w600,
),

prefixIconColor: textSecondary,
suffixIconColor: textSecondary,

border: OutlineInputBorder(
borderRadius: BorderRadius.circular(17),

borderSide: const BorderSide(
color: glassBorder,
width: 1,
),
),

enabledBorder: OutlineInputBorder(
borderRadius: BorderRadius.circular(17),

borderSide: const BorderSide(
color: glassBorder,
width: 1,
),
),

focusedBorder: OutlineInputBorder(
borderRadius: BorderRadius.circular(17),

borderSide: const BorderSide(
color: primary,
width: 1.5,
),
),

errorBorder: OutlineInputBorder(
borderRadius: BorderRadius.circular(17),

borderSide: const BorderSide(
color: error,
width: 1,
),
),

focusedErrorBorder: OutlineInputBorder(
borderRadius: BorderRadius.circular(17),

borderSide: const BorderSide(
color: error,
width: 1.5,
),
),
),

// ----------------------------------------------------------
// TEXT
// ----------------------------------------------------------

textTheme: const TextTheme(
displayLarge: TextStyle(
fontSize: 34,
fontWeight: FontWeight.w800,
letterSpacing: -1.0,
),

displayMedium: TextStyle(
fontSize: 30,
fontWeight: FontWeight.w800,
letterSpacing: -0.8,
),

displaySmall: TextStyle(
fontSize: 26,
fontWeight: FontWeight.w700,
letterSpacing: -0.5,
),

headlineLarge: TextStyle(
fontSize: 24,
fontWeight: FontWeight.w700,
letterSpacing: -0.4,
),

headlineMedium: TextStyle(
fontSize: 21,
fontWeight: FontWeight.w700,
letterSpacing: -0.2,
),

headlineSmall: TextStyle(
fontSize: 18,
fontWeight: FontWeight.w700,
),

titleLarge: TextStyle(
fontSize: 18,
fontWeight: FontWeight.w700,
),

titleMedium: TextStyle(
fontSize: 16,
fontWeight: FontWeight.w600,
),

titleSmall: TextStyle(
fontSize: 14,
fontWeight: FontWeight.w600,
),

bodyLarge: TextStyle(
fontSize: 16,
fontWeight: FontWeight.w400,
),

bodyMedium: TextStyle(
fontSize: 14,
fontWeight: FontWeight.w400,
),

bodySmall: TextStyle(
fontSize: 12,
fontWeight: FontWeight.w400,
color: textSecondary,
),

labelLarge: TextStyle(
fontSize: 14,
fontWeight: FontWeight.w700,
),

labelMedium: TextStyle(
fontSize: 12,
fontWeight: FontWeight.w600,
),

labelSmall: TextStyle(
fontSize: 11,
fontWeight: FontWeight.w600,
),
),

// ----------------------------------------------------------
// DIVIDERS
// ----------------------------------------------------------

dividerTheme: const DividerThemeData(
color: divider,
thickness: 1,
space: 1,
),

dividerColor: divider,

// ----------------------------------------------------------
// ICONS
// ----------------------------------------------------------

iconTheme: const IconThemeData(
color: textPrimary,
size: 22,
),

// ----------------------------------------------------------
// LIST TILES
// ----------------------------------------------------------

listTileTheme: const ListTileThemeData(
contentPadding: EdgeInsets.symmetric(
horizontal: 16,
vertical: 4,
),

minVerticalPadding: 8,

iconColor: textSecondary,
textColor: textPrimary,

shape: RoundedRectangleBorder(
borderRadius: BorderRadius.all(
Radius.circular(18),
),
),
),

// ----------------------------------------------------------
// DIALOGS
// ----------------------------------------------------------

dialogTheme: DialogThemeData(
backgroundColor: surface.withValues(alpha: 0.94),
surfaceTintColor: Colors.transparent,

elevation: 0,

shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(26),

side: BorderSide(
color: glassBorderStrong,
width: 1,
),
),

titleTextStyle: const TextStyle(
color: textPrimary,
fontSize: 20,
fontWeight: FontWeight.w700,
),

contentTextStyle: const TextStyle(
color: textSecondary,
fontSize: 14,
height: 1.4,
),
),

// ----------------------------------------------------------
// BOTTOM SHEETS
// ----------------------------------------------------------

bottomSheetTheme: BottomSheetThemeData(
backgroundColor: surface.withValues(alpha: 0.96),
surfaceTintColor: Colors.transparent,

elevation: 0,

shape: const RoundedRectangleBorder(
borderRadius: BorderRadius.vertical(
top: Radius.circular(28),
),
),

showDragHandle: true,

dragHandleColor: Colors.white24,
),

// ----------------------------------------------------------
// SNACKBARS
// ----------------------------------------------------------

snackBarTheme: SnackBarThemeData(
backgroundColor: surfaceLight,

elevation: 0,

behavior: SnackBarBehavior.floating,

shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(16),

side: const BorderSide(
color: glassBorder,
),
),

contentTextStyle: const TextStyle(
color: textPrimary,
fontSize: 14,
fontWeight: FontWeight.w500,
),
),

// ----------------------------------------------------------
// SWITCH
// ----------------------------------------------------------

switchTheme: SwitchThemeData(
thumbColor: WidgetStateProperty.resolveWith(
(states) {
if (states.contains(WidgetState.selected)) {
return Colors.black;
}

return textSecondary;
},
),

trackColor: WidgetStateProperty.resolveWith(
(states) {
if (states.contains(WidgetState.selected)) {
return primary;
}

return surfaceBright;
},
),

trackOutlineColor: WidgetStateProperty.all(
glassBorderStrong,
),
),

// ----------------------------------------------------------
// CHECKBOX
// ----------------------------------------------------------

checkboxTheme: CheckboxThemeData(
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(6),
),

side: const BorderSide(
color: textSecondary,
width: 1.5,
),

fillColor: WidgetStateProperty.resolveWith(
(states) {
if (states.contains(WidgetState.selected)) {
return primary;
}

return Colors.transparent;
},
),

checkColor: WidgetStateProperty.all(
Colors.black,
),
),

// ----------------------------------------------------------
// PROGRESS INDICATOR
// ----------------------------------------------------------

progressIndicatorTheme: const ProgressIndicatorThemeData(
color: primary,
linearTrackColor: surfaceLight,
circularTrackColor: surfaceLight,
),

// ----------------------------------------------------------
// SCROLLBAR
// ----------------------------------------------------------

scrollbarTheme: ScrollbarThemeData(
thumbColor: WidgetStateProperty.all(
primary.withValues(alpha: 0.65),
),

trackColor: WidgetStateProperty.all(
Colors.white.withValues(alpha: 0.03),
),

thickness: WidgetStateProperty.all(4),

radius: const Radius.circular(10),

minThumbLength: 40,
),

// ----------------------------------------------------------
// PAGE TRANSITIONS
// ----------------------------------------------------------

pageTransitionsTheme: const PageTransitionsTheme(
builders: {
TargetPlatform.android:
FadeForwardsPageTransitionsBuilder(),
TargetPlatform.iOS:
CupertinoPageTransitionsBuilder(),
TargetPlatform.macOS:
CupertinoPageTransitionsBuilder(),
},
),
);
}

// ============================================================
// 🫧 GLASS DECORATIONS
// ============================================================

/// Основная glass-панель.
static BoxDecoration get glassDecoration {
return BoxDecoration(
color: glass,

borderRadius: BorderRadius.circular(22),

border: Border.all(
color: glassBorderStrong,
width: 1,
),
);
}

/// Активная glass-панель BearCord.
static BoxDecoration get glassActiveDecoration {
return BoxDecoration(
color: glassActive,

borderRadius: BorderRadius.circular(22),

border: Border.all(
color: primary.withValues(alpha: 0.25),
width: 1,
),
);
}

/// Светлая glass-панель.
static BoxDecoration get glassLightDecoration {
return BoxDecoration(
color: glassLight,

borderRadius: BorderRadius.circular(22),

border: Border.all(
color: glassHighlight,
width: 1,
),
);
}

// ============================================================
// 💬 MESSAGE BUBBLES
// ============================================================

/// Сообщение текущего пользователя.
static BoxDecoration get messageBubbleMy {
return BoxDecoration(
color: primary.withValues(alpha: 0.13),

border: Border.all(
color: primary.withValues(alpha: 0.22),
width: 1,
),

borderRadius: const BorderRadius.only(
topLeft: Radius.circular(20),
topRight: Radius.circular(20),
bottomLeft: Radius.circular(20),
bottomRight: Radius.circular(6),
),
);
}

/// Сообщение другого пользователя.
static BoxDecoration get messageBubbleOther {
return BoxDecoration(
color: Colors.white.withValues(alpha: 0.055),

border: Border.all(
color: Colors.white.withValues(alpha: 0.09),
width: 1,
),

borderRadius: const BorderRadius.only(
topLeft: Radius.circular(20),
topRight: Radius.circular(20),
bottomLeft: Radius.circular(6),
bottomRight: Radius.circular(20),
),
);
}

// ============================================================
// ✏️ CHAT INPUT
// ============================================================

static BoxDecoration get inputField {
return BoxDecoration(
color: Colors.white.withValues(alpha: 0.065),

borderRadius: BorderRadius.circular(26),

border: Border.all(
color: Colors.white.withValues(alpha: 0.11),
width: 1,
),
);
}

// ============================================================
// 🃏 CARDS
// ============================================================

static BoxDecoration get cardDecoration {
return BoxDecoration(
color: glass,

borderRadius: BorderRadius.circular(22),

border: Border.all(
color: glassBorderStrong,
width: 1,
),
);
}

// ============================================================
// 👤 AVATAR
// ============================================================

static Decoration get avatarDecoration {
return BoxDecoration(
shape: BoxShape.circle,

border: Border.all(
color: primary.withValues(alpha: 0.35),
width: 2,
),
);
}

// ============================================================
// 🟢 ONLINE AVATAR
// ============================================================

static Decoration get onlineAvatarDecoration {
return BoxDecoration(
shape: BoxShape.circle,

border: Border.all(
color: online.withValues(alpha: 0.8),
width: 2,
),

boxShadow: [
BoxShadow(
color: online.withValues(alpha: 0.22),
blurRadius: 10,
spreadRadius: 1,
),
],
);
}

// ============================================================
// 🟡 PRIMARY GLOW
// ============================================================

static List<BoxShadow> get primaryGlow {
return [
BoxShadow(
color: primary.withValues(alpha: 0.18),
blurRadius: 22,
spreadRadius: 1,
),
];
}

// ============================================================
// 🌫️ GLASS SHADOW
// ============================================================

static List<BoxShadow> get glassShadow {
return [
BoxShadow(
color: Colors.black.withValues(alpha: 0.28),
blurRadius: 28,
offset: const Offset(0, 10),
),
];
}

// ============================================================
// 🫧 GLASS BLUR
// ============================================================

/// Стандартный blur для glass-компонентов.
static ImageFilter get glassBlur {
return ImageFilter.blur(
sigmaX: 18,
sigmaY: 18,
);
}

/// Более сильный blur для крупных панелей.
static ImageFilter get strongGlassBlur {
return ImageFilter.blur(
sigmaX: 28,
sigmaY: 28,
);
}
}
