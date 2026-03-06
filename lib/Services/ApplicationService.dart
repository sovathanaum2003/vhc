import '../RestAPI/RestAPIService.dart';
import '../Model/ApplicationModel.dart';

class ApplicationService {

  // 1. Get List of Applications
  static Future<List<ApplicationModel>> getApplications(String tenantId) async {
    try {
      final data = await RestAPIService.get('/applications?limit=100&tenantId=$tenantId');
      final List resultList = data['result'] ?? [];
      return resultList.map((json) => ApplicationModel.fromJson(json)).toList();
    } catch (e) {
      throw Exception("Failed to load applications: $e");
    }
  }

  // 2. NEW: Get Device Count for a specific Application
  static Future<int> getDeviceCount(String applicationId) async {
    try {
      // We limit=1 because we only care about the 'totalCount' field, not the actual list
      final data = await RestAPIService.get('/devices?limit=1&applicationId=$applicationId');

      // Chirpstack returns totalCount as a String or Int depending on version
      var total = data['totalCount'];

      if (total is int) return total;
      if (total is String) return int.tryParse(total) ?? 0;
      return 0;
    } catch (e) {
      return 0; // If error, show 0
    }
  }
}