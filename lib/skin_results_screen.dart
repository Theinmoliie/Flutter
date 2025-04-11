// 📁 lib/pages/result_page.dart
import 'dart:io';
import 'package:flutter/material.dart';

import 'quality_checker.dart';
import 'analysis_page.dart'; // Add this import

class ResultPage extends StatelessWidget {
  final String imagePath;
  final bool isFrontCamera;

  const ResultPage({
    required this.imagePath,
    this.isFrontCamera = true, // Default to true since we're using front camera
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Review Your Selfie')),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Transform(
                alignment: Alignment.center,
                transform:
                    Matrix4.identity()
                      ..scale(isFrontCamera ? -1.0 : 1.0, 1.0, 1.0),
                child: Image.file(File(imagePath)),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: () async {
                // Double-check quality before analysis (optional)
                final qualityIssue = await ImageQualityChecker.getQualityIssue(
                  File(imagePath),
                );
                if (qualityIssue != null) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(qualityIssue)));
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => AnalysisPage(
                            imagePath: imagePath,
                            isFrontCamera: isFrontCamera,
                          ),
                    ),
                  );
                }
              },
              child: Text('Analyze Skin'),
            ),
          ),
        ],
      ),
    );
  }
}
