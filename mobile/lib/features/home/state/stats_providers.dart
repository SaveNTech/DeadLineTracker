import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../models/stats.dart';
import '../data/stats_repository.dart';

final statsRepositoryProvider = Provider<StatsRepository>((ref) {
  return StatsRepository(ref.watch(apiClientProvider));
});

final statsSummaryProvider = FutureProvider.autoDispose<StatsSummary>((ref) {
  return ref.watch(statsRepositoryProvider).fetchSummary();
});

final dailyStatsProvider = FutureProvider.autoDispose<List<DailyStatPoint>>((ref) {
  return ref.watch(statsRepositoryProvider).fetchDaily();
});
