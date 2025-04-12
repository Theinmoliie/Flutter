import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'skin_results_screen.dart';
import 'quality_checker.dart';

class CameraPage extends StatefulWidget {
  @override
  _CameraPage createState() => _CameraPage();
}

class _CameraPage extends State<CameraPage> {
  late CameraController _controller;
  bool _isCameraReady = false;
  bool _isCapturing = false;

  final double guideBoxWidth = 250;
  final double guideBoxHeight = 350;

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
      ResolutionPreset.high,
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
          Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()..scale(-1.0, 1.0, 1.0),
            child: CameraPreview(_controller),
          ),
          _buildCaptureGuidelines(),
          _buildGuidedBox(),
          _buildCaptureButton(),
        ],
      ),
    );
  }

  Widget _buildCaptureGuidelines() {
  return Positioned(
    top: 50,
    left: 20,
    right: 20,
    child: Container(
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            'Align your face within the frame',
            style: TextStyle(color: Colors.white, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 6),
          Text(
            'Ensure good lighting',
            style: TextStyle(color: Colors.white, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

Widget _buildGuidedBox() {
  return Center(
    child: Container(
      width: guideBoxWidth,
      height: guideBoxHeight,
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.white.withOpacity(0.8),
          width: 2.0,
        ),
        borderRadius: BorderRadius.circular(10),
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
              final qualityIssue = await ImageQualityChecker.getQualityIssue(
                File(imagePath),
                guideBoxSize: Size(guideBoxWidth, guideBoxHeight),
                screenSize: MediaQuery.of(context).size,
              );

              if (qualityIssue != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(qualityIssue),
                    duration: Duration(seconds: 3),
                  ),
                );
                return;
              }

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