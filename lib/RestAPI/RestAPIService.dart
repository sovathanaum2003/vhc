import 'dart:convert';
import 'package:http/http.dart' as http;

class RestAPIService {
  // Centralized Configuration
  static const String baseUrl = "https://mobileapi.vhtelecbill.app/api";
  static const String token = "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJhdWQiOiJjaGlycHN0YWNrIiwiaXNzIjoiY2hpcnBzdGFjayIsInN1YiI6Ijg2NmI1ZDRjLWFmMDEtNDFhNS05YzA1LTY1YjEwMzQzYzVjOCIsInR5cCI6ImtleSJ9.dQtinFU-AcBU8iYl4RhE0dZPU_oRcIm-pjUC91RZRJU";

  // Generic GET method
  static Future<dynamic> get(String endpoint) async {
    final url = Uri.parse('$baseUrl$endpoint');

    try {
      final response = await http.get(
        url,
        headers: {
          'Grpc-Metadata-Authorization': 'Bearer $token',
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        // Return decoded JSON
        return jsonDecode(response.body);
      } else {
        // throw Exception("Server Error: ${response.statusCode}");
        throw Exception("Server Error: Please check your server.");
      }
    } catch (e) {
      // throw Exception("Network Error: $e");
      throw Exception("Network Error: Please check your network connection.");
    }
  }
}