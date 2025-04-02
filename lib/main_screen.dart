import 'package:flutter/material.dart';
import 'home.dart';
import 'skin_profile.dart';

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  void _onProfileSaved(Map<String, dynamic> profile) {
    print("Profile saved: $profile");
  }

  List<Widget> get _screens => [
        HomeScreen(),
        SkinProfileScreen(onProfileSaved: _onProfileSaved),
      ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
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
