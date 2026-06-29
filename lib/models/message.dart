class RCAttachment {
  final String? color;
  final String? text;
  final String? ts;
  final String? thumbUrl;
  final String? messageLink;
  final bool? collapsed;
  final String? authorName;
  final String? authorLink;
  final String? authorIcon;
  final String? title;
  final String? titleLink;
  final bool? titleLinkDownload;
  final String? imageUrl;
  final String? audioUrl;
  final String? videoUrl;
  final List<Map<String, String>> fields;

  RCAttachment({
    this.color, this.text, this.ts, this.thumbUrl, this.messageLink,
    this.collapsed, this.authorName, this.authorLink, this.authorIcon,
    this.title, this.titleLink, this.titleLinkDownload,
    this.imageUrl, this.audioUrl, this.videoUrl,
    this.fields = const [],
  });

  factory RCAttachment.fromJson(Map<String, dynamic> json) => RCAttachment(
    color: json['color'], text: json['text'], ts: json['ts'],
    thumbUrl: json['thumb_url'], messageLink: json['message_link'],
    collapsed: json['collapsed'], authorName: json['author_name'],
    authorLink: json['author_link'], authorIcon: json['author_icon'],
    title: json['title'], titleLink: json['title_link'],
    titleLinkDownload: json['title_link_download'],
    imageUrl: json['image_url'], audioUrl: json['audio_url'],
    videoUrl: json['video_url'],
    fields: (json['fields'] as List<dynamic>?)
      ?.map((e)=>Map<String,String>.from(e as Map))?.toList() ?? const [],
  );
}

/// 消息发送者
class MsgSender {
  final String id;
  final String username;
  final String? name;
  MsgSender({required this.id, required this.username, this.name});
  factory MsgSender.fromJson(Map<String, dynamic> json) => MsgSender(
    id: json['_id']??'', username: json['username']??'', name: json['name'],
  );
}

/// Rocket.Chat 原生消息
class RCMessage {
  final String id;
  final String rid;
  final String msg;
  final String ts;
  final MsgSender u;
  final String? type;
  final List<RCAttachment> attachments;
  final String? editedAt;
  final String? editedBy;
  final bool? groupable;

  RCMessage({
    required this.id, required this.rid, required this.msg,
    required this.ts, required this.u, this.type,
    this.attachments = const [], this.editedAt, this.editedBy,
    this.groupable,
  });

  factory RCMessage.fromJson(Map<String, dynamic> json) => RCMessage(
    id: json['_id']??'', rid: json['rid']??'',
    msg: json['msg']??'', ts: json['ts']??'',
    u: MsgSender.fromJson(json['u']??{}),
    type: json['t'],
    attachments: (json['attachments'] as List<dynamic>?)
      ?.map((e)=>RCAttachment.fromJson(e as Map<String,dynamic>))?.toList()??[],
    editedAt: json['editedAt'],
    editedBy: json['editedBy'] is Map ? json['editedBy']['username'] : null,
    groupable: json['groupable'],
  );

  /// 转为视图层 ChatMessage
  ChatMessage toChatMessage() => ChatMessage(
    id: id, roomId: rid, content: msg,
    senderId: u.id, senderName: u.name??u.username,
    timestamp: _parseTs(ts),
    editedAt: editedAt != null ? DateTime.tryParse(editedAt!)?.millisecondsSinceEpoch : null,
    isEdited: editedAt != null,
    attachments: attachments.map((a)=>a.toChatAttachment()).toList(),
    type: type,
  );

  static int _parseTs(String ts) {
    final d = DateTime.tryParse(ts);
    if (d != null) return d.millisecondsSinceEpoch;
    final i = int.tryParse(ts);
    if (i != null) return i > 1e12 ? i : i*1000;
    return DateTime.now().millisecondsSinceEpoch;
  }
}

/// 消息历史响应
class RCMessagesResponse {
  final List<RCMessage> messages;
  final int count; final int offset; final int total;
  RCMessagesResponse({this.messages=const[], this.count=0, this.offset=0, this.total=0});
  factory RCMessagesResponse.fromJson(Map<String, dynamic> json) => RCMessagesResponse(
    messages: ((json['messages']??[]) as List)
      .map((e)=>RCMessage.fromJson(e as Map<String,dynamic>)).toList(),
    count: json['count']??0, offset: json['offset']??0, total: json['total']??0,
  );
}

/// 发送消息请求
class RCPostMessageRequest {
  final String roomId;
  final String? text;
  RCPostMessageRequest({required this.roomId, this.text});
  Map<String, dynamic> toJson() => {'roomId': roomId, 'text': text??''};
}

/// 发送消息响应
class RCPostMessageResponse {
  final RCMessage message;
  RCPostMessageResponse({required this.message});
  factory RCPostMessageResponse.fromJson(Map<String, dynamic> json) =>
    RCPostMessageResponse(message: RCMessage.fromJson(json['message']??{}));
}

// ========== 视图层模型 ==========

enum ChatAttachmentType { image, video, audio, file }

class ChatAttachment {
  final ChatAttachmentType type;
  final String url;
  final String? title;
  final String? name;
  final int? size;
  final String? description;
  final String? thumbUrl;
  final String? color;
  final bool? titleLinkDownload;

  ChatAttachment({
    required this.type, required this.url, this.title, this.name,
    this.size, this.description, this.thumbUrl, this.color,
    this.titleLinkDownload,
  });
}

extension RCAttachmentExt on RCAttachment {
  ChatAttachment toChatAttachment() {
    ChatAttachmentType type = ChatAttachmentType.file;
    String url = '';
    if (imageUrl != null) { type = ChatAttachmentType.image; url = imageUrl!; }
    else if (videoUrl != null) { type = ChatAttachmentType.video; url = videoUrl!; }
    else if (audioUrl != null) { type = ChatAttachmentType.audio; url = audioUrl!; }
    else { url = titleLink ?? ''; }

    return ChatAttachment(
      type: type, url: url, title: title, name: title,
      description: text, thumbUrl: thumbUrl,
      color: color, titleLinkDownload: titleLinkDownload,
    );
  }
}

class ChatMessage {
  final String id;
  final String roomId;
  final String content;
  final String senderId;
  final String senderName;
  final int timestamp;
  final int? editedAt;
  final bool isEdited;
  final List<ChatAttachment> attachments;
  final String? type;

  ChatMessage({
    required this.id, required this.roomId, required this.content,
    required this.senderId, required this.senderName,
    required this.timestamp, this.editedAt, this.isEdited=false,
    this.attachments=const[], this.type,
  });
}
