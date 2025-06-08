// lib/services/tflite_service.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui'; // For Rect
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img; // Import with a prefix
import 'package:tflite_flutter/tflite_flutter.dart';

class Prediction {
  final String label;
  final double confidence;
  Prediction(this.label, this.confidence);
}

class TfliteService {
  late Interpreter _skinTypeInterpreter;
  late List<String> _skinTypeLabels;
  bool _modelsLoaded = false;

  static final TfliteService _instance = TfliteService._internal();
  factory TfliteService() => _instance;
  TfliteService._internal();

  bool get modelsLoaded => _modelsLoaded;

  Future<void> loadModels() async {
    if (_modelsLoaded) {
      print("[TfliteService] Models are already loaded.");
      return;
    }
    try {
      _skinTypeInterpreter = await Interpreter.fromAsset('assets/models/resnet50_best.tflite');
      final labelsData = await rootBundle.loadString('assets/labels/skin_type_labels(3_classes).txt');
      _skinTypeLabels = labelsData.split('\n').map((label) => label.trim()).where((label) => label.isNotEmpty).toList();

      _skinTypeInterpreter.allocateTensors();
      
      print("[TfliteService] Skin Labels loaded: $_skinTypeLabels");
      var skinInput = _skinTypeInterpreter.getInputTensor(0);
      var skinOutput = _skinTypeInterpreter.getOutputTensor(0);
      print("[TFLiteService] Skin Model Input: ${skinInput.shape}, ${skinInput.type}");
      print("[TFLiteService] Skin Model Output: ${skinOutput.shape}, ${skinOutput.type}");
      
      _modelsLoaded = true;
      print("[TfliteService] Skin Type TFLite model loaded successfully.");
    } catch (e) {
      print("[TfliteService] Error loading TFLite models: $e");
      _modelsLoaded = false;
    }
  }

  /// **THE FIX IS HERE:** This function now correctly normalizes the image
  /// data for a float32 model, matching the PyTorch training pipeline.
  Float32List _imageToFloat32List(img.Image image) {
    var E_IMG_SIZE = 224;
    var a = Float32List(1 * E_IMG_SIZE * E_IMG_SIZE * 3);
    var buffer = a.buffer;
    Float32List float32list = buffer.asFloat32List();
    
    // Pre-defined mean and std for normalization (from your Python script)
    final mean = [0.485, 0.456, 0.406];
    final std = [0.229, 0.224, 0.225];

    int bufferIndex = 0;
    for (int y = 0; y < E_IMG_SIZE; y++) {
      for (int x = 0; x < E_IMG_SIZE; x++) {
        var pixel = image.getPixel(x, y);
        // Normalize each channel and write to the buffer
        float32list[bufferIndex++] = ( (pixel.r / 255.0) - mean[0] ) / std[0];
        float32list[bufferIndex++] = ( (pixel.g / 255.0) - mean[1] ) / std[1];
        float32list[bufferIndex++] = ( (pixel.b / 255.0) - mean[2] ) / std[2];
      }
    }
    return float32list;
  }

  Future<Prediction?> predictImage({
    required File imageFile,
    required Rect faceBoundingBox,
  }) async {
    if (!_modelsLoaded) {
      print("[TFLiteService] Models not loaded, cannot predict.");
      return null;
    }

    try {
      final originalImage = img.decodeImage(imageFile.readAsBytesSync());
      if (originalImage == null) {
        throw Exception("Could not decode image file.");
      }
      print("[TfliteService] Original image size: ${originalImage.width}x${originalImage.height}");
      
      final croppedImage = img.copyCrop(
        originalImage,
        x: faceBoundingBox.left.toInt(),
        y: faceBoundingBox.top.toInt(),
        width: faceBoundingBox.width.toInt(),
        height: faceBoundingBox.height.toInt(),
      );

      final resizedImage = img.copyResize(
        croppedImage,
        width: 224,
        height: 224,
        interpolation: img.Interpolation.average,
      );
      print("[TfliteService] Resized cropped image to: ${resizedImage.width}x${resizedImage.height}");
      
      // *** THE FIX IS HERE: The input tensor must be reshaped for PyTorch's channel-first format ***
      // 1. Convert the image to a normalized Float32List
      var imageAsList = _imageToFloat32List(resizedImage);
      // 2. Reshape it to the [1, 3, 224, 224] format
      var E_IMG_SIZE = 224;
      var reshapedInput = List.generate(1, (i) => List.generate(3, (j) => List.generate(E_IMG_SIZE, (k) => List.filled(E_IMG_SIZE, 0.0))));
      int bufferIndex = 0;
      for (int j = 0; j < 3; j++) {
        for (int k = 0; k < E_IMG_SIZE; k++) {
          for (int l = 0; l < E_IMG_SIZE; l++) {
            // This transposes the data from HWC to CHW
            reshapedInput[0][j][k][l] = imageAsList[bufferIndex++];
          }
        }
      }
      
      final output = List.filled(1 * 3, 0.0).reshape([1, 3]);

      print("[TFLiteService] Running skin type inference...");
      // Use the correctly shaped tensor for inference
      _skinTypeInterpreter.run(reshapedInput, output);
      
      final results = output[0] as List<double>;
      
      int topResultIndex = 0;
      double topScore = -1.0; // Start with a very low score
      for (int i = 0; i < results.length; i++) {
        if (results[i] > topScore) {
          topScore = results[i];
          topResultIndex = i;
        }
      }

      final predictedLabel = _skinTypeLabels[topResultIndex];
      // Note: The direct output from a classification layer like this is a logit, not a 0-1 confidence.
      // To get true confidence, you'd apply a Softmax function, but for just finding the top class, this is fine.
      final confidence = topScore;
      
      print("[TFLiteService] Prediction: $predictedLabel with logit score: $confidence");
      
      return Prediction(predictedLabel, confidence);

    } catch (e) {
      print("[TFLiteService] Error during TFLite prediction: $e");
      print(e.toString());
      return null;
    }
  }

  void dispose() {
    _skinTypeInterpreter.close();
    _modelsLoaded = false;
  }
}