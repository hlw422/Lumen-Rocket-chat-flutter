import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../providers/chat_provider.dart';
import '../models/user.dart';

class UserTile extends StatelessWidget {
  final RCUser user;
  const UserTile({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Text(user.username.isNotEmpty ? user.username[0].toUpperCase() : '?'),
      ),
      title: Text(user.name ?? user.username),
      subtitle: Text('@${user.username}', style: const TextStyle(fontSize: 12)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: user.status == 'online' ? Colors.green : Colors.grey),
          const SizedBox(width: 8),
          const Icon(Icons.chat_bubble_outline, size: 20),
        ],
      ),
      onTap: () => _startChat(context),
    );
  }

  Future<void> _startChat(BuildContext context) async {
    final up = context.read<UserProvider>();
    final room = await up.createIm(user.username);
    if (room != null && context.mounted) {
      final chat = context.read<ChatProvider>();
      await chat.loadConversations(); // 刷新会话列表
      chat.selectConversation(room.id);
    }
  }
}
