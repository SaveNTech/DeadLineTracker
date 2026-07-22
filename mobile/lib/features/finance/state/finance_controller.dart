import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../models/finance.dart';
import '../data/finance_repository.dart';

final financeRepositoryProvider = Provider<FinanceRepository>((ref) {
  return FinanceRepository(ref.watch(apiClientProvider));
});

final financeSummaryProvider = FutureProvider.autoDispose<FinanceSummary>((ref) {
  return ref.watch(financeRepositoryProvider).fetchSummary();
});

final goalsControllerProvider =
    StateNotifierProvider.autoDispose<GoalsController, AsyncValue<List<FinancialGoal>>>((ref) {
  return GoalsController(ref.watch(financeRepositoryProvider));
});

class GoalsController extends StateNotifier<AsyncValue<List<FinancialGoal>>> {
  GoalsController(this._repository) : super(const AsyncValue.loading()) {
    refresh();
  }

  final FinanceRepository _repository;

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repository.fetchGoals());
  }

  Future<void> addGoal({required String title, required double targetAmount}) async {
    await _repository.createGoal(title: title, targetAmount: targetAmount);
    await refresh();
  }

  Future<void> removeGoal(String goalId) async {
    await _repository.deleteGoal(goalId);
    await refresh();
  }
}

final incomeControllerProvider =
    StateNotifierProvider.autoDispose<IncomeController, AsyncValue<List<IncomeEntry>>>((ref) {
  return IncomeController(ref.watch(financeRepositoryProvider));
});

class IncomeController extends StateNotifier<AsyncValue<List<IncomeEntry>>> {
  IncomeController(this._repository) : super(const AsyncValue.loading()) {
    refresh();
  }

  final FinanceRepository _repository;

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repository.fetchIncome());
  }

  Future<void> addManualEntry({required double amount, String? note, String? goalId}) async {
    await _repository.createIncome(amount: amount, note: note, goalId: goalId);
    await refresh();
  }

  Future<void> assignGoal(String entryId, String? goalId) async {
    await _repository.updateIncomeGoal(entryId, goalId);
    await refresh();
  }

  Future<void> removeEntry(String entryId) async {
    await _repository.deleteIncome(entryId);
    await refresh();
  }
}
