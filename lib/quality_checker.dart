import 'dart:io';
import 'dart:typed_data'; // Add this import
import 'package:image/image.dart' as img;
import 'package:google_ml_kit/google_ml_kit.dart';

class ImageQualityChecker {
  static Future<String?> getQualityIssue(File imageFile) async {
    try {
      // 1. Basic file check
      if (!await imageFile.exists()) {
        return "Image file not found";
      }
      if (await imageFile.length() < 1024) {
        return "Image file too small";
      }

      // 2. Decode image with timeout
      final imageData = await imageFile.readAsBytes();
      final image = await _decodeImageWithTimeout(Uint8List.fromList(imageData)); // Convert to Uint8List
      if (image == null) return "Could not process image";

      // 3. Resolution check (more flexible)
      if (image.width < 480 || image.height < 640) {
        return "Move closer - higher resolution needed";
      }

      // 4. Face detection with simpler options
      final faceDetector = GoogleMlKit.vision.faceDetector(
        FaceDetectorOptions(
          performanceMode: FaceDetectorMode.fast,
          enableLandmarks: false,
          enableContours: false,
          enableClassification: false,
        ),
      );
      
      final inputImage = InputImage.fromFilePath(imageFile.path);
      final faces = await faceDetector.processImage(inputImage);
      await faceDetector.close();

      if (faces.isEmpty) return "Face not detected - look directly at camera";

      // 5. Simplified face position check
      final face = faces.first;
      final faceArea = face.boundingBox.width * face.boundingBox.height;
      final imageArea = image.width * image.height;
      
      if (faceArea < imageArea * 0.15) {
        return "Move closer - face should fill more of the frame";
      }

      return null; // No issues found
    } catch (e) {
      print('Quality check error: $e');
      return "Could not check image quality";
    }
  }

  static Future<img.Image?> _decodeImageWithTimeout(Uint8List bytes) async { // Changed parameter type
    try {
      return await Future.any([
        Future.delayed(Duration(seconds: 2)).then((_) => null),
        Future.microtask(() => img.decodeImage(bytes)),
      ]);
    } catch (e) {
      return null;
    }
  }
}