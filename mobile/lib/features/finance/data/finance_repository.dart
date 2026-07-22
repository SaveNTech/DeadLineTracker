import '../../../core/api/api_client.dart';
import '../../../models/finance.dart';

class FinanceRepository {
  FinanceRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<FinanceSummary> fetchSummary() async {
    final response = await _apiClient.dio.get('/finance/summary');
    return FinanceSummary.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<FinancialGoal>> fetchGoals() async {
    final response = await _apiClient.dio.get('/finance/goals');
    return (response.data as List)
        .map((e) => FinancialGoal.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> createGoal({required String title, required double targetAmount}) {
    return _apiClient.dio.post(
      '/finance/goals',
      data: {'title': title, 'target_amount': targetAmount},
    );
  }

  Future<void> updateGoal(String goalId, {String? title, double? targetAmount}) {
    return _apiClient.dio.patch(
      '/finance/goals/$goalId',
      data: {
        if (title != null) 'title': title,
        if (targetAmount != null) 'target_amount': targetAmount,
      },
    );
  }

  Future<void> deleteGoal(String goalId) {
    return _apiClient.dio.delete('/finance/goals/$goalId');
  }

  Future<List<IncomeEntry>> fetchIncome({DateTime? from, DateTime? to}) async {
    final response = await _apiClient.dio.get(
      '/finance/income',
      queryParameters: {
        if (from != null) 'from': _formatDate(from),
        if (to != null) 'to': _formatDate(to),
      },
    );
    return (response.data as List)
        .map((e) => IncomeEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> createIncome({required double amount, String? note, String? goalId}) {
    return _apiClient.dio.post(
      '/finance/income',
      data: {
        'amount': amount,
        if (note != null && note.isNotEmpty) 'note': note,
        if (goalId != null) 'goal_id': goalId,
      },
    );
  }

  Future<void> updateIncomeGoal(String entryId, String? goalId) {
    return _apiClient.dio.patch('/finance/income/$entryId', data: {'goal_id': goalId});
  }

  Future<void> deleteIncome(String entryId) {
    return _apiClient.dio.delete('/finance/income/$entryId');
  }

  String _formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
