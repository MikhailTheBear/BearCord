
class Message {
final int id;
final int userId;
final String nick;
final String? avatar;

final String type;
final String content;

final String? fileUrl;
final String? fileName;
final int? fileSize;

final int? repliedTo;

final String? editedAt;
final DateTime createdAt;

final List<MessageReaction> reactions;

const Message({
required this.id,
required this.userId,
required this.nick,
this.avatar,
required this.type,
required this.content,
this.fileUrl,
this.fileName,
this.fileSize,
this.repliedTo,
this.editedAt,
required this.createdAt,
this.reactions = const [],
});

// ============================================================
// FROM JSON
// ============================================================

factory Message.fromJson(Map<String, dynamic> json) {
return Message(
id: _toInt(json['id']),
userId: _toInt(json['user_id']),
nick: json['nick']?.toString() ?? 'Unknown',
avatar: json['avatar']?.toString(),
type: json['type']?.toString().toLowerCase() ?? 'text',
content: json['content']?.toString() ?? '',
fileUrl: json['file_url']?.toString(),
fileName: json['file_name']?.toString(),
fileSize: json['file_size'] != null
? _toInt(json['file_size'])
    : null,
repliedTo: json['replied_to'] != null
? _toInt(json['replied_to'])
    : null,
editedAt: json['edited_at']?.toString(),
createdAt: _toDateTime(json['created_at']),
reactions: _parseReactions(json['reactions']),
);
}

// ============================================================
// TO JSON
// ============================================================

Map<String, dynamic> toJson() {
return {
'id': id,
'user_id': userId,
'nick': nick,
'avatar': avatar,
'type': type,
'content': content,
'file_url': fileUrl,
'file_name': fileName,
'file_size': fileSize,
'replied_to': repliedTo,
'edited_at': editedAt,
'created_at': createdAt.toIso8601String(),
'reactions': reactions.map((r) => r.toJson()).toList(),
};
}

// ============================================================
// HELPERS
// ============================================================

static int _toInt(dynamic value) {
if (value is int) {
return value;
}

if (value is double) {
return value.toInt();
}

return int.tryParse(
value?.toString() ?? '',
) ??
0;
}

static DateTime _toDateTime(dynamic value) {
if (value is DateTime) {
return value;
}

final string = value?.toString();

if (string == null || string.isEmpty) {
return DateTime.fromMillisecondsSinceEpoch(0);
}

return DateTime.tryParse(string) ??
DateTime.fromMillisecondsSinceEpoch(0);
}

static List<MessageReaction> _parseReactions(dynamic value) {
if (value is! List) {
return [];
}

return value
    .whereType<Map>()
    .map(
(reaction) => MessageReaction.fromJson(
Map<String, dynamic>.from(reaction),
),
)
    .toList();
}

// ============================================================
// TYPE HELPERS
// ============================================================

bool get isText => type == 'text';

bool get isGif => type == 'gif';

bool get isImage => type == 'image';

bool get isFile => type == 'file';

bool get isVideo =>
type == 'video' ||
type == 'mp4' ||
type == 'mov';

bool get isAudio =>
type == 'audio' ||
type == 'mp3' ||
type == 'wav' ||
type == 'ogg';

bool get isDeleted => type == 'deleted';

bool get isEdited =>
editedAt != null && editedAt!.isNotEmpty;

bool get hasReply => repliedTo != null;

bool get hasFile =>
fileUrl != null && fileUrl!.isNotEmpty;

// ============================================================
// IMAGE DETECTION
// ============================================================

  /// Проверяет расширение файла/URL.
  bool _isImageExtension(String value) {
    var name = value.toLowerCase().trim();

    // Убираем query-параметры и fragment:
    // image.jpg?token=123 -> image.jpg
    name = name.split('?').first;
    name = name.split('#').first;

    return name.endsWith('.jpg') ||
        name.endsWith('.jpeg') ||
        name.endsWith('.png') ||
        name.endsWith('.webp') ||
        name.endsWith('.bmp') ||
        name.endsWith('.heic') ||
        name.endsWith('.heif') ||
        name.endsWith('.avif');
  }

  /// Проверяет GIF отдельно.
  bool _isGifExtension(String value) {
    var name = value.toLowerCase().trim();

    name = name.split('?').first;
    name = name.split('#').first;

    return name.endsWith('.gif');
  }

  /// Определяет, является ли файл изображением.
  ///
  /// Проверяет:
  /// 1. type
  /// 2. file_name
  /// 3. file_url
  /// 4. content
  bool get isImageFile {
    final name = fileName?.trim() ?? '';
    final url = fileUrl?.trim() ?? '';
    final text = content.trim();

    return _isImageExtension(name) ||
        _isImageExtension(url) ||
        _isImageExtension(text);
  }

  /// GIF определяется отдельно.
  bool get isGifFile {
    final name = fileName?.trim() ?? '';
    final url = fileUrl?.trim() ?? '';
    final text = content.trim();

    return _isGifExtension(name) ||
        _isGifExtension(url) ||
        _isGifExtension(text);
  }

  /// Общая проверка изображения.
  ///
  /// GIF не включаем сюда, потому что для него есть
  /// отдельный _buildGifContent().
  bool get isAnyImage {
    return isImage || isImageFile;
  }

// ============================================================
// AVATAR
// ============================================================

String get displayAvatar {
if (avatar != null && avatar!.trim().isNotEmpty) {
return avatar!.trim();
}

return '';
}

// ============================================================
// DATE HELPERS
// ============================================================

String get createdAtString =>
createdAt.toIso8601String();
}

// ============================================================
// MESSAGE REACTION
// ============================================================

class MessageReaction {
final String reaction;
final int userId;
final String nick;

const MessageReaction({
required this.reaction,
required this.userId,
required this.nick,
});

factory MessageReaction.fromJson(
Map<String, dynamic> json,
) {
return MessageReaction(
reaction: json['reaction']?.toString() ?? '',
userId: _toInt(json['user_id']),
nick: json['nick']?.toString() ?? 'Unknown',
);
}

Map<String, dynamic> toJson() {
return {
'reaction': reaction,
'user_id': userId,
'nick': nick,
};
}

static int _toInt(dynamic value) {
if (value is int) {
return value;
}

if (value is double) {
return value.toInt();
}

return int.tryParse(
value?.toString() ?? '',
) ??
0;
}
}
