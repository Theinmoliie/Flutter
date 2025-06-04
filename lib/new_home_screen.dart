import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home.dart';
import 'searchProducts.dart';
import 'routine_display_screen.dart';


class NewHomeScreen extends StatefulWidget {
  final VoidCallback onSwitchToProfile;

  const NewHomeScreen({super.key, required this.onSwitchToProfile});

  @override
  State<NewHomeScreen> createState() => _NewHomeScreenState();
}

class _NewHomeScreenState extends State<NewHomeScreen> {
  final _supabase = Supabase.instance.client;

  Future<void> _handleLogout() async {
    if (!mounted) return;
    try {
      await _supabase.auth.signOut();
      print("User logged out successfully from NewHomeScreen.");
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  "Logout Failed: ${e is AuthException ? e.message : e.toString()}")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: const Color(0xFFFAF6FF), // Light lavender background
      body: Column(
        children: [
          _buildHeader(context), // Pass context to _buildHeader
          Expanded(
            child: SingleChildScrollView( // Makes the content below scrollable
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 50.0, vertical: 20.0),
              child: Column(
                mainAxisAlignment:
                    MainAxisAlignment.start, // Align cards to the top
                children: [
                  const SizedBox(height: 20),
                  _buildFeatureCard(
                    context,
                    imagePath: 'assets/skincare_product_suitability_logo.png',
                    title: "Check Product Suitability",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SafetyRatingLandingScreen(
                              onSwitchToProfile: widget.onSwitchToProfile),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 25),
                  _buildFeatureCard(
                    context,
                    imagePath: 'assets/skincare_routine_builder_logo.png',
                    title: "View Skincare Routine",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                const RoutineDisplayScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 25),
                  _buildFeatureCard(
                    context,
                    imagePath: 'assets/check_product_safety_rating_logo.png',
                    title: "Check Product Safety Rating",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SafetyRatingLandingScreen(
                             onSwitchToProfile: widget.onSwitchToProfile),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    // Get the colorScheme from the context
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top +
            15, // Status bar padding + custom padding
        bottom: 20,
        left: 20,
        right: 10,
      ),
      decoration: BoxDecoration( // MODIFIED BoxDecoration
        color: colorScheme.primary, // <-- USE THEME'S PRIMARY COLOR HERE
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(25),
          bottomRight: Radius.circular(25),
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: widget.onSwitchToProfile,
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 30,
                    backgroundImage: AssetImage('assets/avatar.png'),
                    backgroundColor: Colors.white24,
                  ),
                  const SizedBox(width: 15),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Hello Molliie!",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          "View Profile",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 20),
                  const SizedBox(width: 40), // Increased space before logout
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            iconSize: 26,
            tooltip: 'Logout',
            onPressed: _handleLogout,
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(
    BuildContext context, {
    required String imagePath,
    required String title,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 15.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 2,
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            Image.asset(
              imagePath,
              height: 130,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 130,
                  color: Colors.grey[200],
                  child: Center(
                      child: Icon(Icons.image_not_supported,
                          size: 50, color: Colors.grey[400])),
                );
              },
            ),
            const SizedBox(height: 15),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
          ],
        ),
      ),
    );
  }
}