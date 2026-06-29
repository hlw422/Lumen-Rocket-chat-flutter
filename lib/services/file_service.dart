import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import '../utils/auth_storage.dart';
import '../utils/constants.dart';

class FileService {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(minutes: 5),
  ));

  FileService() {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final auth = await AuthStorage.getAuthData();
        if (auth != null) {
          options.headers['X-Auth-Token'] = auth.authToken;
          options.headers['X-User-Id'] = auth.userId;
        }
        // 相对路径补全为绝对路径
        if (options.path.startsWith('/') && !options.path.startsWith('http')) {
          options.path = '$rcHost${options.path}';
        }
        handler.next(options);
      },
    ));
  }

  /// 带认证头下载图片，返回 bytes
  Future<Uint8List> loadImage(String url) async {
    final resp = await _dio.get(url,
        options: Options(responseType: ResponseType.bytes));
    return Uint8List.fromList(resp.data);
  }

  /// 带认证头下载文件到临时目录，触发系统打开
  Future<void> downloadFile(String url, String fileName) async {
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/$fileName';
    await _dio.download(url, path);
    await OpenFile.open(path);
  }
}
