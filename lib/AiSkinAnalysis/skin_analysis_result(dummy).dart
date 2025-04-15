import 'package:flutter/material.dart';
import 'dart:io';

class AnalysisPage extends StatefulWidget {
  final String imagePath;
  final bool isFrontCamera;

  const AnalysisPage({
    Key? key,
    required this.imagePath,
    this.isFrontCamera = true,
  }) : super(key: key);

  @override
  _AnalysisPageState createState() => _AnalysisPageState();
}

class _AnalysisPageState extends State<AnalysisPage> {
  bool _isAnalyzing = true;
  // Keep simulation delay, result data isn't used for display here
  // final Duration _analysisDelay = const Duration(seconds: 3); // Example

  @override
  void initState() {
    super.initState();
    _startAnalysis();
  }

  Future<void> _startAnalysis() async {
    // Simulate analysis delay
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) {
      setState(() {
        _isAnalyzing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get theme data for consistent styling
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Skin Analysis Result'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        backgroundColor: colorScheme.primary, // Consistent AppBar color
        foregroundColor: colorScheme.onPrimary, // Text/Icon color on AppBar
        elevation: 2.0, // Subtle elevation
      ),
      body: Center( // Center the content vertically
        child: _isAnalyzing
            ? Column( // Show text with indicator
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                     valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Analyzing your skin...',
                    style: theme.textTheme.titleMedium?.copyWith(
                       color: colorScheme.onSurface.withOpacity(0.7)
                    ),
                  ),
                ],
              )
            : _buildResults(theme, colorScheme), // Pass theme data
      ),
    );
  }

  Widget _buildResults(ThemeData theme, ColorScheme colorScheme) {
    return ListView( // Use ListView for potential future scrolling if content grows
      padding: const EdgeInsets.all(20.0), // Generous padding around content
      children: [
        // Image Display Card
        Card(
          elevation: 4.0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0), // More rounded corners
          ),
          clipBehavior: Clip.antiAlias, // Ensures image adheres to rounded corners
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..scale(widget.isFrontCamera ? -1.0 : 1.0, 1.0, 1.0),
            child: AspectRatio( // Maintain aspect ratio
              aspectRatio: 3 / 4, // Common portrait aspect ratio, adjust if needed
              child: Image.file(
                File(widget.imagePath),
                fit: BoxFit.cover, // Cover the aspect ratio box
                 errorBuilder: (context, error, stackTrace) => const Center(
                   child: Icon(Icons.error_outline, color: Colors.red, size: 50)
                 ), // Handle image loading errors
              ),
            ),
          ),
        ),
        const SizedBox(height: 24), // Increased spacing

        // Results Section Title
        Text(
          'Analysis Summary', // Changed title slightly
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
            side: BorderSide(color: colorScheme.outline.withOpacity(0.3)) // Subtle border
          ),
          color: colorScheme.surfaceVariant.withOpacity(0.5), // Slightly different background
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center, // Center items in the row
              children: [
                Icon(
                  Icons.eco_outlined, // Using an icon related to nature/skin health
                  color: colorScheme.primary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Flexible( // Allow text to wrap if needed
                  child: Text(
                    'Primary Skin Type: Oily', // More descriptive text
                    style: theme.textTheme.titleMedium?.copyWith(
                       color: colorScheme.onSurfaceVariant, // Text color appropriate for the card background
                       fontWeight: FontWeight.w500
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

         // Optional: Disclaimer Text
        Text(
          "Note: This analysis provides a general indication. Consult a dermatologist for a professional diagnosis.",
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurface.withOpacity(0.6),
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}