// Create a new file: services/roboflow_service.dart
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart'; // For kDebugMode

class RoboflowService {
  // --- ⚠️ IMPORTANT: REPLACE WITH YOUR ACTUAL API DETAILS ---
  // !! NEVER HARDCODE KEYS IN PRODUCTION !! Use secure methods like flutter_dotenv.
  static const String _apiKey = "1dkfDVXCWIeeCE9Fa7nb"; // <--- PASTE YOUR KEY HERE
  // Get this URL from the Roboflow Workflow Deploy Tab (HTTP / cURL section)
  // Make sure it points to YOUR specific workflow endpoint
  static const String _workflowUrl = "https://serverless.roboflow.com/infer/workflows/fyp-symvg/detect-and-classify"; // <--- PASTE YOUR WORKFLOW URL HERE (e.g., fyp-symvg/detect-and-classify)


  // Function to call the Roboflow Workflow API
  static Future<Map<String, dynamic>> analyseSkinWorkflow(File imageFile) async {
    // Basic configuration check
    if (_apiKey == "YOUR_ROBOFLOW_API_KEY" || _workflowUrl.contains("YOUR_")) {
      if (kDebugMode) { // Only print sensitive info in debug mode
        print("API Key or Workflow URL not configured in roboflow_service.dart");
      }
       throw Exception("API Key or Workflow URL not configured.");
    }

    debugPrint("[RoboflowService] Starting analysis for ${imageFile.path}"); // Use debugPrint

    try {
      // 1. Read image bytes and encode to Base64
      List<int> imageBytes = await imageFile.readAsBytes();
      String base64Image = base64Encode(imageBytes);
      debugPrint("[RoboflowService] Image encoded to Base64 (length: ${base64Image.length})");

      // 2. Construct the API request URL
      Uri uri = Uri.parse(_workflowUrl);

      // 3. Construct the JSON body (matching the cURL example)
      final body = jsonEncode({
        "api_key": _apiKey,
        "inputs": {
          // Ensure your workflow's image input is named "image"
          "image": {"type": "base64", "value": base64Image},
          // Add other input parameters if your workflow requires them:
          // "param_name": {"type": "string", "value": "some_value"}
        }
      });

      debugPrint("[RoboflowService] Sending POST request to $uri");

      // 4. Send POST request with timeout
      http.Response response = await http.post(
        uri,
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: body,
      ).timeout(const Duration(seconds: 90)); // Increased timeout for potentially slow networks/processing

      debugPrint("[RoboflowService] Response Status Code: ${response.statusCode}");
      if (kDebugMode) {
        // Avoid printing large bodies in release mode unless necessary
        // You might want to truncate this if the response is huge
        debugPrint("[RoboflowService] Response Body (first 500 chars): ${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}...");
      }


      // 5. Process response
             // 5. Process response
      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        // --- 👇 CORRECTED PARSING LOGIC FOR OBJECT THEN LIST STRUCTURE 👇 ---
        try {
          // Check if the response body is a Map and contains the 'outputs' key
          if (responseBody is Map && responseBody.containsKey('outputs')) {
            var outputsList = responseBody['outputs']; // Get the list associated with the 'outputs' key

            // Check if 'outputsList' is a List and has at least one element
            if (outputsList is List && outputsList.isNotEmpty) {
              var firstOutput = outputsList[0]; // Get the first main output object from the list

              // Check if it's a Map and contains 'classification_predictions'
              if (firstOutput is Map && firstOutput.containsKey('classification_predictions')) {
                var classificationPredictionsList = firstOutput['classification_predictions'];

                // Check if 'classification_predictions' is a List and has at least one element
                if (classificationPredictionsList is List && classificationPredictionsList.isNotEmpty) {
                  var firstClassificationPrediction = classificationPredictionsList[0]; // Get the first classification prediction container

                  // Check if this container is a Map and has the inner 'predictions' object
                  if (firstClassificationPrediction is Map && firstClassificationPrediction.containsKey('predictions')) {
                     var innerPredictionsObject = firstClassificationPrediction['predictions'];

                     // Check if the inner 'predictions' object is a Map and has the 'predictions' list
                     if (innerPredictionsObject is Map && innerPredictionsObject.containsKey('predictions')) {
                        var actualPredictionsList = innerPredictionsObject['predictions'];

                        // Check if the actual 'predictions' list is a List and has at least one element
                        if (actualPredictionsList is List && actualPredictionsList.isNotEmpty) {
                           var finalPrediction = actualPredictionsList[0]; // Get the final prediction map

                           // Check if the final prediction map contains 'class' and 'confidence'
                           if (finalPrediction is Map && finalPrediction.containsKey('class') && finalPrediction.containsKey('confidence')) {
                               debugPrint("[RoboflowService] Successfully parsed nested classification result.");
                               return {
                                 'success': true,
                                 'skin_type': finalPrediction['class']?.toString() ?? 'N/A', // Ensure string
                                 'confidence': (finalPrediction['confidence'] ?? 0.0).toDouble(), // Ensure double
                                 'raw_response': kDebugMode ? responseBody : null // Only include raw in debug
                               };
                           } else {
                              debugPrint("[RoboflowService] Innermost prediction object missing 'class' or 'confidence'. Structure: ${finalPrediction}");
                           }
                        } else {
                           debugPrint("[RoboflowService] Innermost 'predictions' list is missing or empty.");
                        }
                     } else {
                         debugPrint("[RoboflowService] Inner 'predictions' object missing 'predictions' list key.");
                     }
                  } else {
                     debugPrint("[RoboflowService] First classification prediction object missing 'predictions' key.");
                  }
                } else {
                   debugPrint("[RoboflowService] 'classification_predictions' list is missing or empty.");
                }
              } else {
                 debugPrint("[RoboflowService] First main output object (within outputs list) missing 'classification_predictions' key.");
              }
            } else {
               debugPrint("[RoboflowService] 'outputs' key exists but value is not a non-empty list.");
            }
          } else {
             debugPrint("[RoboflowService] Roboflow response body is not a Map or missing 'outputs' key.");
          }

          // If parsing failed after all checks, return failure
          return {'success': false, 'error': 'Could not parse expected classification structure from response', 'raw_response': kDebugMode ? responseBody : response.statusCode};

        } catch (e, stackTrace) {
           // Catch potential errors during nested access (e.g., type mismatch)
           debugPrint("[RoboflowService] Error parsing Roboflow JSON response: $e\n$stackTrace");
           return {'success': false, 'error': 'Error parsing response', 'raw_response': kDebugMode ? responseBody : response.statusCode};
        }

      } else {
         // Handle API errors (Keep this part as is)
         String errorMessage = 'API Error ${response.statusCode}';
         try {
            var errorBody = jsonDecode(response.body);
            errorMessage += ": ${errorBody['message'] ?? response.body}";
         } catch (_) {
            errorMessage += ": ${response.body}";
         }
         debugPrint("[RoboflowService] $errorMessage");
         return {'success': false, 'error': errorMessage};
      }
      
    } catch (e, stackTrace) {
      // Handle network errors, timeouts, etc.
      debugPrint("[RoboflowService] Error calling API: $e\n$stackTrace");
      return {'success': false, 'error': 'Network or processing error: $e'};
    }
  }
}