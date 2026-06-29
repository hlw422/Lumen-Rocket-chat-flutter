import 'dart:convert';
import 'package:flutter/foundation.dart';
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
    debugPrint('[AUTH_STORAGE] getAuthData: raw=${raw != null ? 'exists(${raw.length} chars)' : 'null'}');
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final data = AuthData(userId: map['userId'], authToken: map['authToken']);
      final tokenPreview = data.authToken.length > 10 ? data.authToken.substring(0, 10) : data.authToken;
      debugPrint('[AUTH_STORAGE] getAuthData: userId=${data.userId}, token=$tokenPreview...');
      return data;
    } catch (e) {
      debugPrint('[AUTH_STORAGE] getAuthData error: $e');
      return null;
    }
  }

  static Future<void> setAuthToken(String userId, String authToken) async {
    final prefs = await SharedPreferences.getInstance();
    final data = AuthData(userId: userId, authToken: authToken);
    await prefs.setString(_authKey, jsonEncode(data.toJson()));
    final tokenPreview = authToken.length > 10 ? authToken.substring(0, 10) : authToken;
    debugPrint('[AUTH_STORAGE] setAuthToken: userId=$userId, token=$tokenPreview...');
  }

  static Future<void> clearAuth() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_authKey);
    debugPrint('[AUTH_STORAGE] clearAuth: done');
  }

  static Future<bool> isLogin() async {
    final data = await getAuthData();
    return data != null;
  }
}
