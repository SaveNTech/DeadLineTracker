import '../../../core/api/api_client.dart';
import '../../../models/stats.dart';

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
      queryParameters: {
        'from': _formatDate(from),
        'to': _formatDate(to),
      },
    );
    return (response.data as List)
        .map((e) => DailyStatPoint.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  String _formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
