// multi_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/skin_profile_provider.dart';
import 'skin_type.dart'; 
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

class _MultiPageSkinProfileScreenState
    extends State<MultiPageSkinProfileScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  int? _selectedSkinTypeId;
  final Set<int> _selectedConcernIds = {};
  bool _isNoneConcernSelected = false;
  String? _selectedSensitivity;
  final List<String> _sensitivityOptions = const ['Yes', 'No'];
  bool _isLoadingSkinTypes = true;
  bool _isLoadingConcerns = true;
  List<Map<String, dynamic>> _skinTypes = [];
  List<Map<String, dynamic>> _skinConcerns = [];
  
  final int _maxConcerns = 3; // Define the maximum number of concerns

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
    await Future.wait([_fetchSkinTypes(), _fetchSkinConcerns()]);
  }

  Future<void> _loadSavedProfile() async {
    if (!mounted) return;
    final profileProvider = Provider.of<SkinProfileProvider>(
      context,
      listen: false,
    );
    if (profileProvider.userSkinTypeId != null ||
        profileProvider.userSensitivity != null) {
      if (mounted) {
        setState(() {
          _selectedSkinTypeId = profileProvider.userSkinTypeId;
          _selectedConcernIds.clear();
          // Ensure loaded concerns don't exceed the max limit
          _selectedConcernIds.addAll(profileProvider.userConcernIds.take(_maxConcerns)); 
          _selectedSensitivity = profileProvider.userSensitivity;
          _isNoneConcernSelected =
              profileProvider.userConcernIds.isEmpty &&
              (profileProvider.userSkinTypeId != null ||
                  profileProvider.userSensitivity != null);
          if (_selectedSensitivity != null &&
              !_sensitivityOptions.contains(_selectedSensitivity)) {
            _selectedSensitivity = null;
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

  Future<void> _fetchSkinTypes() async {
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
        _showErrorSnackBar('Error fetching skin types: ${e.toString()}');
      }
    }
  }

  Future<void> _fetchSkinConcerns() async {
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
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Concerns Cleared'),
          content: const SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Your selections for skin concerns have been reset.'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15.0),
          ),
        );
      },
    );
  }

  void _saveProfile() {
    if (!mounted) return;
    if (_selectedSkinTypeId == null) {
      _showValidationErrorDialog('Please select your skin type.');
      return;
    }
    if (_selectedSensitivity == null) {
      _showValidationErrorDialog('Please select your sensitivity level.');
      return;
    }
    if (!_isNoneConcernSelected && _selectedConcernIds.isEmpty) {
      _showValidationErrorDialog(
        'Please select at least one skin concern, or select \'None\'.',
      );
      return;
    }
    // Additional check: Ensure not more than _maxConcerns are selected if "None" is not active
    if (!_isNoneConcernSelected && _selectedConcernIds.length > _maxConcerns) {
        _showValidationErrorDialog('You can select a maximum of $_maxConcerns skin concerns.');
        // Optionally, trim the selection here, or rely on the UI to prevent this state.
        // For robustness, you could trim:
        // _selectedConcernIds = _selectedConcernIds.take(_maxConcerns).toSet();
        return;
    }

    final selectedSkinTypeData =
        _selectedSkinTypeId == null
            ? null
            : _skinTypes.firstWhere(
              (type) => type['skin_type_id'] == _selectedSkinTypeId,
              orElse: () => {'skin_type': null},
            );
    final selectedSkinTypeName = selectedSkinTypeData?['skin_type'] as String?;
    final List<String> concernsToSave;
    final List<int> concernIdsToSave;
    if (_isNoneConcernSelected) {
      concernsToSave = [];
      concernIdsToSave = [];
    } else {
      concernsToSave =
          _skinConcerns
              .where(
                (concern) =>
                    _selectedConcernIds.contains(concern['concern_id']),
              )
              .map((concern) => concern['concern'] as String)
              .toList();
      concernIdsToSave = _selectedConcernIds.toList();
    }
    Provider.of<SkinProfileProvider>(context, listen: false).updateSkinProfile(
      skinType: selectedSkinTypeName,
      skinTypeId: _selectedSkinTypeId,
      concerns: concernsToSave,
      concernIds: concernIdsToSave,
      sensitivity: _selectedSensitivity,
    );
    widget.onProfileSaved?.call({
      'skinTypeId': _selectedSkinTypeId,
      'concernIds': concernIdsToSave,
      'sensitivity': _selectedSensitivity,
    });
    _showInfoSnackBar('Profile successfully saved!');
  }

  void _nextPage() {
    if (_currentPage == 0 && _selectedSkinTypeId == null) {
      _showValidationErrorDialog(
        'Please select your skin type before proceeding.',
      );
      return;
    }
    if (_currentPage == 1 && _selectedSensitivity == null) {
      _showValidationErrorDialog(
        'Please select your sensitivity level before proceeding.',
      );
      return;
    }
    // Validation for concerns page when trying to proceed
    if (_currentPage == 2 && !_isNoneConcernSelected && _selectedConcernIds.isEmpty) {
        _showValidationErrorDialog(
          'Please select at least one skin concern, or choose \'None\'.',
        );
        return;
    }
     if (_currentPage == 2 && !_isNoneConcernSelected && _selectedConcernIds.length > _maxConcerns) {
        _showValidationErrorDialog(
          'You can select a maximum of $_maxConcerns skin concerns. Please adjust your selection.',
        );
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
      builder:
          (context) => AlertDialog(
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

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showInfoSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _getAppBarTitle() {
    switch (_currentPage) {
      case 0:
        return 'Select Skin Type (1/3)';
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

    final displayableSkinTypes =
        _skinTypes
            .where(
              (type) =>
                  type['skin_type']?.toString().toLowerCase() != 'sensitive',
            )
            .toList();

    final List<Widget> pages = [
      SkinTypePage(
        key: const ValueKey('SkinTypePage'),
        skinTypes: displayableSkinTypes,
        selectedSkinTypeId: _selectedSkinTypeId,
        isLoading: _isLoadingSkinTypes,
        onChanged: (value) {
          if (mounted) setState(() => _selectedSkinTypeId = value);
        },
      ),
      SensitivityPage(
        key: const ValueKey('SensitivityPage'),
        sensitivityOptions: _sensitivityOptions,
        selectedSensitivity: _selectedSensitivity,
        onChanged: (value) {
          if (mounted) setState(() => _selectedSensitivity= value);
        },
      ),
      ConcernsPage(
        key: const ValueKey('ConcernsPage'),
        skinConcerns: _skinConcerns,
        selectedConcernIds: _selectedConcernIds,
        isNoneSelected: _isNoneConcernSelected,
        isLoading: _isLoadingConcerns,
        onConcernChanged: (concernId, value) {
          if (mounted && value != null) {
            setState(() {
              if (value == true) { // Trying to add a concern
                if (_selectedConcernIds.length < _maxConcerns) {
                  _isNoneConcernSelected = false; 
                  _selectedConcernIds.add(concernId);
                } else {
                  // Optionally show a message if trying to exceed limit by checking the box
                   ScaffoldMessenger.of(context).showSnackBar(
                     SnackBar(content: Text('You can select a maximum of $_maxConcerns concerns.'), duration: const Duration(seconds: 2))
                   );
                }
              } else { // Trying to remove a concern
                _selectedConcernIds.remove(concernId);
                // If all concerns are deselected, "None" does not automatically become true.
                // User must explicitly select "None".
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

    final double progress =
        (pages.isNotEmpty) ? (_currentPage + 1) / pages.length : 0.0;
    final bool isLastPage = _currentPage == pages.length - 1;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _getAppBarTitle(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: colorScheme.primary,
        leading:
            widget.onBackPressed != null && _currentPage == 0
                ? IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: widget.onBackPressed,
                )
                : _currentPage > 0
                ? IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: _previousPage,
                )
                : null,
        elevation: 1,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 12.0,
            ),
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
                    setState(() {
                    _currentPage = page;
                    });
                }
              },
              children: pages,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 16.0,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min, 
              children: [
                if (isLastPage) 
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(
                        bottom: 8.0,
                      ), 
                      child: TextButton(
                        child: const Text('Clear Concerns'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.grey[700],
                        ),
                        onPressed: _clearConcerns,
                      ),
                    ),
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    SizedBox(
                      width: buttonSize + 8, 
                      height: buttonSize,
                      child: Opacity(
                        opacity: _currentPage > 0 ? 1.0 : 0.0,
                        child: IgnorePointer(
                          ignoring: _currentPage == 0,
                          child: ElevatedButton(
                            onPressed: _previousPage,
                            child: const Icon(
                              Icons.arrow_back_ios_new,
                              size: 20,
                            ),
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
                    if (isLastPage)
                      ElevatedButton(
                        child: const Text('Save Profile'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromARGB(
                            255,
                            170,
                            136,
                            176,
                          ),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 12,
                          ), 
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        onPressed: _saveProfile,
                      ),
                    SizedBox(
                      width: buttonSize + 8,
                      height: buttonSize,
                      child: Opacity(
                        opacity: !isLastPage ? 1.0 : 0.0,
                        child: IgnorePointer(
                          ignoring: isLastPage,
                          child: ElevatedButton(
                            onPressed: _nextPage,
                            child: const Icon(
                              Icons.arrow_forward_ios,
                              size: 20,
                            ),
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
        ],
      ),
    );
  }
}