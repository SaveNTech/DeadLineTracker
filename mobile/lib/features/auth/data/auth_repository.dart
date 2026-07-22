import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../../../core/storage/token_storage.dart';
import '../../../models/auth_tokens.dart';
import '../../../models/user.dart';

class AuthRepository {
  AuthRepository(this._apiClient, this._tokenStorage);

  final ApiClient _apiClient;
  final TokenStorage _tokenStorage;

  Future<AppUser> register({
    required String email,
    required String username,
    required String password,
  }) async {
    final response = await _apiClient.dio.post(
      '/auth/register',
      data: {'email': email, 'username': username, 'password': password},
    );
    return AppUser.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> login({required String email, required String password}) async {
    final response = await _apiClient.dio.post(
      '/auth/login',
      data: FormData.fromMap({'username': email, 'password': password}),
    );
    final tokens = AuthTokens.fromJson(response.data as Map<String, dynamic>);
    await _tokenStorage.save(tokens);
  }

  Future<AppUser> fetchCurrentUser() async {
    final response = await _apiClient.dio.get('/users/me');
    return AppUser.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> logout() async {
    final refreshToken = await _tokenStorage.readRefreshToken();
    if (refreshToken != null) {
      try {
        await _apiClient.dio.post('/auth/logout', data: {'refresh_token': refreshToken});
      } catch (_) {
        // best-effort server-side revoke; always clear local state below
      }
    }
    await _tokenStorage.clear();
  }

  Future<bool> hasSession() async => (await _tokenStorage.readAccessToken()) != null;
}
