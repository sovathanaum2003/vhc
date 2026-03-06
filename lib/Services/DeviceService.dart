import 'dart:async';
import '../RestAPI/RestAPIService.dart';
import '../Model/DeviceModel.dart';

class DeviceService {
  // --- In-Memory Cache for Instant Re-visits ---
  static final Map<String, List<DeviceModel>> _deviceCache = {};

  static Future<List<DeviceModel>> getDevices(String applicationId, {bool forceRefresh = false}) async {
    try {
      // Return cached data immediately if available and not forcing a refresh
      if (!forceRefresh && _deviceCache.containsKey(applicationId)) {
        return _deviceCache[applicationId]!;
      }

      // Increased limit to 1000 to ensure frontend search applies to all devices
      final String endpoint = '/devices?limit=1000&applicationId=$applicationId';

      // Enforce a strict 15-second timeout on the network request
      final data = await RestAPIService.get(endpoint).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException('Please check your connection or server status.');
        },
      );

      final List resultList = data['result'] ?? [];
      final devices = resultList.map((json) => DeviceModel.fromJson(json)).toList();

      // Save the fresh data to cache
      _deviceCache[applicationId] = devices;

      return devices;

    } catch (e) {
      // Pass the clean error message back to the UI
      throw Exception(e.toString());
    }
  }

  // Optional: Call this when user logs out or switches tenants
  static void clearCache() {
    _deviceCache.clear();
  }
}