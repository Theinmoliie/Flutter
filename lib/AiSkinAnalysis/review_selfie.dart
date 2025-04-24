// .TFLITE MODEL IMPLEMENTATION
//_______________________________________

/// lib/review_selfie.dart
import 'dart:io';
import 'dart:ui'; // Required for Rect
import 'package:flutter/foundation.dart'; // For kDebugMode
import 'package:flutter/material.dart';
import 'package:skinsafe/services/tflite_service.dart'; // Adjust path if needed
import 'skin_analysis_result.dart';

class ResultPage extends StatefulWidget {
  final String imagePath;
  final bool isFrontCamera;
  final Rect faceBoundingBox; // Received from CameraPage

  const ResultPage({
    Key? key,
    required this.imagePath,
    required this.faceBoundingBox, // Make required
    this.isFrontCamera = true,
  }) : super(key: key);

  @override
  _ResultPageState createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  bool _isLoading = false;
  final TfliteService _tfliteService = TfliteService();

  @override
  void initState() {
    super.initState();
    // _tfliteService.loadModels(); // Called in service constructor
  }

  @override
  void dispose() {
    _tfliteService.dispose();
    super.dispose();
  }

  Future<void> _analyseSkin() async {
    if (_isLoading) return;
    setState(() { _isLoading = true; });
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final File imageFile = File(widget.imagePath);

      // Call the TFLite service, passing the bounding box
      final result = await _tfliteService.predictImage(
        imageFile,
        widget.faceBoundingBox, // Pass the detected bounding box
      );

      if (mounted) Navigator.pop(context);
      if (!mounted) return;

      if (result['success'] == true) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => AnalysisPage(
              skinType: result['skin_type'],
              confidence: result['confidence'],
              imagePath: widget.imagePath,
              isFrontCamera: widget.isFrontCamera,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Analysis failed: ${result['error'] ?? 'Unknown TFLite error'}'),
            backgroundColor: Colors.redAccent,
          ),
        );
        if (kDebugMode) {
          debugPrint("[ReviewScreen] TFLite Error: ${result['error']}");
        }
      }
    } catch (e, stackTrace) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        debugPrint("[ReviewScreen] Unexpected error: $e\n$stackTrace");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('An unexpected error occurred. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Your Selfie'),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 2.0,
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Center(
                child: AspectRatio(
                  aspectRatio: 3 / 4,
                  child: Container(
                     decoration: BoxDecoration(
                       borderRadius: BorderRadius.circular(16.0),
                       boxShadow: [ BoxShadow( color: Colors.black.withOpacity(0.2), blurRadius: 8.0, spreadRadius: 2.0, ) ]
                     ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16.0),
                      child: Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()..scale(widget.isFrontCamera ? -1.0 : 1.0, 1.0, 1.0),
                        child: Image.file(
                          File(widget.imagePath),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [ Icon(Icons.broken_image_outlined, size: 60, color: Colors.grey), SizedBox(height: 10), Text("Error loading preview", style: TextStyle(color: Colors.grey)), ],
                            )
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 32.0),
            child: _isLoading
                ? CircularProgressIndicator(color: colorScheme.primary)
                : ElevatedButton.icon(
                    icon: const Icon(Icons.analytics_outlined),
                    label: const Text('Analyze Skin Type'),
                    onPressed: _analyseSkin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      minimumSize: const Size(double.infinity, 55),
                      textStyle: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      shape: RoundedRectangleBorder( borderRadius: BorderRadius.circular(30.0) ),
                      elevation: 4,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}