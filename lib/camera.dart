import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'skin_results_screen.dart';
import 'quality_checker.dart'; // Add this import

class CameraPage  extends StatefulWidget {
  @override
  _CameraPage createState() => _CameraPage ();
}

class _CameraPage extends State<CameraPage > {
  late CameraController _controller;
  bool _isCameraReady = false;
  bool _isCapturing = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    final frontCamera = cameras.firstWhere(
      (cam) => cam.lensDirection == CameraLensDirection.front,
    );

    _controller = CameraController(
      frontCamera,
      ResolutionPreset.high, // High resolution for skin details
      enableAudio: false,
    );

    await _controller.initialize();
    if (mounted) setState(() => _isCameraReady = true);
  }

  Future<String?> _captureImage() async {
    if (!_isCameraReady || _isCapturing) return null;
    setState(() => _isCapturing = true);
    
    try {
      final image = await _controller.takePicture();
      return image.path;
    } catch (e) {
      debugPrint('Capture error: $e');
      return null;
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isCameraReady) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Mirrored camera preview
          Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()..scale(-1.0, 1.0, 1.0),
            child: CameraPreview(_controller),
          ),
          _buildCaptureGuidelines(),
          _buildCaptureButton(),
        ],
      ),
    );
  }

  Widget _buildCaptureGuidelines() {
    return Center(
      child: Container(
        width: 250,
        height: 350,
        decoration: BoxDecoration(
          border: Border.all(
            color: Colors.white.withOpacity(0.8),
            width: 2.0,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.face, size: 50, color: Colors.white),
            SizedBox(height: 20),
            Text(
              'Align your face within the frame',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              'Ensure good lighting',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

    Widget _buildCaptureButton() {
    return Positioned(
      bottom: 40,
      left: 0,
      right: 0,
      child: Center(
        child: FloatingActionButton(
          backgroundColor: Colors.white,
          onPressed: () async {
            final imagePath = await _captureImage();
            if (imagePath != null && mounted) {
              // Check image quality before proceeding
              final qualityIssue = await ImageQualityChecker.getQualityIssue(File(imagePath));
              if (qualityIssue != null) {
                // Show error message if quality check fails
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(qualityIssue),
                    duration: Duration(seconds: 3),
                  ),
                );
                return;
              }
              
              // Only navigate if quality check passes
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ResultPage(
                    imagePath: imagePath,
                    isFrontCamera: true,
                  ),
                ),
              );
            }
          },
          child: Icon(Icons.camera_alt, color: Colors.black, size: 30),
        ),
      ),
    );
  }
}
