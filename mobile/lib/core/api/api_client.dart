import 'dart:io';

import 'package:dio/dio.dart';

import '../../models/auth_tokens.dart';
import '../storage/token_storage.dart';

/// Base URL for the FastAPI backend.
///
/// `10.0.2.2` is how the Android emulator reaches the host machine's
/// `localhost`. Point this at a real host (and use https) for a physical
/// device or production build.
String get _defaultBaseUrl {
  if (Platform.isAndroid) return 'http://10.0.2.2:8000/api/v1';
  return 'http://localhost:8000/api/v1';
}

class ApiClient {
  ApiClient(this._tokenStorage, {String? baseUrl, this.onUnauthenticated})
      : dio = Dio(BaseOptions(baseUrl: baseUrl ?? _defaultBaseUrl)) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _tokenStorage.readAccessToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final isAuthEndpoint = error.requestOptions.path.contains('/auth/');
          if (error.response?.statusCode == 401 && !isAuthEndpoint) {
            final refreshed = await _tryRefresh();
            if (refreshed) {
              final retryResponse = await dio.fetch(error.requestOptions);
              return handler.resolve(retryResponse);
            }
            await _tokenStorage.clear();
            onUnauthenticated?.call();
          }
          handler.next(error);
        },
      ),
    );
  }

  final Dio dio;
  final TokenStorage _tokenStorage;

  /// Called once when a refresh attempt fails and the session is no longer valid.
  void Function()? onUnauthenticated;

  bool _refreshing = false;

  Future<bool> _tryRefresh() async {
    if (_refreshing) return false;
    _refreshing = true;
    try {
      final refreshToken = await _tokenStorage.readRefreshToken();
      if (refreshToken == null) return false;

      final response = await Dio(BaseOptions(baseUrl: dio.options.baseUrl)).post(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );
      await _tokenStorage.save(AuthTokens.fromJson(response.data as Map<String, dynamic>));
      return true;
    } catch (_) {
      return false;
    } finally {
      _refreshing = false;
    }
  }
}
