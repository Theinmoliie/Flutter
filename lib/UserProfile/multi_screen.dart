// lib/UserProfile/multi_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:skinsafe/providers/skin_profile_provider.dart';
import 'package:skinsafe/AiSkinAnalysis/analysis_camera_page.dart';
import '../UserProfile/skin_sensitivity_edit_page.dart';
import '../UserProfile/skin_concerns_edit_page.dart';

// A simple model for the profile items to make the list cleaner
class ProfileItem {
  final String title;
  final String? value;
  final VoidCallback onEdit;

  ProfileItem({required this.title, this.value, required this.onEdit});
}

class MultiPageSkinProfileScreen extends StatefulWidget {
  final VoidCallback? onBackPressed;

  const MultiPageSkinProfileScreen({
    Key? key,
    this.onBackPressed,
  }) : super(key: key);

  @override
  _MultiPageSkinProfileScreenState createState() =>
      _MultiPageSkinProfileScreenState();
}

class _MultiPageSkinProfileScreenState
    extends State<MultiPageSkinProfileScreen> {
  // --- Navigation Methods for Editing Sections ---

  void _editSkinType() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AnalysisCameraPage(
          onAnalysisComplete: (String skinTypeName) {
            // This callback is triggered from AnalysisCameraPage after a successful analysis.
            // We find the ID and update the provider.
            final profileProvider = Provider.of<SkinProfileProvider>(context, listen: false);
            final skinTypeData = profileProvider.getSkinTypeByName(skinTypeName);
            
            if (skinTypeData != null) {
              profileProvider.updateSkinProfile(
                skinTypeId: skinTypeData['skin_type_id'],
                skinType: skinTypeData['skin_type'],
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Error: Could not match '$skinTypeName' to a known skin type."))
              );
            }
            // Pop the camera page to return to the profile screen.
            Navigator.of(context).pop(); 
          },
        ),
      ),
    );
  }

  void _editSensitivity() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SkinSensitivityEditPage(), // A new, dedicated page
      ),
    );
  }

  void _editConcerns() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SkinConcernsEditPage(), // A new, dedicated page
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    // Use a Consumer to listen for changes in the SkinProfileProvider
    return Consumer<SkinProfileProvider>(
      builder: (context, profileProvider, child) {

        // Build the list of items to display on the profile page
        final List<ProfileItem> profileItems = [
          ProfileItem(
            title: "Username",
            value: "ChilliCrab", // Replace with actual user data if available
            onEdit: () { /* TODO: Implement username edit logic */ 
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Edit username coming soon!")));
            },
          ),
          ProfileItem(
            title: "Email",
            value: "ChilliCrab@gmail.com", // Replace with actual user data
            onEdit: () { /* TODO: Implement email edit logic */
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Edit email coming soon!")));
            },
          ),
          ProfileItem(
            title: "Date Of Birth",
            value: "4/1/2009", // Replace with actual user data
            onEdit: () { /* TODO: Implement DOB edit logic */ 
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Edit date of birth coming soon!")));
            },
          ),
          ProfileItem(
            title: "Skin Type",
            value: profileProvider.userSkinType ?? "Not Set",
            onEdit: _editSkinType,
          ),
          ProfileItem(
            title: "Skin Sensitivity",
            value: profileProvider.userSensitivity ?? "Not Set",
            onEdit: _editSensitivity,
          ),
          ProfileItem(
            title: "Skin Concerns",
            value: profileProvider.userConcerns.isEmpty
                ? "None"
                : profileProvider.userConcerns.join(', '),
            onEdit: _editConcerns,
          ),
        ];

        return Scaffold(
          backgroundColor: const Color(0xFFFAF6FF), // Light lavender background
          appBar: AppBar(
            title: const Text('Profile', style: TextStyle(fontWeight: FontWeight.bold)),
            leading: widget.onBackPressed != null
                ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: widget.onBackPressed)
                : null,
            backgroundColor: colorScheme.primary,
            foregroundColor: Colors.white,
            elevation: 1,
          ),
          body: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
            children: [
              const Center(
                child: CircleAvatar(
                  radius: 50,
                  backgroundImage: AssetImage('assets/avatar.png'),
                  backgroundColor: Colors.white70,
                ),
              ),
              const SizedBox(height: 32),
              ...profileItems.map((item) => _buildProfileItemCard(context, item)).toList(),
            ],
          ),
        );
      },
    );
  }

  // Helper widget to build each item card
  Widget _buildProfileItemCard(BuildContext context, ProfileItem item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        title: Text(
          item.title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Text(
          item.value ?? 'Not Set',
          style: TextStyle(fontSize: 16, color: Colors.grey[700]),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          icon: Icon(Icons.edit, color: Theme.of(context).colorScheme.primary),
          onPressed: item.onEdit,
        ),
      ),
    );
  }
}