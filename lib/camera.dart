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
    ResolutionPreset.high, // 720p (1280x720)
    // For better skin analysis:
    imageFormatGroup: Platform.isAndroid 
        ? ImageFormatGroup.yuv420 
        : ImageFormatGroup.bgra8888,
    enableAudio: false,
    );

    await _controller.initialize();
    if (mounted) setState(() => _isCameraReady = true);

     // Lock settings for consistency
    await _controller.setFocusMode(FocusMode.locked);
    await _controller.setExposureMode(ExposureMode.locked);
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

 Widget _buildGuidedBox() {
  return Center(
    child: Container(
      width: guideBoxWidth,
      height: guideBoxHeight,
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.white.withOpacity(0.9),
          width: 2.0,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
    ),
  );
}



Widget _buildCaptureGuidelines() {
  return Positioned(
    top: 50,
    left: 20,
    right: 20,
    child: AnimatedContainer(
      duration: Duration(milliseconds: 300),
      padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.face_retouching_natural, 
                  color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                'Skin Analysis Guide',
                style: TextStyle(
                  color: Colors.white, 
                  fontSize: 18,
                  fontWeight: FontWeight.w600),
              ),
            ],
          ),
          SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _buildGuideItem(Icons.light_mode, 'Good lighting'),
              _buildGuideItem(Icons.face, 'No makeup'),
              _buildGuideItem(Icons.close_fullscreen, 'Fill the frame'),
            ],
          ),
        ],
      ),
    ),
  );
}

Widget _buildGuideItem(IconData icon, String text) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, color: Colors.white.withOpacity(0.8), size: 16),
      SizedBox(width: 4),
      Text(
        text,
        style: TextStyle(
          color: Colors.white.withOpacity(0.8),
          fontSize: 14,
        ),
      ),
    ],
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