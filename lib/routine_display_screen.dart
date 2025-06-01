// screens/routine_display_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart'; // For SetEquality
import '../providers/skin_profile_provider.dart';
import '../services/skincare_routine_service.dart';
import '../model/routine_models.dart'; // Ensure this path is correct
import '../UserProfile/multi_screen.dart'; // For navigation

class RoutineDisplayScreen extends StatefulWidget {
  final VoidCallback? onNavigateToProfile; // Callback to tell MainScreen to switch

  const RoutineDisplayScreen({Key? key, this.onNavigateToProfile}) : super(key: key);

  @override
  _RoutineDisplayScreenState createState() => _RoutineDisplayScreenState();
}

class _RoutineDisplayScreenState extends State<RoutineDisplayScreen> {
  final SkincareRoutineService _routineService = SkincareRoutineService();
  SkincareRoutine? _skincareRoutine;
  bool _isLoading = true;
  String? _errorMessage;
  SkinProfileProvider? _profileProviderRef; // To store and compare

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) { // Ensure mounted before accessing context
        _profileProviderRef = Provider.of<SkinProfileProvider>(context, listen: false);
        _fetchRoutine();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (mounted) { // Ensure mounted
        final currentProfileProvider = Provider.of<SkinProfileProvider>(context, listen: true); // Listen for changes

        // Check if it's the first load or if critical data has changed
        bool shouldRefresh = false;
        if (_profileProviderRef == null) { // First time didChangeDependencies is called after initState
             shouldRefresh = true; // Or rely on initState's fetch
        } else {
            // Compare relevant parts of the profile
            if (_profileProviderRef!.userSkinTypeId != currentProfileProvider.userSkinTypeId ||
                _profileProviderRef!.userSensitivity != currentProfileProvider.userSensitivity ||
                !SetEquality().equals(
                    _profileProviderRef!.userConcernIds.toSet(),
                    currentProfileProvider.userConcernIds.toSet()
                )) {
                shouldRefresh = true;
            }
        }

        if (shouldRefresh) {
            print("Profile data changed or initial load in didChangeDependencies, re-fetching routine.");
            _profileProviderRef = currentProfileProvider; // Update the reference
            _fetchRoutine();
        }
    }
  }


  Future<void> _fetchRoutine() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null; // Reset error message on new fetch
    });

    // Use the stored _profileProviderRef if available, otherwise get a fresh one
    final profileProvider = _profileProviderRef ?? Provider.of<SkinProfileProvider>(context, listen: false);

    // Check if profile is complete before attempting to build routine
    if (profileProvider.userSkinTypeId == null || profileProvider.userSensitivity == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = "PROFILE_NOT_SET"; // Special error code
      });
      return;
    }

    try {
      final routine = await _routineService.buildRoutine(
        skinTypeId: profileProvider.userSkinTypeId,
        sensitivity: profileProvider.userSensitivity,
        concernIds: profileProvider.userConcernIds.toSet(),
      );
      if (mounted) {
        setState(() {
          _skincareRoutine = routine;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Failed to build routine: ${e.toString()}";
        });
      }
    }
  }

  void _navigateToProfileScreen() {
    // This function will push MultiPageSkinProfileScreen
    // and trigger a re-fetch of the routine when it's popped after saving.
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (routeContext) => MultiPageSkinProfileScreen(
          onProfileSaved: (profileData) {
            Navigator.of(routeContext).pop(); // Pop the profile screen
            // The didChangeDependencies or a direct call to _fetchRoutine will handle refresh
            // _fetchRoutine(); // Explicitly call after profile is saved and popped
          },
          onBackPressed: () {
            Navigator.of(routeContext).pop(); // Just pop if back is pressed
          },
        ),
      ),
    ).then((_) {
        // This .then() block executes after MultiPageSkinProfileScreen is popped.
        // If onProfileSaved was called, the Provider would have updated.
        // didChangeDependencies should pick up the change.
        // If you want to be absolutely sure, you can call _fetchRoutine here,
        // but it might be redundant if didChangeDependencies is working correctly.
        print("Returned from profile screen. Checking if refresh needed.");
        // _fetchRoutine(); // Consider if this is needed or if didChangeDependencies is sufficient
    });
  }


  Widget _buildProfileSetupPrompt() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.person_search_rounded, size: 60, color: Theme.of(context).colorScheme.primary.withOpacity(0.7)),
            const SizedBox(height: 20),
            const Text(
              "Personalize Your Skincare Routine",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              "Please set up your skin profile so we can recommend the best products for you.",
              style: TextStyle(fontSize: 15, color: Colors.grey[700]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.edit_note_rounded, color: Colors.white),
              label: const Text("Set Skin Profile", style: TextStyle(color: Colors.white)),
              onPressed: _navigateToProfileScreen, // Use the new navigation method
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
            ),
          ],
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    // Ensure provider is listened to for didChangeDependencies to work effectively
    // Provider.of<SkinProfileProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Skincare Routine', style: TextStyle(color: Colors.white)),
        backgroundColor: Theme.of(context).colorScheme.primary,
        iconTheme: const IconThemeData(color: Colors.white), // For back button if pushed
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      if (_errorMessage == "PROFILE_NOT_SET") {
        return _buildProfileSetupPrompt();
      }
      // General error message
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.red[400], size: 50),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red[700], fontSize: 16)
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _fetchRoutine, // Retry fetching
                child: const Text('Try Again'),
              ),
              const SizedBox(height: 10),
              TextButton( // Option to go to profile settings
                onPressed: _navigateToProfileScreen,
                child: const Text('Check Profile Settings'),
              )
            ],
          ),
        ),
      );
    }
    if (_skincareRoutine == null) {
      return Center(
          child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Could not generate a routine at this time.'),
          const SizedBox(height: 10),
          ElevatedButton(onPressed: _fetchRoutine, child: const Text("Retry"))
        ],
      ));
    }

    // ... (rest of your _buildRoutineSection and ListView for displaying the routine)
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildRoutineSection("Morning Routine", _skincareRoutine!.morningRoutine),
        const SizedBox(height: 24),
        _buildRoutineSection("Night Routine", _skincareRoutine!.nightRoutine),
      ],
    );
  }

  Widget _buildRoutineSection(String title, List<RoutineStep> steps) {
    // ... (your existing _buildRoutineSection implementation)
     return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        if (steps.isEmpty) const Padding(
          padding: EdgeInsets.symmetric(vertical: 8.0),
          child: Text("No steps defined for this routine, or profile needs completion.", style: TextStyle(fontStyle: FontStyle.italic)),
        ),
        ...steps.map((step) {
          bool productFound = step.recommendedProduct != null;
          return Card(
            elevation: 2.0,
            margin: const EdgeInsets.symmetric(vertical: 8.0),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey[200],
                    ),
                    child: productFound && step.recommendedProduct!.imageUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              step.recommendedProduct!.imageUrl!,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return Center(child: CircularProgressIndicator(
                                  value: progress.expectedTotalBytes != null
                                      ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                                      : null,
                                  strokeWidth: 2.0,
                                ));
                              },
                              errorBuilder: (context, error, stackTrace) =>
                                  Icon(Icons.broken_image, size: 30, color: Colors.grey[400]),
                            ),
                          )
                        : Icon(Icons.spa_outlined, size: 30, color: Colors.grey[400]), // Placeholder for no image or no product
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "${step.stepName}",
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                         Text(
                          "(${step.productTypeExpected})",
                          style: TextStyle(fontSize: 13, color: Colors.grey[600], fontStyle: FontStyle.italic),
                        ),
                        const SizedBox(height: 6),
                        if (productFound) ...[
                          Text(
                            step.recommendedProduct!.name,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (step.recommendedProduct!.brand != null)
                            Text(
                              "Brand: ${step.recommendedProduct!.brand!}",
                              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                            ),
                          if (step.recommendedProduct!.price != null)
                            Text(
                              "Price: \$${step.recommendedProduct!.price!.toStringAsFixed(2)}",
                              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                            ),
                        ] else
                          const Text(
                            "No suitable product found for your profile.",
                            style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: Colors.orangeAccent),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ],
    );
  }
}