import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../models/message.dart';

class AttachmentWidget extends StatefulWidget {
  final ChatAttachment attachment;
  const AttachmentWidget({super.key, required this.attachment});

  @override State<AttachmentWidget> createState() => _AttachmentWidgetState();
}

class _AttachmentWidgetState extends State<AttachmentWidget> {
  Uint8List? _imageBytes;
  bool _loading = false;

  ChatAttachment get att => widget.attachment;

  @override
  void initState() {
    super.initState();
    if (att.type == ChatAttachmentType.image && att.url.isNotEmpty) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    if (_imageBytes != null) return;
    setState(() => _loading = true);
    try {
      final bytes = await context.read<ChatProvider>().loadImageBytes(att.url);
      if (mounted) setState(() => _imageBytes = bytes);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  void _downloadFile() {
    final chat = context.read<ChatProvider>();
    final fileName = att.name ?? att.title ?? att.url.split('/').last;
    chat.downloadFile(att.url, fileName);
  }

  @override
  Widget build(BuildContext context) {
    switch (att.type) {
      case ChatAttachmentType.image:
        return _buildImage();
      case ChatAttachmentType.video:
        return _buildFileCard('🎬', att.title ?? '视频文件');
      case ChatAttachmentType.audio:
        return _buildAudio();
      default:
        return _buildFileCard('📎', att.title ?? att.name ?? '文件');
    }
  }

  Widget _buildImage() {
    if (_loading) {
      return const SizedBox(width: 200, height: 120, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
    }
    if (_imageBytes != null) {
      return GestureDetector(
        onTap: () => _showPreview(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280, maxHeight: 200),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(_imageBytes!, fit: BoxFit.contain),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('图片', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _downloadFile,
                  child: const Text('下载', style: TextStyle(fontSize: 12, color: Colors.blue, decoration: TextDecoration.underline)),
                ),
              ],
            ),
          ],
        ),
      );
    }
    return const SizedBox(
      width: 200, height: 120,
      child: Center(child: Text('🖼️ 加载失败', style: TextStyle(color: Colors.grey))),
    );
  }

  Widget _buildFileCard(String icon, String name) {
    return InkWell(
      onTap: _downloadFile,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(name, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.download, size: 18, color: Colors.blue),
          ],
        ),
      ),
    );
  }

  Widget _buildAudio() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.audiotrack, size: 20),
          const SizedBox(width: 4),
          const Text('音频消息', style: TextStyle(fontSize: 13)),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _downloadFile,
            child: const Icon(Icons.download, size: 18, color: Colors.blue),
          ),
        ],
      ),
    );
  }

  void _showPreview() {
    if (_imageBytes == null) return;
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: InteractiveViewer(child: Image.memory(_imageBytes!)),
      ),
    );
  }
}
