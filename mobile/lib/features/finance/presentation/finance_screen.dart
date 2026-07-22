import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/finance.dart';
import '../../../shared/widgets/amount_entry_dialog.dart';
import '../../../shared/widgets/empty_state.dart';
import '../state/finance_controller.dart';

class FinanceScreen extends ConsumerWidget {
  const FinanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final summaryAsync = ref.watch(financeSummaryProvider);
    final goalsAsync = ref.watch(goalsControllerProvider);
    final incomeAsync = ref.watch(incomeControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Финансы')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddMenu(context, ref),
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(financeSummaryProvider);
          await ref.read(goalsControllerProvider.notifier).refresh();
          await ref.read(incomeControllerProvider.notifier).refresh();
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            summaryAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (summary) => Row(
                children: [
                  Expanded(
                    child: _MoneyStat(
                      label: 'За месяц',
                      amount: summary.totalThisMonth,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MoneyStat(
                      label: 'Всего',
                      amount: summary.totalAllTime,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('Цели', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            goalsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Text('Не удалось загрузить цели'),
              data: (goals) {
                if (goals.isEmpty) {
                  return const EmptyState(
                    icon: Icons.flag_rounded,
                    title: 'Пока нет целей',
                    subtitle: 'Например, «закрыть кредит» — добавьте её через +',
                  );
                }
                return GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.95,
                  children: goals.map((g) => _GoalCard(goal: g, ref: ref)).toList(),
                );
              },
            ),
            const SizedBox(height: 24),
            Text('Доход', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            incomeAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Text('Не удалось загрузить доход'),
              data: (entries) {
                if (entries.isEmpty) {
                  return Text(
                    'Записей пока нет',
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
                  );
                }
                return Column(
                  children: entries
                      .map(
                        (e) => Dismissible(
                          key: ValueKey(e.id),
                          direction: DismissDirection.endToStart,
                          onDismissed: (_) =>
                              ref.read(incomeControllerProvider.notifier).removeEntry(e.id),
                          background: Container(color: AppColors.overdue),
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.payments_rounded, color: AppColors.success),
                            title: Text('+${e.amount.toStringAsFixed(2)} ₽'),
                            subtitle: Text(
                              '${e.entryDate.day}.${e.entryDate.month.toString().padLeft(2, '0')}.${e.entryDate.year}'
                              '${e.note != null ? ' · ${e.note}' : ''}',
                            ),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAddMenu(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.payments_rounded),
              title: const Text('Добавить доход'),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                final result = await showAmountEntryDialog(context, title: 'Добавить доход');
                if (result != null) {
                  await ref
                      .read(incomeControllerProvider.notifier)
                      .addManualEntry(amount: result.amount, goalId: result.goalId);
                  // Progress rings are driven by goalsControllerProvider, which doesn't
                  // know an income entry was just linked to one of its goals.
                  await ref.read(goalsControllerProvider.notifier).refresh();
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.flag_rounded),
              title: const Text('Новая цель'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _showAddGoalDialog(context, ref);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAddGoalDialog(BuildContext context, WidgetRef ref) {
    final titleController = TextEditingController();
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Новая цель'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Название (например, «Мечта на колёсах»)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Сумма цели, ₽'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              final title = titleController.text.trim();
              final amount = double.tryParse(amountController.text.replaceAll(',', '.'));
              if (title.isEmpty || amount == null || amount <= 0) return;
              ref.read(goalsControllerProvider.notifier).addGoal(title: title, targetAmount: amount);
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Создать'),
          ),
        ],
      ),
    );
  }
}

class _MoneyStat extends StatelessWidget {
  const _MoneyStat({required this.label, required this.amount, required this.color});
  final String label;
  final double amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
            ),
            const SizedBox(height: 4),
            Text(
              '${amount.toStringAsFixed(2)} ₽',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.goal, required this.ref});
  final FinancialGoal goal;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        onLongPress: () => _confirmDelete(context),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 76,
                height: 76,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: goal.progress,
                      strokeWidth: 7,
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation(
                        goal.isAchieved ? AppColors.success : AppColors.goalRing,
                      ),
                    ),
                    Text(
                      '${(goal.progress * 100).round()}%',
                      style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                goal.title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                '${goal.currentAmount.toStringAsFixed(0)} / ${goal.targetAmount.toStringAsFixed(0)} ₽',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Удалить «${goal.title}»?'),
        content: const Text('Связанные записи о доходе останутся, просто перестанут быть привязаны к цели.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(goalsControllerProvider.notifier).removeGoal(goal.id);
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }
}
