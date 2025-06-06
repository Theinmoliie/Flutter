// cropping_screen.dart (or within safety_input_screen.dart)
import 'dart:io';
import 'dart:ui' as dart_ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For Uint8List
import 'package:crop_image/crop_image.dart';
import 'package:path_provider/path_provider.dart';

class CroppingScreen extends StatefulWidget {
  final File imageFile;

  const CroppingScreen({Key? key, required this.imageFile}) : super(key: key);

  @override
  _CroppingScreenState createState() => _CroppingScreenState();
}

class _CroppingScreenState extends State<CroppingScreen> {
  final _controller = CropController(
    // You can set an initial aspect ratio if desired, e.g., for a square:
    // aspectRatio: 1.0,
    // Or keep it freeform by default
    defaultCrop: const Rect.fromLTRB(0.1, 0.1, 0.9, 0.9), // Initial selection
  );


Future<void> _cropAndPop() async {
  // Show a loading indicator while cropping
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return const Center(child: CircularProgressIndicator());
    },
  );

  try {
    // REMOVE: final pixelRatio = MediaQuery.of(context).devicePixelRatio;
    final uiImage = await _controller.croppedBitmap(); // CALL WITHOUT pixelRatio
    Navigator.pop(context); // Dismiss loading indicator

    if (uiImage != null) {
      final File? finalImageFile = await _convertUiImageToFile(uiImage);
      Navigator.pop(context, finalImageFile); // Pop with the cropped file
    } else {
      print("Cropping returned a null ui.Image.");
      Navigator.pop(context, null); // Pop with null if cropping failed
    }
  } catch (e) {
    Navigator.pop(context); // Dismiss loading indicator on error
    print("Error during cropping: $e");
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Error cropping image")),
    );
    Navigator.pop(context, null); // Pop with null on error
  }
}

  Future<File?> _convertUiImageToFile(dart_ui.Image uiImage) async {
    try {
      final byteData = await uiImage.toByteData(format: dart_ui.ImageByteFormat.png);
      if (byteData == null) return null;

      final Uint8List pngBytes = byteData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final epoch = DateTime.now().millisecondsSinceEpoch;
      final file = File('${tempDir.path}/cropped_image_$epoch.png');

      await file.writeAsBytes(pngBytes);
      return file;
    } catch (e) {
      print("Error converting ui.Image to File: $e");
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Crop Image", // Or "Edit Photo"
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: colorScheme.primary, // Your app's primary color
        iconTheme: const IconThemeData(color: Colors.white), // For back button
        actions: [
          IconButton(
            icon: const Icon(Icons.check, color: Colors.white),
            onPressed: _cropAndPop,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: CropImage(
              controller: _controller,
              image: Image.file(widget.imageFile),
              gridColor: Colors.white.withOpacity(0.5),
              gridCornerSize: 25,
              gridThinWidth: 1,
              gridThickWidth: 3,
              scrimColor: Colors.black.withOpacity(0.6),
              alwaysShowThirdLines: true,
              // minimumImageSize: 100, // Optional
            ),
          ),
          // Optional: Add controls for aspect ratio, rotation etc. in a bottom bar
          // _buildControls(),
        ],
      ),
    );
  }

  // Example of how you might add controls
  /*
  Widget _buildControls() {
    return Container(
      color: Colors.black.withOpacity(0.8),
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          IconButton(
            icon: Icon(Icons.aspect_ratio, color: Colors.white),
            onPressed: () {
              // Example: cycle through aspect ratios or show a dialog
              if (_controller.aspectRatio == null) {
                _controller.aspectRatio = 1.0; // Square
              } else if (_controller.aspectRatio == 1.0) {
                _controller.aspectRatio = 16 / 9; // 16:9
              } else {
                _controller.aspectRatio = null; // Freeform
              }
              setState(() {});
            },
          ),
          // Add more controls like rotation if needed
        ],
      ),
    );
  }
  */
}