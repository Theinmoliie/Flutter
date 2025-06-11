// lib/services/gemini_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as p; // Add path package for getting extension
import 'package:http_parser/http_parser.dart'; // Add http_parser for mime type

class GeminiService {
  final functions = Supabase.instance.client.functions;

  /// Analyzes the skin type by calling a Supabase Edge Function.
  /// This function now converts the image to a base64 string to use with 'invoke'.
  Future<String?> analyzeSkinType(File imageFile) async {
    try {
      // 1. Read the image file as bytes.
      final imageBytes = await imageFile.readAsBytes();

      // 2. Convert the bytes to a base64 string.
      final String base64Image = base64Encode(imageBytes);

      // 3. Determine the MIME type from the file extension.
      final String fileExtension = p.extension(imageFile.path).toLowerCase();
      // Use MediaType to look up the mime type, default to jpeg if unknown.
      final mimeType = MediaType.parse('image/${fileExtension.replaceAll('.', '')}').toString();
      
      // 4. Create the data URI format that the Edge Function expects.
      final String dataUri = 'data:$mimeType;base64,$base64Image';
      
      debugPrint("Invoking 'analyze-skin' function...");

      // 5. Use the correct 'invoke' method.
      final response = await functions.invoke(
        'analyze-skin',
        body: {'image': dataUri}, // Send the base64 string in the body
      );

      if (response.status == 200) {
        final data = response.data;
        final skinType = data['skinType'] as String?;
        debugPrint("Successfully received skin type: $skinType");

        if (skinType == 'Uncertain') {
          return null; // Return null to indicate failure/uncertainty
        }

        return skinType;
      } else {
        debugPrint("Edge Function failed with status ${response.status}: ${response.data}");
        return null;
      }
    } catch (e) {
      // The 'invoke' method throws a FunctionException on error
      if (e is FunctionException) {
        debugPrint("Error from Supabase Function: $e");
      } else {
        debugPrint("An unexpected error occurred: $e");
      }
      return null;
    }
  }
}