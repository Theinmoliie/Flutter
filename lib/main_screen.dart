// lib/main_screen.dart
import 'package:flutter/material.dart';
import 'package:skinsafe/UserProfile/multi_screen.dart';
import 'package:skinsafe/AiSkinAnalysis/analysis_camera_page.dart'; // Import for navigation
import 'package:skinsafe/routine_display_screen.dart';
import 'package:skinsafe/new_home_screen.dart';
import 'package:provider/provider.dart'; // Import Provider
import 'package:skinsafe/providers/skin_profile_provider.dart'; // Import your provider

class MainScreen extends StatefulWidget {
  final bool showSuccessDialog;

  const MainScreen({
    super.key,
    this.showSuccessDialog = false,
  });

  @override
  MainScreenState createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

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
    if (mounted && ScaffoldMessenger.maybeOf(context) != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Account successfully created"),
          duration: Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
  
  // This is the list of main screens accessible from the BottomNavigationBar.
  // The camera page is opened as a separate route and not a main tab.
  late final List<Widget> _screens = [
    NewHomeScreen(
      onSwitchToProfile: () => _onItemTapped(1), // Switch to Profile tab
    ),
    MultiPageSkinProfileScreen(
      onBackPressed: () => _onItemTapped(0), // Go back to Home tab
    ),
    const RoutineDisplayScreen(),
  ];

  void _onItemTapped(int index) {
    // If the "Selfie" icon (index 3) is tapped, open the camera screen.
    if (index == 3) {
      _openSelfieScreen();
    } 
    // Otherwise, if a valid tab is tapped, switch the screen.
    else if (_selectedIndex != index && index < _screens.length) {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  // This function now just opens the camera page.
  // The result is handled within the Profile page flow.
  Future<void> _openSelfieScreen() async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AnalysisCameraPage(
          onAnalysisComplete: (skinTypeResult) {
            // When analysis completes, update the provider and pop back.
            // The Profile page will automatically rebuild with the new data.
            final profileProvider = Provider.of<SkinProfileProvider>(context, listen: false);
            final skinTypeData = profileProvider.getSkinTypeByName(skinTypeResult);
            
            if (skinTypeData != null) {
              profileProvider.updateSkinProfile(
                skinTypeId: skinTypeData['skin_type_id'],
                skinType: skinTypeData['skin_type'],
              );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Skin Type updated to: $skinTypeResult"))
              );
            }
            Navigator.of(context).pop(); // Close the camera page
          },
        ),
      ),
    );
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