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