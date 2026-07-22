import '../../../core/api/api_client.dart';
import '../../../models/daily_task.dart';

class DailyTasksRepository {
  DailyTasksRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<DailyTaskInstance>> fetchToday() async {
    final response = await _apiClient.dio.get('/daily-tasks');
    return (response.data as List)
        .map((e) => DailyTaskInstance.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<DailyTaskTemplate>> fetchTemplates() async {
    final response = await _apiClient.dio.get('/daily-tasks/templates');
    return (response.data as List)
        .map((e) => DailyTaskTemplate.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> createTemplate({
    required String title,
    String? description,
    String? dueTime,
    bool isFinancial = false,
  }) {
    return _apiClient.dio.post(
      '/daily-tasks/templates',
      data: {
        'title': title,
        if (description != null && description.isNotEmpty) 'description': description,
        if (dueTime != null) 'due_time': dueTime,
        'is_financial': isFinancial,
      },
    );
  }

  Future<void> deleteTemplate(String templateId) {
    return _apiClient.dio.delete('/daily-tasks/templates/$templateId');
  }

  Future<void> uncomplete(String instanceId) {
    return _apiClient.dio.patch('/daily-tasks/$instanceId/uncomplete');
  }

  /// [amount] is required by the backend when the instance's template is
  /// financial; [goalId] optionally allocates the resulting income entry.
  Future<void> complete(String instanceId, {double? amount, String? goalId}) {
    return _apiClient.dio.patch(
      '/daily-tasks/$instanceId/complete',
      data: {
        if (amount != null) 'amount': amount,
        if (goalId != null) 'goal_id': goalId,
      },
    );
  }
}
