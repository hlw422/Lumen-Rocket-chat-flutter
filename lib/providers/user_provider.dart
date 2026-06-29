import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../models/user.dart';
import '../models/room.dart';

class UserProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  List<RCUser> users = [];
  bool loading = false;
  String? error;

  /// 加载用户列表
  Future<void> loadUsers({int count=50, int offset=0}) async {
    loading = true; error = null; notifyListeners();
    try {
      users = await _api.getUsers(count: count, offset: offset);
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false; notifyListeners();
    }
  }

  /// 搜索用户（本地过滤）
  List<RCUser> searchLocal(String query) {
    if (query.isEmpty) return users;
    final q = query.toLowerCase();
    return users.where((u) =>
      u.username.toLowerCase().contains(q) ||
      (u.name?.toLowerCase().contains(q) ?? false)
    ).toList();
  }

  /// 与用户发起私聊
  Future<RCRoom?> createIm(String username) async {
    try {
      final room = await _api.createIm(username);
      return room;
    } catch (e) {
      debugPrint('createIm error: $e');
      return null;
    }
  }

  /// 创建频道
  Future<RCRoom?> createChannel(String name, {List<String>? members}) async {
    try {
      final room = await _api.createChannel(name, members: members);
      return room;
    } catch (e) {
      debugPrint('createChannel error: $e');
      return null;
    }
  }
}
