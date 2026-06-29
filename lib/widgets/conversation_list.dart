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
