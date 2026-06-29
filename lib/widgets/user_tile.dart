import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../providers/chat_provider.dart';
import '../models/user.dart';
import '../models/room.dart';

class UserTile extends StatefulWidget {
  final RCUser user;
  const UserTile({super.key, required this.user});

  @override State<UserTile> createState() => _UserTileState();
}

class _UserTileState extends State<UserTile> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Text(widget.user.username.isNotEmpty ? widget.user.username[0].toUpperCase() : '?'),
      ),
      title: Text(widget.user.name ?? widget.user.username),
      subtitle: Text('@${widget.user.username}', style: const TextStyle(fontSize: 12)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: widget.user.status == 'online' ? Colors.green : Colors.grey),
          const SizedBox(width: 8),
          _loading
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.chat_bubble_outline, size: 20),
        ],
      ),
      enabled: !_loading,
      onTap: _loading ? null : () => _startChat(context),
    );
  }

  Future<void> _startChat(BuildContext context) async {
    setState(() => _loading = true);
    try {
      final up = context.read<UserProvider>();
      final room = await up.createIm(widget.user.username);
      if (!mounted) return;
      if (room != null) {
        final chat = context.read<ChatProvider>();
        await chat.loadConversations();
        await chat.selectConversation(room.id, type: ConversationType.direct);
        if (mounted) setState(() => _loading = false);
      } else {
        setState(() => _loading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('无法与 @${widget.user.username} 发起私聊'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('网络异常: ${e.toString().length > 50 ? e.toString().substring(0, 50) : e}'), backgroundColor: Colors.red),
      );
    }
  }
}
