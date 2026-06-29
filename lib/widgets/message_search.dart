import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../models/message.dart';

class MessageSearchWidget extends StatefulWidget {
  const MessageSearchWidget({super.key});
  @override State<MessageSearchWidget> createState() => _MessageSearchWidgetState();
}

class _MessageSearchWidgetState extends State<MessageSearchWidget> {
  final _searchCtrl = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      context.read<ChatProvider>().searchMessages(value);
    });
  }

  void _clear() {
    _searchCtrl.clear();
    context.read<ChatProvider>().clearSearch();
    _focusNode.requestFocus();
  }

  String _formatTime(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _preview(String content, int maxLen) {
    if (content.length <= maxLen) return content;
    return '${content.substring(0, maxLen)}…';
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final results = chat.searchResults;
    final loading = chat.searchLoading;
    final query = chat.searchQuery;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 搜索输入栏
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            border: const Border(bottom: BorderSide(color: Colors.black12)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  focusNode: _focusNode,
                  onChanged: _onChanged,
                  decoration: InputDecoration(
                    hintText: '在当前会话中搜索…',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: _clear,
                          )
                        : null,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    isDense: true,
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('取消'),
              ),
            ],
          ),
        ),

        // 结果区域
        Expanded(
          child: _buildResults(context, results, loading, query),
        ),
      ],
    );
  }

  Widget _buildResults(BuildContext context, List<ChatMessage> results, bool loading, String? query) {
    if (query == null || query.isEmpty) {
      return const Center(
        child: Text('输入关键词搜索聊天记录', style: TextStyle(color: Colors.grey)),
      );
    }
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (results.isEmpty) {
      return const Center(
        child: Text('未找到相关消息', style: TextStyle(color: Colors.grey)),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: results.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 12, endIndent: 12),
      itemBuilder: (_, i) {
        final msg = results[i];
        return _buildResultItem(context, msg, query);
      },
    );
  }

  Widget _buildResultItem(BuildContext context, ChatMessage msg, String query) {
    return InkWell(
      onTap: () => Navigator.of(context).pop(msg.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 发件人 + 时间
            Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: Colors.blueGrey,
                  child: Text(
                    (msg.senderName.isNotEmpty ? msg.senderName[0] : '?').toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    msg.senderName,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  _formatTime(msg.timestamp),
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // 消息正文 — 高亮关键词
            _buildHighlightedText(msg.content, query),
            // 附件提示
            if (msg.attachments.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '[${msg.attachments.map((a) {
                    switch (a.type) {
                      case ChatAttachmentType.image: return '图片';
                      case ChatAttachmentType.video: return '视频';
                      case ChatAttachmentType.audio: return '音频';
                      case ChatAttachmentType.file: return '文件';
                    }
                  }).join(', ')}]',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHighlightedText(String text, String query) {
    if (query.isEmpty || !text.toLowerCase().contains(query.toLowerCase())) {
      return Text(
        _preview(text, 120),
        style: const TextStyle(fontSize: 14),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      );
    }

    final lower = text.toLowerCase();
    final qLower = query.toLowerCase();
    final spans = <InlineSpan>[];
    int start = 0;

    while (true) {
      final idx = lower.indexOf(qLower, start);
      if (idx < 0) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }
      if (idx > start) {
        spans.add(TextSpan(text: text.substring(start, idx)));
      }
      spans.add(TextSpan(
        text: text.substring(idx, idx + query.length),
        style: const TextStyle(
          backgroundColor: Color(0xFFFFEB3B),
          fontWeight: FontWeight.bold,
        ),
      ));
      start = idx + query.length;
    }

    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 14, color: Colors.black87),
        children: spans,
      ),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );
  }

  @override void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}
