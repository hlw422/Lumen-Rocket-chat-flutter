import 'user.dart';

/// 会话类型枚举
enum ConversationType {
  channel, // # 公开频道
  group, // 🔒 私有群组
  direct, // 👤 私聊
}

/// 会话/房间显示模型
class Conversation {
  final String id;
  final String name;
  final ConversationType type;
  final String lastMessage;
  final int? lastMessageTime; // unix ms
  final int unread;
  final int? usersCount;
  final String? description;
  final String? topic;

  Conversation({
    required this.id,
    required this.name,
    required this.type,
    this.lastMessage = '',
    this.lastMessageTime,
    this.unread = 0,
    this.usersCount,
    this.description,
    this.topic,
  });
}

/// Rocket.Chat 原生房间模型
class RCRoom {
  final String id;
  final String? name;
  final String? fname;
  final String t; // c=channel, p=group, d=direct
  final List<String> usernames;
  final int? usersCount;
  final int? msgs;
  final String? ts;
  final bool? ro;
  final bool? sysMes;
  final bool? isDefault;
  final String? updatedAt;
  final String? description;
  final String? topic;
  final String? lm; // last message timestamp
  final RCUser? u;

  RCRoom({
    required this.id,
    this.name,
    this.fname,
    required this.t,
    this.usernames = const [],
    this.usersCount,
    this.msgs,
    this.ts,
    this.ro,
    this.sysMes,
    this.isDefault,
    this.updatedAt,
    this.description,
    this.topic,
    this.lm,
    this.u,
  });

  factory RCRoom.fromJson(Map<String, dynamic> json) => RCRoom(
        id: json['_id'] ?? '',
        name: json['name'],
        fname: json['fname'],
        t: json['t'] ?? 'd',
        usernames: (json['usernames'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        usersCount: json['usersCount'],
        msgs: json['msgs'],
        ts: json['ts'],
        ro: json['ro'],
        sysMes: json['sysMes'],
        isDefault: json['default'],
        updatedAt: json['_updatedAt'],
        description: json['description'],
        topic: json['topic'],
        lm: json['lm'],
        u: json['u'] != null ? RCUser.fromJson(json['u']) : null,
      );

  /// 转为视图层 Conversation
  Conversation toConversation(ConversationType type) => Conversation(
        id: id,
        name: fname ?? name ?? (usernames.isNotEmpty ? usernames.join(', ') : 'Unknown'),
        type: type,
        lastMessageTime: lm != null ? DateTime.parse(lm!).millisecondsSinceEpoch : null,
        usersCount: usersCount,
        description: description,
        topic: topic,
      );
}

/// 会话列表响应
class RCChannelsListResponse {
  final List<RCRoom> channels;
  final int count; final int offset; final int total;
  RCChannelsListResponse({required this.channels, this.count=0, this.offset=0, this.total=0});
  factory RCChannelsListResponse.fromJson(Map<String, dynamic> json) => RCChannelsListResponse(
    channels: ((json['channels']??[]) as List).map((e)=>RCRoom.fromJson(e)).toList(),
    count: json['count']??0, offset: json['offset']??0, total: json['total']??0,
  );
}

class RCGroupsListResponse {
  final List<RCRoom> groups;
  final int count; final int offset; final int total;
  RCGroupsListResponse({required this.groups, this.count=0, this.offset=0, this.total=0});
  factory RCGroupsListResponse.fromJson(Map<String, dynamic> json) => RCGroupsListResponse(
    groups: ((json['groups']??[]) as List).map((e)=>RCRoom.fromJson(e)).toList(),
    count: json['count']??0, offset: json['offset']??0, total: json['total']??0,
  );
}

class RCImListResponse {
  final List<RCRoom> ims;
  final int count; final int offset; final int total;
  RCImListResponse({required this.ims, this.count=0, this.offset=0, this.total=0});
  factory RCImListResponse.fromJson(Map<String, dynamic> json) => RCImListResponse(
    ims: ((json['ims']??[]) as List).map((e)=>RCRoom.fromJson(e)).toList(),
    count: json['count']??0, offset: json['offset']??0, total: json['total']??0,
  );
}
