// safety_input_screen.dart
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart'; // Import image_cropper
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

import 'ocr_safety_display_screen.dart';
import 'safety_rating_display_screen.dart';
import 'cropping_screen.dart';

class SafetyInputScreen extends StatefulWidget {
  final VoidCallback onSwitchToProfile;

  const SafetyInputScreen({Key? key, required this.onSwitchToProfile}) : super(key: key);

  @override
  _SafetyInputScreenState createState() => _SafetyInputScreenState();
}

class _SafetyInputScreenState extends State<SafetyInputScreen> {
  final _supabase = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  final ImagePicker _imagePicker = ImagePicker();
  final ImageCropper _imageCropper = ImageCropper(); // Instantiate ImageCropper

  @override
  void initState() {
    super.initState();
    _checkAndRequestCameraPermission();
    _searchController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _checkAndRequestCameraPermission() async {
    var status = await Permission.camera.status;
    if (!status.isGranted) {
      status = await Permission.camera.request();
    }
    if (!status.isGranted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Camera permission is recommended.")));
    }
  }

  Future<void> _searchProducts(String query) async {
    if (query.isEmpty) {
      if (mounted) setState(() => _searchResults.clear());
      return;
    }
    try {
      final response = await _supabase
          .from('Products')
          .select('Product_Id, Product_Name, Brand, Image_Url')
          .or('Product_Name.ilike.%$query%,Brand.ilike.%$query%')
          .limit(15);
      if (mounted) {
        setState(() {
          _searchResults = List<Map<String, dynamic>>.from(response);
        });
      }
    } catch (e) {
      print("Error in search: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to search products")));
      }
    }
  }

   Future<File?> _navigateToCropScreen(File imageFile) async {
  final File? croppedImage = await Navigator.push<File?>(
    context,
    MaterialPageRoute(
      builder: (context) => CroppingScreen(imageFile: imageFile),
    ),
  );
  return croppedImage;
}

Future<void> _pickImage(ImageSource source) async {
  try {
    final pickedFile = await _imagePicker.pickImage(source: source);
    if (pickedFile == null) return;

    File imageToProcess = File(pickedFile.path);

    // Navigate to your custom cropping screen
    final File? croppedImageFile = await _navigateToCropScreen(imageToProcess); // MODIFIED
    if (croppedImageFile == null) {
      print("Cropping was cancelled or failed.");
      return;
    }

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OcrSafetyDisplayScreen(
            imageFile: croppedImageFile,
          ),
        ),
      );
    }
  } catch (e) {
    print("Error picking or navigating to crop screen: $e");
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to process image: ${e.toString()}")));
    }
  }
}

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bool showClearIcon = _searchController.text.isNotEmpty;
    final screenWidth = MediaQuery.of(context).size.width;
    final double desiredImageWidth = screenWidth * 0.55;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Product Safety Check",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: colorScheme.primary,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.black87),
                  decoration: InputDecoration(
                    labelText: "Search Product or Brand",
                    labelStyle: TextStyle(color: Colors.grey[700]),
                    hintText: "e.g. Soy Face Cleanser / Clinique",
                    hintStyle: TextStyle(color: Colors.grey[500]),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.95),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: Icon(Icons.search, color: Colors.grey[700]),
                    suffixIcon: showClearIcon
                        ? IconButton(
                            icon: Icon(Icons.clear, color: Colors.grey[600]),
                            tooltip: 'Clear search',
                            onPressed: () {
                              if (mounted) {
                                setState(() {
                                  _searchController.clear();
                                  _searchResults.clear();
                                });
                              }
                              FocusScope.of(context).unfocus();
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 15.0),
                  ),
                  onChanged: _searchProducts,
                  textInputAction: TextInputAction.search,
                  onSubmitted: _searchProducts,
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 40.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 15.0),
                        child: Text(
                          "Or",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).brightness == Brightness.dark
                                   ? Colors.white.withOpacity(0.9)
                                   : Colors.black.withOpacity(0.7),
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.camera_alt, color: Colors.deepPurpleAccent),
                        label: const Text("Capture Ingredients", style: TextStyle(fontSize: 17, color: Colors.deepPurpleAccent, fontWeight: FontWeight.w600)),
                        onPressed: () => _pickImage(ImageSource.camera),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.white,
                          shadowColor: Colors.deepPurple.withOpacity(0.4),
                          elevation: 6,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                            side: const BorderSide(color: Colors.deepPurpleAccent, width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
                      Text(
                        "Or",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).brightness == Brightness.dark
                                 ? Colors.white.withOpacity(0.9)
                                 : Colors.black.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: 15),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.upload_file, color: Colors.deepPurpleAccent),
                        label: const Text("Upload Image", style: TextStyle(fontSize: 17, color: Colors.deepPurpleAccent, fontWeight: FontWeight.w600)),
                        onPressed: () => _pickImage(ImageSource.gallery),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.white,
                          shadowColor: Colors.deepPurple.withOpacity(0.4),
                          elevation: 6,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                            side: const BorderSide(color: Colors.deepPurpleAccent, width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 25),
                      Text(
                        "Search for a product or capture/upload ingredient label to check its safety rating",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      SizedBox(height: MediaQuery.of(context).size.height * 0.05),
                      Padding(
                        padding: const EdgeInsets.only(top: 20.0, bottom: 20.0),
                        child: Opacity(
                          opacity: 0.5,
                          child: SizedBox(
                            width: desiredImageWidth,
                            child: Image.asset(
                              "assets/skincare.png",
                              fit: BoxFit.contain,
                              errorBuilder: (context, exception, stackTrace) {
                                print("Error loading decorative image: assets/skincare.png. $exception");
                                return const SizedBox.shrink();
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_searchResults.isNotEmpty)
            Positioned.fill(
              top: 65, 
              left: 10, 
              right: 10, 
              child: GestureDetector(
                onTap: () {
                  if (mounted) setState(() => _searchResults.clear());
                  FocusScope.of(context).unfocus();
                },
                child: Container(
                  color: Colors.black.withOpacity(0.1),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      margin: const EdgeInsets.only(top: 5),
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 12.0, bottom: 4.0),
                            child: Text(
                              "Search Results",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                            ),
                          ),
                          const Divider(height: 1, thickness: 1),
                          Flexible(
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              itemCount: _searchResults.length,
                              shrinkWrap: true,
                              separatorBuilder: (context, index) => const Divider(height: 1, indent: 10, endIndent: 10),
                              itemBuilder: (context, index) {
                                final product = _searchResults[index];
                                return ListTile(
                                  title: Text(
                                    product['Product_Name'] ?? 'Unknown Product',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    product['Brand'] ?? 'Unknown Brand',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  onTap: () {
                                    if (mounted) {
                                      setState(() {
                                        _searchResults.clear();
                                        FocusScope.of(context).unfocus();
                                      });
                                    }
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => SafetyRatingDisplayScreen(
                                          productId: product['Product_Id'],
                                          productName: product['Product_Name'],
                                          brand: product['Brand'],
                                          imageUrl: product['Image_Url'] ?? '',
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}