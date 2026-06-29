import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import '../utils/auth_storage.dart';
import '../utils/constants.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  late final Dio dio;

  ApiClient._internal() {
    dio = Dio(BaseOptions(
      baseUrl: apiBase,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    // 自定义 HttpClient，增加超时
    dio.httpClientAdapter = IOHttpClientAdapter(
      onHttpClientCreate: (client) {
        client.connectionTimeout = const Duration(seconds: 15);
        return client;
      },
    );

    // 日志拦截器（调试用）
    dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      logPrint: (obj) => stdout.writeln('[DIO] $obj'),
    ));

    // Auth 拦截器
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final auth = await AuthStorage.getAuthData();
        if (auth != null) {
          options.headers['X-Auth-Token'] = auth.authToken;
          options.headers['X-User-Id'] = auth.userId;
          stdout.writeln('[API_CLIENT] Added auth headers: userId=${auth.userId}, token=${auth.authToken.length} chars');
        } else {
          stdout.writeln('[API_CLIENT] No auth data found for ${options.uri.path}');
        }
        handler.next(options);
      },
      onResponse: (response, handler) {
        final data = response.data;
        stdout.writeln('[API_CLIENT] Response ${response.statusCode} for ${response.requestOptions.uri.path}: type=${data.runtimeType}');
        if (data is Map) {
          stdout.writeln('[API_CLIENT] Response keys: ${data.keys.take(5).join(', ')}');
          if (data.containsKey('status') && data['status'] == 'success') {
            final innerData = data['data'];
            if (innerData is Map) {
              stdout.writeln('[API_CLIENT] Unwrapping status=success data field');
              response.data = innerData;
            }
          } else if (data.containsKey('success') && data['success'] == true) {
            final innerData = data['data'];
            if (innerData is Map) {
              stdout.writeln('[API_CLIENT] Unwrapping success=true data field');
              response.data = innerData;
            }
          }
        } else {
          stdout.writeln('[API_CLIENT] Response data is not a Map, keeping original');
        }
        handler.next(response);
      },
      onError: (error, handler) {
        stdout.writeln('[API_CLIENT] Error ${error.response?.statusCode} for ${error.requestOptions.uri.path}: ${error.message}');
        handler.next(error);
      },
    ));
  }
}
