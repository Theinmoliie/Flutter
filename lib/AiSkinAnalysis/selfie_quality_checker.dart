// lib/selfie_quality_checker.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:math';
import 'dart:ui'; // Required for Rect
import 'package:flutter/foundation.dart'; // For kIsWeb, debugPrint
import 'package:flutter/material.dart'; // For Rect, Size, debugPrint
import 'package:image/image.dart' as img;
// Use the broader ML Kit import
import 'package:google_ml_kit/google_ml_kit.dart';

// Result class to return either an error or the detected Face
class QualityCheckResult {
  final String? error;
  final Face? face;

  QualityCheckResult({this.error, this.face});

  bool get isValid => error == null && face != null;
}


class ImageQualityChecker {
  // Returns a QualityCheckResult containing an error string or a Face object
  static Future<QualityCheckResult> getQualityIssue(
    File imageFile, {
    required Size guideBoxSize, // Used for context, not direct cropping here
    required Size screenSize,   // Used for context, not direct cropping here
  }) async {
    try {
      // --- Basic File Checks ---
      if (!await imageFile.exists()) {
        return QualityCheckResult(error: "Image file not found");
      }
      final fileLength = await imageFile.length();
      if (fileLength < 1024 * 50) { // Check for minimum size (e.g., 50KB)
        return QualityCheckResult(error: "Image file too small (less than 50KB)");
      }
      print("Image file length: $fileLength bytes");

      // --- Image Decoding and Initial Validation ---
      final imageData = await imageFile.readAsBytes();
      // Use a timeout for decoding potentially large/corrupt images
      final image = await _decodeImageWithTimeout(Uint8List.fromList(imageData));
      if (image == null) {
        return QualityCheckResult(error: "Could not process image (decode failed or timed out)");
      }
      print("Image decoded: ${image.width}x${image.height}");

      // Basic resolution check (can adjust thresholds)
      if (image.width < 480 || image.height < 640) {
        return QualityCheckResult(error: "Move closer - higher resolution needed (min 480x640)");
      }

      // --- Face Detection using ML Kit ---
      // Initialize the face detector
      final faceDetector = GoogleMlKit.vision.faceDetector(
        FaceDetectorOptions(
          performanceMode: FaceDetectorMode.accurate, // Prioritize accuracy
          enableLandmarks: true, // Need landmarks for angle check
          enableContours: true, // Keep contours if needed for future checks, otherwise disable
          enableClassification: false, // Not needed for quality checks
          enableTracking: false, // Not needed for single image
          minFaceSize: 0.15, // Detect faces that are at least 15% of the image width
        ),
      );

      // Prepare the image for ML Kit
      final inputImage = InputImage.fromFilePath(imageFile.path);

      // Process the image to detect faces
      final List<Face> faces = await faceDetector.processImage(inputImage);

      // Release the detector resources
      await faceDetector.close();

      // --- Face Presence and Count Check ---
      if (faces.isEmpty) {
        return QualityCheckResult(error: "Face not detected - please center your face");
      }
      if (faces.length > 1) {
        return QualityCheckResult(error: "Multiple faces detected - only one face should be visible");
      }

      final face = faces.first;

      // --- Bounding Box Check ---
      // Ensure bounding box was actually detected
      if (face.boundingBox == null) {
         return QualityCheckResult(error: "Could not detect face boundary");
      }

      // --- Face Size Check (Relative to Image) ---
      final faceWidth = face.boundingBox.width;
      final faceHeight = face.boundingBox.height;
      final faceArea = faceWidth * faceHeight;

      // Use image dimensions derived from InputImage metadata if available for accuracy
      final imageWidth = inputImage.metadata?.size.width ?? image.width.toDouble();
      final imageHeight = inputImage.metadata?.size.height ?? image.height.toDouble();
      final imageArea = imageWidth * imageHeight;

      if (imageArea <= 0) { // Sanity check
        return QualityCheckResult(error: "Invalid image dimensions detected");
      }

      final faceCoverage = faceArea / imageArea;
      print("Face BBox: ${face.boundingBox}");
      print("Image Size (ML Kit): ${imageWidth}x$imageHeight");
      print("Face Coverage: ${(faceCoverage * 100).toStringAsFixed(1)}%");

      // Adjust coverage thresholds as needed based on testing
      if (faceCoverage < 0.15) { // Slightly lower threshold
        return QualityCheckResult(error: "Move closer - face is too small in the frame");
      }
      if (faceCoverage > 0.60) { // Slightly higher threshold
        return QualityCheckResult(error: "Move back - face is too large in the frame");
      }

      // --- Face Angle Check (Head Tilt) ---
      final leftEye = face.landmarks[FaceLandmarkType.leftEye]?.position;
      final rightEye = face.landmarks[FaceLandmarkType.rightEye]?.position;

      if (leftEye != null && rightEye != null) {
        // Calculate angle of the line connecting the eyes relative to horizontal
        final eyeAngle = atan2(
          (rightEye.y - leftEye.y).toDouble(), // Use double for atan2
          (rightEye.x - leftEye.x).toDouble()
        ) * 180 / pi; // Convert radians to degrees

        print("Eye Angle: ${eyeAngle.toStringAsFixed(1)} degrees");

        // Allow a small tilt tolerance (e.g., +/- 15 degrees)
        if (eyeAngle.abs() > 15) {
          return QualityCheckResult(error: "Please keep your head straight - avoid tilting");
        }
      } else {
        // If landmarks aren't detected, we can't check angle, might allow or warn
        print("Warning: Eye landmarks not detected, skipping angle check.");
      }

       // --- Optional: Face Angle Check (Yaw/Roll - looking side-to-side/rotating) ---
       // ML Kit provides headEulerAngleY (yaw) and headEulerAngleZ (roll)
       final yaw = face.headEulerAngleY; // Looking left/right
       final roll = face.headEulerAngleZ; // Tilting head side-to-side (similar to eye angle check)

       print("Head Yaw: ${yaw?.toStringAsFixed(1)}, Head Roll: ${roll?.toStringAsFixed(1)}");

       if (yaw != null && yaw.abs() > 20) { // Allow +/- 20 degrees yaw
         return QualityCheckResult(error: "Please face the camera directly (avoid turning head side-to-side)");
       }
       // Roll check often overlaps with eye angle check, but can be added if needed
       // if (roll != null && roll.abs() > 15) {
       //   return QualityCheckResult(error: "Please keep your head straight (avoid tilting ear to shoulder)");
       // }


      // --- Brightness Check ---
      // Uses the decoded 'image' object
      final brightness = _estimateBrightness(image);
      print("Estimated Center Brightness (0-255): $brightness");

      // Adjust brightness thresholds based on testing what works best
      if (brightness < 70) { // Lowered threshold slightly
        return QualityCheckResult(error: "Image too dark - please find better lighting");
      }
      if (brightness > 235) { // Increased threshold slightly
        return QualityCheckResult(error: "Image too bright or washed out - reduce glare/direct light");
      }

      // --- All Checks Passed ---
      print("Image quality checks passed.");
      return QualityCheckResult(face: face); // Return the detected Face object

    } catch (e, stackTrace) {
      // Log detailed error in debug mode
      if (kDebugMode) {
        print('!!! Quality check error: $e\n$stackTrace');
      } else {
         print('Quality check error: $e');
      }
      return QualityCheckResult(error: "An error occurred during image quality check");
    }
  }

  // Estimates brightness in the center 100x100 region using luminance
  static int _estimateBrightness(img.Image image) {
    final centerX = image.width ~/ 2;
    final centerY = image.height ~/ 2;
    const sampleSize = 100;
    final startX = max(0, centerX - sampleSize ~/ 2);
    final startY = max(0, centerY - sampleSize ~/ 2);
    final endX = min(image.width, startX + sampleSize);
    final endY = min(image.height, startY + sampleSize);

    if (startX >= endX || startY >= endY) {
      print("Warning: Invalid sample area for brightness estimation.");
      return 0; // Return 0 if area is invalid
    }

    double totalLuminance = 0;
    int sampleCount = 0;

    for (var y = startY; y < endY; y++) {
      for (var x = startX; x < endX; x++) {
        try {
           final pixel = image.getPixel(x, y);
           // Calculate luminance (perceptual brightness)
           final luminance = 0.2126 * pixel.r + 0.7152 * pixel.g + 0.0722 * pixel.b;
           totalLuminance += luminance;
           sampleCount++;
        } catch (e) {
           print("Warning: Error getting pixel at ($x, $y) for brightness: $e");
           // Continue sampling other pixels
        }
      }
    }

    // Return average luminance scaled to 0-255
    if (sampleCount > 0) {
      return (totalLuminance / sampleCount).round().clamp(0, 255);
    } else {
      print("Warning: No samples collected for brightness estimation.");
      return 0; // Explicitly return 0 if sampleCount is still 0
    }
  }

  // Decodes image bytes with a timeout
  static Future<img.Image?> _decodeImageWithTimeout(Uint8List bytes) async {
    try {
      return await Future.any([
        Future.delayed(const Duration(seconds: 5)).then((_) {
          print("Image decoding timed out."); // Log timeout
          return null;
        }),
        Future.microtask(() => img.decodeImage(bytes)),
      ]);
    } catch (e) {
      print("Error decoding image: $e");
      return null;
    }
  }

  // Helper functions for min/max
  static int max(int a, int b) => a > b ? a : b;
  static int min(int a, int b) => a < b ? a : b;
}