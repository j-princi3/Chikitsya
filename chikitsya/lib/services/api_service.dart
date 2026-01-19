import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // For Android emulator use 10.0.2.2
  // For real device use your laptop IP (e.g. 192.168.x.x)
  static const String baseUrl = 'http://192.168.1.4:5000';
  static const Duration requestTimeout = Duration(seconds: 60);

  static Future<String> reportSymptoms({
    required List<String> selectedSymptoms,
    required String otherSymptoms,
  }) async {
    final response = await http.post(
      Uri.parse("$baseUrl/report-symptoms"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "symptoms": selectedSymptoms,
        "other_symptoms": otherSymptoms,
      }),
    );

    if (response.statusCode == 200) {
      return response.body;
    } else {
      throw Exception("Failed to report symptoms");
    }
  }

  /// Sends de-identified discharge text to backend
  /// and returns Gemini-generated care plan
  static Future<Map<String, dynamic>> generateCarePlan(
    String dischargeText,
    String language,
  ) async {
    final uri = Uri.parse("$baseUrl/generate-care-plan");
    http.Response response;

    try {
      response = await http
          .post(
            uri,
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "discharge_text": dischargeText,
              "language": language,
            }),
          )
          .timeout(requestTimeout);
    } catch (e) {
      throw Exception(
        "Failed to reach backend at $baseUrl. "
        "Make sure Flask is running and your phone can access the same Wi‑Fi. Details: $e",
      );
    }

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception(
        "Backend error (${response.statusCode}): ${response.body}",
      );
    }
  }
}
