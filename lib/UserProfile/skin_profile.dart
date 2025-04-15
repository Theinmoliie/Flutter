import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/skin_profile_provider.dart'; // Make sure this path is correct

final supabase = Supabase.instance.client;

class SkinProfileScreen extends StatefulWidget {
  final Function(Map<String, dynamic>)? onProfileSaved;
  final VoidCallback? onBackPressed; // <-- ADD THIS: Callback for back press

  const SkinProfileScreen({
    Key? key,
    required this.onProfileSaved,
    this.onBackPressed, // <-- ADD THIS: Make it optional in constructor
  }) : super(key: key);

  @override
  _SkinProfileScreenState createState() => _SkinProfileScreenState();
}

class _SkinProfileScreenState extends State<SkinProfileScreen> {
  // ... (keep existing state variables: _selectedSkinTypeId, _selectedConcernIds, etc.) ...
  int? _selectedSkinTypeId;
  final Set<int> _selectedConcernIds = {};
  bool _isLoadingSkinTypes = true;
  bool _isLoadingConcerns = true;
  List<Map<String, dynamic>> _skinTypes = [];
  List<Map<String, dynamic>> _skinConcerns = [];


  // ... (keep existing methods: initState, _loadSavedProfile, _fetchSkinTypes, etc.) ...
   @override
  void initState() {
    super.initState();
    _fetchSkinTypes();
    _fetchSkinConcerns();
    // Use listen: false because initState runs before the widget is fully built
    // and we don't need to rebuild based on provider changes right here.
    _loadSavedProfile();
  }

  Future<void> _loadSavedProfile() async {
    // Ensure context is available and mounted before accessing Provider
    if (!mounted) return;
    final profileProvider = Provider.of<SkinProfileProvider>(context, listen: false);
    // Check if provider actually has data before setting state
    if (profileProvider.userSkinTypeId != null || profileProvider.userConcernIds.isNotEmpty) {
       if (mounted) { // Check mounted again before calling setState
         setState(() {
           _selectedSkinTypeId = profileProvider.userSkinTypeId;
           // Clear existing concerns before adding from provider to avoid duplicates
           _selectedConcernIds.clear();
           _selectedConcernIds.addAll(profileProvider.userConcernIds);
         });
       }
    }
  }

   Future<void> _fetchSkinTypes() async {
    if (!mounted) return; // Check if mounted
    setState(() => _isLoadingSkinTypes = true); // Indicate loading starts
    try {
      final response = await supabase
          .from('Skin Types')
          .select('skin_type_id, skin_type')
          .order('skin_type_id');

       if (mounted) { // Check if mounted before setState
         setState(() {
           _skinTypes = List<Map<String, dynamic>>.from(response);
           _isLoadingSkinTypes = false;
         });
       }
    } catch (e) {
       if (mounted) { // Check if mounted before setState and showing SnackBar
         setState(() => _isLoadingSkinTypes = false);
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Error fetching skin types: ${e.toString()}'))
         );
       }
    }
  }

  Future<void> _fetchSkinConcerns() async {
     if (!mounted) return; // Check if mounted
    setState(() => _isLoadingConcerns = true); // Indicate loading starts
    try {
      final response = await supabase
          .from('Skin Concerns')
          .select('concern_id, concern')
          .order('concern_id');

      if (mounted) { // Check if mounted before setState
        setState(() {
          _skinConcerns = List<Map<String, dynamic>>.from(response);
          _isLoadingConcerns = false;
        });
      }
    } catch (e) {
       if (mounted) { // Check if mounted before setState and showing SnackBar
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
      });
       // Optionally clear provider too if desired
      // Provider.of<SkinProfileProvider>(context, listen: false).clearProfile();
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selections cleared')),
      );
    }

   void _saveProfile() {
    if (!mounted) return;
    // Adjusted logic: Allow saving if *either* type or concerns are selected
     // --- NEW VALIDATION LOGIC ---
  // Check specifically if skin type is selected
  if (_selectedSkinTypeId == null) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Selection Required'),
        // Specific message requested by user
        content: const Text('Please select your skin type.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    return; // Stop execution if skin type is not selected
  }
  // --- END NEW VALIDATION LOGIC ---
  
    if (_selectedSkinTypeId == null && _selectedConcernIds.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Selection Required'),
          // More informative message
          content: const Text('Please select your skin type and at least one skin concern to save.'),
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

    // Handle potential null skin type safely
    final selectedSkinType = _selectedSkinTypeId == null
        ? null
        : _skinTypes.firstWhere(
            (type) => type['skin_type_id'] == _selectedSkinTypeId,
            orElse: () => {'skin_type': null}, // Safety net
          )['skin_type'];

    final selectedConcerns = _skinConcerns
        .where((concern) => _selectedConcernIds.contains(concern['concern_id']))
        .map((concern) => concern['concern'] as String)
        .toList();

    // Update provider
    Provider.of<SkinProfileProvider>(context, listen: false).updateSkinProfile(
      selectedSkinType, // Pass nullable String
      _selectedSkinTypeId!, // Pass nullable int
      selectedConcerns,
      _selectedConcernIds.toList(),
    );

    // Notify parent about saved profile - Send IDs is often cleaner
    widget.onProfileSaved?.call({
      'skinTypeId': _selectedSkinTypeId,
      'concernIds': _selectedConcernIds.toList(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile successfully saved!')),
    );

    // Optional: Automatically go back after saving
    // widget.onBackPressed?.call();
  }


  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Skin Profile',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: colorScheme.primary,
        // --- REMOVE this line: automaticallyImplyLeading: false, ---
        // --- ADD this leading section ---
        leading: widget.onBackPressed != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white), // Set icon color
                onPressed: widget.onBackPressed, // Use the callback
              )
            : null, // If no callback provided, no back button shown
        // --- END leading section ---
      ),
      body: SingleChildScrollView(
         // ... (rest of the body remains the same) ...
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
                : _skinTypes.isEmpty // Handle case where fetch might return empty
                  ? const Center(child: Text('No skin types found.'))
                  : Column(
                    children: _skinTypes.map((type) {
                      return RadioListTile<int>(
                        title: Text(type['skin_type'] ?? 'Unknown Type'), // Handle potential null
                        value: type['skin_type_id'],
                        groupValue: _selectedSkinTypeId,
                        onChanged: (value) {
                          if (mounted) setState(() => _selectedSkinTypeId = value);
                        },
                        activeColor: colorScheme.primary, // Theme color
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
                : _skinConcerns.isEmpty // Handle empty case
                  ? const Center(child: Text('No skin concerns found.'))
                  : Column(
                    children: _skinConcerns.map((concern) {
                      return CheckboxListTile(
                        title: Text(concern['concern'] ?? 'Unknown Concern'), // Handle potential null
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
                         activeColor: colorScheme.primary, // Theme color
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
                    backgroundColor: Colors.grey[600], // Slightly darker grey
                    shape: RoundedRectangleBorder( // Rounded corners
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
                  backgroundColor: const Color.fromARGB(255, 170, 136, 176), // Your custom color
                   shape: RoundedRectangleBorder( // Rounded corners
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