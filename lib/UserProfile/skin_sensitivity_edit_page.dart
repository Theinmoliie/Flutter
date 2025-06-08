import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:skinsafe/providers/skin_profile_provider.dart';

class SkinSensitivityEditPage extends StatefulWidget {
  const SkinSensitivityEditPage({super.key});

  @override
  _SkinSensitivityEditPageState createState() => _SkinSensitivityEditPageState();
}

class _SkinSensitivityEditPageState extends State<SkinSensitivityEditPage> {
  String? _selectedSensitivity;
  final List<String> _sensitivityOptions = const ['Yes', 'No'];

  @override
  void initState() {
    super.initState();
    // Load the current value from the provider when the page opens
    _selectedSensitivity = Provider.of<SkinProfileProvider>(context, listen: false).userSensitivity;
  }

  void _saveSensitivity() {
    if (_selectedSensitivity == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please make a selection.')));
      return;
    }
    // Update the provider with the new value
    Provider.of<SkinProfileProvider>(context, listen: false).updateSkinProfile(sensitivity: _selectedSensitivity);
    // Go back to the profile page
    Navigator.of(context).pop();
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
              onPressed: _saveSensitivity,
              style: ElevatedButton.styleFrom(backgroundColor: colorScheme.primary,
                                              foregroundColor: colorScheme.onPrimary,minimumSize: const Size(double.infinity, 50)),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}