const _justNow = '刚刚';
const _minuteAgo = '分钟前';
const _dayAgo = '天前';
const _monthAgo = '月前';

String formatChatTime(int ms) {
  final now = DateTime.now();
  final dt = DateTime.fromMillisecondsSinceEpoch(ms);
  final diff = now.difference(dt);

  if (diff.inSeconds < 60) return _justNow;
  if (diff.inMinutes < 60) return '${diff.inMinutes}$_minuteAgo';
  if (diff.inHours < 24) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
  if (diff.inDays < 30) return '${diff.inDays}$_dayAgo';
  if (diff.inDays < 365) {
    return '${(diff.inDays/30).floor()}$_monthAgo';
  }
  return '${dt.year}-${dt.month.toString().padLeft(2,'0')}-${dt.day.toString().padLeft(2,'0')}';
}

String formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024*1024) return '${(bytes/1024).toStringAsFixed(1)} KB';
  if (bytes < 1024*1024*1024) return '${(bytes/(1024*1024)).toStringAsFixed(1)} MB';
  return '${(bytes/(1024*1024*1024)).toStringAsFixed(1)} GB';
}
