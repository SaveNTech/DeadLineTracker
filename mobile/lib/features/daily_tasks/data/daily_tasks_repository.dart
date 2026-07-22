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

  Future<void> createTemplate({required String title, String? description, String? dueTime}) {
    return _apiClient.dio.post(
      '/daily-tasks/templates',
      data: {
        'title': title,
        if (description != null && description.isNotEmpty) 'description': description,
        if (dueTime != null) 'due_time': dueTime,
      },
    );
  }

  Future<void> deleteTemplate(String templateId) {
    return _apiClient.dio.delete('/daily-tasks/templates/$templateId');
  }

  Future<void> setCompleted(String instanceId, bool completed) {
    final action = completed ? 'complete' : 'uncomplete';
    return _apiClient.dio.patch('/daily-tasks/$instanceId/$action');
  }
}
