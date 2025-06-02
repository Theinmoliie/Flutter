// screens/routine_display_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart'; // For SetEquality
import '../providers/skin_profile_provider.dart';
import '../services/skincare_routine_service.dart';
import '../model/routine_models.dart'; // Ensure this path is correct
import '../UserProfile/multi_screen.dart'; // For navigation

// Enum to represent the selected routine time
enum RoutineTime { morning, night }

class RoutineDisplayScreen extends StatefulWidget {
  const RoutineDisplayScreen({Key? key}) : super(key: key);

  @override
  _RoutineDisplayScreenState createState() => _RoutineDisplayScreenState();
}

class _RoutineDisplayScreenState extends State<RoutineDisplayScreen> {
  final SkincareRoutineService _routineService = SkincareRoutineService();
  SkincareRoutine? _skincareRoutine;
  bool _isLoading = true;
  String? _errorMessage;

  // --- To track the previous state of the provider for comparison ---
  int? _lastSkinTypeId;
  String? _lastSensitivity;
  Set<int>? _lastConcernIds;
  // --- ---

  // --- NEW STATE VARIABLE for AM/PM toggle ---
  RoutineTime _selectedRoutineTime = RoutineTime.morning; // Default to morning

  @override
  void initState() {
    super.initState();
    // Initial fetch after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Store initial provider state before first fetch
        final initialProfileProvider = Provider.of<SkinProfileProvider>(context, listen: false);
        _updateLastKnownProfileState(initialProfileProvider);
        _fetchRoutine();
      }
    });
  }

  // Helper to store the last known state of relevant profile data
  void _updateLastKnownProfileState(SkinProfileProvider provider) {
    _lastSkinTypeId = provider.userSkinTypeId;
    _lastSensitivity = provider.userSensitivity;
    _lastConcernIds = provider.userConcernIds.toSet(); // Store as a set for easy comparison
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (mounted) {
      // Listen to the provider to detect changes
      final currentProfileProvider = Provider.of<SkinProfileProvider>(context /*, listen: true is default */);

      bool profileHasChanged = false;
      if (_lastSkinTypeId == null && currentProfileProvider.userSkinTypeId != null) {
        // This handles the case where the profile was initially null and now has data
        profileHasChanged = true;
      } else if (_lastSkinTypeId != currentProfileProvider.userSkinTypeId ||
          _lastSensitivity != currentProfileProvider.userSensitivity ||
          !SetEquality().equals(_lastConcernIds, currentProfileProvider.userConcernIds.toSet())) {
        profileHasChanged = true;
      }

      if (profileHasChanged) {
        print("Profile data changed in didChangeDependencies, re-fetching routine.");
        _updateLastKnownProfileState(currentProfileProvider); // Update our tracker
        _fetchRoutine();
      }
    }
  }

  Future<void> _fetchRoutine() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Get the most current provider state for fetching
    final profileProvider = Provider.of<SkinProfileProvider>(context, listen: false);

    if (profileProvider.userSkinTypeId == null || profileProvider.userSensitivity == null) {
      print("Profile not set, showing prompt.");
      setState(() {
        _isLoading = false;
        _errorMessage = "PROFILE_NOT_SET";
      });
      return;
    }

    print("Profile is set, attempting to build routine.");
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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (routeContext) => MultiPageSkinProfileScreen(
          onProfileSaved: (profileData) {
            Navigator.of(routeContext).pop();
          },
          onBackPressed: () {
            Navigator.of(routeContext).pop();
          },
        ),
      ),
    );
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
              onPressed: _navigateToProfileScreen,
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
    Provider.of<SkinProfileProvider>(context); // Establishes dependency for didChangeDependencies

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Skincare Routine', style: TextStyle(color: Colors.white)),
        backgroundColor: Theme.of(context).colorScheme.primary,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _buildBodyWithToggle(), // Changed to use the new body builder
    );
  }

  // --- NEW: Method to build the AM/PM toggle ---
  Widget _buildAmPmToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
      child: Center(
        child: Container(
          decoration: BoxDecoration(
            // Optional: Add a background to the toggle container itself for better visual separation
            // color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
            // borderRadius: BorderRadius.circular(12.0),
          ),
          child: ToggleButtons(
            isSelected: [
              _selectedRoutineTime == RoutineTime.morning,
              _selectedRoutineTime == RoutineTime.night,
            ],
            onPressed: (int index) {
              if (!mounted) return;
              setState(() {
                _selectedRoutineTime = index == 0 ? RoutineTime.morning : RoutineTime.night;
              });
            },
            borderRadius: BorderRadius.circular(10.0),
            selectedColor: Colors.white,
            color: Theme.of(context).colorScheme.primary.withOpacity(0.7), // Icon color when not selected
            fillColor: Theme.of(context).colorScheme.primary, // Background of selected button
            splashColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
            borderColor: Theme.of(context).colorScheme.outline.withOpacity(0.5),
            selectedBorderColor: Theme.of(context).colorScheme.primary,
            borderWidth: 1.5,
            constraints: const BoxConstraints(minHeight: 48.0, minWidth: 100.0), // Ensure buttons have good tap area
            children: const <Widget>[
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.wb_sunny_outlined, size: 22),
                    SizedBox(width: 8),
                    Text("AM", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.nights_stay_outlined, size: 22),
                    SizedBox(width: 8),
                    Text("PM", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- MODIFIED: Main body builder to include toggle ---
  Widget _buildBodyWithToggle() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage == "PROFILE_NOT_SET") {
      return _buildProfileSetupPrompt();
    }
    if (_errorMessage != null) {
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
                onPressed: _fetchRoutine,
                child: const Text('Try Again'),
              ),
              const SizedBox(height: 10),
              TextButton(
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

    return Column(
      children: [
        _buildAmPmToggle(), // Add the toggle button
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0), // Adjusted top padding
            children: [
              // Conditionally render the selected routine
              if (_selectedRoutineTime == RoutineTime.morning)
                _buildRoutineSection("Morning Routine", _skincareRoutine!.morningRoutine)
              else // It must be night
                _buildRoutineSection("Night Routine", _skincareRoutine!.nightRoutine),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRoutineSection(String title, List<RoutineStep> steps) {
     return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The title is now implicitly handled by the toggle, but you can keep it if you like
        // Padding(
        //   padding: const EdgeInsets.only(bottom: 8.0),
        //   child: Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
        // ),
        if (steps.isEmpty && (_skincareRoutine?.morningRoutine.every((s) => s.recommendedProducts.isEmpty) ?? true) && (_skincareRoutine?.nightRoutine.every((s) => s.recommendedProducts.isEmpty) ?? true) )
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16.0),
            child: Center(child: Text("No products could be recommended for your current profile. Please ensure your profile is complete or try adjusting your concerns.", style: TextStyle(fontStyle: FontStyle.italic, color: Colors.orangeAccent), textAlign: TextAlign.center,)),
          )
        else if (steps.isEmpty) const Padding(
          padding: EdgeInsets.symmetric(vertical: 16.0),
          child: Center(child: Text("No steps defined for this routine.", style: TextStyle(fontStyle: FontStyle.italic), textAlign: TextAlign.center,)),
        ),
        ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: steps.length,
            itemBuilder: (context, index) {
              final step = steps[index];
              return Card(
                elevation: 2.0,
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${step.stepName} (${step.productTypeExpected})",
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        step.recommendedProducts.isEmpty
                            ? "No suitable products found for your profile."
                            : "${step.recommendedProducts.length} product(s) recommended:",
                        style: TextStyle(
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                          color: step.recommendedProducts.isEmpty ? Colors.orangeAccent : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (step.recommendedProducts.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(
                            "Try adjusting your skin concerns or check back later!",
                            style: TextStyle(color: Colors.grey[700]),
                          ),
                        )
                      else
                        SizedBox(
                          height: 240, // Height of the horizontal product list
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: step.recommendedProducts.length,
                            itemBuilder: (context, productIndex) {
                              final product = step.recommendedProducts[productIndex];
                              return _buildProductCard(product);
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildProductCard(RecommendedProduct product) {
     return SizedBox(
      width: 180,
      child: Card(
        elevation: 1.5,
        margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            _showProductDetailsModal(context, product);
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 110,
                  width: double.infinity,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey[200],
                    ),
                    child: product.imageUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              product.imageUrl!,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5)));
                              },
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.broken_image, size: 40, color: Colors.grey),
                            ),
                          )
                        : const Icon(Icons.spa_outlined, size: 40, color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  product.name,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (product.brand != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 3.0),
                    child: Text(
                      product.brand!,
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                const Spacer(),
                if (product.price != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      "\RM${product.price!.toStringAsFixed(2)}",
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  // --- NEW: Method to show product details in a modal bottom sheet ---
  void _showProductDetailsModal(BuildContext context, RecommendedProduct product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allows the sheet to take up more height
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      builder: (BuildContext bmsContext) {
        return DraggableScrollableSheet( // Makes content scrollable within the sheet
          initialChildSize: 0.6, // Start at 60% of screen height
          minChildSize: 0.4,   // Min at 40%
          maxChildSize: 0.9,   // Max at 90%
          expand: false, // Important: set to false
          builder: (BuildContext _, ScrollController scrollController) {
            return Container(
              padding: const EdgeInsets.all(20.0),
              child: ListView( // Use ListView for scrollable content
                controller: scrollController,
                children: <Widget>[
                  // Drag Handle (Optional but good UX)
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 15.0),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  // Product Image (Larger)
                  if (product.imageUrl != null && product.imageUrl!.isNotEmpty)
                    Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12.0),
                        child: Image.network(
                          product.imageUrl!,
                          height: 180, // Larger image in modal
                          width: 180,
                          fit: BoxFit.contain, // Use contain to see full image
                           errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.broken_image, size: 100, color: Colors.grey),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  // Product Name
                  Text(
                    product.name,
                    style: Theme.of(bmsContext).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  // Brand
                  if (product.brand != null)
                    Center(
                      child: Text(
                        "Brand: ${product.brand!}",
                        style: Theme.of(bmsContext).textTheme.titleMedium?.copyWith(color: Colors.grey[700]),
                      ),
                    ),
                  const SizedBox(height: 8),
                  // Price
                  if (product.price != null)
                    Center(
                      child: Text(
                        "\RM${product.price!.toStringAsFixed(2)}",
                        style: Theme.of(bmsContext).textTheme.titleLarge?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                  const SizedBox(height: 4),
                  // Similarity Score (Optional)
                  // if (product.similarityScore != null)
                  //    Center(
                  //      child: Text(
                  //        "Relevance: ${(product.similarityScore! * 100).toStringAsFixed(0)}%",
                  //        style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic),
                  //      ),
                  //    ),

                  const Divider(height: 32, thickness: 1),
                  // Product Description
                  Text(
                    "Description:",
                    style: Theme.of(bmsContext).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    product.description != null && product.description!.isNotEmpty
                        ? product.description!
                        : "No description available for this product.",
                    style: Theme.of(bmsContext).textTheme.bodyMedium?.copyWith(height: 1.5),
                  ),
                  const SizedBox(height: 20), // Space at the bottom
                ],
              ),
            );
          },
        );
      },
    );
  }

}