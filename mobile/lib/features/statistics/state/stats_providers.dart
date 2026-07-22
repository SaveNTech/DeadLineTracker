import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../models/stats.dart';
import '../../../models/stats_log.dart';
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

class DateRange {
  const DateRange(this.from, this.to);
  final DateTime from;
  final DateTime to;

  @override
  bool operator ==(Object other) =>
      other is DateRange && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);
}

final taskLogProvider =
    FutureProvider.autoDispose.family<TaskLogResponse, DateRange>((ref, range) {
  return ref.watch(statsRepositoryProvider).fetchTaskLog(from: range.from, to: range.to);
});

final templateHistoryProvider =
    FutureProvider.autoDispose.family<TemplateStatsDetail, String>((ref, templateId) {
  return ref.watch(statsRepositoryProvider).fetchTemplateHistory(templateId);
});
