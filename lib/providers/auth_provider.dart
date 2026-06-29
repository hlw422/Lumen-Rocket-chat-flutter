import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../utils/auth_storage.dart';
import '../models/user.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  RCMeResponse? user;
  bool loading = false;
  String? error;

  bool get isLoggedIn => user != null;
  String get userId => user?.id ?? '';
  String get username => user?.username ?? '';

  /// 初始化：从本地恢复登录态
  Future<void> init() async {
    final auth = await AuthStorage.getAuthData();
    if (auth == null) return;
    try {
      final me = await _api.getMe();
      user = me;
      notifyListeners();
    } catch (e) {
      await AuthStorage.clearAuth();
    }
  }

  /// 登录
  Future<bool> login(String loginUser, String password) async {
    loading = true; error = null; notifyListeners();
    try {
      final res = await _api.login(loginUser, password);
      await AuthStorage.setAuthToken(res.userId, res.authToken);
      user = RCMeResponse(
        id: res.me.id, username: res.me.username, name: res.me.name,
        avatarUrl: res.me.avatarUrl, status: res.me.status,
        statusConnection: res.me.statusConnection,
        utcOffset: res.me.utcOffset, active: res.me.active,
        roles: res.me.roles, emails: res.me.emails,
      );
      notifyListeners();
      return true;
    } catch (e) {
      error = _formatError(e);
      notifyListeners();
      return false;
    } finally {
      loading = false; notifyListeners();
    }
  }

  /// 注册
  Future<bool> register({
    required String username, required String email,
    required String pass, required String name,
  }) async {
    loading = true; error = null; notifyListeners();
    try {
      final res = await _api.register(
        username: username, email: email, pass: pass, name: name);
      if (res.success) return true;
      error = '注册失败，请稍后重试';
      return false;
    } catch (e) {
      error = _formatError(e);
      return false;
    } finally {
      loading = false; notifyListeners();
    }
  }

  /// 登出
  Future<void> logout() async {
    try { await _api.logout(); } catch (_) {}
    await AuthStorage.clearAuth();
    user = null;
    notifyListeners();
  }

  String _formatError(Object e) {
    final s = e.toString();
    if (s.contains('DioException')) return '网络连接失败，请检查服务器地址';
    if (s.contains('error')) try {
      final m = s.split('error:')[1].trim();
      return m;
    } catch (_) {}
    return '操作失败，请稍后重试';
  }
}
