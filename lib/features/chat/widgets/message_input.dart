// lib/features/chat/widgets/message_input.dart

import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../../../config/app_theme.dart';

class MessageInput extends StatefulWidget {
final TextEditingController controller;
final Function(String) onSend;
final Function(String) onSendGif;
final Function(String) onSendFile;
final String roomCode;

const MessageInput({
super.key,
required this.controller,
required this.onSend,
required this.onSendGif,
required this.onSendFile,
required this.roomCode,
});

@override
State<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput> {
final ImagePicker _picker = ImagePicker();

bool get _hasText => widget.controller.text.trim().isNotEmpty;

@override
void initState() {
super.initState();
widget.controller.addListener(_onTextChanged);
}

@override
void dispose() {
widget.controller.removeListener(_onTextChanged);
super.dispose();
}

void _onTextChanged() {
if (mounted) {
setState(() {});
}
}

void _sendMessage() {
final text = widget.controller.text.trim();

if (text.isEmpty) return;

widget.onSend(text);
widget.controller.clear();
}

// ============================================================
// ADD MENU
// ============================================================

void _showAddMenu() {
showModalBottomSheet<void>(
context: context,
backgroundColor: Colors.transparent,
barrierColor: Colors.black.withValues(alpha: 0.45),
isScrollControlled: true,
useSafeArea: true,
builder: (sheetContext) {
return _AddMenu(
onGif: () {
Navigator.pop(sheetContext);
_showGifSearch();
},
onGallery: () {
Navigator.pop(sheetContext);
_pickImage();
},
onCamera: () {
Navigator.pop(sheetContext);
_takePhoto();
},
onFile: () {
Navigator.pop(sheetContext);
_pickFile();
},
);
},
);
}

// ============================================================
// IMAGE
// ============================================================

Future<void> _pickImage() async {
try {
final file = await _picker.pickImage(
source: ImageSource.gallery,
imageQuality: 90,
);

if (file == null) return;

widget.onSendFile(file.path);
} catch (_) {
if (mounted) {
_showError('Не удалось выбрать изображение');
}
}
}

// ============================================================
// CAMERA
// ============================================================

Future<void> _takePhoto() async {
try {
final file = await _picker.pickImage(
source: ImageSource.camera,
imageQuality: 90,
);

if (file == null) return;

widget.onSendFile(file.path);
} catch (_) {
if (mounted) {
_showError('Не удалось сделать фотографию');
}
}
}

// ============================================================
// FILE
// ============================================================

Future<void> _pickFile() async {
try {
final result = await FilePicker.pickFiles(
allowMultiple: false,
withData: false,
);

if (result == null || result.files.isEmpty) return;

final file = result.files.first;

if (file.path == null) {
_showError('Не удалось получить файл');
return;
}

widget.onSendFile(file.path!);
} catch (_) {
if (mounted) {
_showError('Не удалось выбрать файл');
}
}
}

// ============================================================
// ERROR
// ============================================================

void _showError(String message) {
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
),
const SizedBox(width: 10),
Expanded(
child: Text(message),
),
],
),
backgroundColor: AppTheme.error,
behavior: SnackBarBehavior.floating,
margin: const EdgeInsets.all(16),
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(18),
),
),
);
}

// ============================================================
// GIF SEARCH
// ============================================================

void _showGifSearch() {
showModalBottomSheet<void>(
context: context,
backgroundColor: Colors.transparent,
barrierColor: Colors.black.withValues(alpha: 0.45),
isScrollControlled: true,
useSafeArea: true,
builder: (sheetContext) {
return Padding(
padding: EdgeInsets.only(
bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
),
child: GifSearchBottomSheet(
onSelect: (url) {
widget.onSendGif(url);
Navigator.pop(sheetContext);
},
),
);
},
);
}

// ============================================================
// BUILD
// ============================================================

@override
Widget build(BuildContext context) {
final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

return ClipRect(
child: BackdropFilter(
filter: ImageFilter.blur(
sigmaX: 24,
sigmaY: 24,
),
child: Container(
padding: EdgeInsets.fromLTRB(
10,
8,
10,
bottomPadding > 0 ? 8 : 10,
),
decoration: BoxDecoration(
color: AppTheme.surface.withValues(alpha: 0.72),
border: Border(
top: BorderSide(
color: Colors.white.withValues(alpha: 0.08),
width: 0.7,
),
),
boxShadow: [
BoxShadow(
color: Colors.black.withValues(alpha: 0.18),
blurRadius: 24,
offset: const Offset(0, -8),
),
],
),
child: SafeArea(
top: false,
child: LayoutBuilder(
builder: (context, constraints) {
final compact = constraints.maxWidth < 360;

return Row(
crossAxisAlignment: CrossAxisAlignment.end,
children: [
_GlassCircleButton(
icon: Icons.add_rounded,
onPressed: _showAddMenu,
tooltip: 'Вложения',
size: compact ? 40 : 44,
),

SizedBox(width: compact ? 6 : 8),

Expanded(
child: AnimatedContainer(
duration: const Duration(milliseconds: 180),
curve: Curves.easeOutCubic,
decoration: BoxDecoration(
color: Colors.white.withValues(
alpha: _hasText ? 0.075 : 0.055,
),
borderRadius: BorderRadius.circular(24),
border: Border.all(
color: _hasText
? AppTheme.primary.withValues(alpha: 0.55)
    : Colors.white.withValues(alpha: 0.09),
width: _hasText ? 1.2 : 0.8,
),
boxShadow: _hasText
? [
BoxShadow(
color: AppTheme.primary.withValues(
alpha: 0.08,
),
blurRadius: 14,
),
]
    : null,
),
child: TextField(
controller: widget.controller,
minLines: 1,
maxLines: 6,
textCapitalization:
TextCapitalization.sentences,
textInputAction: TextInputAction.newline,
style: TextStyle(
color: AppTheme.textPrimary,
fontSize: compact ? 14 : 15,
),
decoration: InputDecoration(
hintText: 'Написать сообщение...',
hintStyle: TextStyle(
color: AppTheme.textMuted,
fontSize: compact ? 14 : 15,
),
border: InputBorder.none,
contentPadding: EdgeInsets.symmetric(
horizontal: compact ? 14 : 16,
vertical: 11,
),
),
onSubmitted: (_) => _sendMessage(),
),
),
),

SizedBox(width: compact ? 6 : 8),

AnimatedScale(
scale: _hasText ? 1.0 : 0.88,
duration: const Duration(milliseconds: 180),
curve: Curves.easeOutBack,
child: _GlassCircleButton(
icon: Icons.arrow_upward_rounded,
onPressed: _hasText ? _sendMessage : null,
tooltip: 'Отправить',
filled: true,
size: compact ? 40 : 44,
),
),
],
);
},
),
),
),
),
);
}
}

// ============================================================
// GLASS ADD MENU
// ============================================================

class _AddMenu extends StatelessWidget {
final VoidCallback onGif;
final VoidCallback onGallery;
final VoidCallback onCamera;
final VoidCallback onFile;

const _AddMenu({
required this.onGif,
required this.onGallery,
required this.onCamera,
required this.onFile,
});

@override
Widget build(BuildContext context) {
return Padding(
padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
child: ClipRRect(
borderRadius: BorderRadius.circular(28),
child: BackdropFilter(
filter: ImageFilter.blur(
sigmaX: 28,
sigmaY: 28,
),
child: Container(
padding: const EdgeInsets.fromLTRB(
16,
10,
16,
18,
),
decoration: BoxDecoration(
color: AppTheme.surface.withValues(alpha: 0.82),
borderRadius: BorderRadius.circular(28),
border: Border.all(
color: Colors.white.withValues(alpha: 0.10),
),
boxShadow: [
BoxShadow(
color: Colors.black.withValues(alpha: 0.35),
blurRadius: 35,
offset: const Offset(0, 12),
),
],
),
child: SafeArea(
top: false,
child: Column(
mainAxisSize: MainAxisSize.min,
children: [
Container(
width: 40,
height: 4,
decoration: BoxDecoration(
color: Colors.white.withValues(alpha: 0.20),
borderRadius: BorderRadius.circular(4),
),
),

const SizedBox(height: 18),

const Align(
alignment: Alignment.centerLeft,
child: Text(
'Добавить',
style: TextStyle(
color: AppTheme.textPrimary,
fontSize: 20,
fontWeight: FontWeight.w700,
),
),
),

const SizedBox(height: 14),

LayoutBuilder(
builder: (context, constraints) {
final compact = constraints.maxWidth < 380;

return Row(
children: [
Expanded(
child: _AttachmentItem(
icon: Icons.gif_box_rounded,
title: 'GIF',
onTap: onGif,
compact: compact,
),
),
const SizedBox(width: 8),
Expanded(
child: _AttachmentItem(
icon: Icons.photo_rounded,
title: 'Фото',
onTap: onGallery,
compact: compact,
),
),
const SizedBox(width: 8),
Expanded(
child: _AttachmentItem(
icon: Icons.camera_alt_rounded,
title: 'Камера',
onTap: onCamera,
compact: compact,
),
),
const SizedBox(width: 8),
Expanded(
child: _AttachmentItem(
icon: Icons.insert_drive_file_rounded,
title: 'Файл',
onTap: onFile,
compact: compact,
),
),
],
);
},
),
],
),
),
),
),
),
);
}
}

// ============================================================
// ATTACHMENT ITEM
// ============================================================

class _AttachmentItem extends StatelessWidget {
final IconData icon;
final String title;
final VoidCallback onTap;
final bool compact;

const _AttachmentItem({
required this.icon,
required this.title,
required this.onTap,
required this.compact,
});

@override
Widget build(BuildContext context) {
return Material(
color: Colors.transparent,
child: InkWell(
onTap: onTap,
borderRadius: BorderRadius.circular(18),
child: Container(
padding: EdgeInsets.symmetric(
vertical: compact ? 12 : 15,
horizontal: 4,
),
decoration: BoxDecoration(
color: Colors.white.withValues(alpha: 0.055),
borderRadius: BorderRadius.circular(18),
border: Border.all(
color: Colors.white.withValues(alpha: 0.08),
),
),
child: Column(
children: [
Container(
width: compact ? 38 : 44,
height: compact ? 38 : 44,
decoration: BoxDecoration(
color: AppTheme.primary.withValues(alpha: 0.12),
shape: BoxShape.circle,
),
child: Icon(
icon,
color: AppTheme.primary,
size: compact ? 21 : 24,
),
),

SizedBox(height: compact ? 6 : 8),

Text(
title,
maxLines: 1,
overflow: TextOverflow.ellipsis,
style: TextStyle(
color: AppTheme.textPrimary,
fontSize: compact ? 11 : 12,
fontWeight: FontWeight.w600,
),
),
],
),
),
),
);
}
}

// ============================================================
// GLASS CIRCLE BUTTON
// ============================================================

class _GlassCircleButton extends StatelessWidget {
final IconData icon;
final VoidCallback? onPressed;
final String tooltip;
final bool filled;
final double size;

const _GlassCircleButton({
required this.icon,
required this.onPressed,
required this.tooltip,
this.filled = false,
this.size = 44,
});

@override
Widget build(BuildContext context) {
final isDisabled = onPressed == null;

return Tooltip(
message: tooltip,
child: ClipOval(
child: BackdropFilter(
filter: ImageFilter.blur(
sigmaX: 12,
sigmaY: 12,
),
child: Material(
color: filled
? (isDisabled
? Colors.white.withValues(alpha: 0.06)
    : AppTheme.primary)
    : Colors.white.withValues(alpha: 0.07),
shape: const CircleBorder(),
child: InkWell(
onTap: onPressed,
customBorder: const CircleBorder(),
child: SizedBox(
width: size,
height: size,
child: Icon(
icon,
color: filled && !isDisabled
? Colors.black
    : AppTheme.textSecondary,
size: size * 0.52,
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
// GIF SEARCH
// ============================================================

class GifSearchBottomSheet extends StatefulWidget {
final Function(String) onSelect;

const GifSearchBottomSheet({
super.key,
required this.onSelect,
});

@override
State<GifSearchBottomSheet> createState() =>
_GifSearchBottomSheetState();
}

class _GifSearchBottomSheetState
extends State<GifSearchBottomSheet> {
final TextEditingController _searchController =
TextEditingController();

Timer? _debounce;

List<Map<String, String>> _gifs = [];

bool _isLoading = false;
String? _error;

static const String _apiKey =
'jhD82EyTF3FvkN0RVgecuiCODExwGLVz';

@override
void dispose() {
_debounce?.cancel();
_searchController.dispose();
super.dispose();
}

// ============================================================
// SEARCH
// ============================================================

void _onSearchChanged(String value) {
_debounce?.cancel();

if (value.trim().isEmpty) {
setState(() {
_gifs = [];
_error = null;
});
return;
}

_debounce = Timer(
const Duration(milliseconds: 500),
() => _searchGif(value),
);
}

Future<void> _searchGif(String query) async {
final trimmedQuery = query.trim();

if (trimmedQuery.isEmpty) return;

FocusScope.of(context).unfocus();

setState(() {
_isLoading = true;
_error = null;
});

try {
final uri = Uri.https(
'api.giphy.com',
'/v1/gifs/search',
{
'api_key': _apiKey,
'q': trimmedQuery,
'limit': '30',
'rating': 'g',
'lang': 'ru',
},
);

final response = await http.get(uri);

if (!mounted) return;

if (response.statusCode != 200) {
setState(() {
_isLoading = false;
_error =
'GIPHY вернул ошибку ${response.statusCode}';
});
return;
}

final data = jsonDecode(response.body);
final rawGifs = data['data'];

if (rawGifs is! List) {
setState(() {
_gifs = [];
_isLoading = false;
_error = 'Некорректный ответ сервера';
});
return;
}

final gifs = <Map<String, String>>[];

for (final item in rawGifs) {
if (item is! Map) continue;

final images = item['images'];

if (images is! Map) continue;

final preview = images['fixed_width_small'];
final original = images['original'];

String? previewUrl;
String? originalUrl;

if (preview is Map) {
previewUrl = preview['url']?.toString();
}

if (original is Map) {
originalUrl = original['url']?.toString();
}

if (previewUrl == null ||
originalUrl == null) {
continue;
}

gifs.add({
'preview': previewUrl,
'url': originalUrl,
'title': item['title']?.toString() ?? 'GIF',
});
}

setState(() {
_gifs = gifs;
_isLoading = false;
});
} catch (_) {
if (!mounted) return;

setState(() {
_isLoading = false;
_error = 'Не удалось подключиться к GIPHY';
});
}
}

// ============================================================
// BUILD GIF SHEET
// ============================================================

@override
Widget build(BuildContext context) {
final height = MediaQuery.of(context).size.height;

return ClipRRect(
borderRadius: const BorderRadius.vertical(
top: Radius.circular(28),
),
child: BackdropFilter(
filter: ImageFilter.blur(
sigmaX: 28,
sigmaY: 28,
),
child: Container(
height: height * 0.78,
decoration: BoxDecoration(
color: AppTheme.surface.withValues(alpha: 0.86),
border: Border(
top: BorderSide(
color: Colors.white.withValues(alpha: 0.10),
),
),
),
child: Column(
children: [
const SizedBox(height: 10),

Container(
width: 40,
height: 4,
decoration: BoxDecoration(
color: Colors.white.withValues(alpha: 0.20),
borderRadius: BorderRadius.circular(4),
),
),

Padding(
padding: const EdgeInsets.fromLTRB(
16,
14,
10,
10,
),
child: Row(
children: [
Container(
width: 40,
height: 40,
decoration: BoxDecoration(
color: AppTheme.primary.withValues(
alpha: 0.12,
),
shape: BoxShape.circle,
),
child: const Icon(
Icons.gif_box_rounded,
color: AppTheme.primary,
size: 24,
),
),

const SizedBox(width: 10),

const Text(
'GIF',
style: TextStyle(
color: AppTheme.textPrimary,
fontSize: 20,
fontWeight: FontWeight.w700,
),
),

const Spacer(),

IconButton(
onPressed: () =>
Navigator.pop(context),
icon: const Icon(
Icons.close_rounded,
color: AppTheme.textSecondary,
),
),
],
),
),

Padding(
padding:
const EdgeInsets.symmetric(horizontal: 16),
child: TextField(
controller: _searchController,
autofocus: true,
onChanged: _onSearchChanged,
onSubmitted: _searchGif,
textInputAction:
TextInputAction.search,
style: const TextStyle(
color: AppTheme.textPrimary,
),
decoration: InputDecoration(
hintText: 'Найти GIF...',
hintStyle: const TextStyle(
color: AppTheme.textMuted,
),
prefixIcon: const Icon(
Icons.search_rounded,
color: AppTheme.textMuted,
),
suffixIcon:
_searchController.text.isNotEmpty
? IconButton(
onPressed: () {
_searchController.clear();

setState(() {
_gifs = [];
_error = null;
});
},
icon: const Icon(
Icons.close_rounded,
color:
AppTheme.textMuted,
),
)
    : null,
filled: true,
fillColor:
Colors.white.withValues(alpha: 0.055),
border: OutlineInputBorder(
borderRadius:
BorderRadius.circular(18),
borderSide: BorderSide(
color:
Colors.white.withValues(alpha: 0.08),
),
),
enabledBorder: OutlineInputBorder(
borderRadius:
BorderRadius.circular(18),
borderSide: BorderSide(
color:
Colors.white.withValues(alpha: 0.08),
),
),
focusedBorder: OutlineInputBorder(
borderRadius:
BorderRadius.circular(18),
borderSide: BorderSide(
color:
AppTheme.primary.withValues(alpha: 0.5),
),
),
),
),
),

const SizedBox(height: 12),

Expanded(
child: _buildGifContent(),
),
],
),
),
),
);
}

// ============================================================
// GIF CONTENT
// ============================================================

Widget _buildGifContent() {
if (_isLoading) {
return const Center(
child: CircularProgressIndicator(
strokeWidth: 2,
),
);
}

if (_error != null) {
return Center(
child: Padding(
padding: const EdgeInsets.all(32),
child: Column(
mainAxisSize: MainAxisSize.min,
children: [
const Icon(
Icons.cloud_off_rounded,
size: 42,
color: AppTheme.textMuted,
),

const SizedBox(height: 12),

Text(
_error!,
textAlign: TextAlign.center,
style: const TextStyle(
color: AppTheme.textSecondary,
),
),

const SizedBox(height: 16),

ElevatedButton(
onPressed: () =>
_searchGif(_searchController.text),
child: const Text('Повторить'),
),
],
),
),
);
}

if (_gifs.isEmpty) {
return const Center(
child: Column(
mainAxisSize: MainAxisSize.min,
children: [
Text(
'🐻',
style: TextStyle(fontSize: 42),
),

SizedBox(height: 12),

Text(
'Найдём подходящий GIF',
style: TextStyle(
color: AppTheme.textPrimary,
fontSize: 15,
fontWeight: FontWeight.w600,
),
),

SizedBox(height: 5),

Text(
'Начните вводить запрос выше',
style: TextStyle(
color: AppTheme.textMuted,
fontSize: 12,
),
),
],
),
);
}

return LayoutBuilder(
builder: (context, constraints) {
final columns = constraints.maxWidth < 360 ? 2 : 3;

return GridView.builder(
padding: const EdgeInsets.fromLTRB(
12,
4,
12,
20,
),
gridDelegate:
SliverGridDelegateWithFixedCrossAxisCount(
crossAxisCount: columns,
crossAxisSpacing: 6,
mainAxisSpacing: 6,
childAspectRatio: 1.15,
),
itemCount: _gifs.length,
itemBuilder: (context, index) {
final gif = _gifs[index];

final preview = gif['preview'];
final original = gif['url'];

if (preview == null || original == null) {
return const SizedBox.shrink();
}

return GestureDetector(
onTap: () => widget.onSelect(original),
child: Hero(
tag: 'gif_$index',
child: ClipRRect(
borderRadius:
BorderRadius.circular(12),
child: Stack(
fit: StackFit.expand,
children: [
Image.network(
preview,
fit: BoxFit.cover,
loadingBuilder: (
context,
child,
loadingProgress,
) {
if (loadingProgress == null) {
return child;
}

return Container(
color: AppTheme.surfaceLight,
child: const Center(
child: SizedBox(
width: 18,
height: 18,
child:
CircularProgressIndicator(
strokeWidth: 2,
),
),
),
);
},
errorBuilder: (
context,
error,
stackTrace,
) {
return Container(
color: AppTheme.surfaceLight,
child: const Icon(
Icons
    .broken_image_outlined,
color:
AppTheme.textMuted,
),
);
},
),

Positioned(
right: 6,
bottom: 6,
child: Container(
padding:
const EdgeInsets.symmetric(
horizontal: 6,
vertical: 3,
),
decoration: BoxDecoration(
color: Colors.black
    .withValues(alpha: 0.55),
borderRadius:
BorderRadius.circular(6),
border: Border.all(
color: Colors.white
    .withValues(alpha: 0.10),
),
),
child: const Text(
'GIF',
style: TextStyle(
color: Colors.white,
fontSize: 9,
fontWeight:
FontWeight.w700,
),
),
),
),
],
),
),
),
);
},
);
},
);
}
}

