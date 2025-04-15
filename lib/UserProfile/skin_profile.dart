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
  final Set<int> _selectedConcernIds = {};
  bool _isLoadingSkinTypes = true;
  bool _isLoadingConcerns = true;
  List<Map<String, dynamic>> _skinTypes = [];
  List<Map<String, dynamic>> _skinConcerns = [];

  // --- MODIFIED: State for Sensitivity Level (starts null) ---
  String? _selectedSensitivityLevel; // Store the selected level (nullable)
  final List<String> _sensitivityOptions = const ['Low', 'Medium', 'High']; // Define options
  // -----------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _fetchSkinTypes();
    _fetchSkinConcerns();
    // Load profile after initial frame build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadSavedProfile();
      }
    });
  }

  Future<void> _loadSavedProfile() async {
    if (!mounted) return;
    final profileProvider = Provider.of<SkinProfileProvider>(context, listen: false);

    // --- MODIFIED: Load existing selections including nullable sensitivity level ---
    if (profileProvider.userSkinTypeId != null ||
        profileProvider.userConcernIds.isNotEmpty ||
        profileProvider.userSensitivityLevel != null ) { // Check if sensitivity is not null
      if (mounted) {
        setState(() {
          _selectedSkinTypeId = profileProvider.userSkinTypeId;
          _selectedConcernIds.clear();
          _selectedConcernIds.addAll(profileProvider.userConcernIds);
          // --- MODIFIED: Load Sensitivity Level (or keep null if not set) ---
          _selectedSensitivityLevel = profileProvider.userSensitivityLevel;
          // Ensure loaded level is one of the options, otherwise set to null
          if (_selectedSensitivityLevel != null && !_sensitivityOptions.contains(_selectedSensitivityLevel)) {
              _selectedSensitivityLevel = null; // Fallback to null if invalid
          }
          // --------------------------------------------------------------
        });
      }
    } else {
        // --- REMOVED: No need to set a default sensitivity level here ---
        // if (mounted) {
        //   setState(() {
        //     // _selectedSensitivityLevel = 'Medium'; // No default selection
        //   });
        // }
        // _selectedSensitivityLevel remains null if nothing is loaded
    }
    // --------------------------------------------------------------------------
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
          .order('concern_id');

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
        // --- MODIFIED: Clear Sensitivity Level to null ---
        _selectedSensitivityLevel = null; // Reset to null (no selection)
        // ---------------------------------------------
      });
      // Optionally clear provider too if desired and implemented
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
      return; // Stop execution
    }
    // --- VALIDATE Sensitivity Level ---
    // This check remains the same, but now correctly handles the null state
    if (_selectedSensitivityLevel == null) {
       _showValidationErrorDialog('Please select your sensitivity level.');
       return; // Stop execution
    }
    // -------------------------------------
    // Optionally keep validation for concerns if needed
    // if (_selectedConcernIds.isEmpty) {
    //   _showValidationErrorDialog('Please select at least one skin concern.');
    //   return;
    // }
      // --- END UPDATED VALIDATION LOGIC ---


    // Handle potential null skin type safely
    final selectedSkinTypeData = _selectedSkinTypeId == null
        ? null
        : _skinTypes.firstWhere(
            (type) => type['skin_type_id'] == _selectedSkinTypeId,
            orElse: () => {'skin_type': null}, // Safety net
          );
    final selectedSkinTypeName = selectedSkinTypeData?['skin_type'] as String?; // Can be null


    final selectedConcerns = _skinConcerns
        .where((concern) => _selectedConcernIds.contains(concern['concern_id']))
        .map((concern) => concern['concern'] as String)
        .toList();

    // --- UPDATE: Update provider with Sensitivity ---
    Provider.of<SkinProfileProvider>(context, listen: false).updateSkinProfile(
      skinType: selectedSkinTypeName, // Pass nullable String
      skinTypeId: _selectedSkinTypeId, // Pass nullable int
      concerns: selectedConcerns,
      concernIds: _selectedConcernIds.toList(),
      sensitivityLevel: _selectedSensitivityLevel, // Pass selected level (nullable, but validated not to be null here)
    );
    // --------------------------------------------

    // Notify parent about saved profile - Include sensitivity level
    widget.onProfileSaved?.call({
      'skinTypeId': _selectedSkinTypeId,
      'concernIds': _selectedConcernIds.toList(),
      // --- Include Sensitivity Level ---
      'sensitivityLevel': _selectedSensitivityLevel,
      // ------------------------------------
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile successfully saved!')),
    );

    // Optional: Automatically go back after saving
    // widget.onBackPressed?.call();
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

    // --- FILTER OUT "Sensitive" Skin Type from display ---
    final displayableSkinTypes = _skinTypes
        .where((type) =>
            type['skin_type']?.toString().toLowerCase() != 'sensitive')
        .toList();
    // ------------------------------------------------------

    return Scaffold(
      appBar: AppBar(
         // ... (keep existing AppBar setup) ...
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
            // --- SKIN TYPE SECTION (Using Filtered List) ---
            // ... (remains the same) ...
             const Text(
              'Select Your Skin Type',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _isLoadingSkinTypes
                ? const Center(child: CircularProgressIndicator())
                : displayableSkinTypes.isEmpty // Use filtered list here
                  ? const Center(child: Text('No skin types found.'))
                  : Column(
                    // Use filtered list here
                    children: displayableSkinTypes.map((type) {
                      return RadioListTile<int?>( // Use nullable int for groupValue
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
            const SizedBox(height: 24), // Spacing

              // --- SENSITIVITY LEVEL SECTION ---
            const Text(
              'Select Your Sensitivity Level',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Column(
              children: _sensitivityOptions.map((level) {
                // The RadioListTile naturally handles a null groupValue
                // by showing no option as selected.
                return RadioListTile<String?>( // Use nullable String for groupValue
                  title: Text(level),
                  value: level,
                  groupValue: _selectedSensitivityLevel, // Can be null
                  onChanged: (value) {
                    if (mounted) setState(() => _selectedSensitivityLevel = value);
                  },
                  activeColor: colorScheme.primary,
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            // ---------------------------------------

            // --- SKIN CONCERNS SECTION (Remains the same) ---
            // ... (remains the same) ...
             const Text(
              'Select Your Skin Concerns',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _isLoadingConcerns
                ? const Center(child: CircularProgressIndicator())
                : _skinConcerns.isEmpty
                  ? const Center(child: Text('No skin concerns found.'))
                  : Column(
                    children: _skinConcerns.map((concern) {
                      return CheckboxListTile(
                        title: Text(concern['concern'] ?? 'Unknown Concern'),
                        value: _selectedConcernIds.contains(concern['concern_id']),
                        onChanged: (bool? value) {
                           if (mounted) {
                              setState(() {
                               if (value == true) {
                                  _selectedConcernIds.add(concern['concern_id']);
                                } else {
                                  _selectedConcernIds.remove(concern['concern_id']);
                                }
                              });
                            }
                        },
                          activeColor: colorScheme.primary,
                      );
                    }).toList(),
                  ),
            const SizedBox(height: 32),

            // --- BUTTONS SECTION (Remains the same) ---
             // ... (remains the same) ...
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
             const SizedBox(height: 20), // Add some padding at the bottom
          ],
        ),
      ),
    );
  }
}