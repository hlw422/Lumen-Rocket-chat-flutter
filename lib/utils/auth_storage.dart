import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

const _authKey = 'rocketchat_auth';

class AuthData {
  final String userId;
  final String authToken;
  AuthData({required this.userId, required this.authToken});

  Map<String, dynamic> toJson() => {'userId': userId, 'authToken': authToken};
}

class AuthStorage {
  static Future<AuthData?> getAuthData() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_authKey);
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return AuthData(userId: map['userId'], authToken: map['authToken']);
    } catch (_) {
      return null;
    }
  }

  static Future<void> setAuthToken(String userId, String authToken) async {
    final prefs = await SharedPreferences.getInstance();
    final data = AuthData(userId: userId, authToken: authToken);
    await prefs.setString(_authKey, jsonEncode(data.toJson()));
  }

  static Future<void> clearAuth() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_authKey);
  }

  static Future<bool> isLogin() async {
    return await getAuthData() != null;
  }
}
