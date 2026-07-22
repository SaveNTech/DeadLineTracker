import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../models/daily_task.dart';
import '../data/daily_tasks_repository.dart';

final dailyTasksRepositoryProvider = Provider<DailyTasksRepository>((ref) {
  return DailyTasksRepository(ref.watch(apiClientProvider));
});

/// Used by the Statistics tab to list habits for per-task history drill-down.
final dailyTemplatesProvider = FutureProvider.autoDispose<List<DailyTaskTemplate>>((ref) {
  return ref.watch(dailyTasksRepositoryProvider).fetchTemplates();
});

final dailyTasksControllerProvider = StateNotifierProvider.autoDispose<
    DailyTasksController, AsyncValue<List<DailyTaskInstance>>>((ref) {
  return DailyTasksController(ref.watch(dailyTasksRepositoryProvider));
});

class DailyTasksController extends StateNotifier<AsyncValue<List<DailyTaskInstance>>> {
  DailyTasksController(this._repository) : super(const AsyncValue.loading()) {
    refresh();
  }

  final DailyTasksRepository _repository;

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repository.fetchToday());
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
    state = state.whenData(
      (items) => items.where((i) => i.templateId != templateId).toList(),
    );
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
