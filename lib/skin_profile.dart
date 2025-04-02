import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/skin_profile_provider.dart';

final supabase = Supabase.instance.client;

class SkinProfileScreen extends StatefulWidget {
  final Function(Map<String, dynamic>)? onProfileSaved;

  const SkinProfileScreen({Key? key, this.onProfileSaved}) : super(key: key);

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
      _isLoadingSkinTypes = false;
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
      _isLoadingConcerns = false;
    }
  }

  void _saveProfile() {
    if (_selectedSkinTypeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your skin type')),
      );
      return;
    }

    String selectedSkinType = _skinTypes.firstWhere(
        (type) => type['skin_type_id'] == _selectedSkinTypeId)['skin_type'];

    List<String> selectedConcerns = _skinConcerns
        .where((concern) => _selectedConcernIds.contains(concern['concern_id']))
        .map((concern) => concern['concern'] as String)
        .toList();

    // Pass skin_type_id and concern_ids to provider
    Provider.of<SkinProfileProvider>(context, listen: false)
        .updateSkinProfile(selectedSkinType, _selectedSkinTypeId!, selectedConcerns, _selectedConcernIds.toList());

    if (widget.onProfileSaved != null) {
      widget.onProfileSaved!({
        'skinType': selectedSkinType,
        'skinTypeId': _selectedSkinTypeId,
        'concerns': selectedConcerns,
        'concernIds': _selectedConcernIds.toList(),
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile successfully saved!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Skin Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _isLoadingSkinTypes
                ? const CircularProgressIndicator()
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
            _isLoadingConcerns
                ? const CircularProgressIndicator()
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
            ElevatedButton(
              onPressed: _saveProfile,
              child: const Text('Save Profile'),
            ),
          ],
        ),
      ),
    );
  }
}
