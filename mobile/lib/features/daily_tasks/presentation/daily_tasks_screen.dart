import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/daily_task.dart';
import '../../../shared/widgets/amount_entry_dialog.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/task_card.dart';
import '../state/daily_tasks_controller.dart';

class DailyTasksScreen extends ConsumerWidget {
  const DailyTasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(dailyTasksControllerProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        heroTag: 'daily_tasks_fab',
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
                final subtitleParts = [
                  if (task.dueTime != null) 'До ${task.dueTime!.substring(0, 5)}',
                  if (task.isFinancial) '💰 финансовая',
                ];
                return TaskCard(
                  key: ValueKey(task.id),
                  index: index,
                  title: task.title,
                  subtitle: subtitleParts.isEmpty ? null : subtitleParts.join(' · '),
                  isCompleted: task.isCompleted,
                  isOverdue: task.isOverdue,
                  onToggle: () => _handleToggle(context, ref, task),
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

  Future<void> _handleToggle(BuildContext context, WidgetRef ref, DailyTaskInstance task) async {
    final controller = ref.read(dailyTasksControllerProvider.notifier);

    if (task.isCompleted) {
      await controller.uncomplete(task);
      return;
    }

    if (task.isFinancial) {
      final result = await showAmountEntryDialog(context, title: 'Сколько заработано?');
      if (result == null) return;
      await controller.complete(task, amount: result.amount, goalId: result.goalId);
      return;
    }

    await controller.complete(task);
  }

  void _showAddSheet(BuildContext context, WidgetRef ref) {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    TimeOfDay? pickedTime;
    bool isFinancial = false;

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
                Text('Новая ежедневная задача', style: Theme.of(sheetContext).textTheme.titleLarge),
                const SizedBox(height: 16),
                TextField(
                  controller: titleController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Название'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  textCapitalization: TextCapitalization.sentences,
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
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Финансовая задача'),
                  subtitle: const Text('При выполнении нужно будет указать заработанную сумму'),
                  value: isFinancial,
                  onChanged: (value) => setState(() => isFinancial = value),
                ),
                const SizedBox(height: 8),
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
                          isFinancial: isFinancial,
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
