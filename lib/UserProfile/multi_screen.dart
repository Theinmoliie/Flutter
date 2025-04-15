// multi_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/skin_profile_provider.dart';
import 'skin_type.dart';      // Assuming public class SkinTypePage
import 'sensitivity_level.dart'; // Assuming public class SensitivityPage
import 'skin_concerns.dart';   // Assuming public class ConcernsPage

final supabase = Supabase.instance.client;

// Main StatefulWidget holding the PageView structure
class MultiPageSkinProfileScreen extends StatefulWidget {
  final Function(Map<String, dynamic>)? onProfileSaved;
  final VoidCallback? onBackPressed;

  const MultiPageSkinProfileScreen({
    Key? key,
    this.onProfileSaved,
    this.onBackPressed,
  }) : super(key: key);

  @override
  _MultiPageSkinProfileScreenState createState() =>
      _MultiPageSkinProfileScreenState();
}

class _MultiPageSkinProfileScreenState extends State<MultiPageSkinProfileScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // --- State variables (no changes needed here) ---
  int? _selectedSkinTypeId;
  final Set<int> _selectedConcernIds = {};
  bool _isNoneConcernSelected = false;
  String? _selectedSensitivityLevel;
  final List<String> _sensitivityOptions = const ['Low', 'Medium', 'High'];
  bool _isLoadingSkinTypes = true;
  bool _isLoadingConcerns = true;
  List<Map<String, dynamic>> _skinTypes = [];
  List<Map<String, dynamic>> _skinConcerns = [];
  // --- End State variables ---

  @override
  void initState() {
    super.initState();
    _fetchData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadSavedProfile();
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // --- Data Fetching, Loading, Saving, Clearing (no changes needed here) ---
  Future<void> _fetchData() async { /* ... */
    await Future.wait([
      _fetchSkinTypes(),
      _fetchSkinConcerns(),
    ]);
   }
  Future<void> _loadSavedProfile() async { /* ... */
    if (!mounted) return;
    final profileProvider = Provider.of<SkinProfileProvider>(context, listen: false);
    if (profileProvider.userSkinTypeId != null || profileProvider.userSensitivityLevel != null ) {
      if (mounted) {
        setState(() {
          _selectedSkinTypeId = profileProvider.userSkinTypeId;
          _selectedConcernIds.clear();
          _selectedConcernIds.addAll(profileProvider.userConcernIds);
          _selectedSensitivityLevel = profileProvider.userSensitivityLevel;
          _isNoneConcernSelected = profileProvider.userConcernIds.isEmpty && (profileProvider.userSkinTypeId != null || profileProvider.userSensitivityLevel != null);
          if (_selectedSensitivityLevel != null && !_sensitivityOptions.contains(_selectedSensitivityLevel)) {
            _selectedSensitivityLevel = null;
          }
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isNoneConcernSelected = false;
        });
      }
    }
   }
  Future<void> _fetchSkinTypes() async { /* ... */
     if (!mounted) return;
    setState(() => _isLoadingSkinTypes = true);
    try {
      final response = await supabase.from('Skin Types').select('skin_type_id, skin_type').order('skin_type_id');
      if (mounted) {
        setState(() {
          _skinTypes = List<Map<String, dynamic>>.from(response);
          _isLoadingSkinTypes = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingSkinTypes = false);
        _showErrorSnackBar('Error fetching skin types: ${e.toString()}');
      }
    }
   }
  Future<void> _fetchSkinConcerns() async { /* ... */
      if (!mounted) return;
    setState(() => _isLoadingConcerns = true);
    try {
      final response = await supabase.from('Skin Concerns').select('concern_id, concern').order('concern_id');
      if (mounted) {
        setState(() {
          _skinConcerns = List<Map<String, dynamic>>.from(response);
          _isLoadingConcerns = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingConcerns = false);
        _showErrorSnackBar('Error fetching skin concerns: ${e.toString()}');
      }
    }
   }
  void _clearConcerns() { /* ... */
    if (!mounted) return;
    setState(() {
      _selectedConcernIds.clear();
      _isNoneConcernSelected = false;
    });
    _showInfoSnackBar('Concern selections cleared');
   }
  void _saveProfile() { /* ... */
      if (!mounted) return;
    if (_selectedSkinTypeId == null) {
      _showValidationErrorDialog('Please select your skin type.');
      return;
    }
    if (_selectedSensitivityLevel == null) {
      _showValidationErrorDialog('Please select your sensitivity level.');
      return;
    }
    if (!_isNoneConcernSelected && _selectedConcernIds.isEmpty) {
      _showValidationErrorDialog('Please select at least one skin concern, or select \'None\'.');
      return;
    }
    final selectedSkinTypeData = _selectedSkinTypeId == null ? null : _skinTypes.firstWhere((type) => type['skin_type_id'] == _selectedSkinTypeId, orElse: () => {'skin_type': null});
    final selectedSkinTypeName = selectedSkinTypeData?['skin_type'] as String?;
    final List<String> concernsToSave;
    final List<int> concernIdsToSave;
    if (_isNoneConcernSelected) {
      concernsToSave = [];
      concernIdsToSave = [];
    } else {
      concernsToSave = _skinConcerns.where((concern) => _selectedConcernIds.contains(concern['concern_id'])).map((concern) => concern['concern'] as String).toList();
      concernIdsToSave = _selectedConcernIds.toList();
    }
    Provider.of<SkinProfileProvider>(context, listen: false).updateSkinProfile(
      skinType: selectedSkinTypeName,
      skinTypeId: _selectedSkinTypeId,
      concerns: concernsToSave,
      concernIds: concernIdsToSave,
      sensitivityLevel: _selectedSensitivityLevel,
    );
    widget.onProfileSaved?.call({
      'skinTypeId': _selectedSkinTypeId,
      'concernIds': concernIdsToSave,
      'sensitivityLevel': _selectedSensitivityLevel,
    });
    _showInfoSnackBar('Profile successfully saved!');
   }
  void _nextPage() { /* ... */
      if (_currentPage == 0 && _selectedSkinTypeId == null) {
        _showValidationErrorDialog('Please select your skin type before proceeding.');
        return;
    }
    if (_currentPage == 1 && _selectedSensitivityLevel == null) {
        _showValidationErrorDialog('Please select your sensitivity level before proceeding.');
        return;
    }

    final totalPages = 3;
    if (_currentPage < totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
   }
  void _previousPage() { /* ... */
     if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
   }
  void _showValidationErrorDialog(String message) { /* ... */
    showDialog( context: context, builder: (context) => AlertDialog( title: const Text('Selection Required'), content: Text(message), actions: [ TextButton( onPressed: () => Navigator.pop(context), child: const Text('OK'), ), ], ), );
   }
  void _showErrorSnackBar(String message) { /* ... */
     if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text(message), backgroundColor: Colors.red), );
   }
  void _showInfoSnackBar(String message) { /* ... */
     if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text(message)), );
   }
  String _getAppBarTitle() { /* ... */
    switch (_currentPage) { case 0: return 'Select Skin Type (1/3)'; case 1: return 'Select Sensitivity (2/3)'; case 2: return 'Select Skin Concerns (3/3)'; default: return 'Skin Profile'; }
   }
  // --- End Unchanged Methods ---


  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final double buttonSize = 48; // Define a size for the circular buttons for consistent spacing

    final displayableSkinTypes = _skinTypes
        .where((type) =>
            type['skin_type']?.toString().toLowerCase() != 'sensitive')
        .toList();

    final List<Widget> pages = [
      SkinTypePage( /* ... */
         key: const ValueKey('SkinTypePage'),
        skinTypes: displayableSkinTypes,
        selectedSkinTypeId: _selectedSkinTypeId,
        isLoading: _isLoadingSkinTypes,
        onChanged: (value) { if (mounted) setState(() => _selectedSkinTypeId = value); },
      ),
      SensitivityPage( /* ... */
        key: const ValueKey('SensitivityPage'),
        sensitivityOptions: _sensitivityOptions,
        selectedSensitivityLevel: _selectedSensitivityLevel,
        onChanged: (value) { if (mounted) setState(() => _selectedSensitivityLevel = value); },
      ),
     // *** CONCERNS PAGE INSTANTIATION ***
      ConcernsPage(
        key: const ValueKey('ConcernsPage'),
        skinConcerns: _skinConcerns,
        selectedConcernIds: _selectedConcernIds,
        // --- USAGE 1: Passing state to child ---
        isNoneSelected: _isNoneConcernSelected, // 
        isLoading: _isLoadingConcerns,

        // --- Callback 1: onConcernChanged ---
        onConcernChanged: (concernId, value) {
          if (mounted && value != null) {
            setState(() {
              if (value == true) {
                 // --- USAGE 2: Modifying state ---
                _isNoneConcernSelected = false; // 
                _selectedConcernIds.add(concernId);
              } else {
                _selectedConcernIds.remove(concernId);
              }
            });
          }
        },

        // --- Callback 2: onNoneChanged ---
        onNoneChanged: (value) {
          if (mounted && value != null) {
            setState(() {
               // --- USAGE 3: Modifying state ---
              _isNoneConcernSelected = value; 
              // --- USAGE 4: Reading state ---
              if (_isNoneConcernSelected) { 
                _selectedConcernIds.clear();
              }
            });
          }
        },
      ), // *** END CONCERNS PAGE INSTANTIATION ***
    ];


    final double progress = (pages.isNotEmpty) ? (_currentPage + 1) / pages.length : 0.0;
    final bool isLastPage = _currentPage == pages.length - 1;

    return Scaffold(
      appBar: AppBar( /* ... AppBar setup ... */
        title: Text( _getAppBarTitle(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), ),
        backgroundColor: colorScheme.primary,
        leading: widget.onBackPressed != null && _currentPage == 0 ? IconButton( icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: widget.onBackPressed, ) : _currentPage > 0 ? IconButton( icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: _previousPage, ) : null,
        elevation: 1,
       ),
      body: Column(
        children: [
          // --- Progress Bar ---
          Padding( /* ... Progress bar setup ... */
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: LinearProgressIndicator( value: progress, backgroundColor: colorScheme.primaryContainer.withOpacity(0.3), valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary), minHeight: 6, borderRadius: BorderRadius.circular(3), ),
          ),
          // --- PageView ---
          Expanded( /* ... PageView setup ... */
            child: PageView( controller: _pageController, physics: const NeverScrollableScrollPhysics(), onPageChanged: (int page) { setState(() { _currentPage = page; }); }, children: pages, ),
          ),

          // --- *** NEW: Navigation Controls Area (Column) *** ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
            child: Column( // Main container for controls
              mainAxisSize: MainAxisSize.min, // Take only needed vertical space
              children: [
                // --- Clear Concerns Button Row (Top Right) ---
                if (isLastPage) // Show only on last page
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8.0), // Space below clear button
                      child: TextButton(
                        child: const Text('Clear Concerns'),
                        style: TextButton.styleFrom(foregroundColor: Colors.grey[700]),
                        onPressed: _clearConcerns,
                      ),
                    ),
                  ),

                // --- Main Navigation Row (Previous / Save / Next) ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    // --- Previous Button ---
                    SizedBox( // Use SizedBox to reserve space even when hidden
                      width: buttonSize + 8, // Approx size of circular button + padding
                      height: buttonSize,
                      child: Opacity(
                        opacity: _currentPage > 0 ? 1.0 : 0.0,
                        child: IgnorePointer(
                          ignoring: _currentPage == 0,
                          child: ElevatedButton(
                            onPressed: _previousPage,
                            child: const Icon(Icons.arrow_back_ios_new, size: 20),
                            style: ElevatedButton.styleFrom(
                              shape: const CircleBorder(),
                              padding: const EdgeInsets.all(12),
                              backgroundColor: Colors.grey[200],
                              foregroundColor: Colors.grey[700],
                              elevation: 2,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // --- Save Button (Center on Last Page) ---
                    if (isLastPage)
                      ElevatedButton(
                        child: const Text('Save Profile'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromARGB(255, 170, 136, 176),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12), // Increased padding
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
                        ),
                        onPressed: _saveProfile,
                      ),

                    // --- Next Button ---
                     SizedBox( // Use SizedBox to reserve space even when hidden
                      width: buttonSize + 8,
                      height: buttonSize,
                       child: Opacity(
                        opacity: !isLastPage ? 1.0 : 0.0,
                        child: IgnorePointer(
                          ignoring: isLastPage,
                          child: ElevatedButton(
                            onPressed: _nextPage,
                            child: const Icon(Icons.arrow_forward_ios, size: 20),
                            style: ElevatedButton.styleFrom(
                              shape: const CircleBorder(),
                              padding: const EdgeInsets.all(12),
                              backgroundColor: colorScheme.primary,
                              foregroundColor: Colors.white,
                              elevation: 2,
                            ),
                          ),
                        ),
                                           ),
                     ),
                  ],
                ),
              ],
            ),
          ),
          // --- *** End Navigation Controls Area *** ---
        ],
      ),
    );
  }
}