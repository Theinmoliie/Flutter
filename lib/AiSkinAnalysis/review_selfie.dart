// // 📁 review_selfie.dart

//ROBOFLOW IPLEMENTATION
// _____________________________________________________________________


// import 'dart:io';
// import 'package:flutter/material.dart';
// // Import your Roboflow service
// import '../services/roboflow_service.dart'; // <--- Adjust path if needed
// // Import the ACTUAL results page (not dummy)
// import 'skin_analysis_result.dart'; // <--- CHANGE THIS IMPORT
// import 'package:flutter/foundation.dart';

// // Convert ResultPage to StatefulWidget
// class ResultPage extends StatefulWidget { // <--- Change here
//   final String imagePath;
//   final bool isFrontCamera;

//   const ResultPage({
//     Key? key, // <--- Add Key? key
//     required this.imagePath,
//     this.isFrontCamera = true,
//   }) : super(key: key); // <--- Add super(key: key)

//   @override
//   _ResultPageState createState() => _ResultPageState(); // <--- Add createState
// }

// // Create the State class
// class _ResultPageState extends State<ResultPage> {
//   bool _isLoading = false; // State variable for loading indicator

//   // Function to handle the analysis process
//   Future<void> _analyseSkin() async {
//     if (_isLoading) return; // Prevent multiple taps

//     setState(() {
//       _isLoading = true; // Show loading indicator
//     });

//     // Show a temporary loading dialog or overlay if desired (optional)
//     // showDialog(context: context, builder: (_) => Center(child: CircularProgressIndicator()), barrierDismissible: false);

//     try {
//       // Create File object from path
//       final File imageFile = File(widget.imagePath);

//       // Call the Roboflow service
//       final result = await RoboflowService.analyseSkinWorkflow(imageFile);

//       // if (Navigator.canPop(context)) { // Dismiss loading dialog if shown
//       //   Navigator.pop(context);
//       // }

//       // Check result and navigate or show error
//       if (result['success'] == true && mounted) { // Check mounted before navigation
//         Navigator.pushReplacement( // Use pushReplacement to remove review screen from stack
//           context,
//           MaterialPageRoute(
//             builder: (context) => AnalysisPage( // Navigate to ACTUAL results page
//               // Pass the relevant data extracted by the service
//               skinType: result['skin_type'],
//               confidence: result['confidence'],
//               imagePath: widget.imagePath, // Pass image path if needed
//             ),
//           ),
//         );
//       } else if (mounted) {
//         // Show error message if API call failed or parsing failed
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Analysis failed: ${result['error'] ?? 'Unknown error'}'),
//             backgroundColor: Colors.red,
//             duration: const Duration(seconds: 4),
//           ),
//         );
//          // Optionally log raw response for debugging errors
//          if (kDebugMode && result.containsKey('raw_response')) {
//            debugPrint("[ReviewScreen] Raw error response: ${result['raw_response']}");
//          }
//       }
//     } catch (e, stackTrace) {
//       // Catch any unexpected errors during the process
//        if (mounted) {
//         // if (Navigator.canPop(context)) { // Dismiss loading dialog if shown
//         //   Navigator.pop(context);
//         // }
//         debugPrint("[ReviewScreen] Unexpected error: $e\n$stackTrace");
//          ScaffoldMessenger.of(context).showSnackBar(
//            SnackBar(
//              content: Text('An unexpected error occurred. Please try again.'),
//              backgroundColor: Colors.red,
//            ),
//          );
//        }
//     } finally {
//       // Ensure loading indicator is hidden if widget is still mounted
//        if (mounted) {
//          setState(() {
//             _isLoading = false;
//          });
//        }
//     }
//   }


//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('Review Your Selfie')),
//       body: Column(
//         children: [
//           Expanded(
//             child: Center(
//               // Use the widget property directly
//               child: Transform(
//                 alignment: Alignment.center,
//                 transform: Matrix4.identity()..scale(widget.isFrontCamera ? -1.0 : 1.0, 1.0, 1.0),
//                 child: Image.file(File(widget.imagePath)),
//               ),
//             ),
//           ),
//           Padding(
//             padding: const EdgeInsets.all(16),
//             // Show loading indicator or button
//             child: _isLoading
//                 ? const CircularProgressIndicator()
//                 : ElevatedButton(
//                     // Call the analysis function on press
//                     onPressed: _analyseSkin,
//                     style: ElevatedButton.styleFrom(
//                        minimumSize: const Size(double.infinity, 50), // Make button wider
//                        textStyle: const TextStyle(fontSize: 18)
//                     ),
//                     child: const Text('Analyze Skin'),
//                   ),
//           ),
//         ],
//       ),
//     );
//   }
// }










// .TFLITE MODEL IMPLEMENTATION
//_______________________________________

// 📁 review_selfie.dart
import 'dart:io';
import 'package:flutter/material.dart';
import '../services/tflite_service.dart'; // <--- Import TFLite service
import 'skin_analysis_result.dart';
import 'package:flutter/foundation.dart'; // For kDebugMode

class ResultPage extends StatefulWidget {
  final String imagePath;
  final bool isFrontCamera;

  const ResultPage({
    Key? key,
    required this.imagePath,
    this.isFrontCamera = true,
  }) : super(key: key);

  @override
  _ResultPageState createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  bool _isLoading = false;
  final TfliteService _tfliteService = TfliteService(); // Instantiate the service

  @override
  void initState() {
    super.initState();
    // Eagerly load model when the review screen initializes (optional but can speed up first prediction)
    // If you initialized it in the constructor, this call might not be strictly necessary
    // but ensures it's loaded before the user taps analyze.
    _tfliteService.loadModel();
  }

  @override
  void dispose() {
    _tfliteService.dispose(); // Dispose the interpreter when the screen is removed
    super.dispose();
  }

  Future<void> _analyseSkin() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final File imageFile = File(widget.imagePath);

      // *** CHANGE: Call TFLite Service ***
      final result = await _tfliteService.predictImage(imageFile);
      // *** --------------------------- ***


      if (result['success'] == true && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => AnalysisPage(
              skinType: result['skin_type'],
              confidence: result['confidence'],
              imagePath: widget.imagePath,
              isFrontCamera: widget.isFrontCamera, // Pass camera orientation if needed
            ),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Analysis failed: ${result['error'] ?? 'Unknown error'}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
        if (kDebugMode) {
          debugPrint("[ReviewScreen] TFLite Error: ${result['error']}");
        }
      }
    } catch (e, stackTrace) {
      if (mounted) {
        debugPrint("[ReviewScreen] Unexpected error: $e\n$stackTrace");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('An unexpected error occurred. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get theme for styling
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Your Selfie'),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding( // Add padding around the image
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: AspectRatio( // Maintain aspect ratio
                  aspectRatio: 3 / 4, // Adjust if your camera preview ratio is different
                  child: ClipRRect( // Clip image with rounded corners
                    borderRadius: BorderRadius.circular(12.0),
                    child: Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..scale(widget.isFrontCamera ? -1.0 : 1.0, 1.0, 1.0),
                      child: Image.file(
                        File(widget.imagePath),
                        fit: BoxFit.cover, // Cover the aspect ratio box
                        errorBuilder: (context, error, stackTrace) => const Center(
                           child: Column(
                             mainAxisAlignment: MainAxisAlignment.center,
                             children: [
                               Icon(Icons.broken_image, size: 50, color: Colors.grey),
                               SizedBox(height: 8),
                               Text("Error loading image", style: TextStyle(color: Colors.grey)),
                             ],
                           )
                         ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0), // Increased padding
            child: _isLoading
                ? CircularProgressIndicator(color: colorScheme.primary)
                : ElevatedButton(
                    onPressed: _analyseSkin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                      minimumSize: const Size(double.infinity, 55), // Make button wider and taller
                      textStyle: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      shape: RoundedRectangleBorder( // Add rounded corners
                        borderRadius: BorderRadius.circular(30.0)
                      ),
                      elevation: 3,
                    ),
                    child: const Text('Analyze Skin Type'),
                  ),
          ),
        ],
      ),
    );
  }
}