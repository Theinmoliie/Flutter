// multi_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/skin_profile_provider.dart';
import '../AiSkinAnalysis/analysis_camera_page.dart'; // IMPORT THE NEW CAMERA PAGE
import 'skin_sensitivity.dart';
import 'skin_concerns.dart';

final supabase = Supabase.instance.client;

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

  // State variables
  int? _selectedSkinTypeId;
  final Set<int> _selectedConcernIds = {};
  bool _isNoneConcernSelected = false;
  String? _selectedSensitivity;
  final List<String> _sensitivityOptions = const ['Yes', 'No'];
  bool _isLoadingConcerns = true;
  List<Map<String, dynamic>> _skinTypes = []; // Still needed for ID lookup
  List<Map<String, dynamic>> _skinConcerns = [];
  final int _maxConcerns = 3;

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

  Future<void> _fetchData() async {
    // We still fetch both to have the data ready for lookups and subsequent pages.
    await Future.wait([_fetchSkinTypes(), _fetchSkinConcerns()]);
  }

  Future<void> _loadSavedProfile() async {
    if (!mounted) return;
    final profileProvider = Provider.of<SkinProfileProvider>(context, listen: false);
    if (profileProvider.userSkinTypeId != null ||
        profileProvider.userSensitivity != null) {
      if (mounted) {
        setState(() {
          _selectedSkinTypeId = profileProvider.userSkinTypeId;
          _selectedConcernIds.clear();
          _selectedConcernIds.addAll(profileProvider.userConcernIds.take(_maxConcerns));
          _selectedSensitivity = profileProvider.userSensitivity;
          _isNoneConcernSelected = profileProvider.userConcernIds.isEmpty &&
              (profileProvider.userSkinTypeId != null ||
                  profileProvider.userSensitivity != null);
          if (_selectedSensitivity != null &&
              !_sensitivityOptions.contains(_selectedSensitivity)) {
            _selectedSensitivity = null;
          }
        });
      }
    }
  }

  Future<void> _fetchSkinTypes() async {
    if (!mounted) return;
    try {
      final response = await supabase.from('Skin Types').select('skin_type_id, skin_type').order('skin_type_id');
      if (mounted) {
        setState(() => _skinTypes = List<Map<String, dynamic>>.from(response));
      }
    } catch (e) {
      if (mounted) _showErrorSnackBar('Error fetching skin types: ${e.toString()}');
    }
  }

  Future<void> _fetchSkinConcerns() async {
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

  void _clearConcerns() {
    if (!mounted) return;
    setState(() {
      _selectedConcernIds.clear();
      _isNoneConcernSelected = false;
    });
    // ... (Your existing dialog logic)
  }

  void _saveProfile() {
    if (!mounted) return;
    if (_selectedSkinTypeId == null) {
      _showValidationErrorDialog('Please complete the skin analysis first.');
      return;
    }
    // ... (Rest of your save logic is fine)
    if (_selectedSensitivity == null) { _showValidationErrorDialog('Please select your sensitivity level.'); return; }
    if (!_isNoneConcernSelected && _selectedConcernIds.isEmpty) { _showValidationErrorDialog('Please select at least one skin concern, or select \'None\'.'); return; }
    if (!_isNoneConcernSelected && _selectedConcernIds.length > _maxConcerns) { _showValidationErrorDialog('You can select a maximum of $_maxConcerns skin concerns.'); return; }
    final selectedSkinTypeData = _skinTypes.firstWhere((type) => type['skin_type_id'] == _selectedSkinTypeId, orElse: () => {'skin_type': null});
    final selectedSkinTypeName = selectedSkinTypeData['skin_type'] as String?;
    final List<int> concernIdsToSave = _isNoneConcernSelected ? [] : _selectedConcernIds.toList();
    final List<String> concernsToSave = _isNoneConcernSelected ? [] : _skinConcerns.where((c) => concernIdsToSave.contains(c['concern_id'])).map((c) => c['concern'] as String).toList();
    Provider.of<SkinProfileProvider>(context, listen: false).updateSkinProfile(skinType: selectedSkinTypeName, skinTypeId: _selectedSkinTypeId, concerns: concernsToSave, concernIds: concernIdsToSave, sensitivity: _selectedSensitivity);
    widget.onProfileSaved?.call({'skinTypeId': _selectedSkinTypeId, 'concernIds': concernIdsToSave, 'sensitivity': _selectedSensitivity});
    _showInfoSnackBar('Profile successfully saved!');
  }

  void _nextPage() {
    if (_currentPage == 0 && _selectedSkinTypeId == null) {
      _showValidationErrorDialog('Please complete the skin analysis to proceed.');
      return;
    }
    if (_currentPage == 1 && _selectedSensitivity == null) {
      _showValidationErrorDialog('Please select your sensitivity level before proceeding.');
      return;
    }
    if (_currentPage == 2 && !_isNoneConcernSelected && _selectedConcernIds.isEmpty) {
      _showValidationErrorDialog('Please select at least one skin concern, or choose \'None\'.');
      return;
    }
    if (_currentPage == 2 && !_isNoneConcernSelected && _selectedConcernIds.length > _maxConcerns) {
      _showValidationErrorDialog('You can select a maximum of $_maxConcerns skin concerns. Please adjust your selection.');
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

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _showValidationErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Selection Required'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  void _showInfoSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _getAppBarTitle() {
    switch (_currentPage) {
      case 0:
        return 'Skin Analysis (1/3)';
      case 1:
        return 'Select Sensitivity (2/3)';
      case 2:
        return 'Select Skin Concerns (3/3)';
      default:
        return 'Skin Profile';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final double buttonSize = 48;

    final List<Widget> pages = [
      // PAGE 1: THE NEW CAMERA ANALYSIS PAGE
      AnalysisCameraPage(
        key: const ValueKey('AnalysisCameraPage'),
        onBackPressed: widget.onBackPressed,
        onAnalysisComplete: (String skinTypeName) {
          if (!mounted) return;

          // Find the corresponding ID from the fetched skin types list.
          final foundType = _skinTypes.firstWhere(
            (type) => (type['skin_type'] as String).toLowerCase() == skinTypeName.toLowerCase(),
            orElse: () => {}, // Return an empty map if not found
          );

          if (foundType.isNotEmpty) {
            final int foundId = foundType['skin_type_id'];
            debugPrint("Analysis complete. Type: '$skinTypeName', ID: $foundId. Moving to next page.");
            setState(() {
              _selectedSkinTypeId = foundId;
            });
            // Automatically advance to the sensitivity page.
            _nextPage();
          } else {
            // Important fallback if the TFLite model returns a name not in the DB.
            debugPrint("Error: Analysis returned type '$skinTypeName', which was not found in the database list.");
            _showErrorSnackBar("Analysis result '$skinTypeName' is not a recognized type. Please try again.");
          }
        },
      ),

      // PAGE 2: SENSITIVITY
      SensitivityPage(
        key: const ValueKey('SensitivityPage'),
        sensitivityOptions: _sensitivityOptions,
        selectedSensitivity: _selectedSensitivity,
        onChanged: (value) {
          if (mounted) setState(() => _selectedSensitivity = value);
        },
      ),

      // PAGE 3: CONCERNS
      ConcernsPage(
        key: const ValueKey('ConcernsPage'),
        skinConcerns: _skinConcerns,
        selectedConcernIds: _selectedConcernIds,
        isNoneSelected: _isNoneConcernSelected,
        isLoading: _isLoadingConcerns,
        onConcernChanged: (concernId, value) {
          if (mounted && value != null) {
            setState(() {
              if (value == true) { // Add concern
                if (_selectedConcernIds.length < _maxConcerns) {
                  _isNoneConcernSelected = false;
                  _selectedConcernIds.add(concernId);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('You can select a maximum of $_maxConcerns concerns.')),
                  );
                }
              } else { // Remove concern
                _selectedConcernIds.remove(concernId);
              }
            });
          }
        },
        onNoneChanged: (value) {
          if (mounted && value != null) {
            setState(() {
              _isNoneConcernSelected = value;
              if (_isNoneConcernSelected) {
                _selectedConcernIds.clear();
              }
            });
          }
        },
      ),
    ];

    final double progress = (_currentPage + 1) / pages.length;
    final bool isLastPage = _currentPage == pages.length - 1;

    return Scaffold(
      appBar: AppBar(
        title: Text(_getAppBarTitle(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: colorScheme.primary,
        leading: _currentPage == 0
            ? (widget.onBackPressed != null
                ? IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: widget.onBackPressed)
                : null)
            : IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: _previousPage),
        elevation: 1,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: colorScheme.primaryContainer.withOpacity(0.3),
              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (int page) {
                if (mounted) {
                  setState(() => _currentPage = page);
                }
              },
              children: pages,
            ),
          ),

          // HIDE the bottom navigation on the camera page.
          if (_currentPage > 0)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isLastPage)
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: TextButton(
                          child: const Text('Clear Concerns'),
                          onPressed: _clearConcerns,
                        ),
                      ),
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      // Previous Button
                      SizedBox(
                        width: buttonSize + 8,
                        height: buttonSize,
                        child: ElevatedButton(
                          onPressed: _previousPage,
                          child: const Icon(Icons.arrow_back_ios_new, size: 20),
                          style: ElevatedButton.styleFrom(
                            shape: const CircleBorder(),
                            padding: const EdgeInsets.all(12),
                          ),
                        ),
                      ),
                      // Save/Next Buttons
                      if (isLastPage)
                        ElevatedButton(
                          child: const Text('Save Profile'),
                          onPressed: _saveProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.primary,
                            foregroundColor: colorScheme.onPrimary,
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                        )
                      else
                        ElevatedButton(
                          onPressed: _nextPage,
                          child: const Icon(Icons.arrow_forward_ios, size: 20),
                          style: ElevatedButton.styleFrom(
                            shape: const CircleBorder(),
                            padding: const EdgeInsets.all(12),
                            backgroundColor: colorScheme.primary,
                            foregroundColor: Colors.white,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}