// 📁 skin_analysis_result.dart
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter/foundation.dart'; // For kDebugMode (if used elsewhere)

class AnalysisPage extends StatelessWidget {
  final String imagePath;
  final bool isFrontCamera;
  final String skinType;
  final double confidence;

  const AnalysisPage({
    Key? key,
    required this.imagePath,
    this.isFrontCamera = true,
    required this.skinType,
    required this.confidence,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) { // <--- context is defined here
    // No need to get theme/colors here anymore, _buildResults will handle it

    return Scaffold(
      appBar: AppBar(
        title: const Text('Skin Analysis Result'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        // Removed theme access here, let AppBar use default theme or set explicitly if needed
        // backgroundColor: colorScheme.primary,
        // foregroundColor: colorScheme.onPrimary,
        elevation: 2.0,
      ),
      body: Center(
        // Pass context down to the helper method
        child: _buildResults(context), // <--- CHANGE: Pass context here
      ),
    );
  }

  // Update _buildResults signature to accept context
  Widget _buildResults(BuildContext context) { // <--- CHANGE: Add BuildContext context parameter
    // Derive theme and colors from the passed context
    final theme = Theme.of(context);         // <--- ADD: Get Theme
    final colorScheme = theme.colorScheme; // <--- ADD: Get ColorScheme

    return ListView(
      padding: const EdgeInsets.all(20.0),
      children: [
        // Image Display Card (Keep as is)
        Card(
          elevation: 4.0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          clipBehavior: Clip.antiAlias,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..scale(isFrontCamera ? -1.0 : 1.0, 1.0, 1.0),
            child: AspectRatio(
              aspectRatio: 3 / 4,
              child: Image.file(
                File(imagePath),
                fit: BoxFit.cover,
                 errorBuilder: (context, error, stackTrace) => const Center(
                   child: Icon(Icons.error_outline, color: Colors.red, size: 50)
                 ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),

        Text(
          'Analysis Summary',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),

        // Result Card
        Card(
          elevation: 2.0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
            side: BorderSide(color: colorScheme.outline.withOpacity(0.3))
          ),
          color: colorScheme.surfaceVariant.withOpacity(0.5),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _getIconForSkinType(skinType),
                      color: colorScheme.primary,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        'Primary Skin Type: $skinType',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
                // const SizedBox(height: 8),
                // Text(
                //   'Confidence: ${(confidence * 100).toStringAsFixed(1)}%',
                //   style: theme.textTheme.bodyMedium?.copyWith(
                //      color: colorScheme.onSurfaceVariant.withOpacity(0.8),
                //   ),
                // ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Optional: Disclaimer Text (Keep as is)
        Text(
          "Note: This analysis provides a general indication. Consult a dermatologist for a professional diagnosis.",
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurface.withOpacity(0.6),
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),


        const SizedBox(height: 24), // Increase spacing before button

         // Done Button - Now context is available
        //  ElevatedButton(
        //     onPressed: () {
        //        // Now 'context' is defined and can be used here
        //        Navigator.of(context).popUntil((route) => route.isFirst);
        //     },
        //     style: ElevatedButton.styleFrom(
        //        // Access colorScheme defined within this method
        //        backgroundColor: colorScheme.primary,
        //        foregroundColor: colorScheme.onPrimary,
        //        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12)
        //     ),
        //     child: const Text('Done')
        //  )


        //NEW
        ElevatedButton(
          onPressed: () {
            // *** THIS IS THE CRITICAL CHANGE ***
            // Pop the analysis screens and return the resulting skinType string.
            Navigator.of(context).pop(skinType);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            textStyle: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          child: const Text('Save'), // Changed text for clarity
        )
      ],
    );
  }

  // Helper function (Keep as is)
  IconData _getIconForSkinType(String type) {
     switch (type.toLowerCase()) {
       case 'oily':
         return Icons.opacity;
       case 'dry':
         return Icons.texture;
       case 'combination':
         return Icons.layers;
       case 'normal':
         return Icons.sentiment_satisfied_alt;
       default:
         return Icons.help_outline;
     }
  }
}