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
    if (!await imageFile.exists()) return "Image file not found";
    if (await imageFile.length() < 1024) return "Image file too small";

    final imageData = await imageFile.readAsBytes();
    final image = await _decodeImageWithTimeout(Uint8List.fromList(imageData));
    if (image == null) return "Could not process image";

    print('Image dimensions: ${image.width}x${image.height}');
    print('Screen dimensions: ${screenSize.width}x${screenSize.height}');
    print('Guide box dimensions: ${guideBoxSize.width}x${guideBoxSize.height}');

    if (image.width < 480 || image.height < 640) {
      return "Move closer - higher resolution needed";
    }

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

    if (faces.isEmpty) return "Face not detected - center your face";

    final face = faces.first;
    final faceContour = face.contours[FaceContourType.face];
    if (faceContour == null || faceContour.points.isEmpty) {
      return "Could not detect complete face outline";
    }

    final positions = faceContour.points;
    final leftMost = positions.reduce((a, b) => a.x < b.x ? a : b);
    final rightMost = positions.reduce((a, b) => a.x > b.x ? a : b);
    final topMost = positions.reduce((a, b) => a.y < b.y ? a : b);
    final bottomMost = positions.reduce((a, b) => a.y > b.y ? a : b);

    print('Face boundaries - Left: ${leftMost.x}, Right: ${rightMost.x}, '
        'Top: ${topMost.y}, Bottom: ${bottomMost.y}');

    // Updated logic: assume image scaled to match screen width
    final scale = image.width / screenSize.width;
    final scaledScreenHeight = screenSize.height * scale;
    final verticalOffset = (image.height - scaledScreenHeight) / 2;

    final guideBoxLeft = (screenSize.width - guideBoxSize.width) / 2 * scale;
    final guideBoxTop = verticalOffset + (screenSize.height - guideBoxSize.height) / 2 * scale;
    final guideBoxRight = guideBoxLeft + guideBoxSize.width * scale;
    final guideBoxBottom = guideBoxTop + guideBoxSize.height * scale;

    print('Guide box in image coordinates: '
        '($guideBoxLeft, $guideBoxTop) to ($guideBoxRight, $guideBoxBottom)');

    final toleranceX = guideBoxSize.width * scale * 0.05;
    final toleranceY = guideBoxSize.height * scale * 0.05;

    // Horizontal alignment
    if (leftMost.x < guideBoxLeft - toleranceX) {
      print('Face too far left');
      return "Move right - face outside guide box";
    }
    if (rightMost.x > guideBoxRight + toleranceX) {
      print('Face too far right');
      return "Move left - face outside guide box";
    }

    // Vertical alignment (fixed message logic)
    if (topMost.y < guideBoxTop - toleranceY) {
      print('Face too high');
      return "Move down - face above guide box";
    }
    if (bottomMost.y > guideBoxBottom + toleranceY) {
      print('Face too low');
      return "Move up - face below guide box";
    }

    // Check for partial face outside top
    final faceHeight = bottomMost.y - topMost.y;
    final aboveThreshold = faceHeight * 0.1;
    if (topMost.y < guideBoxTop && (guideBoxTop - topMost.y) > aboveThreshold) {
      print('Face partially above guide box');
      return "Move down - face extending above guide box";
    }

    // Face size check
    final faceWidth = rightMost.x - leftMost.x;
    final faceArea = faceWidth * faceHeight;
    final imageArea = image.width * image.height;
    final faceCoverage = faceArea / imageArea;

    print('Face size - Width: $faceWidth, Height: $faceHeight');
    print('Face coverage: ${(faceCoverage * 100).toStringAsFixed(1)}%');

    if (faceCoverage < 0.2) return "Move closer - face too small";
    if (faceCoverage > 0.5) return "Move back - face too large";

    // Brightness check
    final brightness = _estimateBrightness(image);
    print('Image brightness: $brightness');
    if (brightness < 100) return "Image too dark - improve lighting";
    if (brightness > 220) return "Image too bright - reduce glare";

    print('All quality checks passed!');
    return null;
  } catch (e) {
    print('Quality check error: $e');
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