/// Rocket.Chat 用户模型
class RCUser {
  final String id;
  final String username;
  final String? name;
  final String? avatarUrl;
  final String? status;
  final String? statusConnection;
  final int? utcOffset;
  final bool? active;
  final List<String> roles;
  final List<RCEmail> emails;
  final String? lastLogin;
  final String? createdAt;

  RCUser({
    required this.id,
    required this.username,
    this.name,
    this.avatarUrl,
    this.status,
    this.statusConnection,
    this.utcOffset,
    this.active,
    this.roles = const [],
    this.emails = const [],
    this.lastLogin,
    this.createdAt,
  });

  factory RCUser.fromJson(Map<String, dynamic> json) {
    return RCUser(
      id: json['_id'] ?? '',
      username: json['username'] ?? '',
      name: json['name'],
      avatarUrl: json['avatarUrl'],
      status: json['status'],
      statusConnection: json['statusConnection'],
      utcOffset: json['utcOffset'],
      active: json['active'],
      roles: (json['roles'] as List<dynamic>?)?.cast<String>() ?? [],
      emails: (json['emails'] as List<dynamic>?)
              ?.map((e) => RCEmail.fromJson(e))
              .toList() ??
          [],
      lastLogin: json['lastLogin'],
      createdAt: json['createdAt'],
    );
  }

  Map<String, dynamic> toJson() => {
        '_id': id,
        'username': username,
        'name': name,
        'avatarUrl': avatarUrl,
        'status': status,
        'statusConnection': statusConnection,
        'utcOffset': utcOffset,
        'active': active,
        'roles': roles,
        'emails': emails.map((e) => e.toJson()).toList(),
        'lastLogin': lastLogin,
        'createdAt': createdAt,
      };
}

class RCEmail {
  final String address;
  final bool verified;

  RCEmail({required this.address, this.verified = false});

  factory RCEmail.fromJson(Map<String, dynamic> json) => RCEmail(
        address: json['address'] ?? '',
        verified: json['verified'] ?? false,
      );

  Map<String, dynamic> toJson() => {'address': address, 'verified': verified};
}

/// 登录请求
class RCLoginRequest {
  final String user;
  final String password;
  RCLoginRequest({required this.user, required this.password});
  Map<String, dynamic> toJson() => {'user': user, 'password': password};
}

/// 登录响应
class RCLoginResponse {
  final String userId;
  final String authToken;
  final RCUser me;

  RCLoginResponse({
    required this.userId,
    required this.authToken,
    required this.me,
  });

  factory RCLoginResponse.fromJson(Map<String, dynamic> json) {
    final data = json;
    return RCLoginResponse(
      userId: data['userId'] ?? '',
      authToken: data['authToken'] ?? '',
      me: RCUser.fromJson(data['me'] ?? {}),
    );
  }
}

/// 注册请求
class RCRegisterRequest {
  final String username;
  final String email;
  final String pass;
  final String name;

  RCRegisterRequest({
    required this.username,
    required this.email,
    required this.pass,
    required this.name,
  });

  Map<String, dynamic> toJson() =>
      {'username': username, 'email': email, 'pass': pass, 'name': name};
}

/// 注册响应
class RCRegisterResponse {
  final bool success;
  final RCUser? user;

  RCRegisterResponse({required this.success, this.user});

  factory RCRegisterResponse.fromJson(Map<String, dynamic> json) =>
      RCRegisterResponse(
        success: json['success'] ?? false,
        user: json['user'] != null ? RCUser.fromJson(json['user']) : null,
      );
}

/// /api/v1/me 响应
class RCMeResponse {
  final String id;
  final String username;
  final String? name;
  final String? avatarUrl;
  final String? status;
  final String? statusConnection;
  final int? utcOffset;
  final bool? active;
  final List<String> roles;
  final List<RCEmail> emails;

  RCMeResponse({
    required this.id,
    required this.username,
    this.name,
    this.avatarUrl,
    this.status,
    this.statusConnection,
    this.utcOffset,
    this.active,
    this.roles = const [],
    this.emails = const [],
  });

  factory RCMeResponse.fromJson(Map<String, dynamic> json) => RCMeResponse(
        id: json['_id'] ?? '',
        username: json['username'] ?? '',
        name: json['name'],
        avatarUrl: json['avatarUrl'],
        status: json['status'],
        statusConnection: json['statusConnection'],
        utcOffset: json['utcOffset'],
        active: json['active'],
        roles: (json['roles'] as List<dynamic>?)?.cast<String>() ?? [],
        emails: (json['emails'] as List<dynamic>?)
                ?.map((e) => RCEmail.fromJson(e))
                .toList() ??
            [],
      );
}
