import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../providers/auth_provider.dart';
import 'message_bubble.dart';
import 'emoji_picker.dart';

class MessagePanelWidget extends StatefulWidget {
  const MessagePanelWidget({super.key});
  @override State<MessagePanelWidget> createState() => _MessagePanelWidgetState();
}

class _MessagePanelWidgetState extends State<MessagePanelWidget> {
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _scrollToBottom() {
    if (_scrollCtrl.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      });
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
    await chat.pickAndUpload(roomId, image: image);
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

    // 新消息滚动
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (messages.isNotEmpty) _scrollToBottom();
    });

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
                    controller: _scrollCtrl,
                    itemCount: messages.length,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemBuilder: (_, i) => MessageBubble(message: messages[i], isMe: messages[i].senderId == userId),
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
