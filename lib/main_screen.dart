import 'package:flutter/material.dart';
import 'home.dart';
import 'UserProfile/skin_profile.dart';
import 'AiSkinAnalysis/selfie.dart'; // Import the selfie screen

class MainScreen extends StatefulWidget {
  // Add constructor parameter
  final bool showSuccessDialog;

  const MainScreen({
    Key? key,
    this.showSuccessDialog = false, // Default to false
  }) : super(key: key);

  @override
  MainScreenState createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> {

  @override
  void initState() {
    super.initState();
    // Check the flag after the first frame is built
    if (widget.showSuccessDialog) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
      _showSignUpSuccessSnackbar();
();
      });
    }
  }


  // Method to show the dialog
   void _showSignUpSuccessSnackbar() {
     // Ensure context is still valid and has a Scaffold ancestor
    if (!mounted || !ScaffoldMessenger.maybeOf(context)!.mounted) return;

    // Use ScaffoldMessenger to show a SnackBar
    ScaffoldMessenger.of(context).showSnackBar(
       const SnackBar(
        content: Text("Account successfully created"),
        duration: Duration(seconds: 4), // Adjust duration as needed
        behavior: SnackBarBehavior.floating, // Optional: Makes it float
       ),
    );
   }


  
  int _selectedIndex = 0;

  void _onProfileSaved(Map<String, dynamic> profile) {
    print("Profile saved in MainScreen: $profile");
    _onItemTapped(0); // Switch back to Home tab after saving
  }

  // --- Define _screens using a method or directly in build ---
  // Using a getter is fine if the dependencies don't change often
  List<Widget> get _screens => [
        HomeScreen(
          onSwitchToProfile: () => _onItemTapped(1),
        ),
        SkinProfileScreen(
          onProfileSaved: _onProfileSaved,
          onBackPressed: () => _onItemTapped(0), // <-- PASS THE CALLBACK HERE
        ),
        Container(), // Placeholder for camera screen
      ];
  // --- Or define inside build if needed ---
  /*
  List<Widget> _buildScreens() => [
        HomeScreen(
          onSwitchToProfile: () => _onItemTapped(1),
        ),
        SkinProfileScreen(
          onProfileSaved: _onProfileSaved,
          onBackPressed: () => _onItemTapped(0), // <-- PASS THE CALLBACK HERE
        ),
        Container(), // Placeholder for camera screen
      ];
  */


  void _onItemTapped(int index) {
    if (index == 2) {
      // Handle camera separately - don't change _selectedIndex here
      _openSelfieScreen();
    } else if (_selectedIndex != index) {
      // Only update state if the index is different AND it's not the camera tab
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  Future<void> _openSelfieScreen() async {
     // Keep track of the index *before* opening the camera
    int previousIndex = _selectedIndex;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CameraPage()),
    );

    // --- Optional: Handle returning from camera ---
    // If you want to return to the *previous* tab after closing the camera:
    // setState(() {
    //   _selectedIndex = previousIndex;
    // });
    // Or if you ALWAYS want to return to Home (index 0):
     if (_selectedIndex != 0) {
       setState(() {
         _selectedIndex = 0;
       });
     }

    if (result != null && result is String) { // Check type if you expect a path
      print("Captured image path: $result");
      // You might want to navigate to a results page or update the profile
      // For example, navigate to profile tab after capture:
      // _onItemTapped(1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme; // Get theme colors

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens, // Use the getter
        // children: _buildScreens(), // Or call the method
      ),
      bottomNavigationBar: BottomNavigationBar(
        // --- Adjust currentIndex for Camera ---
        // When camera is pushed, the MainScreen's build method might still run.
        // Ensure the visual indicator doesn't wrongly highlight the camera tab (index 2)
        // while the camera screen is actually displayed via Navigator.push.
        // Show the currently selected tab (0 or 1) as active.
        currentIndex: _selectedIndex < 2 ? _selectedIndex : 0, // Default to Home if index is invalid
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
          BottomNavigationBarItem(icon: Icon(Icons.camera_alt), label: "Selfie"),
        ],
        // Optional: Styling
        backgroundColor: Colors.white, // Or use theme color: colorScheme.surface
        selectedItemColor: colorScheme.primary, // Color for selected icon/label
        unselectedItemColor: Colors.grey[600], // Color for unselected items
        type: BottomNavigationBarType.fixed, // Keep labels visible
        // showUnselectedLabels: true, // Explicitly show unselected labels
      ),
    );
  }
}