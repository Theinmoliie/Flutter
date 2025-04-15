// 📁 lib/pages/result_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'selfie_quality_checker.dart';
import 'skin_analysis_result(dummy).dart'; // Add this import


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
                transform: Matrix4.identity()..scale(isFrontCamera ? -1.0 : 1.0, 1.0, 1.0),
                child: Image.file(File(imagePath)),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AnalysisPage(imagePath: imagePath,
                    isFrontCamera: true, // Set based on which camera was used),
                  ),
                ),
                );
              },
              child: Text('Analyze Skin'),
            ),
          ),
        ],
      ),
    );
  }
}