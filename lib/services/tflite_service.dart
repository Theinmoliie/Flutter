// lib/services/tflite_service.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui'; // Required for Rect
import 'package:flutter/foundation.dart'; // for kDebugMode
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
// *** Using the original tflite_flutter package import ***
import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:math'; // For clamp

class TfliteService {
  Interpreter? _skinInterpreter;
  List<String>? _skinLabels;
  bool _isSkinModelLoaded = false;
  static const String _skinModelPath = 'assets/models/3_class_best_float32.tflite';
  static const String _skinLabelPath = 'assets/labels/skin_type_labels(3_classes).txt';
  static const int _skinInputSize = 224;

  TfliteService() {
    _loadSkinModel();
  }

  Future<void> _loadSkinModel() async {
    if (_isSkinModelLoaded) return;
    try {
      final labelsData = await rootBundle.loadString(_skinLabelPath);
      _skinLabels = labelsData.split('\n').map((label) => label.trim()).where((label) => label.isNotEmpty).toList();
      if (_skinLabels == null || _skinLabels!.isEmpty) {
        throw Exception("Could not load or parse skin labels from $_skinLabelPath");
      }
      print("[TfliteService] Skin Labels loaded: $_skinLabels");

      _skinInterpreter = await Interpreter.fromAsset(_skinModelPath);

      var inputDetails = _skinInterpreter!.getInputTensor(0);
      var outputDetails = _skinInterpreter!.getOutputTensor(0);
      print('[TFLiteService] Skin Model Input: ${inputDetails.shape}, ${inputDetails.type}');
      print('[TFLiteService] Skin Model Output: ${outputDetails.shape}, ${outputDetails.type}');

      if (outputDetails.shape.length != 2 || outputDetails.shape[1] != _skinLabels!.length) {
         print("Warning: Model output shape ${outputDetails.shape} doesn't match labels count (${_skinLabels!.length})");
      }

      _isSkinModelLoaded = true;
      print("[TfliteService] Skin Type TFLite model (using tflite_flutter) loaded successfully.");

    } catch (e) {
      print("[TfliteService] Error loading Skin Type TFLite model: $e");
      _isSkinModelLoaded = false;
    }
  }

  Future<Map<String, dynamic>> predictImage(File imageFile, Rect faceBoundingBox) async {
    if (!_isSkinModelLoaded || _skinInterpreter == null || _skinLabels == null) {
      print("[TfliteService] Skin model not loaded. Attempting to load...");
      await _loadSkinModel();
      if (!_isSkinModelLoaded || _skinInterpreter == null || _skinLabels == null) {
        return {'success': false, 'error': 'Skin Model failed to load'};
      }
    }

    try {
      // 1. Decode Image
      final imageBytes = await imageFile.readAsBytes();
      img.Image? originalImage = img.decodeImage(imageBytes);
      if (originalImage == null) {
        return {'success': false, 'error': 'Could not decode image'};
      }
      if (kDebugMode) {
          print("[TfliteService] Original image size: ${originalImage.width}x${originalImage.height}");
          print("[TfliteService] Received BoundingBox: $faceBoundingBox");
      }

      // 2. Crop the Face
      int cropX = faceBoundingBox.left.toInt().clamp(0, originalImage.width - 1);
      int cropY = faceBoundingBox.top.toInt().clamp(0, originalImage.height - 1);
      int cropWidth = faceBoundingBox.width.toInt().clamp(1, originalImage.width - cropX);
      int cropHeight = faceBoundingBox.height.toInt().clamp(1, originalImage.height - cropY);

       if (cropWidth <= 0 || cropHeight <= 0) {
         print("[TfliteService] Error: Invalid crop dimensions after clamping. Box: $faceBoundingBox, Image: ${originalImage.width}x${originalImage.height}");
         return {'success': false, 'error': 'Invalid face crop area calculated'};
       } else if (kDebugMode) {
          print("[TfliteService] Cropping to: x=$cropX, y=$cropY, w=$cropWidth, h=$cropHeight");
       }

      img.Image croppedFace = img.copyCrop( originalImage, x: cropX, y: cropY, width: cropWidth, height: cropHeight, );

      // 3. Resize the CROPPED face
      img.Image resizedImage = img.copyResize( croppedFace, width: _skinInputSize, height: _skinInputSize, interpolation: img.Interpolation.average, );
      if (kDebugMode) print("[TfliteService] Resized cropped image to: ${resizedImage.width}x${resizedImage.height}");

      // 4. Normalize and Convert Input Tensor [0, 1]
      var inputBytes = Float32List(1 * _skinInputSize * _skinInputSize * 3);
      int pixelIndex = 0;
      for (int y = 0; y < _skinInputSize; y++) {
        for (int x = 0; x < _skinInputSize; x++) {
          img.Pixel pixel = resizedImage.getPixelSafe(x, y);
          inputBytes[pixelIndex++] = pixel.r / 255.0;
          inputBytes[pixelIndex++] = pixel.g / 255.0;
          inputBytes[pixelIndex++] = pixel.b / 255.0;
        }
      }
      final input = inputBytes.reshape([1, _skinInputSize, _skinInputSize, 3]);

      // 5. Prepare Output Tensor
      final outputShape = _skinInterpreter!.getOutputTensor(0).shape;
      final numClasses = outputShape[1];
      if (numClasses != _skinLabels!.length) {
         print("[TFLiteService] Error: Model output classes (${outputShape[1]}) != Label file classes (${_skinLabels!.length})");
         return {'success': false, 'error': 'Model output/label mismatch'};
      }
      final output = List.filled(1 * numClasses, 0.0).reshape([1, numClasses]);

      // 6. Run Inference
      if (kDebugMode) print("[TFLiteService] Running skin type inference...");
      _skinInterpreter!.run(input, output);
      if (kDebugMode) print("[TFLiteService] Inference complete.");

      // 7. Post-process Output
      List<double> probabilities = List<double>.from(output[0]);
      double maxProb = 0.0;
      int maxIndex = -1;
      for (int i = 0; i < probabilities.length; i++) {
        if (probabilities[i] > maxProb) {
          maxProb = probabilities[i];
          maxIndex = i;
        }
      }

      if (kDebugMode) {
        print("[TFLiteService] Output Probabilities: $probabilities");
        print("[TFLiteService] Max Index: $maxIndex, Max Prob: $maxProb");
      }


      if (maxIndex != -1 && maxIndex < _skinLabels!.length) {
        String predictedLabel = _skinLabels![maxIndex];
        print("[TFLiteService] Predicted Label: $predictedLabel");
        return { 'success': true, 'skin_type': predictedLabel, 'confidence': maxProb, };
      } else {
        print("[TFLiteService] Error: Could not determine prediction from probabilities.");
        return {'success': false, 'error': 'Could not determine prediction'};
      }

    } catch (e, stackTrace) {
      print("[TFLiteService] Error during TFLite prediction: $e");
      print(stackTrace);
      return {'success': false, 'error': 'Prediction error: $e'};
    }
  }

  void dispose() {
    _skinInterpreter?.close();
    _isSkinModelLoaded = false;
    print("[TfliteService] TFLite skin interpreter closed.");
  }
}