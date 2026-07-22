import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/task_card.dart';
import '../state/extra_tasks_controller.dart';

final _deadlineFormat = DateFormat('d MMM, HH:mm', 'ru');

const _priorityLabels = {1: 'Низкая', 2: 'Средняя', 3: 'Высокая'};

class ExtraTasksScreen extends ConsumerWidget {
  const ExtraTasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(extraTasksControllerProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        heroTag: 'extra_tasks_fab',
        onPressed: () => _showAddSheet(context, ref),
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(extraTasksControllerProvider.notifier).refresh(),
        child: tasksAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(
            child: FilledButton(
              onPressed: () => ref.read(extraTasksControllerProvider.notifier).refresh(),
              child: const Text('Повторить'),
            ),
          ),
          data: (tasks) {
            if (tasks.isEmpty) {
              return const EmptyState(
                icon: Icons.task_alt_rounded,
                title: 'Нет дополнительных задач',
                subtitle: 'Добавьте разовую задачу, при желании с дедлайном',
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
                  subtitle: task.deadline != null ? _deadlineFormat.format(task.deadline!.toLocal()) : null,
                  isCompleted: task.isCompleted,
                  isOverdue: task.isOverdue,
                  priorityColor: AppColors.priorityColor(task.priority),
                  onToggle: () => ref.read(extraTasksControllerProvider.notifier).toggle(task),
                  onDelete: () => ref.read(extraTasksControllerProvider.notifier).remove(task.id),
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
    DateTime? pickedDeadline;
    int priority = 1;

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
                Text('Новая задача', style: Theme.of(sheetContext).textTheme.titleLarge),
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
                  icon: const Icon(Icons.event),
                  label: Text(
                    pickedDeadline == null ? 'Без дедлайна' : _deadlineFormat.format(pickedDeadline!),
                  ),
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: sheetContext,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now().subtract(const Duration(days: 1)),
                      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
                    );
                    if (date == null) return;
                    if (!sheetContext.mounted) return;
                    final time = await showTimePicker(
                      context: sheetContext,
                      initialTime: TimeOfDay.now(),
                    );
                    if (time == null) return;
                    setState(() {
                      pickedDeadline =
                          DateTime(date.year, date.month, date.day, time.hour, time.minute);
                    });
                  },
                ),
                const SizedBox(height: 16),
                Text('Важность', style: Theme.of(sheetContext).textTheme.labelLarge),
                const SizedBox(height: 8),
                Row(
                  children: [1, 2, 3].map((level) {
                    final selected = priority == level;
                    final color = AppColors.priorityColor(level);
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: level == 3 ? 0 : 8),
                        child: ChoiceChip(
                          label: Text(_priorityLabels[level]!),
                          selected: selected,
                          onSelected: (_) => setState(() => priority = level),
                          avatar: CircleAvatar(backgroundColor: color, radius: 6),
                          selectedColor: color.withValues(alpha: 0.18),
                          side: BorderSide(color: selected ? color : Colors.transparent),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    final title = titleController.text.trim();
                    if (title.isEmpty) return;
                    ref.read(extraTasksControllerProvider.notifier).add(
                          title: title,
                          description: descController.text.trim(),
                          deadline: pickedDeadline,
                          priority: priority,
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
