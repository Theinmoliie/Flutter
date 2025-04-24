// lib/services/tflite_service.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart'; // For rootBundle
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';


class TfliteService {
  Interpreter? _interpreter;
  List<String>? _labels;
  bool _isModelLoaded = false;
  static const String _modelPath = 'assets/models/skin_type_model.tflite';
  static const String _labelPath = 'assets/labels/skin_type_labels.txt';
  static const int _inputSize = 224; // From your YOLOv8 script

  TfliteService() {
    // Consider loading the model eagerly or lazily
    // Eager loading (on instantiation):
    loadModel();
  }

  Future<void> loadModel() async {
    if (_isModelLoaded) return; // Prevent reloading

    try {
      // Load labels first
      final labelsData = await rootBundle.loadString(_labelPath);
      _labels = labelsData.split('\n').map((label) => label.trim()).where((label) => label.isNotEmpty).toList();
      if (_labels == null || _labels!.isEmpty) {
         throw Exception("Could not load or parse labels from $_labelPath");
      }
       print("Labels loaded: $_labels"); // Debug print

      // Load TFLite model
      _interpreter = await Interpreter.fromAsset(
        _modelPath,
        // Optional: configure options like GPU delegation or number of threads
        // options: InterpreterOptions()..addDelegate(GpuDelegateV2()),
      );

      // Check model input/output details (optional but helpful for debugging)
      var inputDetails = _interpreter!.getInputTensor(0);
      var outputDetails = _interpreter!.getOutputTensor(0);
      print('Input details: ${inputDetails.shape}, ${inputDetails.type}');
      print('Output details: ${outputDetails.shape}, ${outputDetails.type}');

      _isModelLoaded = true;
      print("TFLite model loaded successfully.");
    } catch (e) {
      print("Error loading TFLite model or labels: $e");
      _isModelLoaded = false;
      // Consider re-throwing or returning an error status
    }
  }

  Future<Map<String, dynamic>> predictImage(File imageFile) async {
    if (!_isModelLoaded || _interpreter == null || _labels == null) {
      print("Model or labels not loaded. Attempting to load...");
      await loadModel(); // Attempt to load if not already loaded
      if (!_isModelLoaded || _interpreter == null || _labels == null) {
        return {'success': false, 'error': 'Model or labels not loaded'};
      }
    }

    try {
      // 1. Decode Image
      final imageBytes = await imageFile.readAsBytes();
      img.Image? originalImage = img.decodeImage(imageBytes);
      if (originalImage == null) {
        return {'success': false, 'error': 'Could not decode image'};
      }

      // 2. Resize Image
      img.Image resizedImage = img.copyResize(
        originalImage,
        width: _inputSize,
        height: _inputSize,
      );

      // 3. Normalize and Convert to Float32List (Input Tensor)
      // IMPORTANT: YOLOv8 typically normalizes to [0, 1] by dividing by 255.
      // TFLite model usually expects shape [1, height, width, 3]
      var inputBytes = Float32List(1 * _inputSize * _inputSize * 3);
      int pixelIndex = 0;
      for (int y = 0; y < _inputSize; y++) {
        for (int x = 0; x < _inputSize; x++) {
          img.Pixel pixel = resizedImage.getPixel(x, y);
          // Normalize to [0, 1]
          inputBytes[pixelIndex++] = pixel.r / 255.0;
          inputBytes[pixelIndex++] = pixel.g / 255.0;
          inputBytes[pixelIndex++] = pixel.b / 255.0;
        }
      }

      // Reshape to [1, 224, 224, 3] - Note: tflite_flutter handles the outer batch dim implicitly usually
      // But the inputBytes list itself needs to represent the HWC format correctly flattened.
      // The interpreter's input tensor shape should confirm this. Let's assume [1, 224, 224, 3].
      final input = inputBytes.reshape([1, _inputSize, _inputSize, 3]);

      // 4. Prepare Output Tensor
      // Shape should be [1, num_classes] (e.g., [1, 4])
      final outputShape = _interpreter!.getOutputTensor(0).shape;
      final numClasses = outputShape[1]; // Assuming [1, num_classes]
      if (numClasses != _labels!.length) {
         print("Warning: Model output classes (${outputShape[1]}) != Label file classes (${_labels!.length})");
         // You might want to throw an error here if the mismatch is critical
      }
      // Output is typically Float32 probabilities
      final output = List.filled(1 * numClasses, 0.0).reshape([1, numClasses]);


      // 5. Run Inference
      _interpreter!.run(input, output);

      // 6. Post-process Output
      // Output[0] contains the list of probabilities for each class
      List<double> probabilities = List<double>.from(output[0]);

      // Find the index with the highest probability
      double maxProb = 0.0;
      int maxIndex = -1;
      for (int i = 0; i < probabilities.length; i++) {
        if (probabilities[i] > maxProb) {
          maxProb = probabilities[i];
          maxIndex = i;
        }
      }

       print("Output Probabilities: $probabilities"); // Debug print
       print("Max Index: $maxIndex, Max Prob: $maxProb"); // Debug print


      if (maxIndex != -1 && maxIndex < _labels!.length) {
        String predictedLabel = _labels![maxIndex];
        return {
          'success': true,
          'skin_type': predictedLabel,
          'confidence': maxProb,
        };
      } else {
        return {'success': false, 'error': 'Could not determine prediction'};
      }
    } catch (e, stackTrace) {
      print("Error during TFLite prediction: $e");
      print(stackTrace); // Print stack trace for debugging
      return {'success': false, 'error': 'Prediction error: $e'};
    }
  }

  void dispose() {
    _interpreter?.close();
    _isModelLoaded = false;
    print("TFLite interpreter closed.");
  }
}