// skin_profile.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/skin_profile_provider.dart'; // Make sure this path is correct

final supabase = Supabase.instance.client;

class SkinProfileScreen extends StatefulWidget {
  final Function(Map<String, dynamic>)? onProfileSaved;
  final VoidCallback? onBackPressed;

  const SkinProfileScreen({
    Key? key,
    this.onProfileSaved,
    this.onBackPressed,
  }) : super(key: key);

  @override
  _SkinProfileScreenState createState() => _SkinProfileScreenState();
}

class _SkinProfileScreenState extends State<SkinProfileScreen> {
  // Existing state
  int? _selectedSkinTypeId;
  final Set<int> _selectedConcernIds = {}; // Stores REAL concern IDs (not 0)
  bool _isLoadingSkinTypes = true;
  bool _isLoadingConcerns = true;
  List<Map<String, dynamic>> _skinTypes = [];
  List<Map<String, dynamic>> _skinConcerns = []; // Fetched concerns from DB

  // --- NEW: State for 'None' concern ---
  bool _isNoneConcernSelected = false;
  // --- END NEW ---

  String? _selectedSensitivityLevel;
  final List<String> _sensitivityOptions = const ['Low', 'Medium', 'High'];

  @override
  void initState() {
    super.initState();
    _fetchSkinTypes();
    _fetchSkinConcerns();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadSavedProfile();
      }
    });
  }

  Future<void> _loadSavedProfile() async {
    if (!mounted) return;
    final profileProvider = Provider.of<SkinProfileProvider>(context, listen: false);

    if (profileProvider.userSkinTypeId != null ||
        profileProvider.userConcernIds.isNotEmpty || // Check if provider has concerns
        profileProvider.userSensitivityLevel != null) {
      if (mounted) {
        setState(() {
          _selectedSkinTypeId = profileProvider.userSkinTypeId;
          _selectedConcernIds.clear();
          _selectedConcernIds.addAll(profileProvider.userConcernIds);
          _selectedSensitivityLevel = profileProvider.userSensitivityLevel;

          // --- MODIFIED: Determine if 'None' should be initially checked ---
          // If the loaded profile has NO specific concerns, mark 'None' as selected.
          // Important: Only do this if the profile has actually been saved before
          // (we infer this if skin type or sensitivity is set).
          // Otherwise, a new user would default to 'None' checked.
          if (profileProvider.userConcernIds.isEmpty &&
              (profileProvider.userSkinTypeId != null || profileProvider.userSensitivityLevel != null)) {
             _isNoneConcernSelected = true;
          } else {
            _isNoneConcernSelected = false; // Make sure it's false if concerns exist
          }
          // --- END MODIFIED ---

          if (_selectedSensitivityLevel != null && !_sensitivityOptions.contains(_selectedSensitivityLevel)) {
              _selectedSensitivityLevel = null;
          }
        });
      }
    } else {
       // If nothing is loaded, ensure 'None' is not selected by default
       if (mounted) {
         setState(() {
           _isNoneConcernSelected = false;
         });
       }
    }
  }

  Future<void> _fetchSkinTypes() async {
    // ... (keep existing fetch logic) ...
     if (!mounted) return;
    setState(() => _isLoadingSkinTypes = true);
    try {
      final response = await supabase
          .from('Skin Types')
          .select('skin_type_id, skin_type')
          .order('skin_type_id');

      if (mounted) {
        setState(() {
          _skinTypes = List<Map<String, dynamic>>.from(response);
          _isLoadingSkinTypes = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingSkinTypes = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching skin types: ${e.toString()}'))
        );
      }
    }
  }

  Future<void> _fetchSkinConcerns() async {
     // ... (keep existing fetch logic) ...
     if (!mounted) return;
    setState(() => _isLoadingConcerns = true);
    try {
      final response = await supabase
          .from('Skin Concerns')
          .select('concern_id, concern')
          .order('concern_id'); // You might want to order by 'concern' name alphabetically

      if (mounted) {
        setState(() {
          _skinConcerns = List<Map<String, dynamic>>.from(response);
          _isLoadingConcerns = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingConcerns = false);
         ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching skin concerns: ${e.toString()}'))
        );
      }
    }
  }

    void _clearSelections() {
    if (!mounted) return;
      setState(() {
        _selectedSkinTypeId = null;
        _selectedConcernIds.clear();
        _selectedSensitivityLevel = null;
        _isNoneConcernSelected = false; // Also clear 'None' selection
      });
      Provider.of<SkinProfileProvider>(context, listen: false).clearProfile();
      ScaffoldMessenger.of(context).showSnackBar(
       const SnackBar(content: Text('Selections cleared')),
      );
    }

    void _saveProfile() {
     if (!mounted) return;

    // --- UPDATED VALIDATION LOGIC ---
    if (_selectedSkinTypeId == null) {
      _showValidationErrorDialog('Please select your skin type.');
      return;
    }
    if (_selectedSensitivityLevel == null) {
       _showValidationErrorDialog('Please select your sensitivity level.');
       return;
    }

    // --- MODIFIED: Concern Validation ---
    // Must select either 'None' OR at least one specific concern
    if (!_isNoneConcernSelected && _selectedConcernIds.isEmpty) {
      _showValidationErrorDialog('Please select at least one skin concern, or select \'None\'.');
      return;
    }
    // --- END MODIFIED ---

    // Handle potential null skin type safely (no changes needed here)
    final selectedSkinTypeData = _selectedSkinTypeId == null
        ? null
        : _skinTypes.firstWhere(
            (type) => type['skin_type_id'] == _selectedSkinTypeId,
            orElse: () => {'skin_type': null},
          );
    final selectedSkinTypeName = selectedSkinTypeData?['skin_type'] as String?;

    // --- MODIFIED: Prepare concern data for provider ---
    // If 'None' is selected, send an empty list of concerns/IDs.
    // Otherwise, send the selected ones.
    final List<String> concernsToSave;
    final List<int> concernIdsToSave;

    if (_isNoneConcernSelected) {
        concernsToSave = []; // Empty list for 'None'
        concernIdsToSave = []; // Empty list for 'None'
    } else {
        concernsToSave = _skinConcerns
            .where((concern) => _selectedConcernIds.contains(concern['concern_id']))
            .map((concern) => concern['concern'] as String)
            .toList();
        concernIdsToSave = _selectedConcernIds.toList(); // Use the actual selected IDs
    }
    // --- END MODIFIED ---

    // Update provider with potentially empty concern lists if 'None' was selected
    Provider.of<SkinProfileProvider>(context, listen: false).updateSkinProfile(
      skinType: selectedSkinTypeName,
      skinTypeId: _selectedSkinTypeId,
      concerns: concernsToSave,
      concernIds: concernIdsToSave,
      sensitivityLevel: _selectedSensitivityLevel,
    );

    // Notify parent about saved profile (pass the actual IDs saved)
    widget.onProfileSaved?.call({
      'skinTypeId': _selectedSkinTypeId,
      'concernIds': concernIdsToSave, // Pass the IDs that were saved
      'sensitivityLevel': _selectedSensitivityLevel,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile successfully saved!')),
    );
  }

  // Helper for validation dialog (remains the same)
  void _showValidationErrorDialog(String message) {
     showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Selection Required'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final displayableSkinTypes = _skinTypes
        .where((type) =>
            type['skin_type']?.toString().toLowerCase() != 'sensitive')
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Skin Profile',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: colorScheme.primary,
        leading: widget.onBackPressed != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: widget.onBackPressed,
              )
            : null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- SKIN TYPE SECTION (No changes) ---
            const Text(
              'Select Your Skin Type',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _isLoadingSkinTypes
                ? const Center(child: CircularProgressIndicator())
                : displayableSkinTypes.isEmpty
                  ? const Center(child: Text('No skin types found.'))
                  : Column(
                    children: displayableSkinTypes.map((type) {
                      return RadioListTile<int?>(
                        title: Text(type['skin_type'] ?? 'Unknown Type'),
                        value: type['skin_type_id'],
                        groupValue: _selectedSkinTypeId,
                        onChanged: (value) {
                          if (mounted) setState(() => _selectedSkinTypeId = value);
                        },
                        activeColor: colorScheme.primary,
                      );
                    }).toList(),
                  ),
            const SizedBox(height: 24),

            // --- SENSITIVITY LEVEL SECTION (No changes) ---
            const Text(
              'Select Your Sensitivity Level',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Column(
              children: _sensitivityOptions.map((level) {
                return RadioListTile<String?>(
                  title: Text(level),
                  value: level,
                  groupValue: _selectedSensitivityLevel,
                  onChanged: (value) {
                    if (mounted) setState(() => _selectedSensitivityLevel = value);
                  },
                  activeColor: colorScheme.primary,
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // --- SKIN CONCERNS SECTION (MODIFIED) ---
            const Text(
              'Select Your Skin Concerns',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _isLoadingConcerns
                ? const Center(child: CircularProgressIndicator())
                : _skinConcerns.isEmpty // Check if *fetched* concerns are empty
                  ? const Center(child: Text('No skin concerns found.'))
                  : Column(
                      children: [
                        // --- NEW: 'None' Checkbox ---
                        CheckboxListTile(
                          title: const Text('None'),
                          value: _isNoneConcernSelected,
                          onChanged: (bool? value) {
                            if (mounted && value != null) { // Check for null value
                              setState(() {
                                _isNoneConcernSelected = value;
                                if (_isNoneConcernSelected) {
                                  // If 'None' is checked, clear all other selections
                                  _selectedConcernIds.clear();
                                }
                                // If 'None' is unchecked, the user needs to select other concerns
                              });
                            }
                          },
                          activeColor: colorScheme.primary,
                        ),
                        // --- END NEW ---

                        // --- Divider (Optional) ---
                        const Divider(height: 1, thickness: 1),
                        const SizedBox(height: 8),
                        // --- End Divider ---

                        // --- List of Real Concerns ---
                        ..._skinConcerns.map((concern) { // Use spread operator (...)
                          final int concernId = concern['concern_id'];
                          return CheckboxListTile(
                            title: Text(concern['concern'] ?? 'Unknown Concern'),
                            // Only allow checking if 'None' is NOT selected
                            // Value is true only if 'None' is false AND this ID is selected
                            value: !_isNoneConcernSelected && _selectedConcernIds.contains(concernId),
                            onChanged: _isNoneConcernSelected ? null : (bool? value) { // Disable if 'None' is selected
                              if (mounted && value != null) {
                                setState(() {
                                  if (value == true) {
                                    // Checking a real concern automatically unchecks 'None' (handled by value logic)
                                    // _isNoneConcernSelected = false; // This state change happens implicitly via the `value` binding
                                    _selectedConcernIds.add(concernId);
                                  } else {
                                    _selectedConcernIds.remove(concernId);
                                  }
                                });
                              }
                            },
                            activeColor: colorScheme.primary,
                            // Optional: Make it look disabled if 'None' is checked
                            controlAffinity: ListTileControlAffinity.leading,
                            enabled: !_isNoneConcernSelected, // Disable interaction if 'None' is selected
                          );
                        }).toList(),
                      ],
                    ),
            const SizedBox(height: 32),

            // --- BUTTONS SECTION (No changes) ---
              Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _clearSelections,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                    backgroundColor: Colors.grey[600],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
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
                     shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                  ),
                  child: const Text(
                    'Save Profile',
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ),
              ],
            ),
             const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}