import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'ProductSafety/capture_product.dart';
import 'ProductSafety/search_product.dart';


class HomeScreen extends StatefulWidget {
  final VoidCallback onSwitchToProfile; // Callback to switch to profile tab

  // Use super key for constructors
  const HomeScreen({super.key, required this.onSwitchToProfile});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _supabase = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  // Remove camera controller logic if not directly used for preview here
  // CameraController? _cameraController;
  // bool _isCameraInitialized = false;
  final ImagePicker _imagePicker = ImagePicker();
  File? _imageFile; // Consider if this state is still needed here

  @override
  void initState() {
    super.initState();
    // Request permission if needed, but initialization might not be necessary here
    _checkAndRequestCameraPermission();

    // Add listener to controller to update UI for clear button visibility
    // (Although onChanged calling setState often covers this implicitly)
    _searchController.addListener(_updateClearIconVisibility);
  }

  // Listener to potentially force UI update for clear icon
  void _updateClearIconVisibility() {
    // This setState ensures the build method runs and checks text length
    // even if onChanged didn't trigger a state change directly affecting the icon
     if (mounted) {
      setState(() {});
     }
  }


  @override
  void dispose() {
    _searchController.removeListener(_updateClearIconVisibility); // Remove listener
    _searchController.dispose();
    // _cameraController?.dispose(); // Dispose if initialized
    super.dispose();
  }

  Future<void> _checkAndRequestCameraPermission() async {
    // Keep permission check logic
    var status = await Permission.camera.status;
    if (!status.isGranted) {
       status = await Permission.camera.request();
    }
    if (!status.isGranted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Camera permission is recommended.")));
    }
    // Initialization might be better done only when camera is actively needed
  }

  // Future<void> _initializeCamera() async { ... } // Keep if needed elsewhere

  Future<void> _searchProducts(String query) async {
    // Clear results immediately if query is empty
    if (query.isEmpty) {
       if (mounted) {
        setState(() => _searchResults.clear());
       }
      return;
    }
    try {
      // Fetch results only if query is not empty
      final response = await _supabase
          .from('Products')
          .select('*') // Select necessary columns: Product_Id, Product_Name, Brand, Image_Url
          .or('Product_Name.ilike.%$query%,Brand.ilike.%$query%')
          .limit(15); // Add a limit for performance

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

  Future<void> _pickImage(ImageSource source) async {
    try {
       final pickedFile = await _imagePicker.pickImage(source: source);
       if (pickedFile != null && mounted) { // Check mounted after await
         File selectedImage = File(pickedFile.path);
         // Navigate to StagingScreen (capture_product.dart)
         // StagingScreen handles the processing now
         Navigator.push(
           context,
           MaterialPageRoute(
             builder: (context) => StagingScreen(
               imageFile: selectedImage,
               onProfileRequested: widget.onSwitchToProfile,
             ),
           ),
         );
       }
    } catch (e) {
       print("Error picking image: $e");
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text("Failed to select image")));
       }
    }
  }

  Future<void> _handleLogout() async {
    // Keep logout logic
    if (!mounted) return;
    try {
      await _supabase.auth.signOut();
      print("User logged out successfully.");
      // Auth listener in main.dart should handle navigation
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Logout Failed: ${e is AuthException ? e.message : e.toString()}")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bool showClearIcon = _searchController.text.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Home",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: colorScheme.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Logout',
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background Image
          Center( /* ... background image setup ... */
             child: Opacity( opacity: 0.3, child: SizedBox( width: 800, height: 500, child: Container( decoration: const BoxDecoration( image: DecorationImage( image: AssetImage("assets/skincare2.jpeg"), fit: BoxFit.cover, ), ), ), ), ),
          ),

          Column(
            children: [
              // --- MODIFIED TextField ---
              Padding(
                padding: const EdgeInsets.all(10),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: "Search Product or Brand",
                    hintText: "Sephora Products Only", // Added hintText
                    border: OutlineInputBorder(
                       borderRadius: BorderRadius.circular(8), // Slightly rounded border
                    ),
                    prefixIcon: const Icon(Icons.search),
                    // --- Add suffixIcon for Clear Button ---
                    suffixIcon: showClearIcon
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.grey),
                            tooltip: 'Clear search', // Accessibility
                            onPressed: () {
                              // Clear controller and results, then update state
                              if (mounted) {
                                 setState(() {
                                   _searchController.clear();
                                   _searchResults.clear(); // Clear results directly
                                 });
                              }
                            },
                          )
                        : null, // No icon if text field is empty
                    // --------------------------------------
                    contentPadding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 10.0), // Adjust padding
                  ),
                  // onChanged triggers search
                  onChanged: (query) => _searchProducts(query),
                  textInputAction: TextInputAction.search, // Keyboard action
                  onSubmitted: (query) => _searchProducts(query), // Optional: Trigger search on submit
                ),
              ),
              // --- END MODIFIED TextField ---

              // --- Keep Center Column for Buttons ---
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Capture Button
                       ElevatedButton.icon( // Using icon button
                        icon: const Icon(Icons.camera_alt, color: Colors.purple),
                        label: const Text( "Capture Ingredients", style: TextStyle( fontSize: 18, color: Colors.purple, ), ),
                        onPressed: () => _pickImage(ImageSource.camera),
                        style: ElevatedButton.styleFrom( padding: const EdgeInsets.symmetric( horizontal: 30, vertical: 15, ), backgroundColor: Colors.white, shadowColor: Colors.purple.withOpacity(0.5), elevation: 5, shape: RoundedRectangleBorder( borderRadius: BorderRadius.circular(50), side: const BorderSide( color: Colors.purple, width: 2, ), ), ),
                       ),
                      const SizedBox(height: 25), // Increased spacing
                      // Upload Button
                      ElevatedButton.icon( // Using icon button
                        icon: const Icon(Icons.upload_file, color: Colors.purple),
                        label: const Text( "Upload Image", style: TextStyle( fontSize: 18, color: Colors.purple, ), ),
                        onPressed: () => _pickImage(ImageSource.gallery),
                        style: ElevatedButton.styleFrom( padding: const EdgeInsets.symmetric( horizontal: 40, vertical: 15, ), backgroundColor: Colors.white, shadowColor: Colors.purple.withOpacity(0.5), elevation: 5, shape: RoundedRectangleBorder( borderRadius: BorderRadius.circular(50), side: const BorderSide( color: Colors.purple, width: 2, ), ), ),
                       ),
                    ],
                  ),
                ),
              ),
              // --- END Center Column ---
            ],
          ),

          // --- Search Results Overlay (Keep as is, maybe add background blur) ---
          if (_searchResults.isNotEmpty)
            Positioned.fill( // Use Positioned.fill for simplicity
              top: 65, // Adjust top position below search bar
              child: GestureDetector( // Allow tapping outside list to close
                onTap: () {
                  if (mounted) {
                    setState(() {
                      _searchResults.clear();
                    });
                  }
                },
                child: Container(
                  // Semi-transparent background to obscure content below
                  color: Colors.black.withOpacity(0.1),
                  child: Align( // Align the results container
                    alignment: Alignment.topCenter,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 10).copyWith(top: 5), // Margin around results
                      constraints: BoxConstraints(
                         maxHeight: MediaQuery.of(context).size.height * 0.5, // Limit height
                      ),
                      decoration: BoxDecoration(
                         color: Colors.white, // Use a slightly off-white or theme color
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
                        mainAxisSize: MainAxisSize.min, // Shrink wrap column
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
                          // Make the ListView flexible and scrollable within constraints
                          Flexible(
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(vertical: 8.0), // Padding inside list
                              itemCount: _searchResults.length,
                              shrinkWrap: true, // Important with Flexible/Constraints
                              separatorBuilder: (context, index) => const Divider(height: 1, indent: 10, endIndent: 10), // Subtle divider
                              itemBuilder: (context, index) {
                                final product = _searchResults[index];
                                return ListTile( // Use ListTile for better structure/padding
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
                                    // Clear results and navigate
                                     if (mounted) {
                                       setState(() {
                                         // Optional: Fill search bar with selection?
                                         // _searchController.text = "${product['Product_Name']} - ${product['Brand']}";
                                         _searchResults.clear();
                                         // Hide keyboard if open
                                         FocusScope.of(context).unfocus();
                                       });
                                     }
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => SafetyResultScreen(
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
          // --- END Search Results Overlay ---
        ],
      ),
    );
  }
}