import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../models/daily_task.dart';
import '../data/daily_tasks_repository.dart';

final dailyTasksRepositoryProvider = Provider<DailyTasksRepository>((ref) {
  return DailyTasksRepository(ref.watch(apiClientProvider));
});

final dailyTasksControllerProvider =
    StateNotifierProvider<DailyTasksController, AsyncValue<List<DailyTaskInstance>>>((ref) {
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

  Future<void> addTemplate({required String title, String? description, String? dueTime}) async {
    await _repository.createTemplate(title: title, description: description, dueTime: dueTime);
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

  Future<void> toggle(DailyTaskInstance instance) async {
    final target = !instance.isCompleted;
    // optimistic update so the checkmark and re-sort feel instant
    state = state.whenData(
      (items) => items
          .map((i) => i.id == instance.id ? _withCompleted(i, target) : i)
          .toList(),
    );
    try {
      await _repository.setCompleted(instance.id, target);
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
        isCompleted: completed,
        completedAt: completed ? DateTime.now() : null,
        isOverdue: completed ? false : i.isOverdue,
      );
}
