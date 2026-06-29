import 'package:dio/dio.dart';
import '../utils/auth_storage.dart';
import '../utils/constants.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  late final Dio dio;

  ApiClient._internal() {
    dio = Dio(BaseOptions(
      baseUrl: apiBase,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));

    // Auth 拦截器
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final auth = await AuthStorage.getAuthData();
        if (auth != null) {
          options.headers['X-Auth-Token'] = auth.authToken;
          options.headers['X-User-Id'] = auth.userId;
        }
        handler.next(options);
      },
      onResponse: (response, handler) {
        // Rocket.Chat 返回 {success, data} 包装，自动解包 data
        final data = response.data;
        if (data is Map && data.containsKey('data') && data['data'] != null) {
          response.data = data['data'];
        }
        handler.next(response);
      },
      onError: (error, handler) {
        handler.next(error);
      },
    ));
  }
}
