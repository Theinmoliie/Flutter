// main_screen.dart
import 'package:flutter/material.dart';
import 'package:skinsafe/searchProducts.dart';
// ... other imports
import 'home.dart'; // Your original HomeScreen
import 'UserProfile/multi_screen.dart';
import 'AiSkinAnalysis/selfie.dart';
import 'routine_display_screen.dart';
import 'new_home_screen.dart'; // <-- IMPORT THE NEW HOME SCREEN

class MainScreen extends StatefulWidget {
  final bool showSuccessDialog;

  const MainScreen({
    super.key, // Use super.key
    this.showSuccessDialog = false,
  });

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

  int _selectedIndex = 0;

  void _onProfileSaved(Map<String, dynamic> profile) {
    print("Profile saved in MainScreen: $profile");
    _onItemTapped(0); // Switch back to Home tab (NewHomeScreen)
  }

  // MODIFIED: _screens list
  List<Widget> get _screens => [
        NewHomeScreen( // <-- USE NewHomeScreen HERE
          onSwitchToProfile: () => _onItemTapped(1), // Profile is at index 1
        ),
        
        MultiPageSkinProfileScreen(
          onProfileSaved: _onProfileSaved,
          onBackPressed: () => _onItemTapped(0), // Home is at index 0
        ),
        const RoutineDisplayScreen(), // Routine Screen is at index 2
        // CameraPage is handled by _openSelfieScreen, not directly in IndexedStack here

        
      ];

  void _onItemTapped(int index) {
    if (index == 3) { // If the "Selfie" icon (visually 4th item, index 3) is tapped
      _openSelfieScreen();
    } else if (_selectedIndex != index && index < _screens.length) {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  Future<void> _openSelfieScreen() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CameraPage()), // Ensure CameraPage is const if possible
    );

    // After returning from camera, you might want to default to a specific tab.
    // Current logic defaults to Home if camera wasn't opened from Home.
    // Or ensure _selectedIndex reflects the tab "underneath" the camera session.
    // For simplicity, if camera is a distinct action, perhaps always reset to home or previous tab.
    // For now, let's assume if camera was opened, _selectedIndex might not change,
    // or if it does, it should reflect the tab to return to.
    // The current logic already handles returning to _selectedIndex, or Home if it changed.
    // If camera was opened while on Profile, it should stay on Profile (or _selectedIndex).
    // The logic here sets _selectedIndex to 0 if it wasn't already.
    // This means after camera, it always goes to Home tab.
    // If you want to return to the tab from which camera was opened, you'd store `_selectedIndex` before push
    // and restore it, or simply don't change `_selectedIndex` when `_openSelfieScreen` is called
    // if the camera itself is not a "tab".

    // Let's refine this: if camera is not a persistent tab, `_selectedIndex` should not change
    // due to opening camera, unless explicitly desired.
    // The current `_onItemTapped` handles index 3 specifically to open camera.
    // `_selectedIndex` will remain what it was.
    // So, no need to change _selectedIndex here after camera closes, unless you want specific behavior.

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
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
          BottomNavigationBarItem(icon: Icon(Icons.list_alt_outlined), label: "Routine"),
          BottomNavigationBarItem(icon: Icon(Icons.camera_alt), label: "Selfie"),
        ],
        backgroundColor: Colors.white,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: Colors.grey[600],
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}