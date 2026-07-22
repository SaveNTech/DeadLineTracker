import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/storage/local_cache.dart';
import '../../../models/home_summary.dart';
import '../../../models/stats.dart';
import '../../statistics/state/stats_providers.dart' show statsRepositoryProvider;
import '../data/home_repository.dart';

final homeRepositoryProvider = Provider<HomeRepository>((ref) {
  return HomeRepository(ref.watch(apiClientProvider));
});

const _cacheKey = 'home_summary';

final homeSummaryProvider =
    StateNotifierProvider.autoDispose<HomeSummaryController, AsyncValue<HomeSummary>>((ref) {
  return HomeSummaryController(ref.watch(homeRepositoryProvider), ref.watch(localCacheProvider));
});

class HomeSummaryController extends StateNotifier<AsyncValue<HomeSummary>> {
  HomeSummaryController(this._repository, this._cache) : super(const AsyncValue.loading()) {
    final cached = _cache.readMap(_cacheKey);
    if (cached != null) state = AsyncValue.data(HomeSummary.fromJson(cached));
    refresh();
  }

  final HomeRepository _repository;
  final LocalCache _cache;

  Future<void> refresh() async {
    if (!state.hasValue) state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() => _repository.fetchSummary());
    result.whenData((summary) => _cache.writeMap(_cacheKey, summary.toJson()));
    if (result.hasError && state.hasValue) return;
    state = result;
  }
}

/// Home only needs the streak chips — the full activity chart and task log
/// live in the Statistics tab (see features/statistics).
final statsSummaryProvider = FutureProvider.autoDispose<StatsSummary>((ref) {
  return ref.watch(statsRepositoryProvider).fetchSummary();
});
