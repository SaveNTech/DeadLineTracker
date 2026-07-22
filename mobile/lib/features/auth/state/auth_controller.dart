import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../models/user.dart';
import '../data/auth_repository.dart';

enum AuthStatus { checking, authenticated, unauthenticated }

class AuthState {
  const AuthState({required this.status, this.user, this.errorMessage});

  final AuthStatus status;
  final AppUser? user;
  final String? errorMessage;

  AuthState copyWith({AuthStatus? status, AppUser? user, String? errorMessage}) => AuthState(
        status: status ?? this.status,
        user: user ?? this.user,
        errorMessage: errorMessage,
      );

  static const checking = AuthState(status: AuthStatus.checking);
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(apiClientProvider), ref.watch(tokenStorageProvider));
});

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  final controller = AuthController(ref.watch(authRepositoryProvider));
  ref.listen(unauthenticatedEventProvider, (previous, next) {
    if (previous != null && next != previous) {
      controller.forceSignOut();
    }
  });
  return controller;
});

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._repository) : super(AuthState.checking) {
    _restoreSession();
  }

  final AuthRepository _repository;

  Future<void> _restoreSession() async {
    if (!await _repository.hasSession()) {
      state = const AuthState(status: AuthStatus.unauthenticated);
      return;
    }
    try {
      final user = await _repository.fetchCurrentUser();
      state = AuthState(status: AuthStatus.authenticated, user: user);
    } catch (_) {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<bool> login({required String email, required String password}) async {
    try {
      await _repository.login(email: email, password: password);
      final user = await _repository.fetchCurrentUser();
      state = AuthState(status: AuthStatus.authenticated, user: user);
      return true;
    } catch (e) {
      state = AuthState(
        status: AuthStatus.unauthenticated,
        errorMessage: _friendlyError(e),
      );
      return false;
    }
  }

  Future<bool> register({
    required String email,
    required String username,
    required String password,
  }) async {
    try {
      await _repository.register(email: email, username: username, password: password);
      return login(email: email, password: password);
    } catch (e) {
      state = AuthState(
        status: AuthStatus.unauthenticated,
        errorMessage: _friendlyError(e),
      );
      return false;
    }
  }

  Future<void> logout() async {
    await _repository.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  void forceSignOut() {
    state = const AuthState(
      status: AuthStatus.unauthenticated,
      errorMessage: 'Сессия истекла, войдите снова',
    );
  }

  String _friendlyError(Object e) => 'Не удалось выполнить вход. Проверьте данные и подключение.';
}
