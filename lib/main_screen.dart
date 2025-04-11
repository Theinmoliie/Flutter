import 'package:flutter/material.dart';
import 'home.dart';
import 'skin_profile.dart';
import 'camera.dart'; // Import the selfie screen

class MainScreen extends StatefulWidget {
  @override
  MainScreenState createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  // This handles both saving profile and switching tabs
  void _onProfileSaved(Map<String, dynamic> profile) {
    print("Profile saved: $profile");
    _onItemTapped(0); // Switch back to Home tab after saving
  }

  List<Widget> get _screens => [
        HomeScreen(
          onSwitchToProfile: () => _onItemTapped(1),
        ),
        SkinProfileScreen(
          onProfileSaved: _onProfileSaved,
        ),
        Container(), // Placeholder for selfie screen (we'll handle it differently)
      ];

  void _onItemTapped(int index) {
    if (index == 2) {
      // Handle the camera tab separately
      _openSelfieScreen();
    } else if (_selectedIndex != index) {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  Future<void> _openSelfieScreen() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CameraPage()),
    );
    
    // Handle the returned image path if needed
    if (result != null) {
      // You can pass this to your skin profile or other screens
      print("Captured image path: $result");
    }
  }

  @override
  Widget build(BuildContext context) {
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
          BottomNavigationBarItem(icon: Icon(Icons.camera_alt), label: "Selfie"),
        ],
      ),
    );
  }
}