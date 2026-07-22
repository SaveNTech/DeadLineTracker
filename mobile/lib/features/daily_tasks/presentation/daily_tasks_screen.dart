import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/task_card.dart';
import '../state/daily_tasks_controller.dart';

class DailyTasksScreen extends ConsumerWidget {
  const DailyTasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(dailyTasksControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Ежедневные')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddSheet(context, ref),
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(dailyTasksControllerProvider.notifier).refresh(),
        child: tasksAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => _ErrorView(
            onRetry: () => ref.read(dailyTasksControllerProvider.notifier).refresh(),
          ),
          data: (tasks) {
            if (tasks.isEmpty) {
              return const EmptyState(
                icon: Icons.checklist_rounded,
                title: 'Пока нет ежедневных задач',
                subtitle: 'Добавьте привычку — она будет появляться каждый день заново',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              itemCount: tasks.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final task = tasks[index];
                return TaskCard(
                  key: ValueKey(task.id),
                  index: index,
                  title: task.title,
                  subtitle: task.dueTime != null ? 'До ${task.dueTime!.substring(0, 5)}' : null,
                  isCompleted: task.isCompleted,
                  isOverdue: task.isOverdue,
                  onToggle: () => ref.read(dailyTasksControllerProvider.notifier).toggle(task),
                  onDelete: () =>
                      ref.read(dailyTasksControllerProvider.notifier).removeTemplate(task.templateId),
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _showAddSheet(BuildContext context, WidgetRef ref) {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    TimeOfDay? pickedTime;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setState) => Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Новая привычка', style: Theme.of(sheetContext).textTheme.titleLarge),
                const SizedBox(height: 16),
                TextField(
                  controller: titleController,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Название'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(labelText: 'Описание (необязательно)'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.schedule),
                  label: Text(pickedTime == null ? 'Без времени' : 'До ${pickedTime!.format(sheetContext)}'),
                  onPressed: () async {
                    final time = await showTimePicker(
                      context: sheetContext,
                      initialTime: pickedTime ?? TimeOfDay.now(),
                    );
                    if (time != null) setState(() => pickedTime = time);
                  },
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    final title = titleController.text.trim();
                    if (title.isEmpty) return;
                    final dueTime = pickedTime == null
                        ? null
                        : '${pickedTime!.hour.toString().padLeft(2, '0')}:'
                            '${pickedTime!.minute.toString().padLeft(2, '0')}:00';
                    ref.read(dailyTasksControllerProvider.notifier).addTemplate(
                          title: title,
                          description: descController.text.trim(),
                          dueTime: dueTime,
                        );
                    Navigator.of(sheetContext).pop();
                  },
                  child: const Text('Добавить'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Не удалось загрузить задачи'),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Повторить')),
        ],
      ),
    );
  }
}
