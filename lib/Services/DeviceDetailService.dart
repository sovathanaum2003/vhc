import 'dart:convert';
import 'package:http/http.dart' as http;
import '../RestAPI/RestAPIService.dart';

class DeviceDetailService {
  /// GET Device Details using the central RestAPIService
  static Future<Map<String, dynamic>> fetchDevice(String devEui) async {
    // RestAPIService handles the base URL, token, and JSON decoding
    return await RestAPIService.get("/devices/$devEui");
  }

  /// PUT Update Device (Currently RestAPIService only has GET, so we use http.put with centralized constants)
  static Future<bool> updateDevice(
      String devEui,
      Map<String, dynamic> originalDeviceData,
      Map<String, dynamic> variables
      ) async {
    final body = {
      "device": {
        "devEui": originalDeviceData["devEui"],
        "name": originalDeviceData["name"],
        "description": originalDeviceData["description"],
        "applicationId": originalDeviceData["applicationId"],
        "deviceProfileId": originalDeviceData["deviceProfileId"],
        "skipFcntCheck": originalDeviceData["skipFcntCheck"],
        "isDisabled": originalDeviceData["isDisabled"],
        "variables": variables,
      }
    };

    final response = await http.put(
      Uri.parse("${RestAPIService.baseUrl}/devices/$devEui"),
      headers: {
        "Authorization": "Bearer ${RestAPIService.token}",
        "Grpc-Metadata-Authorization": "Bearer ${RestAPIService.token}",
        "Content-Type": "application/json",
      },
      body: jsonEncode(body),
    );

    return response.statusCode == 200;
  }
}