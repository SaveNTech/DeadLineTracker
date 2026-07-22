import '../../../core/api/api_client.dart';
import '../../../models/extra_task.dart';

class ExtraTasksRepository {
  ExtraTasksRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<ExtraTask>> fetchAll() async {
    final response = await _apiClient.dio.get('/extra-tasks');
    return (response.data as List)
        .map((e) => ExtraTask.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> create({
    required String title,
    String? description,
    DateTime? deadline,
    int priority = 1,
  }) {
    return _apiClient.dio.post(
      '/extra-tasks',
      data: {
        'title': title,
        if (description != null && description.isNotEmpty) 'description': description,
        if (deadline != null) 'deadline': deadline.toUtc().toIso8601String(),
        'priority': priority,
      },
    );
  }

  Future<void> delete(String taskId) {
    return _apiClient.dio.delete('/extra-tasks/$taskId');
  }

  Future<void> setCompleted(String taskId, bool completed) {
    final action = completed ? 'complete' : 'uncomplete';
    return _apiClient.dio.patch('/extra-tasks/$taskId/$action');
  }
}
