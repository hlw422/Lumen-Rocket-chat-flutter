import 'package:flutter/material.dart';
import '../models/message.dart';
import '../utils/date_format.dart';
import 'attachment_widget.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;

  const MessageBubble({super.key, required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = isMe ? cs.primaryContainer : cs.surfaceContainerHighest;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(12),
      topRight: const Radius.circular(12),
      bottomLeft: isMe ? const Radius.circular(12) : Radius.zero,
      bottomRight: isMe ? Radius.zero : const Radius.circular(12),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe) ...[
            CircleAvatar(
        radius: 16,
        backgroundColor: cs.surfaceContainerHighest,
              child: Text(message.senderName.isNotEmpty ? message.senderName[0].toUpperCase() : '?', style: const TextStyle(fontSize: 14)),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(message.senderName, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
                  ),
                Container(
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: bg, borderRadius: radius),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (message.content.isNotEmpty)
                        SelectableText(message.content, style: const TextStyle(fontSize: 15)),
                      if (message.attachments.isNotEmpty)
                        ...message.attachments.map((att) => Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: AttachmentWidget(attachment: att),
                            )),
                      if (message.isEdited)
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Text('(已编辑)', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(formatChatTime(message.timestamp), style: TextStyle(fontSize: 11, color: Theme.of(context).disabledColor)),
                ),
              ],
            ),
          ),
          if (isMe) const SizedBox(width: 8),
        ],
      ),
    );
  }
}
