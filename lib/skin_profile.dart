import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/skin_profile_provider.dart';

final supabase = Supabase.instance.client;

class SkinProfileScreen extends StatefulWidget {
  final Function(Map<String, dynamic>)? onProfileSaved;

  const SkinProfileScreen({
    Key? key, 
    required this.onProfileSaved,
  }) : super(key: key);

  @override
  _SkinProfileScreenState createState() => _SkinProfileScreenState();
}

class _SkinProfileScreenState extends State<SkinProfileScreen> {
  int? _selectedSkinTypeId;
  final Set<int> _selectedConcernIds = {};
  bool _isLoadingSkinTypes = true;
  bool _isLoadingConcerns = true;
  List<Map<String, dynamic>> _skinTypes = [];
  List<Map<String, dynamic>> _skinConcerns = [];

  @override
  void initState() {
    super.initState();
    _fetchSkinTypes();
    _fetchSkinConcerns();
    _loadSavedProfile();
  }

  Future<void> _loadSavedProfile() async {
    final profileProvider = Provider.of<SkinProfileProvider>(context, listen: false);
    if (profileProvider.userSkinTypeId != null) {
      setState(() {
        _selectedSkinTypeId = profileProvider.userSkinTypeId;
        _selectedConcernIds.addAll(profileProvider.userConcernIds);
      });
    }
  }

  Future<void> _fetchSkinTypes() async {
    try {
      final response = await supabase
          .from('Skin Types')
          .select('skin_type_id, skin_type')
          .order('skin_type_id');

      setState(() {
        _skinTypes = List<Map<String, dynamic>>.from(response);
        _isLoadingSkinTypes = false;
      });
    } catch (e) {
      setState(() => _isLoadingSkinTypes = false);
    }
  }

  Future<void> _fetchSkinConcerns() async {
    try {
      final response = await supabase
          .from('Skin Concerns')
          .select('concern_id, concern')
          .order('concern_id');

      setState(() {
        _skinConcerns = List<Map<String, dynamic>>.from(response);
        _isLoadingConcerns = false;
      });
    } catch (e) {
      setState(() => _isLoadingConcerns = false);
    }
  }

  void _clearSelections() {
      setState(() {
        _selectedSkinTypeId = null;
        _selectedConcernIds.clear();
      });
    }

  void _saveProfile() {
    if (_selectedSkinTypeId == null || _selectedConcernIds.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Selection Required'),
          content: const Text('Please select at least one option.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final selectedSkinType = _skinTypes.firstWhere(
      (type) => type['skin_type_id'] == _selectedSkinTypeId,
    )['skin_type'];

    final selectedConcerns = _skinConcerns
        .where((concern) => _selectedConcernIds.contains(concern['concern_id']))
        .map((concern) => concern['concern'] as String)
        .toList();

    // Update provider with both names and IDs
    Provider.of<SkinProfileProvider>(context, listen: false).updateSkinProfile(
      selectedSkinType,
      _selectedSkinTypeId!,
      selectedConcerns,
      _selectedConcernIds.toList(),
    );

    // Notify parent about saved profile
    widget.onProfileSaved?.call({
      'skinType': selectedSkinType,
      'skinTypeId': _selectedSkinTypeId,
      'concerns': selectedConcerns,
      'concernIds': _selectedConcernIds.toList(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile successfully saved!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Skin Profile'),
        automaticallyImplyLeading: false, // Remove back button
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Your Skin Type',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _isLoadingSkinTypes
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: _skinTypes.map((type) {
                      return RadioListTile<int>(
                        title: Text(type['skin_type']),
                        value: type['skin_type_id'],
                        groupValue: _selectedSkinTypeId,
                        onChanged: (value) {
                          setState(() {
                            _selectedSkinTypeId = value;
                          });
                        },
                      );
                    }).toList(),
                  ),
            const SizedBox(height: 24),
            const Text(
              'Select Your Skin Concerns',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _isLoadingConcerns
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: _skinConcerns.map((concern) {
                      return CheckboxListTile(
                        title: Text(concern['concern']),
                        value: _selectedConcernIds.contains(concern['concern_id']),
                        onChanged: (bool? value) {
                          setState(() {
                            if (value == true) {
                              _selectedConcernIds.add(concern['concern_id']);
                            } else {
                              _selectedConcernIds.remove(concern['concern_id']);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
            const SizedBox(height: 32),
               Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _clearSelections,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                    backgroundColor: Colors.grey,
                  ),
                  
                  child: const Text(
                    'Clear',
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 20),
                
                ElevatedButton(
                onPressed: _saveProfile,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  backgroundColor: const Color.fromARGB(255, 170, 136, 176),
                ),
                child: const Text(
                  'Save Profile',
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}