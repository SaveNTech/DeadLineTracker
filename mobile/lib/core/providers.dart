import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api/api_client.dart';
import 'storage/local_cache.dart';
import 'storage/token_storage.dart';

final tokenStorageProvider = Provider<TokenStorage>((ref) {
  return TokenStorage(const FlutterSecureStorage());
});

/// Overridden with the real instance in main() before runApp — SharedPreferences
/// needs an async init that can't happen inside a provider constructor.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden in main()');
});

final localCacheProvider = Provider<LocalCache>((ref) {
  return LocalCache(ref.watch(sharedPreferencesProvider));
});

/// Bumped whenever the API client decides the session is no longer valid
/// (refresh failed on a 401), so the auth controller can react and the
/// router can redirect to /login.
final unauthenticatedEventProvider = StateProvider<int>((ref) => 0);

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(ref.watch(tokenStorageProvider));
  client.onUnauthenticated = () {
    ref.read(unauthenticatedEventProvider.notifier).state++;
  };
  return client;
});
