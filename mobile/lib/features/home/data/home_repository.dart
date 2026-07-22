import '../../../core/api/api_client.dart';
import '../../../models/home_summary.dart';

class HomeRepository {
  HomeRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<HomeSummary> fetchSummary() async {
    final response = await _apiClient.dio.get('/home/summary');
    return HomeSummary.fromJson(response.data as Map<String, dynamic>);
  }
}
