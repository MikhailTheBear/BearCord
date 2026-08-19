
class User {
final int id;
final String login;
final String nick;
final String? avatar;
final String? bio;
final String status;
final String? lastSeen;

const User({
required this.id,
required this.login,
required this.nick,
this.avatar,
this.bio,
this.status = 'offline',
this.lastSeen,
});

// ============================================================
// JSON → USER
// ============================================================

factory User.fromJson(Map<String, dynamic> json) {
return User(
id: _parseInt(json['id']),
login: json['login']?.toString() ?? '',
nick: json['nick']?.toString() ?? '',
avatar: _parseNullableString(json['avatar']),
bio: _parseNullableString(json['bio']),
status: json['status']?.toString() ?? 'offline',
lastSeen: _parseNullableString(json['last_seen']),
);
}

// ============================================================
// USER → JSON
// ============================================================

Map<String, dynamic> toJson() {
return {
'id': id,
'login': login,
'nick': nick,
'avatar': avatar,
'bio': bio,
'status': status,
'last_seen': lastSeen,
};
}

// ============================================================
// GETTERS
// ============================================================

String get displayName {
if (nick.trim().isNotEmpty) {
return nick.trim();
}

return login;
}

String get displayAvatar {
if (avatar != null && avatar!.trim().isNotEmpty) {
return avatar!;
}

return '';
}

String get displayBio {
if (bio != null && bio!.trim().isNotEmpty) {
return bio!.trim();
}

return '';
}

bool get isOnline => status == 'online';

// ============================================================
// COPY WITH
// ============================================================

User copyWith({
int? id,
String? login,
String? nick,
String? avatar,
String? bio,
String? status,
String? lastSeen,
}) {
return User(
id: id ?? this.id,
login: login ?? this.login,
nick: nick ?? this.nick,
avatar: avatar ?? this.avatar,
bio: bio ?? this.bio,
status: status ?? this.status,
lastSeen: lastSeen ?? this.lastSeen,
);
}

// ============================================================
// HELPERS
// ============================================================

static int _parseInt(dynamic value) {
if (value is int) return value;

if (value is num) {
return value.toInt();
}

return int.tryParse(
value?.toString() ?? '',
) ??
0;
}

static String? _parseNullableString(dynamic value) {
if (value == null) return null;

final string = value.toString().trim();

if (string.isEmpty) return null;

return string;
}

// ============================================================
// DEBUG
// ============================================================

@override
String toString() {
return 'User('
'id: $id, '
'login: $login, '
'nick: $nick, '
'bio: $bio, '
'status: $status'
')';
}
}

