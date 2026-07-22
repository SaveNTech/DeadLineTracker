import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/notifications/notification_service.dart';
import '../../../core/providers.dart';
import '../../../core/storage/local_cache.dart';
import '../../../models/extra_task.dart';
import '../data/extra_tasks_repository.dart';

final extraTasksRepositoryProvider = Provider<ExtraTasksRepository>((ref) {
  return ExtraTasksRepository(ref.watch(apiClientProvider));
});

const _cacheKey = 'extra_tasks';

final extraTasksControllerProvider =
    StateNotifierProvider.autoDispose<ExtraTasksController, AsyncValue<List<ExtraTask>>>((ref) {
  return ExtraTasksController(ref.watch(extraTasksRepositoryProvider), ref.watch(localCacheProvider));
});

class ExtraTasksController extends StateNotifier<AsyncValue<List<ExtraTask>>> {
  ExtraTasksController(this._repository, this._cache) : super(const AsyncValue.loading()) {
    _loadFromCache();
    refresh();
  }

  final ExtraTasksRepository _repository;
  final LocalCache _cache;

  void _loadFromCache() {
    final cached = _cache.readList(_cacheKey);
    if (cached == null) return;
    state = AsyncValue.data(cached.map(ExtraTask.fromJson).toList());
  }

  Future<void> refresh() async {
    if (!state.hasValue) state = const AsyncValue.loading();
    final result = await AsyncValue.guard(() => _repository.fetchAll());
    result.whenData((items) {
      _cache.writeList(_cacheKey, items.map((e) => e.toJson()).toList());
      _syncReminders(items);
    });
    if (result.hasError && state.hasValue) return;
    state = result;
  }

  Future<void> _syncReminders(List<ExtraTask> items) async {
    for (final task in items) {
      final deadline = task.deadline;
      if (task.isCompleted || deadline == null) {
        await NotificationService.instance.cancelTaskReminder('extra_${task.id}');
        continue;
      }
      await NotificationService.instance.scheduleTaskReminder(
        taskId: 'extra_${task.id}',
        title: 'Дедлайн: ${task.title}',
        body: 'Задача ещё не выполнена',
        deadline: deadline,
      );
    }
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
    await NotificationService.instance.cancelTaskReminder('extra_$taskId');
    try {
      await _repository.delete(taskId);
    } catch (_) {
      state = previous;
    }
  }

  Future<void> toggle(ExtraTask task) async {
    final target = !task.isCompleted;
    if (target) await NotificationService.instance.cancelTaskReminder('extra_${task.id}');
    try {
      await _repository.setCompleted(task.id, target);
    } finally {
      await refresh();
    }
  }
}
