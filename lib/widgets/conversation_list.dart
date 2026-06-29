import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../models/room.dart';
import 'conversation_tile.dart';

class ConversationListWidget extends StatelessWidget {
  const ConversationListWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    if (chat.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (chat.conversationsError && chat.conversations.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(chat.error ?? '加载会话列表失败', style: const TextStyle(color: Colors.red, fontSize: 14)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => chat.loadConversations(),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('点击重试'),
            ),
          ],
        ),
      );
    }
    if (chat.conversations.isEmpty) {
      return const Center(
        child: Text('暂无会话', style: TextStyle(color: Colors.grey)),
      );
    }

    // 按 lastMessageTime 排序
    final sorted = List<Conversation>.from(chat.conversations)
      ..sort((a, b) => (b.lastMessageTime ?? 0).compareTo(a.lastMessageTime ?? 0));

    return ListView.builder(
      itemCount: sorted.length,
      itemBuilder: (_, i) => ConversationTile(
        conversation: sorted[i],
        isActive: sorted[i].id == chat.currentRoomId,
        onTap: () => chat.selectConversation(sorted[i].id),
      ),
    );
  }
}
