import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../models/home_summary.dart';
import '../../../models/stats.dart';
import '../../statistics/state/stats_providers.dart' show statsRepositoryProvider;
import '../data/home_repository.dart';

final homeRepositoryProvider = Provider<HomeRepository>((ref) {
  return HomeRepository(ref.watch(apiClientProvider));
});

final homeSummaryProvider = FutureProvider.autoDispose<HomeSummary>((ref) {
  return ref.watch(homeRepositoryProvider).fetchSummary();
});

/// Home only needs the streak chips — the full activity chart and task log
/// live in the Statistics tab (see features/statistics).
final statsSummaryProvider = FutureProvider.autoDispose<StatsSummary>((ref) {
  return ref.watch(statsRepositoryProvider).fetchSummary();
});
