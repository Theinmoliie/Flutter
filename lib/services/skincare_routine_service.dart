// services/skincare_routine_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart'; // For kDebugMode
import 'package:http/http.dart' as http;
import '../model/routine_models.dart'; // Ensure this path is correct
import 'dart:io'; // <--- ADD THIS IMPORT for SocketException
import 'dart:async';


class SkincareRoutineService {
  // Define your backend API base URL
  // For local development with Android emulator: 'http://10.0.2.2:8000'
  // For local development with iOS simulator or physical device on same Wi-Fi: 'http://YOUR_COMPUTER_IP_ADDRESS:8000'
  // For deployed backend: 'https://your-backend-domain.com'

  // --- IMPORTANT: REPLACE 'YOUR_COMPUTER_IP_ADDRESS' with your actual IP ---
  // ---      when testing with a physical device on the same Wi-Fi.     ---
  static const String _localDevAndroidEmulatorBaseUrl = 'http://10.0.2.2:8000';
  static const String _localDevPhysicalOrIOSBaseUrl = 'http://192.168.1.28:8000'; // <<<<<<< CHANGE THIS
  static const String _productionBaseUrl = 'https://your-deployed-api.com'; // <<<<<<< CHANGE THIS IF DEPLOYED

  String get _baseUrl {
    if (kDebugMode) {
      // You might need a way to differentiate between emulator and physical device in debug
      // For simplicity, let's assume physical device if not web and not emulator
      // This detection is not foolproof. Better to use environment variables for Flutter.
      // For now, manually switch or use a more robust detection if needed.
      // return _localDevAndroidEmulatorBaseUrl; // Use this for Android Emulator
      return _localDevPhysicalOrIOSBaseUrl; // Use this for physical device / iOS Sim
    } else {
      return _productionBaseUrl;
    }
  }

  Future<SkincareRoutine?> buildRoutine({
    required int? skinTypeId,
    required String? sensitivity, // "Yes" or "No"
    required Set<int> concernIds,
  }) async {
    if (skinTypeId == null || sensitivity == null) {
      debugPrint("SkincareRoutineService: Skin type ID or sensitivity is null. Cannot call backend.");
      return null;
    }

    final String apiUrl = '$_baseUrl/build_routine';
    debugPrint("SkincareRoutineService: Calling API: $apiUrl");

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode({
          'skin_type_id': skinTypeId,
          'sensitivity': sensitivity,
          'concern_ids': concernIds.toList(),
        }),
      ).timeout(const Duration(seconds: 20)); // Added timeout

      debugPrint("SkincareRoutineService: API Response Status: ${response.statusCode}");
      if (kDebugMode) { // Only print full body in debug mode
        // debugPrint("SkincareRoutineService: API Response Body: ${response.body}");
      }


      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
            debugPrint("SkincareRoutineService: Parsable API Response Body: ${response.body}"); // Print the raw JSON
        return SkincareRoutine.fromJson(responseData);
      } else {
        debugPrint('SkincareRoutineService: Failed to build routine. Status code: ${response.statusCode}');
        debugPrint('SkincareRoutineService: Response body: ${response.body}');
        throw Exception('Failed to load routine from backend: ${response.statusCode} ${response.reasonPhrase}');
      }
    } catch (e) {
      debugPrint('SkincareRoutineService: Error calling buildRoutine API: $e');
      if (e is http.ClientException || e is SocketException || e is TimeoutException) {
        throw Exception('Network error or server unavailable. Please check your connection and try again.');
      }
      throw Exception('Error connecting to routine builder service: $e');
    }
  }
}