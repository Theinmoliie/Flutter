// lib/selfie.dart
import 'dart:io';
import 'dart:ui'; // Required for Rect
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'review_selfie.dart'; // Needs faceBoundingBox parameter
import 'selfie_quality_checker.dart'; // Uses google_ml_kit and returns QualityCheckResult

class CameraPage extends StatefulWidget {
  // Using const constructor is fine for StatefulWidget if no params needed immediately
  const CameraPage({super.key});

  @override
  _CameraPage createState() => _CameraPage();
}

class _CameraPage extends State<CameraPage> {
  // Use late initialization
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
    // Using the corrected initialization logic with try-catch for modes
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        print("Error: No cameras available!");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("No cameras found on this device.")),
          );
        }
        return;
      }

      CameraDescription? frontCamera;
      try {
        frontCamera = cameras.firstWhere(
          (cam) => cam.lensDirection == CameraLensDirection.front,
          orElse: () => cameras.first,
        );
      } catch (e) {
        print("Error finding front camera: $e. Using first available camera.");
        frontCamera = cameras.first;
      }

      _controller = CameraController(
        frontCamera,
        ResolutionPreset.high,
        imageFormatGroup:
            Platform.isAndroid
                ? ImageFormatGroup.yuv420
                : ImageFormatGroup.bgra8888,
        enableAudio: false,
      );

      await _controller.initialize();
      print("Camera initialized successfully.");

      // Attempt to set modes AFTER initialization using try-catch
      try {
        await _controller.setFocusMode(FocusMode.locked);
        print("Focus mode successfully set to locked.");
      } on CameraException catch (e) {
        print("Could not set focus mode to locked: ${e.code} ${e.description}");
      } catch (e) {
        print("Unexpected error setting focus mode: $e");
      }

      try {
        await _controller.setExposureMode(ExposureMode.locked);
        print("Exposure mode successfully set to locked.");
      } on CameraException catch (e) {
        print(
          "Could not set exposure mode to locked: ${e.code} ${e.description}",
        );
      } catch (e) {
        print("Unexpected error setting exposure mode: $e");
      }

      if (mounted) {
        setState(() => _isCameraReady = true);
      }
    } catch (e) {
      print("Error initializing camera: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error initializing camera: ${e.toString()}")),
        );
      }
    }
  }

  Future<String?> _captureImage() async {
    // Using the corrected capture logic
    if (!_controller.value.isInitialized || !_isCameraReady || _isCapturing) {
      return null;
    }
    if (_controller.value.isTakingPicture) {
      return null;
    }
    setState(() => _isCapturing = true);
    try {
      XFile image = await _controller.takePicture();
      return image.path;
    } on CameraException catch (e) {
      /* ... error handling ... */
      return null;
    } catch (e) {
      /* ... error handling ... */
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
      // Check before dispose
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (!_isCameraReady) {
      // Your original loading scaffold
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(/* ... Loading UI ... */),
      );
    }

    // *** Restore your original Scaffold and Stack structure ***
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Skin Analysis Camera',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: colorScheme.primary,
        leading:
            Navigator.canPop(context)
                ? IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                )
                : null,
      ),
      // Body structure exactly as you provided
      body: Stack(
        children: [
          // *** RESTORED Original Transform and CameraPreview ***
          Transform(
            alignment: Alignment.center,
            transform:
                Matrix4.identity()..scale(-1.0, 1.0, 1.0), // Your flip method
            child: CameraPreview(
              _controller,
            ), // Direct preview, potentially stretched
          ),
          // Your existing overlay widgets
          _buildCaptureGuidelines(),
          _buildGuidedBox(),
          _buildCaptureButton(), // This contains the fixed logic
        ],
      ),
    );
  }

  // --- UI Helper Widgets (Exactly as you provided) ---

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
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.face_retouching_natural,
                  color: Colors.white,
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  'Skin Analysis Guide',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
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
        SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14),
        ),
      ],
    );
  }

  // --- Capture Button (UI as you provided, LOGIC FIXED) ---
  Widget _buildCaptureButton() {
    // Your original Capture Button UI structure
    return Positioned(
      bottom: 40,
      left: 0,
      right: 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 80,
            width: double.infinity,
            color: Colors.white,
            child: Center(
              child: FloatingActionButton(
                backgroundColor: Colors.white,
                heroTag: 'captureButton', // Ensure unique heroTag
                onPressed:
                    _isCapturing
                        ? null
                        : () async {
                          // Add _isCapturing check
                          final imagePath = await _captureImage();
                          if (imagePath == null || !mounted) return;

                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder:
                                (context) => const Center(
                                  child: CircularProgressIndicator(),
                                ),
                          );

                          // *** Call correct quality checker ***
                          final QualityCheckResult qualityResult =
                              await ImageQualityChecker.getQualityIssue(
                                File(imagePath),
                                guideBoxSize: Size(
                                  guideBoxWidth,
                                  guideBoxHeight,
                                ), // Use fixed size from class
                                screenSize: MediaQuery.of(context).size,
                              );

                          if (mounted)
                            Navigator.pop(context); // Dismiss loading
                          if (!mounted) return;

                          // *** Check error property ***
                          if (qualityResult.error != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(qualityResult.error!),
                                duration: const Duration(seconds: 3),
                              ),
                            );
                            return;
                          }

                          // *** Navigate with required faceBoundingBox ***
                          if (qualityResult.isValid) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => ResultPage(
                                      imagePath: imagePath,
                                      isFrontCamera:
                                          _controller
                                              .description
                                              .lensDirection ==
                                          CameraLensDirection.front,
                                      faceBoundingBox:
                                          qualityResult
                                              .face!
                                              .boundingBox, // <-- PASS BOUNDING BOX
                                    ),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Could not get face details."),
                              ),
                            );
                          }
                        },
                child:
                    _isCapturing
                        ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Colors.black,
                          ),
                        )
                        : const Icon(
                          Icons.camera_alt,
                          color: Colors.black,
                          size: 30,
                        ),
              ),
            ),
          ),
        ],
      ),
    );
  }
} // End of _CameraPage class
