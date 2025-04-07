import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'staging.dart';
import 'safety_result.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onSwitchToProfile; // Callback to switch to profile tab

  const HomeScreen({required this.onSwitchToProfile});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _supabase = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  final ImagePicker _imagePicker = ImagePicker();
  File? _imageFile;

  @override
  void initState() {
    super.initState();
    _checkAndRequestCameraPermission();
  }

  Future<void> _checkAndRequestCameraPermission() async {
    var status = await Permission.camera.status;
    if (status.isDenied || status.isPermanentlyDenied) {
      status = await Permission.camera.request();
    }
    if (status.isGranted) {
      await _initializeCamera();
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Camera permission is required!")));
    }
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    if (cameras.isNotEmpty) {
      _cameraController = CameraController(cameras[0], ResolutionPreset.medium);
      await _cameraController?.initialize();
      if (mounted) {
        setState(() => _isCameraInitialized = true);
      }
    }
  }

  Future<void> _searchProducts(String query) async {
    if (query.isEmpty) return;
    try {
      final response = await _supabase
          .from('Products')
          .select('*')
          .or('Product_Name.ilike.%$query%,Brand.ilike.%$query%');

      setState(
        () => _searchResults = (response as List).cast<Map<String, dynamic>>(),
      );
    } catch (e) {
      print("Error in search: $e");
    }
  }

  /// Pick Image from Gallery or Camera
  Future<void> _pickImage(ImageSource source) async {
  final pickedFile = await _imagePicker.pickImage(source: source);
  if (pickedFile != null) {
    File selectedImage = File(pickedFile.path);

    // Navigate to cropping screen
    File? croppedImage = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StagingScreen(imageFile: selectedImage,  onProfileRequested: widget.onSwitchToProfile,),
      ),
    );

    // Update state with the cropped image
    if (croppedImage != null) {
      setState(() {
        _imageFile = croppedImage;
      });
    }
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Home",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color.fromARGB(255, 170, 136, 176),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacementNamed(context, "/login");
          },
        ),
      ),
      body: Stack(
        children: [
          // Background Image
          // Background Image with Opacity
          Center(
            child: Opacity(
              opacity: 0.3, // Adjust opacity here (0.0 to 1.0)
              child: SizedBox(
                width: 800, // Adjust width
                height: 500, // Adjust height
                child: Container(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage("assets/skincare2.jpeg"),
                      fit: BoxFit.cover, // Adjust the fit as needed
                    ),
                  ),
                ),
              ),
            ),
          ),

          Column(
            children: [
              Padding(
                padding: EdgeInsets.all(10),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: "Search Product or Brand",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (query) => _searchProducts(query),
                ),
              ),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Capture Button
                      ElevatedButton(
                        onPressed: () => _pickImage(ImageSource.camera),
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            horizontal: 40,
                            vertical: 15,
                          ),
                          backgroundColor: Colors.white, // White background
                          shadowColor: Colors.purple.withOpacity(
                            0.5,
                          ), // Shadow color
                          elevation: 5, // Shadow effect
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(50),
                            side: BorderSide(
                              color: Colors.purple,
                              width: 2,
                            ), // Violet border
                          ),
                        ),
                        child: Text(
                          "Capture",
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.purple,
                          ), // Violet text color
                        ),
                      ),

                      SizedBox(height: 20),

                      // Upload Button
                      ElevatedButton(
                        onPressed: () => _pickImage(ImageSource.gallery),
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            horizontal: 40,
                            vertical: 15,
                          ),
                          backgroundColor: Colors.white, // White background
                          shadowColor: Colors.purple.withOpacity(
                            0.5,
                          ), // Shadow color
                          elevation: 5, // Shadow effect
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(50),
                            side: BorderSide(
                              color: Colors.purple,
                              width: 2,
                            ), // Violet border
                          ),
                        ),
                        child: Text(
                          "Upload",
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.purple,
                          ), // Violet text color
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          if (_searchResults.isNotEmpty)
            Positioned(
              top: 70,
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                color: Color.fromARGB(255, 255, 254, 253),
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 20),
                child: Column(
                  children: [
                    Text(
                      "Search Results",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    Divider(color: Colors.black),
                    Expanded(
                      child: ListView.separated(
                        itemCount: _searchResults.length,
                        separatorBuilder:
                            (context, index) => Divider(color: Colors.black),
                        itemBuilder: (context, index) {
                          final product = _searchResults[index];
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _searchController.text =
                                    "${product['Product_Name']} - ${product['Brand']}";
                                _searchResults.clear();
                              });
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => SafetyResultScreen(
                                    productId: product['Product_Id'],
                                    productName: product['Product_Name'],
                                    brand: product['Brand'],
                                    imageUrl: product['Image_Url'] ?? '',
                                    onProfileRequested: widget.onSwitchToProfile,
                                  ),
                                ),
                              );
                            },
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 10),
                              child: Text(
                                "${product['Product_Name']} - ${product['Brand']}",
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
