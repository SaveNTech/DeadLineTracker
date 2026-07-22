import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/finance/state/finance_controller.dart';

class AmountEntryResult {
  const AmountEntryResult({required this.amount, this.goalId});
  final double amount;
  final String? goalId;
}

/// Shown when completing a "financial" daily task (amount required) and when
/// manually logging income from the Finance tab (amount required either way,
/// goal always optional).
Future<AmountEntryResult?> showAmountEntryDialog(
  BuildContext context, {
  required String title,
}) {
  return showDialog<AmountEntryResult>(
    context: context,
    builder: (context) => _AmountEntryDialog(title: title),
  );
}

class _AmountEntryDialog extends ConsumerStatefulWidget {
  const _AmountEntryDialog({required this.title});
  final String title;

  @override
  ConsumerState<_AmountEntryDialog> createState() => _AmountEntryDialogState();
}

class _AmountEntryDialogState extends ConsumerState<_AmountEntryDialog> {
  final _amountController = TextEditingController();
  String? _selectedGoalId;
  String? _error;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = double.tryParse(_amountController.text.replaceAll(',', '.'));
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Введите сумму больше нуля');
      return;
    }
    Navigator.of(context).pop(AmountEntryResult(amount: amount, goalId: _selectedGoalId));
  }

  @override
  Widget build(BuildContext context) {
    final goalsAsync = ref.watch(goalsControllerProvider);

    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _amountController,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: 'Сумма, ₽', errorText: _error),
          ),
          const SizedBox(height: 12),
          goalsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (goals) {
              if (goals.isEmpty) return const SizedBox.shrink();
              return DropdownMenu<String?>(
                expandedInsets: EdgeInsets.zero,
                label: const Text('Отнести к цели (необязательно)'),
                initialSelection: _selectedGoalId,
                dropdownMenuEntries: [
                  const DropdownMenuEntry<String?>(value: null, label: 'Без цели'),
                  ...goals.map(
                    (g) => DropdownMenuEntry<String?>(value: g.id, label: g.title),
                  ),
                ],
                onSelected: (value) => setState(() => _selectedGoalId = value),
              );
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Сохранить')),
      ],
    );
  }
}
