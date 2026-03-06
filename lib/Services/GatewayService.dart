import 'dart:async';
import '../Model/GatewayModel.dart';
import '../RestAPI/RestAPIService.dart';

class GatewayService {
  static Future<List<Gateway>> getGateways(String tenantId) async {
    try {
      // Enforce a strict 5-second timeout on the network request
      final data = await RestAPIService.get('/gateways?limit=1000&tenantId=$tenantId&orderBy=NAME')
          .timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw TimeoutException('No data received within 5 seconds. Please check your connection or server status.');
        },
      );

      final List resultList = data['result'] ?? [];

      // Efficiently map the JSON response to a list of Gateway objects
      return resultList.map((json) => Gateway.fromJson(json)).toList();

    } catch (e) {
      // Pass the clean error message back to the UI
      throw Exception(e.toString());
    }
  }
}