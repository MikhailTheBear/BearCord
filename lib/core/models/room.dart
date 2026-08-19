class Room {
  final String code;
  final String? name;
  final String type;
  final String? avatar;

  final Participant? participant;

  final bool isOnline;
  final int unreadCount;

  const Room({
    required this.code,
    this.name,
    required this.type,
    this.avatar,
    this.participant,
    this.isOnline = false,
    this.unreadCount = 0,
  });

  // ============================================================
  // JSON → ROOM
  // ============================================================

  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString(),
      type: json['type']?.toString() ?? 'group',
      avatar: json['avatar']?.toString(),
      participant: json['participant'] is Map<String, dynamic>
          ? Participant.fromJson(
        json['participant'] as Map<String, dynamic>,
      )
          : null,
      isOnline: json['is_online'] == true,
      unreadCount: _parseInt(json['unread_count']),
    );
  }

  // ============================================================
  // ROOM → JSON
  // ============================================================

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'name': name,
      'type': type,
      'avatar': avatar,
      'participant': participant?.toJson(),
      'is_online': isOnline,
      'unread_count': unreadCount,
    };
  }

  // ============================================================
  // УДОБНЫЕ GETTERS
  // ============================================================

  bool get isDm => type == 'dm';

  bool get isGroup => type == 'group';

  bool get hasUnread => unreadCount > 0;

  String get displayName {
    // Для DM показываем ник собеседника
    if (isDm && participant != null) {
      return participant!.nick.isNotEmpty
          ? participant!.nick
          : participant!.login;
    }

    // Для группы используем название
    if (name != null && name!.trim().isNotEmpty) {
      return name!.trim();
    }

    // Если названия нет — код комнаты
    return code;
  }

  String? get displayAvatar {
    // Для DM — аватар собеседника
    if (isDm && participant != null) {
      return participant!.avatar;
    }

    // Для группы — аватар комнаты
    return avatar;
  }

  // ============================================================
  // COPY WITH
  // ============================================================

  Room copyWith({
    String? code,
    String? name,
    String? type,
    String? avatar,
    Participant? participant,
    bool? isOnline,
    int? unreadCount,
  }) {
    return Room(
      code: code ?? this.code,
      name: name ?? this.name,
      type: type ?? this.type,
      avatar: avatar ?? this.avatar,
      participant: participant ?? this.participant,
      isOnline: isOnline ?? this.isOnline,
      unreadCount: unreadCount ?? this.unreadCount,
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

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  @override
  String toString() {
    return 'Room('
        'code: $code, '
        'name: $name, '
        'type: $type, '
        'participant: $participant, '
        'isOnline: $isOnline, '
        'unreadCount: $unreadCount'
        ')';
  }
}

// ============================================================
// PARTICIPANT — СОБЕСЕДНИК В DM
// ============================================================

class Participant {
  final int id;
  final String nick;
  final String login;
  final String? avatar;
  final String status;

  const Participant({
    required this.id,
    required this.nick,
    required this.login,
    this.avatar,
    this.status = 'offline',
  });

  factory Participant.fromJson(Map<String, dynamic> json) {
    return Participant(
      id: _parseInt(json['id']),
      nick: json['nick']?.toString() ?? '',
      login: json['login']?.toString() ?? '',
      avatar: json['avatar']?.toString(),
      status: json['status']?.toString() ?? 'offline',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nick': nick,
      'login': login,
      'avatar': avatar,
      'status': status,
    };
  }

  bool get isOnline => status == 'online';

  static int _parseInt(dynamic value) {
    if (value is int) return value;

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  @override
  String toString() {
    return 'Participant('
        'id: $id, '
        'nick: $nick, '
        'login: $login, '
        'status: $status'
        ')';
  }
}