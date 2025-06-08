// lib/AiSkinAnalysis/analysis_camera_page.dart
import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'review_selfie.dart';
import 'selfie_quality_checker.dart';

class AnalysisCameraPage extends StatefulWidget {
  final Function(String skinTypeName) onAnalysisComplete;
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

  // --- State variable for the bottom error message bar ---
  String? _bottomErrorText;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }
  
  // All other methods like _initializeCamera, _captureImage, and dispose remain the same.
  // I will omit them here for brevity but they should be kept in your file.
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
        frontCamera = cameras.first;
      }
      _controller = CameraController(
        frontCamera,
        ResolutionPreset.high,
        imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.yuv420 : ImageFormatGroup.bgra8888,
        enableAudio: false,
      );
      await _controller.initialize();
      try {
        await _controller.setFocusMode(FocusMode.locked);
      } catch (e) { debugPrint("Could not set focus mode to locked: $e"); }
      try {
        await _controller.setExposureMode(ExposureMode.locked);
      } catch (e) { debugPrint("Could not set exposure mode to locked: $e"); }
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

  // --- MODIFIED: _handleCapture now controls the bottom error bar ---
  Future<void> _handleCapture() async {
    // Clear any previous error message when starting a new capture
    setState(() {
      _bottomErrorText = null;
    });

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
      // **THE FIX IS HERE**: Update the state to show the error at the bottom
      setState(() {
        _bottomErrorText = qualityResult.error;
      });
      // Clear the error message after a few seconds
      Timer(const Duration(seconds: 4), () {
        if (mounted) {
          setState(() {
            _bottomErrorText = null;
          });
        }
      });
      return;
    }

    if (qualityResult.isValid) {
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

      if (analysisResult != null && mounted) {
        widget.onAnalysisComplete(analysisResult);
      }
    } else {
      setState(() {
        _bottomErrorText = "Could not get face details. Please try again.";
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (!_isCameraReady) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 16),
              Text("Preparing Camera...", style: const TextStyle(color: Colors.white)),
            ],
          ),
        ),
      );
    }
    
    // --- **NEW RESTRUCTURED BUILD METHOD** ---
     return Scaffold(
      appBar: AppBar(
        title: const Text('Skin Analysis Camera'),
        // Use the colorScheme for a consistent look
        backgroundColor: colorScheme.primary, 
        foregroundColor: colorScheme.onPrimary,
        leading: widget.onBackPressed != null
            ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: widget.onBackPressed)
            : null,
      ),
      backgroundColor: Colors.black, // The background behind the camera should be black
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera Preview (flipped for selfie)
          Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()..scale(-1.0, 1.0, 1.0),
            child: CameraPreview(_controller),
          ),
          
          // Face Guide Overlay
          _buildGuidedBox(),
          
          // Top Guide Box
          _buildCaptureGuidelines(),

          // Bottom Bar with Capture Button and Error Message
          _buildBottomBar(),
        ],
      ),
    );
  }

  // Helper for the face outline
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

  // Helper for the informational guide at the top
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

  // Helper for individual guide items
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

  // --- **NEW: Widget for the entire bottom bar section** ---
  Widget _buildBottomBar() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // White container for the capture button
          Container(
            height: 100, // Adjust height as needed
            width: double.infinity,
            color: Colors.white,
            child: Center(
              child: SizedBox(
                width: 70,
                height: 70,
                child: FloatingActionButton(
                  backgroundColor: Colors.white,
                  onPressed: _isCapturing ? null : _handleCapture,
                  elevation: 2.0,
                  shape: CircleBorder(side: BorderSide(color: Colors.grey.shade300, width: 2)),
                  child: _isCapturing
                      ? const CircularProgressIndicator(color: Colors.black)
                      : const Icon(Icons.camera_alt, color: Colors.black, size: 36),
                ),
              ),
            ),
          ),

          // **NEW**: Error message bar, only visible if _bottomErrorText is not null
          if (_bottomErrorText != null)
            Container(
              width: double.infinity,
              color: Colors.black.withOpacity(0.8),
              padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
              child: Text(
                _bottomErrorText!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
        ],
      ),
    );
  }
}