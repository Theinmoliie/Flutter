// NewHomeScreen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:skinsafe/providers/skin_profile_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Import the new input screens
import 'ProductAnalysis/ProductSafety/safety_input_screen.dart';
import 'ProductAnalysis/ProductSuitability/suitability_input_screen.dart';
import 'routine_display_screen.dart';

// NEW: Import the spotlight screen.
// Note: Adjust the path if your file is in a different directory.
import 'decade_guide_screen.dart';


class NewHomeScreen extends StatefulWidget {
  final VoidCallback onSwitchToProfile;

  const NewHomeScreen({super.key, required this.onSwitchToProfile});

  @override
  State<NewHomeScreen> createState() => _NewHomeScreenState();
}

class _NewHomeScreenState extends State<NewHomeScreen> {
  final _supabase = Supabase.instance.client;

  Future<void> _handleLogout() async {
    // ... (logout logic is unchanged)
    if (!mounted) return;
    try {
      context.read<SkinProfileProvider>().clearProfile();
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
      backgroundColor: const Color(0xFFFAF6FF),
      body: Column(
        children: [
          Consumer<SkinProfileProvider>(
            builder: (context, profileProvider, child) {
              final username = profileProvider.username ?? 'User';
              return _buildHeader(context, username);
            },
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 40.0, vertical: 20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
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
                            builder: (context) => SuitabilityInputScreen(
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
                            builder: (context) => SafetyInputScreen(
                                onSwitchToProfile: widget.onSwitchToProfile),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 25),

                    // NEW: Add the Ingredient Spotlight feature card
                    _buildFeatureCard(
                      context,
                      imagePath: 'assets/skin compass.png', // Use your new image asset
                      title: "Skincare Compass",
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const DecadeGuideScreen(),
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

  Widget _buildHeader(BuildContext context, String username) {
    // ... (header logic is unchanged)
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 15,
        bottom: 20,
        left: 20,
        right: 10,
      ),
      decoration: BoxDecoration(
        color: colorScheme.primary,
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Hello $username!",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        const Text(
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
                  const SizedBox(width: 10),
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
    // ... (this widget is unchanged)
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              imagePath,
              height: 100,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                print("Error loading asset image $imagePath: $error");
                return Container(
                  height: 100,
                  color: Colors.grey[200],
                  child: Center(
                      child: Icon(Icons.broken_image_outlined,
                          size: 40, color: Colors.grey[400])),
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