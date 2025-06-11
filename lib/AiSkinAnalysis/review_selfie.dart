// lib/review_selfie.dart

import 'dart:io';
import 'dart:ui'; // Required for Rect
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// --- (1) IMPORT THE NEW SERVICE ---
import 'package:skinsafe/services/gemini_service.dart'; // Adjust path if needed
import 'skin_analysis_result.dart';

class ResultPage extends StatefulWidget {
  final String imagePath;
  final bool isFrontCamera;
  final Rect faceBoundingBox; // Although not used by Gemini, we keep it for consistency

  const ResultPage({
    Key? key,
    required this.imagePath,
    required this.faceBoundingBox,
    this.isFrontCamera = true,
  }) : super(key: key);

  @override
  _ResultPageState createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  bool _isLoading = false;
  
  // --- (2) INSTANTIATE THE NEW SERVICE ---
  final GeminiService _geminiService = GeminiService();

  @override
  void initState() {
    super.initState();
    // No models to load anymore
  }

  @override
  void dispose() {
    // No TFLite service to dispose
    super.dispose();
  }

  // --- (3) THE FULLY UPDATED ANALYSIS METHOD ---
  Future<void> _analyseSkin() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
    });

    // Show a loading indicator while processing
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final File imageFile = File(widget.imagePath);

      // Call the Gemini service. It directly returns the skin type string or null.
      final String? resultSkinType = await _geminiService.analyzeSkinType(imageFile);

      // Dismiss the loading dialog
      if (mounted) Navigator.pop(context);
      if (!mounted) return;

      // Check if the result is not null
      if (resultSkinType != null) {
        // If we have a valid result, navigate to the AnalysisPage.
        // We await the final result from AnalysisPage if the user confirms.
        final String? finalResult = await Navigator.push<String>(
          context,
          MaterialPageRoute(
            builder: (context) => AnalysisPage(
              skinType: resultSkinType,
              // Confidence isn't directly applicable from Gemini in this setup
              confidence: 1.0, 
              imagePath: widget.imagePath,
              isFrontCamera: widget.isFrontCamera,
            ),
          ),
        );
        
        // If AnalysisPage popped with a result (meaning the user saved it),
        // we pop this page as well and pass that result down the navigation stack.
        if (finalResult != null && mounted) {
          Navigator.of(context).pop(finalResult);
        }

      } else {
        // If result is null, it means analysis failed or was uncertain.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not determine skin type. Please try again with a clear photo.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        if (kDebugMode) {
          debugPrint("[ReviewScreen] Gemini service returned a null or 'Uncertain' result.");
        }
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // Also dismiss on error
      if (mounted) {
        debugPrint("[ReviewScreen] Unexpected error during analysis: $e");
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
                    onPressed: _analyseSkin, // This button now triggers the Gemini call
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