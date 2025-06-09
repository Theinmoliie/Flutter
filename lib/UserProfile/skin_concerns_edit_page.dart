import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:skinsafe/providers/skin_profile_provider.dart';

class SkinConcernsEditPage extends StatefulWidget {
  const SkinConcernsEditPage({super.key});

  @override
  _SkinConcernsEditPageState createState() => _SkinConcernsEditPageState();
}

class _SkinConcernsEditPageState extends State<SkinConcernsEditPage> {
  final Set<int> _selectedConcernIds = {};
  bool _isNoneSelected = false;
  final int _maxConcerns = 3;

  @override
  void initState() {
    super.initState();
    // Load current values from provider when the page opens
    final profileProvider = Provider.of<SkinProfileProvider>(context, listen: false);
    _selectedConcernIds.addAll(profileProvider.userConcernIds);
    _isNoneSelected = profileProvider.userConcerns.isEmpty;
  }
  
  void _saveConcerns() {
    final profileProvider = Provider.of<SkinProfileProvider>(context, listen: false);
    
    // Determine which concern IDs and names to save based on user selection
    final List<int> concernIdsToSave = _isNoneSelected ? [] : _selectedConcernIds.toList();
    final List<String> concernsToSave = _isNoneSelected 
        ? [] 
        : profileProvider.allSkinConcerns
            .where((c) => concernIdsToSave.contains(c['concern_id']))
            .map((c) => c['concern'] as String).toList();
            
    // Update the provider
    profileProvider.updateUserProfile(concerns: concernsToSave, concernIds: concernIdsToSave);
    // Go back to the profile page
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Use a Consumer to get the list of all available concerns from the provider
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
                    const Text(
                      'Update your specific skin concerns',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Select up to $_maxConcerns, or choose \'None\'.',
                      style: TextStyle(fontSize: 15, color: Colors.grey[700]),
                    ),
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
                        title: Text(
                          concern['concern'] ?? 'Unknown',
                          style: TextStyle(color: isDisabled && !isSelected ? Colors.grey : null)
                        ),
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
                  onPressed: _saveConcerns,
                  child: const Text('Save'),
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