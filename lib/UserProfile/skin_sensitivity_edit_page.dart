// lib/UserProfile/skin_sensitivity_edit_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:skinsafe/providers/skin_profile_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // 1. Import Supabase

class SkinSensitivityEditPage extends StatefulWidget {
  const SkinSensitivityEditPage({super.key});

  @override
  _SkinSensitivityEditPageState createState() => _SkinSensitivityEditPageState();
}

class _SkinSensitivityEditPageState extends State<SkinSensitivityEditPage> {
  String? _selectedSensitivity;
  final List<String> _sensitivityOptions = const ['Yes', 'No'];
  bool _isLoading = false; // Add a loading state for the button

  @override
  void initState() {
    super.initState();
    // Load the current value from the provider when the page opens
    _selectedSensitivity = Provider.of<SkinProfileProvider>(context, listen: false).userSensitivity;
  }

  // 2. Make the save method async to handle the database call
  Future<void> _saveSensitivity() async {
    if (_selectedSensitivity == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please make a selection.')));
      return;
    }
    
    setState(() => _isLoading = true);
    final userId = Supabase.instance.client.auth.currentUser!.id;

    try {
      // 3. UPDATE the 'profiles' table in Supabase
      // Assuming your column is of type 'text' or 'varchar'
      await Supabase.instance.client
          .from('profiles')
          .update({'skin_sensitivity': _selectedSensitivity})
          .eq('id', userId);

      if (mounted) {
        // 4. Update the local provider AFTER the database save is successful
        Provider.of<SkinProfileProvider>(context, listen: false)
            .updateUserProfile(sensitivity: _selectedSensitivity);
        
        // Go back to the profile page
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving sensitivity: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Skin Sensitivity'),backgroundColor: colorScheme.primary, 
        foregroundColor: colorScheme.onPrimary,),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Do you consider your skin to be sensitive?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Consider how easily your skin reacts to new products or environmental factors.',
              style: TextStyle(fontSize: 15, color: Colors.grey[700]),
            ),
            const SizedBox(height: 24),
            ..._sensitivityOptions.map((level) => RadioListTile<String?>(
              title: Text(level),
              value: level,
              groupValue: _selectedSensitivity,
              onChanged: (value) => setState(() => _selectedSensitivity = value),
            )),
            const Spacer(),
            ElevatedButton(
              onPressed: _isLoading ? null : _saveSensitivity, // Use the loading state
              style: ElevatedButton.styleFrom(backgroundColor: colorScheme.primary,
                                              foregroundColor: colorScheme.onPrimary,minimumSize: const Size(double.infinity, 50)),
              child: Text(_isLoading ? 'Saving...' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }
}