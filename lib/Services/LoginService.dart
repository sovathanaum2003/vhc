
import '../RestAPI/RestAPIService.dart';

class TenantService {

  static Future<String?> getTenantIdByName(String name) async {
    try {
      // Use the global service. Note: endpoint starts with /
      final data = await RestAPIService.get('/tenants?limit=10&search=$name');

      // Parsing logic
      final List<dynamic> result = data['result'] ?? [];

      if (result.isNotEmpty) {
        return result[0]['id'].toString();
      }
      return null;

    } catch (e) {
      // print("Error fetching tenant: $e");
      print("Error fetching tenant.");
      return null;
    }
  }
}