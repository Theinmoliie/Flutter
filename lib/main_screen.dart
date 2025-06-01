import 'package:flutter/material.dart';
import 'home.dart';
import 'UserProfile/multi_screen.dart';
import 'AiSkinAnalysis/selfie.dart'; // Import the selfie screen
import 'routine_display_screen.dart'; // <-- IMPORT THE ROUTINE DISPLAY SCREEN

class MainScreen extends StatefulWidget {
  final bool showSuccessDialog;

  const MainScreen({
    Key? key,
    this.showSuccessDialog = false,
  }) : super(key: key);

  @override
  MainScreenState createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.showSuccessDialog) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showSignUpSuccessSnackbar();
      });
    }
  }

  void _showSignUpSuccessSnackbar() {
    if (!mounted || !ScaffoldMessenger.maybeOf(context)!.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Account successfully created"),
        duration: Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  int _selectedIndex = 0; // Default to Home

  void _onProfileSaved(Map<String, dynamic> profile) {
    print("Profile saved in MainScreen: $profile");
    // Optional: Navigate to the Routine tab after saving profile
    // _onItemTapped(2); // Assuming Routine is now at index 2
    // Or stay on profile or go to home
    _onItemTapped(0); // Switch back to Home tab
  }

  List<Widget> get _screens => [
        HomeScreen(
          onSwitchToProfile: () => _onItemTapped(1), // Profile is at index 1
        ),
        MultiPageSkinProfileScreen(
          onProfileSaved: _onProfileSaved,
          onBackPressed: () => _onItemTapped(0), // Home is at index 0
        ),
        const RoutineDisplayScreen(), // <-- ADDED: Routine Screen is at index 2
        // Placeholder for camera - camera is handled by _openSelfieScreen
        // If you add the camera as a permanent tab, it would go here,
        // but your current logic pushes it as a separate route.
      ];

  void _onItemTapped(int index) {
    // --- ADJUST INDEX FOR CAMERA ---
    // Your camera is currently the 3rd *visual* item in BottomNavBar (index 2 if 0-indexed)
    // But it's not part of the `_screens` that `IndexedStack` manages directly.
    // Let's assume the new layout is: Home (0), Profile (1), Routine (2), Selfie (3rd visual item)

    if (index == 3) { // If the "Selfie" icon (now visually the 4th item, index 3) is tapped
      _openSelfieScreen();
    } else if (_selectedIndex != index && index < _screens.length) {
      // Only update state if the index is different AND it's a valid screen index
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  Future<void> _openSelfieScreen() async {
    // int previousIndex = _selectedIndex; // Keep track if needed

    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CameraPage()),
    );

    // After returning from camera, you might want to default to a specific tab
    // For example, always go back to Home or the previously selected tab
    if (_selectedIndex != 0) { // Example: always go back to Home if not already there
      // This ensures if camera was opened from Profile or Routine, it returns to Home
      // Or, you could use 'previousIndex' to go back to where they were.
      // For simplicity, let's default to Home to avoid confusion with the selectedIndex
      // if the camera isn't a "permanent" tab in the IndexedStack.
      setState(() {
         _selectedIndex = 0; // Or `_selectedIndex = previousIndex;`
      });
    }


    if (result != null && result is String) {
      print("Captured image path: $result");
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        // Adjust currentIndex logic
        // If camera (index 3 visually) was "selected", visually show the _selectedIndex
        // which would be the tab underneath the camera overlay.
        // Since camera is a pushed route, _selectedIndex should reflect the active tab in _screens.
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"), // Index 0
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"), // Index 1
          BottomNavigationBarItem(icon: Icon(Icons.list_alt_outlined), label: "Routine"), // Index 2 <-- NEW
          BottomNavigationBarItem(icon: Icon(Icons.camera_alt), label: "Selfie"), // Index 3 (visual, handled by _openSelfieScreen)
        ],
        backgroundColor: Colors.white,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: Colors.grey[600],
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}