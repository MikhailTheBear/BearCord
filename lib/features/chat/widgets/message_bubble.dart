
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/app_theme.dart';
import '../../../core/models/message.dart';
import '../../../shared/widgets/user_avatar.dart';

class MessageBubble extends StatelessWidget {
final Message message;
final bool isMy;
final Function(String) onEdit;
final VoidCallback onDelete;
final Function(String) onReaction;

const MessageBubble({
super.key,
required this.message,
required this.isMy,
required this.onEdit,
required this.onDelete,
required this.onReaction,
});

static const List<String> _availableReactions = [
'👍',
'❤️',
'😂',
'😮',
'😢',
'😡',
'🔥',
'💀',
];

static const String _fileBaseUrl = 'https://hub.tailsbear.ru';

// ============================================================
// URL
// ============================================================

String _resolveUrl(String url) {
final value = url.trim();

if (value.isEmpty) return '';

if (value.startsWith('http://') ||
value.startsWith('https://')) {
return value;
}

if (value.startsWith('/')) {
return '$_fileBaseUrl$value';
}

return '$_fileBaseUrl/$value';
}

// ============================================================
// FILE TYPE
// ============================================================

String _fileExtension(String value) {
final clean = value
    .split('?')
    .first
    .split('#')
    .first
    .toLowerCase();

final dot = clean.lastIndexOf('.');

if (dot == -1 || dot == clean.length - 1) {
return '';
}

return clean.substring(dot + 1);
}

bool _isImageExtension(String value) {
const extensions = {
'jpg',
'jpeg',
'png',
'webp',
'bmp',
'gif',
'avif',
'heic',
'heif',
};

return extensions.contains(_fileExtension(value));
}

bool _isGifExtension(String value) {
return _fileExtension(value) == 'gif';
}

bool _looksLikeImage() {
final fileUrl = message.fileUrl?.trim() ?? '';
final fileName = message.fileName?.trim() ?? '';
final content = message.content.trim();

return message.isAnyImage ||
_isImageExtension(fileUrl) ||
_isImageExtension(fileName) ||
_isImageExtension(content);
}

bool _looksLikeGif() {
final fileUrl = message.fileUrl?.trim() ?? '';
final fileName = message.fileName?.trim() ?? '';
final content = message.content.trim();

return message.isGif ||
_isGifExtension(fileUrl) ||
_isGifExtension(fileName) ||
_isGifExtension(content);
}

// ============================================================
// CONTEXT MENU
// ============================================================

void _showContextMenu(BuildContext context) {
showModalBottomSheet<void>(
context: context,
backgroundColor: Colors.transparent,
barrierColor: Colors.black.withValues(
alpha: 0.45,
),
isScrollControlled: true,
useSafeArea: true,
builder: (sheetContext) {
return _MessageBottomSheet(
child: Column(
mainAxisSize: MainAxisSize.min,
children: [
const _SheetHandle(),

const SizedBox(height: 16),

const Align(
alignment: Alignment.centerLeft,
child: Padding(
padding: EdgeInsets.symmetric(
horizontal: 10,
),
child: Text(
'Реакция',
style: TextStyle(
color: AppTheme.textSecondary,
fontSize: 12,
fontWeight: FontWeight.w700,
),
),
),
),

const SizedBox(height: 9),

SizedBox(
height: 54,
child: ListView.separated(
padding: const EdgeInsets.symmetric(
horizontal: 5,
),
scrollDirection: Axis.horizontal,
itemCount: _availableReactions.length,
separatorBuilder: (_, __) {
return const SizedBox(width: 7);
},
itemBuilder: (_, index) {
final reaction =
_availableReactions[index];

return Material(
color: AppTheme.surfaceLight,
borderRadius:
BorderRadius.circular(16),
child: InkWell(
borderRadius:
BorderRadius.circular(16),
onTap: () {
Navigator.pop(sheetContext);
onReaction(reaction);
},
child: SizedBox(
width: 50,
height: 50,
child: Center(
child: Text(
reaction,
style: const TextStyle(
fontSize: 23,
),
),
),
),
),
);
},
),
),

const SizedBox(height: 12),

Divider(
height: 1,
color: AppTheme.divider.withValues(
alpha: 0.7,
),
),

const SizedBox(height: 5),

_MenuItem(
icon: Icons.copy_rounded,
title: 'Копировать',
onTap: () {
Navigator.pop(sheetContext);
_copyText(context);
},
),

if (isMy && message.isText)
_MenuItem(
icon: Icons.edit_rounded,
title: 'Редактировать',
onTap: () {
Navigator.pop(sheetContext);
_showEditDialog(context);
},
),

if (isMy)
_MenuItem(
icon: Icons.delete_outline_rounded,
title: 'Удалить',
color: AppTheme.error,
onTap: () {
Navigator.pop(sheetContext);
_showDeleteDialog(context);
},
),

_MenuItem(
icon: Icons.close_rounded,
title: 'Отмена',
color: AppTheme.textMuted,
onTap: () {
Navigator.pop(sheetContext);
},
),
],
),
);
},
);
}

// ============================================================
// COPY
// ============================================================

void _copyText(BuildContext context) {
if (message.content.isEmpty) return;

Clipboard.setData(
ClipboardData(
text: message.content,
),
);

ScaffoldMessenger.of(context)
..hideCurrentSnackBar()
..showSnackBar(
SnackBar(
content: const Row(
children: [
Icon(
Icons.check_circle_rounded,
color: Colors.white,
size: 20,
),
SizedBox(width: 10),
Text('Текст скопирован'),
],
),
backgroundColor: AppTheme.success,
behavior: SnackBarBehavior.floating,
margin: const EdgeInsets.all(16),
duration: const Duration(seconds: 1),
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(14),
),
),
);
}

// ============================================================
// EDIT DIALOG
// ============================================================

void _showEditDialog(BuildContext context) {
showDialog<void>(
context: context,
barrierColor: Colors.black.withValues(
alpha: 0.62,
),
builder: (dialogContext) {
return _EditMessageDialog(
initialText: message.content,
onSave: onEdit,
);
},
);
}

// ============================================================
// DELETE DIALOG
// ============================================================

void _showDeleteDialog(BuildContext context) {
showDialog<void>(
context: context,
barrierColor: Colors.black.withValues(
alpha: 0.60,
),
builder: (dialogContext) {
return Dialog(
backgroundColor: Colors.transparent,
elevation: 0,
insetPadding: const EdgeInsets.symmetric(
horizontal: 28,
),
child: Container(
padding: const EdgeInsets.fromLTRB(
24,
24,
24,
20,
),
decoration: BoxDecoration(
color: AppTheme.surface,
borderRadius: BorderRadius.circular(28),
border: Border.all(
color: Colors.white.withValues(
alpha: 0.06,
),
),
boxShadow: [
BoxShadow(
color: Colors.black.withValues(
alpha: 0.35,
),
blurRadius: 30,
offset: const Offset(0, 12),
),
],
),
child: Column(
mainAxisSize: MainAxisSize.min,
children: [
Container(
width: 58,
height: 58,
decoration: BoxDecoration(
color: AppTheme.error.withValues(
alpha: 0.12,
),
shape: BoxShape.circle,
),
child: const Icon(
Icons.delete_outline_rounded,
color: AppTheme.error,
size: 29,
),
),

const SizedBox(height: 18),

const Text(
'Удалить сообщение?',
textAlign: TextAlign.center,
style: TextStyle(
color: AppTheme.textPrimary,
fontSize: 20,
fontWeight: FontWeight.w700,
letterSpacing: -0.3,
),
),

const SizedBox(height: 10),

const Text(
'Сообщение будет удалено для всех '
'участников чата.',
textAlign: TextAlign.center,
style: TextStyle(
color: AppTheme.textSecondary,
fontSize: 14,
height: 1.45,
),
),

const SizedBox(height: 24),

Row(
children: [
Expanded(
child: TextButton(
onPressed: () {
Navigator.pop(
dialogContext,
);
},
style: TextButton.styleFrom(
minimumSize: const Size(
double.infinity,
50,
),
shape:
RoundedRectangleBorder(
borderRadius:
BorderRadius.circular(15),
),
),
child: const Text(
'Отмена',
style: TextStyle(
color:
AppTheme.textSecondary,
fontSize: 15,
fontWeight:
FontWeight.w600,
),
),
),
),

const SizedBox(width: 10),

Expanded(
child: ElevatedButton(
onPressed: () {
Navigator.pop(
dialogContext,
);
onDelete();
},
style:
ElevatedButton.styleFrom(
backgroundColor:
AppTheme.error,
foregroundColor:
Colors.white,
elevation: 0,
minimumSize: const Size(
double.infinity,
50,
),
shape:
RoundedRectangleBorder(
borderRadius:
BorderRadius.circular(15),
),
),
child: const Text(
'Удалить',
style: TextStyle(
fontSize: 15,
fontWeight:
FontWeight.w700,
),
),
),
),
],
),
],
),
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
return Padding(
padding: EdgeInsets.only(
left: isMy ? 54 : 10,
right: isMy ? 10 : 54,
top: 4,
bottom: 4,
),
child: Row(
crossAxisAlignment:
CrossAxisAlignment.end,
mainAxisAlignment: isMy
? MainAxisAlignment.end
    : MainAxisAlignment.start,
children: [
if (!isMy)
Padding(
padding: const EdgeInsets.only(
right: 9,
bottom: 3,
),
child: UserAvatar(
avatarUrl: message.displayAvatar,
name: message.nick,
size: 36,
showOnlineIndicator: false,
),
),

Flexible(
child: GestureDetector(
onLongPress: () {
_showContextMenu(context);
},
onSecondaryTap: () {
_showContextMenu(context);
},
child: _buildBubble(context),
),
),
],
),
);
}

// ============================================================
// BUBBLE
// ============================================================

Widget _buildBubble(BuildContext context) {
final bubbleColor = isMy
? AppTheme.primary.withValues(
alpha: 0.15,
)
    : AppTheme.surfaceLight;

final borderColor = isMy
? AppTheme.primary.withValues(
alpha: 0.18,
)
    : AppTheme.divider.withValues(
alpha: 0.75,
);

return Container(
constraints: const BoxConstraints(
maxWidth: 540,
),
padding: const EdgeInsets.fromLTRB(
14,
10,
14,
9,
),
decoration: BoxDecoration(
color: bubbleColor,
borderRadius: BorderRadius.only(
topLeft: const Radius.circular(18),
topRight: const Radius.circular(18),
bottomLeft: Radius.circular(
isMy ? 18 : 5,
),
bottomRight: Radius.circular(
isMy ? 5 : 18,
),
),
border: Border.all(
color: borderColor,
),
boxShadow: [
BoxShadow(
color: Colors.black.withValues(
alpha: 0.04,
),
blurRadius: 8,
offset: const Offset(0, 2),
),
],
),
child: Column(
crossAxisAlignment:
CrossAxisAlignment.start,
children: [
if (!isMy) ...[
Row(
mainAxisSize: MainAxisSize.min,
children: [
Container(
width: 7,
height: 7,
decoration:
const BoxDecoration(
color: AppTheme.primary,
shape: BoxShape.circle,
),
),
const SizedBox(width: 6),
Flexible(
child: Text(
message.nick,
maxLines: 1,
overflow:
TextOverflow.ellipsis,
style: const TextStyle(
color: AppTheme.primary,
fontSize: 12,
fontWeight:
FontWeight.w700,
),
),
),
],
),
const SizedBox(height: 5),
],

_buildContent(context),

const SizedBox(height: 5),

Row(
mainAxisSize: MainAxisSize.min,
children: [
Text(
_formatTime(
message.createdAt,
),
style: const TextStyle(
color: AppTheme.textMuted,
fontSize: 10,
fontWeight:
FontWeight.w500,
),
),

if (message.isEdited) ...[
const SizedBox(width: 5),
const Icon(
Icons.edit_rounded,
color: AppTheme.textMuted,
size: 10,
),
const SizedBox(width: 2),
const Text(
'изменено',
style: TextStyle(
color: AppTheme.textMuted,
fontSize: 9,
fontStyle:
FontStyle.italic,
),
),
],

if (isMy) ...[
const SizedBox(width: 5),
const Icon(
Icons.done_all_rounded,
color: AppTheme.primary,
size: 13,
),
],
],
),

if (message.reactions.isNotEmpty) ...[
const SizedBox(height: 6),
_buildReactions(),
],
],
),
);
}

// ============================================================
// CONTENT
// ============================================================

Widget _buildContent(BuildContext context) {
if (message.isDeleted) {
return const Row(
mainAxisSize: MainAxisSize.min,
children: [
Icon(
Icons.delete_outline_rounded,
color: AppTheme.textMuted,
size: 16,
),
SizedBox(width: 7),
Text(
'Сообщение удалено',
style: TextStyle(
color: AppTheme.textMuted,
fontSize: 14,
fontStyle: FontStyle.italic,
),
),
],
);
}

if (_looksLikeGif()) {
return _buildGifContent(context);
}

if (_looksLikeImage()) {
return _buildImageContent(context);
}

if (message.isVideo ||
message.isAudio ||
message.isFile) {
return _buildFileContent(context);
}

return SelectableText(
message.content,
style: const TextStyle(
color: AppTheme.textPrimary,
fontSize: 14.5,
height: 1.38,
),
);
}

// ============================================================
// IMAGE
// ============================================================

Widget _buildImageContent(
BuildContext context,
) {
final rawUrl =
message.fileUrl != null &&
message.fileUrl!.trim().isNotEmpty
? message.fileUrl!.trim()
    : message.content.trim();

final url = _resolveUrl(rawUrl);

if (url.isEmpty) {
return _buildImageError();
}

return GestureDetector(
onTap: () {
_openFullScreenImage(
context,
url,
);
},
child: ClipRRect(
borderRadius:
BorderRadius.circular(14),
child: Stack(
children: [
Image.network(
url,
width: 300,
height: 220,
fit: BoxFit.cover,
filterQuality:
FilterQuality.medium,
loadingBuilder: (
context,
child,
loadingProgress,
) {
if (loadingProgress == null) {
return child;
}

return _buildImageLoading(
loadingProgress,
);
},
errorBuilder: (
context,
error,
stackTrace,
) {
debugPrint(
'IMAGE LOAD ERROR: $error',
);
debugPrint(
'IMAGE URL: $url',
);

return _buildImageError();
},
),

_buildFullscreenButton(),
],
),
),
);
}

Widget _buildImageLoading(
ImageChunkEvent loadingProgress,
) {
return Container(
width: 300,
height: 220,
color: AppTheme.surface,
child: Center(
child: CircularProgressIndicator(
strokeWidth: 2,
color: AppTheme.primary,
value:
loadingProgress.expectedTotalBytes !=
null
? loadingProgress
    .cumulativeBytesLoaded /
loadingProgress
    .expectedTotalBytes!
    : null,
),
),
);
}

Widget _buildFullscreenButton() {
return Positioned(
right: 8,
bottom: 8,
child: Container(
width: 32,
height: 32,
decoration: BoxDecoration(
color: Colors.black.withValues(
alpha: 0.55,
),
shape: BoxShape.circle,
),
child: const Icon(
Icons.fullscreen_rounded,
color: Colors.white,
size: 18,
),
),
);
}

Widget _buildImageError() {
return Container(
width: 300,
height: 220,
decoration: BoxDecoration(
color: AppTheme.surface,
borderRadius:
BorderRadius.circular(14),
),
child: const Center(
child: Column(
mainAxisSize: MainAxisSize.min,
children: [
Icon(
Icons.broken_image_outlined,
size: 42,
color: AppTheme.textMuted,
),
SizedBox(height: 8),
Text(
'Не удалось загрузить изображение',
textAlign: TextAlign.center,
style: TextStyle(
color: AppTheme.textMuted,
fontSize: 12,
),
),
],
),
),
);
}

// ============================================================
// GIF
// ============================================================

Widget _buildGifContent(
BuildContext context,
) {
final rawUrl =
message.fileUrl != null &&
message.fileUrl!.trim().isNotEmpty
? message.fileUrl!.trim()
    : message.content.trim();

final url = _resolveUrl(rawUrl);

if (url.isEmpty) {
return _buildGifError();
}

return GestureDetector(
onTap: () {
_openFullScreenImage(
context,
url,
);
},
child: ClipRRect(
borderRadius:
BorderRadius.circular(14),
child: Stack(
children: [
Image.network(
url,
width: 300,
height: 220,
fit: BoxFit.cover,
filterQuality:
FilterQuality.medium,
loadingBuilder: (
context,
child,
loadingProgress,
) {
if (loadingProgress == null) {
return child;
}

return Container(
width: 300,
height: 220,
color: AppTheme.surface,
child: const Center(
child:
CircularProgressIndicator(
strokeWidth: 2,
color:
AppTheme.primary,
),
),
);
},
errorBuilder: (
context,
error,
stackTrace,
) {
debugPrint(
'GIF LOAD ERROR: $error',
);
debugPrint(
'GIF URL: $url',
);

return _buildGifError();
},
),

Positioned(
left: 10,
bottom: 10,
child: Container(
padding:
const EdgeInsets.symmetric(
horizontal: 8,
vertical: 5,
),
decoration: BoxDecoration(
color:
Colors.black.withValues(
alpha: 0.65,
),
borderRadius:
BorderRadius.circular(8),
),
child: const Text(
'GIF',
style: TextStyle(
color: Colors.white,
fontSize: 10,
fontWeight:
FontWeight.w800,
),
),
),
),

_buildFullscreenButton(),
],
),
),
);
}

Widget _buildGifError() {
return Container(
width: 300,
height: 220,
decoration: BoxDecoration(
color: AppTheme.surface,
borderRadius:
BorderRadius.circular(14),
),
alignment: Alignment.center,
child: const Column(
mainAxisSize: MainAxisSize.min,
children: [
Icon(
Icons.broken_image_outlined,
color: AppTheme.textMuted,
size: 36,
),
SizedBox(height: 7),
Text(
'Не удалось загрузить GIF',
style: TextStyle(
color: AppTheme.textMuted,
fontSize: 12,
),
),
],
),
);
}

// ============================================================
// FILE
// ============================================================

  Widget _buildFileContent(BuildContext context) {
    IconData icon = Icons.insert_drive_file_rounded;

    if (message.isVideo) {
      icon = Icons.movie_rounded;
    } else if (message.isAudio) {
      icon = Icons.music_note_rounded;
    }

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          final rawUrl = message.fileUrl?.trim() ?? '';

          if (rawUrl.isEmpty) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                const SnackBar(
                  content: Text('Ссылка на файл отсутствует'),
                ),
              );
            return;
          }

          final url = _resolveUrl(rawUrl);
          final uri = Uri.tryParse(url);

          if (uri == null) {
            return;
          }

          try {
            final launched = await launchUrl(
              uri,
              mode: LaunchMode.externalApplication,
            );

            if (!launched && context.mounted) {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  const SnackBar(
                    content: Text('Не удалось открыть файл'),
                  ),
                );
            }
          } catch (e) {
            debugPrint('FILE OPEN ERROR: $e');

            if (context.mounted) {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  const SnackBar(
                    content: Text('Не удалось открыть файл'),
                  ),
                );
            }
          }
        },
        child: Container(
          constraints: const BoxConstraints(
            minWidth: 240,
            maxWidth: 340,
          ),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppTheme.divider,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(
                    alpha: 0.12,
                  ),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  icon,
                  color: AppTheme.primary,
                  size: 23,
                ),
              ),

              const SizedBox(width: 11),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.fileName ?? 'Файл',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    if (message.fileSize != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _formatFileSize(message.fileSize!),
                        style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 8),

              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_downward_rounded,
                  color: AppTheme.textSecondary,
                  size: 17,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

// ============================================================
// REACTIONS
// ============================================================

Widget _buildReactions() {
final grouped =
<String, List<String>>{};

for (final reaction
in message.reactions) {
grouped
    .putIfAbsent(
reaction.reaction,
() => [],
)
    .add(reaction.nick);
}

return Wrap(
spacing: 5,
runSpacing: 5,
children:
grouped.entries.map((entry) {
final emoji = entry.key;
final users = entry.value;

return Material(
color: AppTheme.surface,
borderRadius:
BorderRadius.circular(13),
child: InkWell(
onTap: () =>
onReaction(emoji),
borderRadius:
BorderRadius.circular(13),
child: Container(
padding:
const EdgeInsets.symmetric(
horizontal: 8,
vertical: 4,
),
decoration: BoxDecoration(
borderRadius:
BorderRadius.circular(13),
border: Border.all(
color: AppTheme.divider,
),
),
child: Row(
mainAxisSize:
MainAxisSize.min,
children: [
Text(
emoji,
style:
const TextStyle(
fontSize: 13,
),
),
const SizedBox(width: 4),
Text(
'${users.length}',
style:
const TextStyle(
color:
AppTheme.textSecondary,
fontSize: 10,
fontWeight:
FontWeight.w700,
),
),
],
),
),
),
);
}).toList(),
);
}

// ============================================================
// FULLSCREEN IMAGE
// ============================================================

void _openFullScreenImage(
BuildContext context,
String url,
) {
if (url.isEmpty) return;

Navigator.of(context).push(
PageRouteBuilder(
opaque: true,
barrierColor: Colors.black,
pageBuilder: (
context,
animation,
secondaryAnimation,
) {
return _FullScreenImagePage(
url: url,
);
},
transitionsBuilder: (
context,
animation,
secondaryAnimation,
child,
) {
return FadeTransition(
opacity: animation,
child: child,
);
},
transitionDuration:
const Duration(
milliseconds: 180,
),
),
);
}

// ============================================================
// HELPERS
// ============================================================

String _formatTime(DateTime dateTime) {
return DateFormat(
'HH:mm',
).format(dateTime.toLocal());
}

String _formatFileSize(int bytes) {
if (bytes < 1024) {
return '$bytes B';
}

if (bytes < 1024 * 1024) {
return '${(bytes / 1024).toStringAsFixed(1)} KB';
}

if (bytes < 1024 * 1024 * 1024) {
return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}
}

// ================================================================
// EDIT MESSAGE DIALOG
// ================================================================

class _EditMessageDialog extends StatefulWidget {
final String initialText;
final ValueChanged<String> onSave;

const _EditMessageDialog({
required this.initialText,
required this.onSave,
});

@override
State<_EditMessageDialog> createState() =>
_EditMessageDialogState();
}

class _EditMessageDialogState
extends State<_EditMessageDialog> {
late final TextEditingController _controller;

@override
void initState() {
super.initState();

_controller = TextEditingController(
text: widget.initialText,
);
}

@override
void dispose() {
_controller.dispose();
super.dispose();
}

@override
Widget build(BuildContext context) {
return Dialog(
backgroundColor: Colors.transparent,
elevation: 0,
insetPadding:
const EdgeInsets.symmetric(
horizontal: 28,
),
child: Container(
padding:
const EdgeInsets.fromLTRB(
22,
22,
22,
18,
),
decoration: BoxDecoration(
color: AppTheme.surface,
borderRadius:
BorderRadius.circular(28),
border: Border.all(
color:
AppTheme.primary.withValues(
alpha: 0.10,
),
),
boxShadow: [
BoxShadow(
color:
Colors.black.withValues(
alpha: 0.35,
),
blurRadius: 30,
offset: const Offset(0, 12),
),
],
),
child: Column(
mainAxisSize: MainAxisSize.min,
crossAxisAlignment:
CrossAxisAlignment.stretch,
children: [
Row(
children: [
Container(
width: 46,
height: 46,
decoration: BoxDecoration(
color: AppTheme.primary
    .withValues(
alpha: 0.12,
),
borderRadius:
BorderRadius.circular(
15,
),
),
child: const Icon(
Icons.edit_rounded,
color: AppTheme.primary,
size: 23,
),
),

const SizedBox(width: 14),

const Expanded(
child: Text(
'Редактировать',
style: TextStyle(
color:
AppTheme.textPrimary,
fontSize: 20,
fontWeight:
FontWeight.w800,
letterSpacing: -0.3,
),
),
),
],
),

const SizedBox(height: 20),

TextField(
controller: _controller,
autofocus: true,
minLines: 1,
maxLines: 6,
textCapitalization:
TextCapitalization.sentences,
style: const TextStyle(
color: AppTheme.textPrimary,
fontSize: 15,
height: 1.4,
),
decoration: InputDecoration(
hintText:
'Введите новый текст...',
hintStyle:
const TextStyle(
color: AppTheme.textMuted,
),
filled: true,
fillColor:
AppTheme.surfaceLight,
contentPadding:
const EdgeInsets.symmetric(
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
borderSide: BorderSide(
color: AppTheme.primary
    .withValues(
alpha: 0.55,
),
width: 1.3,
),
),
),
),

const SizedBox(height: 18),

Row(
children: [
Expanded(
child: TextButton(
onPressed: () {
Navigator.pop(context);
},
style:
TextButton.styleFrom(
foregroundColor:
AppTheme
    .textSecondary,
padding:
const EdgeInsets
    .symmetric(
vertical: 14,
),
shape:
RoundedRectangleBorder(
borderRadius:
BorderRadius
    .circular(
15,
),
),
),
child: const Text(
'Отмена',
style: TextStyle(
fontWeight:
FontWeight.w700,
),
),
),
),

const SizedBox(width: 10),

Expanded(
child: ElevatedButton(
onPressed: () {
final text =
_controller.text
    .trim();

if (text.isEmpty) {
return;
}

widget.onSave(text);
Navigator.pop(context);
},
style:
ElevatedButton.styleFrom(
backgroundColor:
AppTheme.primary,
foregroundColor:
Colors.black,
elevation: 0,
padding:
const EdgeInsets
    .symmetric(
vertical: 14,
),
shape:
RoundedRectangleBorder(
borderRadius:
BorderRadius
    .circular(
15,
),
),
),
child: const Text(
'Сохранить',
style: TextStyle(
fontWeight:
FontWeight.w800,
),
),
),
),
],
),
],
),
),
);
}
}

// ================================================================
// MENU ITEM
// ================================================================

class _MenuItem extends StatelessWidget {
final IconData icon;
final String title;
final VoidCallback onTap;
final Color color;

const _MenuItem({
required this.icon,
required this.title,
required this.onTap,
this.color = AppTheme.textPrimary,
});

@override
Widget build(BuildContext context) {
return Material(
color: Colors.transparent,
borderRadius:
BorderRadius.circular(14),
child: InkWell(
onTap: onTap,
borderRadius:
BorderRadius.circular(14),
child: Padding(
padding:
const EdgeInsets.symmetric(
horizontal: 12,
vertical: 12,
),
child: Row(
children: [
Container(
width: 38,
height: 38,
decoration: BoxDecoration(
color:
color.withValues(
alpha: 0.09,
),
borderRadius:
BorderRadius.circular(
11,
),
),
child: Icon(
icon,
color: color,
size: 20,
),
),

const SizedBox(width: 12),

Expanded(
child: Text(
title,
style: TextStyle(
color: color,
fontSize: 14,
fontWeight:
FontWeight.w600,
),
),
),

Icon(
Icons.chevron_right_rounded,
color: AppTheme.textMuted
    .withValues(
alpha: 0.7,
),
size: 20,
),
],
),
),
),
);
}
}

// ================================================================
// BOTTOM SHEET
// ================================================================

class _MessageBottomSheet
extends StatelessWidget {
final Widget child;

const _MessageBottomSheet({
required this.child,
});

@override
Widget build(BuildContext context) {
return Container(
margin: const EdgeInsets.all(10),
decoration: BoxDecoration(
color: AppTheme.surface,
borderRadius:
BorderRadius.circular(26),
border: Border.all(
color:
AppTheme.divider.withValues(
alpha: 0.8,
),
),
boxShadow: [
BoxShadow(
color:
Colors.black.withValues(
alpha: 0.35,
),
blurRadius: 30,
offset: const Offset(0, 10),
),
],
),
child: SafeArea(
top: false,
child: Padding(
padding:
const EdgeInsets.fromLTRB(
10,
10,
10,
8,
),
child: child,
),
),
);
}
}

// ================================================================
// SHEET HANDLE
// ================================================================

class _SheetHandle extends StatelessWidget {
const _SheetHandle();

@override
Widget build(BuildContext context) {
return Center(
child: Container(
width: 38,
height: 4,
decoration: BoxDecoration(
color: AppTheme.textMuted,
borderRadius:
BorderRadius.circular(10),
),
),
);
}
}

// ================================================================
// FULLSCREEN IMAGE PAGE
// ================================================================

class _FullScreenImagePage
extends StatelessWidget {
final String url;

const _FullScreenImagePage({
required this.url,
});

@override
Widget build(BuildContext context) {
return Scaffold(
backgroundColor: Colors.black,
body: SafeArea(
child: Stack(
children: [
Positioned.fill(
child: InteractiveViewer(
minScale: 0.5,
maxScale: 5.0,
panEnabled: true,
scaleEnabled: true,
child: Center(
child: Image.network(
url,
fit: BoxFit.contain,
loadingBuilder: (
context,
child,
loadingProgress,
) {
if (loadingProgress ==
null) {
return child;
}

return const Center(
child:
CircularProgressIndicator(
color: Colors.white,
strokeWidth: 2,
),
);
},
errorBuilder: (
context,
error,
stackTrace,
) {
return const Column(
mainAxisSize:
MainAxisSize.min,
children: [
Icon(
Icons
    .broken_image_outlined,
color:
Colors.white54,
size: 64,
),
SizedBox(height: 12),
Text(
'Не удалось загрузить изображение',
style: TextStyle(
color:
Colors.white70,
fontSize: 14,
),
),
],
);
},
),
),
),
),

Positioned(
top: 10,
left: 10,
child: Material(
color: Colors.black54,
shape:
const CircleBorder(),
child: InkWell(
customBorder:
const CircleBorder(),
onTap: () {
Navigator.of(
context,
).pop();
},
child: const Padding(
padding:
EdgeInsets.all(11),
child: Icon(
Icons.close_rounded,
color: Colors.white,
size: 24,
),
),
),
),
),
],
),
),
);
}
}

