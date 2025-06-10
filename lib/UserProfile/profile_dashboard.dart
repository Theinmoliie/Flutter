// lib/UserProfile/multi_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:skinsafe/providers/skin_profile_provider.dart';
import 'package:skinsafe/AiSkinAnalysis/analysis_camera_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../UserProfile/skin_sensitivity_edit_page.dart';
import '../UserProfile/skin_concerns_edit_page.dart';
import 'generic_profile_field_edit_page.dart';

// ProfileItem model class
class ProfileItem {
  final String title;
  final String? value;
  final VoidCallback onEdit;
  final bool isEditable;

  ProfileItem({
    required this.title,
    this.value,
    required this.onEdit,
    this.isEditable = true,
  });
}

// Main Profile Dashboard Widget
class ProfileDashboard extends StatefulWidget {
  final VoidCallback? onBackPressed;

  const ProfileDashboard({
    Key? key,
    this.onBackPressed,
  }) : super(key: key);

  @override
  _ProfileDashboardState createState() =>
      _ProfileDashboardState();
}

class _ProfileDashboardState
    extends State<ProfileDashboard> {
  
  // --- Navigation Methods ---

  void _editGenericField(EditableProfileField field) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GenericProfileFieldEditPage(fieldToEdit: field),
      ),
    );
  }

  // THIS METHOD CONTAINS THE SKIN TYPE SAVING LOGIC
  void _editSkinType() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AnalysisCameraPage(
          // The onAnalysisComplete callback is where the saving happens.
          // It's marked 'async' to allow for awaiting the database call.
          onAnalysisComplete: (String skinTypeName) async {
            final profileProvider = Provider.of<SkinProfileProvider>(context, listen: false);
            final skinTypeData = profileProvider.getSkinTypeByName(skinTypeName);
            
            if (skinTypeData != null) {
              final skinTypeId = skinTypeData['skin_type_id'];
              final skinType = skinTypeData['skin_type'];
              final userId = Supabase.instance.client.auth.currentUser!.id;

              try {
                // UPDATE the 'profiles' table in Supabase with the new skin_type_id.
                await Supabase.instance.client
                    .from('profiles')
                    .update({'skin_type_id': skinTypeId})
                    .eq('id', userId);

                // If the database save succeeds, update the local provider state.
                if (mounted) {
                  profileProvider.updateUserProfile(
                    skinTypeId: skinTypeId,
                    skinType: skinType,
                  );
                   ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Skin type updated to: $skinType"))
                  );
                }

              } catch (e) {
                 // Handle any errors during the database save.
                 if (mounted) {
                   ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error saving skin type: $e"))
                  );
                }
              }
            } else {
               // Handle the case where the analysis result doesn't match a known type.
               if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Error: Could not match skin type."))
                );
              }
            }
            // Finally, close the camera page to return the user to the profile.
            if (mounted) {
              Navigator.of(context).pop();
            }
          },
        ),
      ),
    );
  }

  void _editSensitivity() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SkinSensitivityEditPage()),
    );
  }

  void _editConcerns() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SkinConcernsEditPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Consumer<SkinProfileProvider>(
      builder: (context, profileProvider, child) {
        // Show a loading spinner while the provider is fetching initial data.
        if (profileProvider.isLoading) {
          return Scaffold(
            appBar: AppBar(title: const Text('Profile'), backgroundColor: colorScheme.primary, foregroundColor: Colors.white),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        // Build the list of items from the provider's data.
        final List<ProfileItem> profileItems = [
          ProfileItem(
            title: "Username",
            value: profileProvider.username,
            onEdit: () => _editGenericField(EditableProfileField.username),
          ),
          ProfileItem(
            title: "Date Of Birth",
            value: profileProvider.dateOfBirth == null 
                   ? "Not Set" 
                   : DateFormat.yMMMMd().format(profileProvider.dateOfBirth!),
            onEdit: () => _editGenericField(EditableProfileField.dateOfBirth),
          ),
          ProfileItem(
            title: "Skin Type",
            value: profileProvider.userSkinType,
            onEdit: _editSkinType,
          ),
          ProfileItem(
            title: "Skin Sensitivity",
            value: profileProvider.userSensitivity,
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
          backgroundColor: const Color(0xFFFAF6FF),
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
              const Center(child: CircleAvatar(radius: 50, backgroundImage: AssetImage('assets/avatar.png'))),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  Supabase.instance.client.auth.currentUser?.email ?? 'Anonymous',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600], fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(height: 24),
              ...profileItems.map((item) => _buildProfileItemCard(context, item)).toList(),
            ],
          ),
        );
      },
    );
  }

  // Helper widget to build each item card.
  Widget _buildProfileItemCard(BuildContext context, ProfileItem item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Text(item.value ?? 'Not Set', style: TextStyle(fontSize: 16, color: Colors.grey[700]), maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: item.isEditable 
          ? IconButton(icon: Icon(Icons.edit, color: Theme.of(context).colorScheme.primary), onPressed: item.onEdit)
          : null,
      ),
    );
  }
}