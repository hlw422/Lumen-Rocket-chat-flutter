import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/message.dart';
import '../utils/date_format.dart';
import 'attachment_widget.dart';

class MessageBubble extends StatefulWidget {
  final ChatMessage message;
  final bool isMe;

  const MessageBubble({super.key, required this.message, required this.isMe});

  @override State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  void _copyText() {
    Clipboard.setData(ClipboardData(text: widget.message.content));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已复制'), duration: Duration(seconds: 1)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isMe = widget.isMe;
    final message = widget.message;
    final bg = isMe ? cs.primaryContainer : cs.surfaceContainerHighest;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(12),
      topRight: const Radius.circular(12),
      bottomLeft: isMe ? const Radius.circular(12) : Radius.zero,
      bottomRight: isMe ? Radius.zero : const Radius.circular(12),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: GestureDetector(
        onLongPress: message.content.isNotEmpty ? _copyText : null,
        onSecondaryTapDown: message.content.isNotEmpty
            ? (details) => _showContextMenu(context, details.globalPosition)
            : null,
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
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      message.senderName,
                      style: TextStyle(
                        fontSize: 12,
                        color: isMe ? cs.primary.withAlpha(180) : Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Container(
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: bg, borderRadius: radius),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (message.content.isNotEmpty)
                          SelectableText(
                            message.content,
                            style: const TextStyle(fontSize: 15),
                            contextMenuBuilder: _buildContextMenu,
                          ),
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
            if (isMe) ...[
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 16,
                backgroundColor: cs.primaryContainer,
                child: Text(message.senderName.isNotEmpty ? message.senderName[0].toUpperCase() : '?', style: const TextStyle(fontSize: 14)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildContextMenu(BuildContext context, EditableTextState editableTextState) {
    return AdaptiveTextSelectionToolbar.editableText(
      editableTextState: editableTextState,
    );
  }

  void _showContextMenu(BuildContext context, Offset position) {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx + 1, position.dy + 1),
      items: [
        const PopupMenuItem(value: 'copy', child: ListTile(leading: Icon(Icons.copy), title: Text('复制'), dense: true)),
      ],
    ).then((value) {
      if (value == 'copy') _copyText();
    });
  }
}
