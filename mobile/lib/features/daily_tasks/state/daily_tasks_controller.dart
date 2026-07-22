import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/notifications/notification_service.dart';
import '../../../core/providers.dart';
import '../../../core/storage/local_cache.dart';
import '../../../models/daily_task.dart';
import '../data/daily_tasks_repository.dart';

final dailyTasksRepositoryProvider = Provider<DailyTasksRepository>((ref) {
  return DailyTasksRepository(ref.watch(apiClientProvider));
});

/// Used by the Statistics tab to list habits for per-task history drill-down.
final dailyTemplatesProvider = FutureProvider.autoDispose<List<DailyTaskTemplate>>((ref) {
  return ref.watch(dailyTasksRepositoryProvider).fetchTemplates();
});

const _cacheKey = 'daily_tasks_today';

final dailyTasksControllerProvider = StateNotifierProvider.autoDispose<
    DailyTasksController, AsyncValue<List<DailyTaskInstance>>>((ref) {
  return DailyTasksController(ref.watch(dailyTasksRepositoryProvider), ref.watch(localCacheProvider));
});

class DailyTasksController extends StateNotifier<AsyncValue<List<DailyTaskInstance>>> {
  DailyTasksController(this._repository, this._cache) : super(const AsyncValue.loading()) {
    _loadFromCache();
    refresh();
  }

  final DailyTasksRepository _repository;
  final LocalCache _cache;

  /// Shows the last-known list instantly (from disk) while [refresh] fetches
  /// a live copy in the background — avoids a loading spinner on every
  /// cold start when we already know roughly what the list looks like.
  void _loadFromCache() {
    final cached = _cache.readList(_cacheKey);
    if (cached == null) return;
    state = AsyncValue.data(cached.map(DailyTaskInstance.fromJson).toList());
  }

  Future<void> refresh() async {
    if (!state.hasValue) state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() => _repository.fetchToday());
    result.whenData((items) {
      _cache.writeList(_cacheKey, items.map((e) => e.toJson()).toList());
      _syncReminders(items);
    });
    // Keep showing cached data if the live fetch failed (e.g. offline).
    if (result.hasError && state.hasValue) return;
    state = result;
  }

  Future<void> _syncReminders(List<DailyTaskInstance> items) async {
    for (final item in items) {
      final due = item.dueDateTime;
      if (item.isCompleted || due == null) {
        await NotificationService.instance.cancelTaskReminder('daily_${item.id}');
        continue;
      }
      await NotificationService.instance.scheduleTaskReminder(
        taskId: 'daily_${item.id}',
        title: 'Пора выполнить: ${item.title}',
        body: 'Ежедневная задача ещё не отмечена как выполненная',
        deadline: due,
      );
    }
  }

  Future<void> addTemplate({
    required String title,
    String? description,
    String? dueTime,
    bool isFinancial = false,
  }) async {
    await _repository.createTemplate(
      title: title,
      description: description,
      dueTime: dueTime,
      isFinancial: isFinancial,
    );
    await refresh();
  }

  Future<void> removeTemplate(String templateId) async {
    final previous = state;
    final removedInstance =
        (state.valueOrNull ?? const []).where((i) => i.templateId == templateId).firstOrNull;
    state = state.whenData(
      (items) => items.where((i) => i.templateId != templateId).toList(),
    );
    if (removedInstance != null) {
      await NotificationService.instance.cancelTaskReminder('daily_${removedInstance.id}');
    }
    try {
      await _repository.deleteTemplate(templateId);
    } catch (_) {
      state = previous;
    }
  }

  /// Completes a non-financial task, or a financial one once the caller has
  /// already collected [amount] (see DailyTasksScreen's completion flow).
  Future<void> complete(DailyTaskInstance instance, {double? amount, String? goalId}) async {
    state = state.whenData(
      (items) => items.map((i) => i.id == instance.id ? _withCompleted(i, true) : i).toList(),
    );
    await NotificationService.instance.cancelTaskReminder('daily_${instance.id}');
    try {
      await _repository.complete(instance.id, amount: amount, goalId: goalId);
    } finally {
      await refresh();
    }
  }

  Future<void> uncomplete(DailyTaskInstance instance) async {
    state = state.whenData(
      (items) => items.map((i) => i.id == instance.id ? _withCompleted(i, false) : i).toList(),
    );
    try {
      await _repository.uncomplete(instance.id);
    } finally {
      await refresh();
    }
  }

  DailyTaskInstance _withCompleted(DailyTaskInstance i, bool completed) => DailyTaskInstance(
        id: i.id,
        templateId: i.templateId,
        title: i.title,
        description: i.description,
        date: i.date,
        dueTime: i.dueTime,
        isFinancial: i.isFinancial,
        isCompleted: completed,
        completedAt: completed ? DateTime.now() : null,
        isOverdue: completed ? false : i.isOverdue,
      );
}
