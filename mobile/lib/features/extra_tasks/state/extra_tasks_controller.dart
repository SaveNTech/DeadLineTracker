import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../models/extra_task.dart';
import '../data/extra_tasks_repository.dart';

final extraTasksRepositoryProvider = Provider<ExtraTasksRepository>((ref) {
  return ExtraTasksRepository(ref.watch(apiClientProvider));
});

final extraTasksControllerProvider =
    StateNotifierProvider.autoDispose<ExtraTasksController, AsyncValue<List<ExtraTask>>>((ref) {
  return ExtraTasksController(ref.watch(extraTasksRepositoryProvider));
});

class ExtraTasksController extends StateNotifier<AsyncValue<List<ExtraTask>>> {
  ExtraTasksController(this._repository) : super(const AsyncValue.loading()) {
    refresh();
  }

  final ExtraTasksRepository _repository;

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repository.fetchAll());
  }

  Future<void> add({
    required String title,
    String? description,
    DateTime? deadline,
    int priority = 1,
  }) async {
    await _repository.create(
      title: title,
      description: description,
      deadline: deadline,
      priority: priority,
    );
    await refresh();
  }

  Future<void> remove(String taskId) async {
    final previous = state;
    state = state.whenData((items) => items.where((t) => t.id != taskId).toList());
    try {
      await _repository.delete(taskId);
    } catch (_) {
      state = previous;
    }
  }

  Future<void> toggle(ExtraTask task) async {
    final target = !task.isCompleted;
    try {
      await _repository.setCompleted(task.id, target);
    } finally {
      await refresh();
    }
  }
}
