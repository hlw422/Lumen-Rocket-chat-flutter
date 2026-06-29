import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../providers/auth_provider.dart';
import 'message_bubble.dart';
import 'message_search.dart';
import 'emoji_picker.dart';

class MessagePanelWidget extends StatefulWidget {
  const MessagePanelWidget({super.key});
  @override State<MessagePanelWidget> createState() => _MessagePanelWidgetState();
}

class _MessagePanelWidgetState extends State<MessagePanelWidget> {
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _focusNode = FocusNode();
  String? _lastRoomId;
  bool? _prevMessagesLoading;
  int _prevMessagesLen = 0;

  @override
  void initState() {
    super.initState();
    // reverse:true 使 ListView 默认从底部开始显示，无需手动滚动
  }

  /// 平滑滚动到底部（offset=0 即 reverse 列表的末端/视觉底部）
  void _scrollToBottom() {
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(0,
          duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    }
  }

  /// 立即跳到底部
  void _scrollToBottomImmediate() {
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.jumpTo(0);
    }
  }

  Future<void> _send() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    final chat = context.read<ChatProvider>();
    final roomId = chat.currentRoomId;
    if (roomId == null) return;
    _textCtrl.clear();
    await chat.sendMessage(roomId, text);
    _scrollToBottom();
  }

  Future<void> _pickAndUpload({bool image=false}) async {
    final chat = context.read<ChatProvider>();
    final roomId = chat.currentRoomId;
    if (roomId == null) return;
    final result = await chat.pickAndUpload(roomId, image: image);
    if (result == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('发送失败，请重试'), backgroundColor: Colors.red),
      );
    }
    _scrollToBottom();
  }

  void _onEmojiSelected(String emoji) {
    _textCtrl.text += emoji;
    _textCtrl.selection = TextSelection.fromPosition(TextPosition(offset: _textCtrl.text.length));
    _focusNode.requestFocus();
  }

  void _insertNewline() {
    final text = _textCtrl.text;
    final selection = _textCtrl.selection;
    final start = selection.start;
    final end = selection.end;
    _textCtrl.text = text.substring(0, start) + '\n' + text.substring(end);
    _textCtrl.selection = TextSelection.collapsed(offset: start + 1);
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final messages = chat.messages;
    final userId = context.read<AuthProvider>().userId;
    final currentRoomId = chat.currentRoomId;
    final messagesLoading = chat.messagesLoading;

    // 切换房间时重置跟踪状态
    if (currentRoomId != _lastRoomId) {
      _lastRoomId = currentRoomId;
      _prevMessagesLoading = null;
      _prevMessagesLen = 0;
    }

    // 消息加载完成时，若列表被重建则自动到底部（reverse 列表 offset=0 就是底部）
    if (_prevMessagesLoading == true && !messagesLoading && messages.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottomImmediate());
    }
    _prevMessagesLoading = messagesLoading;

    // DDP 实时推送新消息时平滑滚动
    if (messages.length > _prevMessagesLen && _prevMessagesLen > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
    _prevMessagesLen = messages.length;

    return Column(
      children: [
        // 消息列表
        Expanded(
          child: chat.messagesLoading
            ? const Center(child: CircularProgressIndicator())
            : messages.isEmpty
              ? const Center(child: Text('暂无消息', style: TextStyle(color: Colors.grey)))
              : SelectionArea(
                  child: ListView.builder(
                    reverse: true,
                    controller: _scrollCtrl,
                    itemCount: messages.length,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemBuilder: (_, i) {
                      // reverse:true 时 index 0 在最底部，所以取 messages 尾部
                      final msg = messages[messages.length - 1 - i];
                      return MessageBubble(message: msg, isMe: msg.senderId == userId);
                    },
                  ),
                ),
        ),
        const Divider(height: 1),
        // 输入区域
        _buildInputBar(),
      ],
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // 搜索聊天记录
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: '搜索聊天记录',
              onPressed: _showMessageSearch,
            ),
            // 图片上传
            IconButton(
              icon: const Icon(Icons.image_outlined),
              tooltip: '发送图片',
              onPressed: () => _pickAndUpload(image: true),
            ),
            // 文件上传
            IconButton(
              icon: const Icon(Icons.attach_file),
              tooltip: '发送文件',
              onPressed: () => _pickAndUpload(),
            ),
            // 表情
            IconButton(
              icon: const Icon(Icons.emoji_emotions_outlined),
              tooltip: '表情',
              onPressed: () => _showEmojiPicker(),
            ),
            // 输入框 — Enter 发送 / Shift+Enter 换行
            Expanded(
              child: CallbackShortcuts(
                bindings: {
                  const SingleActivator(LogicalKeyboardKey.enter): _send,
                  const SingleActivator(LogicalKeyboardKey.enter, shift: true): _insertNewline,
                },
                child: Focus(
                  onKeyEvent: (node, event) {
                    // 拦截裸 Enter（无修饰键）用于发送
                    if (event is KeyDownEvent &&
                        event.logicalKey == LogicalKeyboardKey.enter &&
                        !HardwareKeyboard.instance.isShiftPressed &&
                        !HardwareKeyboard.instance.isControlPressed) {
                      _send();
                      return KeyEventResult.handled;
                    }
                    return KeyEventResult.ignored;
                  },
                  child: TextField(
                    controller: _textCtrl,
                    focusNode: _focusNode,
                    maxLines: 5,
                    minLines: 1,
                    decoration: const InputDecoration(
                      hintText: '输入消息…',
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      isDense: true,
                    ),
                    textInputAction: TextInputAction.newline,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            // 发送按钮
            IconButton(
              icon: const Icon(Icons.send_rounded),
              color: Theme.of(context).colorScheme.primary,
              onPressed: _send,
            ),
          ],
        ),
      ),
    );
  }

  void _showMessageSearch() {
    final chat = context.read<ChatProvider>();
    if (chat.currentRoomId == null) return;
    chat.clearSearch();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: const MessageSearchWidget(),
      ),
    );
  }

  void _showEmojiPicker() {
    showModalBottomSheet(
      context: context,
      builder: (_) => EmojiPicker(onSelected: _onEmojiSelected),
    );
  }

  @override void dispose() {
    _textCtrl.dispose(); _scrollCtrl.dispose(); _focusNode.dispose();
    super.dispose();
  }
}
