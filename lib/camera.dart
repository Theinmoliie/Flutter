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
   
    // Use theme colors
    final colorScheme = Theme.of(context).colorScheme;


    if (!_isCameraReady) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Full-screen black background
            Container(color: Colors.black),

            // Centered content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Spinner with custom styling
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withOpacity(0.2),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const CircularProgressIndicator(
                      strokeWidth: 3,
                      color: Colors.white,
                      backgroundColor: Colors.transparent,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Loading text
                  Text(
                    "Initializing Camera...",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Calculate scale if needed, but keep existing logic
    // final mediaSize = MediaQuery.of(context).size;
    // final scale = 1 / (_controller.value.aspectRatio * mediaSize.aspectRatio);


    return Scaffold(
      // *** ADDED AppBar HERE ***
      appBar: AppBar(
        // No backgroundColor specified, so it uses the theme's default color
        title: const Text(
          'Skin Analysis Camera',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ), 
        backgroundColor: colorScheme.primary,        // Added a title
        // Optional: Add back button if needed, using theme icon color
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white), // Set icon color
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
      ),
      // *** ---------------- ***
      // Body remains unchanged, starting below the AppBar
      body: Stack(
        children: [
          // Existing Transform and CameraPreview
          Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()..scale(-1.0, 1.0, 1.0),
            child: CameraPreview(_controller),
          ),
          // Existing overlay widgets remain unchanged
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
    top: 10,
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
    bottom: 40, // Keep the same bottom position
    left: 0,
    right: 0,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // White background container (now taller)
        Container(
          height: 80, // Adjust this value to make the white area taller
          width: double.infinity, // Full screen width
          color: Colors.white, // Semi-transparent white
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
        ),
      ],
    ),
  );
}
}