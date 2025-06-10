// lib/UserProfile/skin_concerns_edit_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:skinsafe/providers/skin_profile_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // 1. Import Supabase

class SkinConcernsEditPage extends StatefulWidget {
  const SkinConcernsEditPage({super.key});

  @override
  _SkinConcernsEditPageState createState() => _SkinConcernsEditPageState();
}

class _SkinConcernsEditPageState extends State<SkinConcernsEditPage> {
  final Set<int> _selectedConcernIds = {};
  bool _isNoneSelected = false;
  final int _maxConcerns = 3;
  bool _isLoading = false; // Add loading state

  @override
  void initState() {
    super.initState();
    final profileProvider = Provider.of<SkinProfileProvider>(context, listen: false);
    _selectedConcernIds.addAll(profileProvider.userConcernIds);
    _isNoneSelected = profileProvider.userConcerns.isEmpty;
  }
  
  // 2. Make the save method async
  Future<void> _saveConcerns() async {
    setState(() => _isLoading = true);
    final profileProvider = Provider.of<SkinProfileProvider>(context, listen: false);
    final userId = Supabase.instance.client.auth.currentUser!.id;
    
    final List<int> concernIdsToSave = _isNoneSelected ? [] : _selectedConcernIds.toList();
    final List<String> concernsToSave = _isNoneSelected 
        ? [] 
        : profileProvider.allSkinConcerns
            .where((c) => concernIdsToSave.contains(c['concern_id']))
            .map((c) => c['concern'] as String).toList();
            
    try {
      // 3. UPDATE the 'profiles' table in Supabase
      // Assuming your column is named 'skin_concerns_id' and is of type integer[]
      await Supabase.instance.client
          .from('profiles')
          .update({'skin_concerns_id': concernIdsToSave})
          .eq('id', userId);

      if (mounted) {
        // 4. Update the local provider AFTER successful save
        profileProvider.updateUserProfile(
          concerns: concernsToSave,
          concernIds: concernIdsToSave,
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving concerns: $e')),
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

    return Consumer<SkinProfileProvider>(
      builder: (context, profileProvider, child) {
        final allConcerns = profileProvider.allSkinConcerns;
        final bool canSelectMore = _selectedConcernIds.length < _maxConcerns;

        return Scaffold(
          appBar: AppBar(title: const Text('Edit Skin Concerns'),backgroundColor: colorScheme.primary, 
            foregroundColor: colorScheme.onPrimary,),
          body: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(24.0),
                  children: [
                    const Text('Update your specific skin concerns', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text('Select up to $_maxConcerns, or choose \'None\'.', style: TextStyle(fontSize: 15, color: Colors.grey[700])),
                    const SizedBox(height: 24),
                    CheckboxListTile(
                      title: const Text('None', style: TextStyle(fontStyle: FontStyle.italic)),
                      value: _isNoneSelected,
                      onChanged: (value) {
                        setState(() {
                          _isNoneSelected = value ?? false;
                          if (_isNoneSelected) _selectedConcernIds.clear();
                        });
                      },
                    ),
                    ...allConcerns.map((concern) {
                      final int concernId = concern['concern_id'];
                      final bool isSelected = _selectedConcernIds.contains(concernId);
                      final bool isDisabled = _isNoneSelected || (!isSelected && !canSelectMore);

                      return CheckboxListTile(
                        title: Text(concern['concern'] ?? 'Unknown', style: TextStyle(color: isDisabled && !isSelected ? Colors.grey : null)),
                        value: isSelected && !_isNoneSelected,
                        onChanged: isDisabled ? null : (bool? value) {
                          setState(() {
                            if (value == true) {
                              _selectedConcernIds.add(concernId);
                            } else {
                              _selectedConcernIds.remove(concernId);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveConcerns, // Use loading state
                  child: Text(_isLoading ? 'Saving...' : 'Save'),
                  style: ElevatedButton.styleFrom(backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,minimumSize: const Size(double.infinity, 50)),
                ),
              )
            ],
          ),
        );
      },
    );
  }
}