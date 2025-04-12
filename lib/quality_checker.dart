import 'dart:io';
import 'dart:typed_data';
import 'dart:math';
import 'package:image/image.dart' as img;
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:flutter/material.dart';

class ImageQualityChecker {
  static Future<String?> getQualityIssue(
    File imageFile, {
    required Size guideBoxSize,
    required Size screenSize,
  }) async {
    try {
      // Basic file checks
      if (!await imageFile.exists()) return "Image file not found";
      if (await imageFile.length() < 1024) return "Image file too small";

      // Image decoding
      final imageData = await imageFile.readAsBytes();
      final image = await _decodeImageWithTimeout(Uint8List.fromList(imageData));
      if (image == null) return "Could not process image";

      // Resolution check
      if (image.width < 480 || image.height < 640) {
        return "Move closer - higher resolution needed";
      }

      // Face detection setup
      final faceDetector = GoogleMlKit.vision.faceDetector(
        FaceDetectorOptions(
          performanceMode: FaceDetectorMode.accurate,
          enableLandmarks: true,
          enableContours: true,
          enableClassification: false,
          enableTracking: false,
          minFaceSize: 0.15,
        ),
      );

      final inputImage = InputImage.fromFilePath(imageFile.path);
      final faces = await faceDetector.processImage(inputImage);
      await faceDetector.close();

      // Face presence check
      if (faces.isEmpty) return "Face not detected - center your face";
      if (faces.length > 1) return "Only one face should be visible";

      final face = faces.first;
      final faceContour = face.contours[FaceContourType.face];
      if (faceContour == null || faceContour.points.isEmpty) {
        return "Could not detect complete face outline";
      }

      // Calculate scaling factors
      final scale = image.width / screenSize.width;
      final scaledScreenHeight = screenSize.height * scale;
      final verticalOffset = (image.height - scaledScreenHeight) / 2;

      // Calculate circular guide box parameters in image coordinates
      final circleCenterX = image.width / 2;
      final circleCenterY = verticalOffset + screenSize.height / 2 * scale;
      final circleRadius = (guideBoxSize.width / 2) * scale;

      // Get face boundary points
      final positions = faceContour.points;
      final leftMost = positions.reduce((a, b) => a.x < b.x ? a : b);
      final rightMost = positions.reduce((a, b) => a.x > b.x ? a : b);
      final topMost = positions.reduce((a, b) => a.y < b.y ? a : b);
      final bottomMost = positions.reduce((a, b) => a.y > b.y ? a : b);

      // Calculate face center
      final faceCenterX = (leftMost.x + rightMost.x) / 2;
      final faceCenterY = (topMost.y + bottomMost.y) / 2;

      // Check if face center is within the circle
      final distanceFromCenter = sqrt(
        pow(faceCenterX - circleCenterX, 2) + 
        pow(faceCenterY - circleCenterY, 2)
      );

      // Allow 5% tolerance outside the circle
      if (distanceFromCenter > circleRadius * 1.05) {
        // Determine which direction to guide the user
        final angle = atan2(
          faceCenterY - circleCenterY, 
          faceCenterX - circleCenterX
        ) * 180 / pi;

        if (angle > -45 && angle <= 45) {
          return "Move left - face outside guide circle";
        } else if (angle > 45 && angle <= 135) {
          return "Move up - face outside guide circle";
        } else if (angle > 135 || angle <= -135) {
          return "Move right - face outside guide circle";
        } else {
          return "Move down - face outside guide circle";
        }
      }

      // Check if face is too close to edge of circle
      if (distanceFromCenter < circleRadius * 0.7) {
        return "Move back - face too small in frame";
      }

      // Face size check (relative to circle)
      final faceWidth = rightMost.x - leftMost.x;
      final faceHeight = bottomMost.y - topMost.y;
      final faceDiagonal = sqrt(pow(faceWidth, 2) + pow(faceHeight, 2));

      if (faceDiagonal > circleRadius * 1.8) {
        return "Move back - face too large in frame";
      }

      // Face angle check (for straight-on shots)
      final leftEye = face.landmarks[FaceLandmarkType.leftEye]?.position;
      final rightEye = face.landmarks[FaceLandmarkType.rightEye]?.position;
      
      if (leftEye != null && rightEye != null) {
        final eyeAngle = atan2(
          rightEye.y - leftEye.y, 
          rightEye.x - leftEye.x
        ) * 180 / pi;
        
        if (eyeAngle.abs() > 15) {
          return "Keep your head straight - don't tilt";
        }
      }

      // Brightness check
      final brightness = _estimateBrightness(image);
      if (brightness < 100) return "Image too dark - improve lighting";
      if (brightness > 220) return "Image too bright - reduce glare";

      // All checks passed
      return null;
    } catch (e) {
      debugPrint('Quality check error: $e');
      return "Error processing image";
    }
  }

  static int _estimateBrightness(img.Image image) {
    final centerX = image.width ~/ 2;
    final centerY = image.height ~/ 2;
    const sampleSize = 100;
    final startX = max(0, centerX - sampleSize ~/ 2);
    final startY = max(0, centerY - sampleSize ~/ 2);
    final endX = min(image.width, startX + sampleSize);
    final endY = min(image.height, startY + sampleSize);

    var totalBrightness = 0;
    var sampleCount = 0;

    for (var y = startY; y < endY; y++) {
      for (var x = startX; x < endX; x++) {
        final pixel = image.getPixel(x, y);
        final brightness = (pixel.r + pixel.g + pixel.b) ~/ 3;
        totalBrightness += brightness;
        sampleCount++;
      }
    }

    return sampleCount > 0 ? totalBrightness ~/ sampleCount : 0;
  }

  static Future<img.Image?> _decodeImageWithTimeout(Uint8List bytes) async {
    try {
      return await Future.any([
        Future.delayed(const Duration(seconds: 2)).then((_) => null),
        Future.microtask(() => img.decodeImage(bytes)),
      ]);
    } catch (e) {
      return null;
    }
  }

  static int max(int a, int b) => a > b ? a : b;
  static int min(int a, int b) => a < b ? a : b;
}