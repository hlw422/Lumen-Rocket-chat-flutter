import 'package:flutter/material.dart';
import '../models/room.dart';
import '../utils/date_format.dart';

class ConversationTile extends StatelessWidget {
  final Conversation conversation;
  final bool isActive;
  final VoidCallback onTap;

  const ConversationTile({
    super.key,
    required this.conversation,
    required this.isActive,
    required this.onTap,
  });

  String get _prefix {
    switch (conversation.type) {
      case ConversationType.channel: return '#';
      case ConversationType.group: return '';
      case ConversationType.direct: return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final nameChars = conversation.name.isNotEmpty ? conversation.name.substring(0, 2).toUpperCase() : '?';
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      selected: isActive,
      selectedTileColor: colorScheme.primaryContainer.withValues(alpha: 0.3),
      leading: CircleAvatar(
        backgroundColor: isActive ? colorScheme.primary : colorScheme.surfaceContainerHighest,
        child: Text(nameChars, style: TextStyle(color: isActive ? colorScheme.onPrimary : colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold, fontSize: 14)),
      ),
      title: Row(
        children: [
          if (_prefix.isNotEmpty) ...[
            Text(_prefix, style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold)),
            const SizedBox(width: 2),
          ],
          Expanded(child: Text(conversation.name, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: isActive ? FontWeight.bold : FontWeight.normal))),
        ],
      ),
      subtitle: conversation.lastMessage.isNotEmpty
        ? Text(conversation.lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))
        : null,
      trailing: conversation.lastMessageTime != null
        ? Text(formatChatTime(conversation.lastMessageTime!), style: TextStyle(fontSize: 11, color: Theme.of(context).disabledColor))
        : null,
      onTap: onTap,
    );
  }
}
