import 'package:flutter/material.dart';
import 'home.dart';
import 'skin_profile.dart';

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
          onSwitchToProfile: () => _onItemTapped(1), // Pass callback to switch tabs
        ),
        SkinProfileScreen(
          onProfileSaved: _onProfileSaved,
        ),
      ];

  void _onItemTapped(int index) {
  if (_selectedIndex != index) {  // Only update if tab actually changed
    setState(() {
      _selectedIndex = index;
    });
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
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Skin Profile"),
        ],
      ),
    );
  }
}