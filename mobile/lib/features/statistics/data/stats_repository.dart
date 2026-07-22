import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../../../models/stats.dart';
import '../../../models/stats_log.dart';

class StatsRepository {
  StatsRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<StatsSummary> fetchSummary() async {
    final response = await _apiClient.dio.get('/stats/summary');
    return StatsSummary.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<DailyStatPoint>> fetchDaily({int days = 14}) async {
    final to = DateTime.now();
    final from = to.subtract(Duration(days: days - 1));
    final response = await _apiClient.dio.get(
      '/stats/daily',
      queryParameters: {'from': _formatDate(from), 'to': _formatDate(to)},
    );
    return (response.data as List)
        .map((e) => DailyStatPoint.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<TaskLogResponse> fetchTaskLog({required DateTime from, required DateTime to}) async {
    final response = await _apiClient.dio.get(
      '/stats/log',
      queryParameters: {'from': _formatDate(from), 'to': _formatDate(to)},
    );
    return TaskLogResponse.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<int>> exportCsv({required DateTime from, required DateTime to}) async {
    final response = await _apiClient.dio.get<List<int>>(
      '/stats/log/export',
      queryParameters: {'from': _formatDate(from), 'to': _formatDate(to)},
      options: Options(responseType: ResponseType.bytes),
    );
    return response.data!;
  }

  Future<TemplateStatsDetail> fetchTemplateHistory(
    String templateId, {
    DateTime? from,
    DateTime? to,
  }) async {
    final response = await _apiClient.dio.get(
      '/stats/daily-tasks/$templateId',
      queryParameters: {
        if (from != null) 'from': _formatDate(from),
        if (to != null) 'to': _formatDate(to),
      },
    );
    return TemplateStatsDetail.fromJson(response.data as Map<String, dynamic>);
  }

  String _formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
