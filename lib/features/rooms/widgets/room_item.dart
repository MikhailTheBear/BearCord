
// lib/features/rooms/widgets/room_item.dart

import 'package:flutter/material.dart';

import '../../../config/app_theme.dart';
import '../../../core/models/room.dart';
import '../../../shared/widgets/user_avatar.dart';

class RoomItem extends StatelessWidget {
final Room room;
final VoidCallback onTap;

const RoomItem({
super.key,
required this.room,
required this.onTap,
});

@override
Widget build(BuildContext context) {
final bool hasUnread = room.hasUnread;

return Padding(
padding: const EdgeInsets.symmetric(
horizontal: 10,
vertical: 3,
),
child: Material(
color: hasUnread
? AppTheme.primary.withValues(alpha: 0.07)
    : Colors.transparent,
borderRadius: BorderRadius.circular(16),
child: InkWell(
onTap: onTap,
borderRadius: BorderRadius.circular(16),
splashColor: AppTheme.primary.withValues(alpha: 0.08),
highlightColor: AppTheme.primary.withValues(alpha: 0.04),
child: Padding(
padding: const EdgeInsets.symmetric(
horizontal: 12,
vertical: 11,
),
child: Row(
children: [
// ============================================================
// AVATAR
// ============================================================

UserAvatar(
avatarUrl: room.displayAvatar,
name: room.displayName,
size: 52,
isOnline: room.isOnline,
),

const SizedBox(width: 13),

// ============================================================
// CONTENT
// ============================================================

Expanded(
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
// ------------------------------------------------------
// NAME + ONLINE / UNREAD
// ------------------------------------------------------

Row(
crossAxisAlignment: CrossAxisAlignment.center,
children: [
Expanded(
child: Text(
room.displayName,
maxLines: 1,
overflow: TextOverflow.ellipsis,
style: TextStyle(
color: AppTheme.textPrimary,
fontSize: 15.5,
fontWeight: hasUnread
? FontWeight.w700
    : FontWeight.w600,
letterSpacing: -0.1,
),
),
),

if (room.isDm && room.isOnline) ...[
const SizedBox(width: 7),
Container(
width: 7,
height: 7,
decoration: const BoxDecoration(
color: AppTheme.online,
shape: BoxShape.circle,
),
),
],
],
),

const SizedBox(height: 5),

// ------------------------------------------------------
// SUBTITLE + UNREAD COUNT
// ------------------------------------------------------

Row(
children: [
Expanded(
child: Text(
room.isDm
? (room.isOnline
? 'В сети'
    : 'Личный чат')
    : 'Групповой чат',
maxLines: 1,
overflow: TextOverflow.ellipsis,
style: TextStyle(
color: room.isDm && room.isOnline
? AppTheme.online.withValues(alpha: 0.85)
    : AppTheme.textMuted,
fontSize: 12.5,
fontWeight: FontWeight.w500,
),
),
),

if (hasUnread) ...[
const SizedBox(width: 8),

Container(
constraints: const BoxConstraints(
minWidth: 22,
minHeight: 22,
),
padding: const EdgeInsets.symmetric(
horizontal: 6,
),
alignment: Alignment.center,
decoration: BoxDecoration(
color: AppTheme.primary,
borderRadius: BorderRadius.circular(11),
),
child: Text(
room.unreadCount > 99
? '99+'
    : '${room.unreadCount}',
style: const TextStyle(
color: Colors.black,
fontSize: 11,
fontWeight: FontWeight.w800,
height: 1,
),
),
),
],
],
),
],
),
),
],
),
),
),
),
);
}
}

