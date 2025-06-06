// lib/analysis_camera_page.dart
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'review_selfie.dart'; // This is your ResultPage file
import 'selfie_quality_checker.dart';

class AnalysisCameraPage extends StatefulWidget {
  /// Callback that returns the final skin type name (e.g., "Oily") after successful analysis.
  final Function(String skinTypeName) onAnalysisComplete;

  /// Callback to handle the back button press, passed from the parent.
  final VoidCallback? onBackPressed;

  const AnalysisCameraPage({
    Key? key,
    required this.onAnalysisComplete,
    this.onBackPressed,
  }) : super(key: key);

  @override
  _AnalysisCameraPageState createState() => _AnalysisCameraPageState();
}

class _AnalysisCameraPageState extends State<AnalysisCameraPage> {
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
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("No cameras found on this device.")),
          );
        }
        return;
      }

      CameraDescription frontCamera;
      try {
        frontCamera = cameras.firstWhere(
          (cam) => cam.lensDirection == CameraLensDirection.front,
        );
      } catch (e) {
        // Fallback to the first camera if no front camera is found
        frontCamera = cameras.first;
      }

      _controller = CameraController(
        frontCamera,
        ResolutionPreset.high,
        imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.yuv420 : ImageFormatGroup.bgra8888,
        enableAudio: false,
      );

      await _controller.initialize();

      // Lock focus and exposure for consistent images
      try {
        await _controller.setFocusMode(FocusMode.locked);
      } catch (e) {
        debugPrint("Could not set focus mode to locked: $e");
      }
      try {
        await _controller.setExposureMode(ExposureMode.locked);
      } catch (e) {
        debugPrint("Could not set exposure mode to locked: $e");
      }

      if (mounted) {
        setState(() => _isCameraReady = true);
      }
    } catch (e) {
      debugPrint("Error initializing camera: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error initializing camera: ${e.toString()}")),
        );
      }
    }
  }

  Future<String?> _captureImage() async {
    if (!_controller.value.isInitialized || _isCapturing) {
      return null;
    }
    setState(() => _isCapturing = true);
    try {
      final image = await _controller.takePicture();
      return image.path;
    } on CameraException catch (e) {
      debugPrint("Error taking picture: ${e.code} ${e.description}");
      return null;
    } finally {
      if (mounted) {
        setState(() => _isCapturing = false);
      }
    }
  }

  @override
  void dispose() {
    if (_controller.value.isInitialized) {
      _controller.dispose();
    }
    super.dispose();
  }

  Future<void> _handleCapture() async {
    final imagePath = await _captureImage();
    if (imagePath == null || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final qualityResult = await ImageQualityChecker.getQualityIssue(
      File(imagePath),
      guideBoxSize: Size(guideBoxWidth, guideBoxHeight),
      screenSize: MediaQuery.of(context).size,
    );

    if (mounted) Navigator.pop(context); // Dismiss loading dialog
    if (!mounted) return;

    if (qualityResult.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(qualityResult.error!),
          backgroundColor: Colors.orangeAccent,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    if (qualityResult.isValid) {
      // Navigate to the review/analysis flow and AWAIT the final result.
      // The result is expected to be the skin type name (String) popped from AnalysisPage.
      final String? analysisResult = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (context) => ResultPage(
            imagePath: imagePath,
            isFrontCamera: _controller.description.lensDirection == CameraLensDirection.front,
            faceBoundingBox: qualityResult.face!.boundingBox,
          ),
        ),
      );

      // If we received a result, the user completed the flow successfully.
      if (analysisResult != null && mounted) {
        // Pass the result up to the parent widget (MultiPageSkinProfileScreen).
        widget.onAnalysisComplete(analysisResult);
      }
    } else {
      // This is a fallback case, as qualityResult.error should have been caught.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not get face details. Please try again.")),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (!_isCameraReady) {
      // Loading state while camera initializes
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text("Preparing Camera...", style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      );
    }

    // Main camera view UI
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox.expand(
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()..scale(-1.0, 1.0, 1.0), // Flip for selfie view
            child: CameraPreview(_controller),
          ),
        ),
        _buildCaptureGuidelines(),
        _buildGuidedBox(),
        _buildCaptureButton(),
      ],
    );
  }

  Widget _buildGuidedBox() {
    return Center(
      child: Container(
        width: guideBoxWidth,
        height: guideBoxHeight,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white.withOpacity(0.9), width: 2.0),
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
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.face_retouching_natural, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('Skin Analysis Guide', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _buildGuideItem(Icons.light_mode, 'Good lighting'),
                _buildGuideItem(Icons.face, 'No makeup'),
                _buildGuideItem(Icons.close_fullscreen, 'Fill the frame'),
                _buildGuideItem(Icons.face_retouching_off, 'Keep hair back'),
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
        const SizedBox(width: 4),
        Text(text, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14)),
      ],
    );
  }

  Widget _buildCaptureButton() {
    return Positioned(
      bottom: 40,
      left: 0,
      right: 0,
      child: Center(
        child: FloatingActionButton.large(
          backgroundColor: Colors.white,
          onPressed: _isCapturing ? null : _handleCapture,
          child: _isCapturing
              ? const CircularProgressIndicator(color: Colors.black)
              : const Icon(Icons.camera_alt, color: Colors.black, size: 40),
        ),
      ),
    );
  }
}