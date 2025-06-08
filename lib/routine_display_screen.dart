// lib/screens/routine_display_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart'; // For SetEquality
import '../providers/skin_profile_provider.dart';
import '../services/skincare_routine_service.dart';
import '../model/routine_models.dart';
import '../UserProfile/multi_screen.dart'; // For navigation

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

  // State to track if the initial profile check has been performed.
  bool _initialCheckDone = false;

  RoutineTime _selectedRoutineTime = RoutineTime.morning;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Use a flag to ensure the initial fetch only happens once,
    // subsequent builds will be handled by the Consumer.
    if (!_initialCheckDone) {
      _fetchRoutine();
      _initialCheckDone = true;
    }
  }

  Future<void> _fetchRoutine() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _skincareRoutine = null; // Clear previous routine on re-fetch
    });

    final profileProvider = Provider.of<SkinProfileProvider>(context, listen: false);

    // **CRITICAL CHECK**: Profile is incomplete if type OR sensitivity is null.
    if (profileProvider.userSkinTypeId == null || profileProvider.userSensitivity == null) {
      print("[RoutineScreen] Profile not fully set. Showing prompt.");
      setState(() {
        _isLoading = false;
        _errorMessage = "PROFILE_NOT_SET";
      });
      return;
    }

    print("[RoutineScreen] Profile is set, attempting to build routine.");
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
        print("[RoutineScreen] Error fetching routine: $_errorMessage");
      }
    }
  }

  // Navigate to the Profile Page for editing
  void _navigateToProfileScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        // The MultiPageSkinProfileScreen now handles its own state.
        // The `onBackPressed` is sufficient for navigation.
        builder: (context) => MultiPageSkinProfileScreen(
          onBackPressed: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Using Consumer to react to changes in the profile provider
    return Consumer<SkinProfileProvider>(
      builder: (context, profileProvider, child) {
        // This builder will re-run whenever notifyListeners() is called in the provider.
        // We can re-evaluate the state and re-fetch if necessary.
        // NOTE: The didChangeDependencies approach is generally more robust for this.
        // We will keep this simple and rely on didChangeDependencies for re-fetching.
        
        return Scaffold(
          appBar: AppBar(
            title: const Text('Your Skincare Routine', style: TextStyle(color: Colors.white)),
            backgroundColor: Theme.of(context).colorScheme.primary,
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              // Add a refresh button to manually re-fetch the routine
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh Routine',
                onPressed: _isLoading ? null : _fetchRoutine,
              )
            ],
          ),
          body: _buildBody(),
        );
      }
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage == "PROFILE_NOT_SET") {
      return _buildProfileSetupPrompt();
    }

    if (_errorMessage != null) {
      return _buildErrorState(_errorMessage!);
    }

    if (_skincareRoutine == null) {
      return _buildErrorState('Could not generate a routine at this time.');
    }
    
    // Main content with the toggle and routine list
    return Column(
      children: [
        _buildAmPmToggle(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 16.0),
            children: [
              _buildUserProfileSummary(),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: _selectedRoutineTime == RoutineTime.morning
                    ? _buildRoutineSection("Morning Routine", _skincareRoutine!.morningRoutine)
                    : _buildRoutineSection("Night Routine", _skincareRoutine!.nightRoutine),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  // --- UI HELPER WIDGETS ---

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

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red[400], size: 50),
            const SizedBox(height: 16),
            Text(
              message,
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
              child: const Text('Edit Profile Settings'),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildAmPmToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
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
        color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
        fillColor: Theme.of(context).colorScheme.primary,
        splashColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
        borderColor: Theme.of(context).colorScheme.outline.withOpacity(0.5),
        selectedBorderColor: Theme.of(context).colorScheme.primary,
        borderWidth: 1.5,
        constraints: const BoxConstraints(minHeight: 48.0, minWidth: 100.0),
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
    );
  }

  Widget _buildUserProfileSummary() {
    // This widget now reads directly from the provider within the build method
    final profileProvider = Provider.of<SkinProfileProvider>(context, listen: false);

    String skinType = profileProvider.userSkinType ?? "Not Set";
    String sensitivity = profileProvider.userSensitivity ?? "Not Set";
    String concerns = profileProvider.userConcerns.isEmpty
        ? "None"
        : profileProvider.userConcerns.join(', ');

    return Container(
      padding: const EdgeInsets.all(16.0),
      margin: const EdgeInsets.only(bottom: 16.0, left: 16.0, right: 16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_circle_outlined, color: Theme.of(context).colorScheme.primary, size: 26),
              const SizedBox(width: 8),
              Text(
                "Your Current Profile",
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              // Add an edit button that navigates to the profile screen
              IconButton(
                icon: Icon(Icons.edit, color: Colors.grey[600]),
                tooltip: 'Edit Profile',
                onPressed: _navigateToProfileScreen,
              )
            ],
          ),
          const Divider(height: 20, thickness: 1),
          _buildProfileDetailRow(icon: Icons.water_drop_outlined, label: "Skin Type:", value: skinType),
          const SizedBox(height: 8),
          _buildProfileDetailRow(icon: Icons.shield_outlined, label: "Sensitivity:", value: sensitivity),
          const SizedBox(height: 8),
          _buildProfileDetailRow(icon: Icons.healing_outlined, label: "Concerns:", value: concerns, isMultiline: true),
        ],
      ),
    );
  }
  
  Widget _buildProfileDetailRow({
    required IconData icon,
    required String label,
    required String value,
    bool isMultiline = false,
  }) {
     return Row(
      crossAxisAlignment: isMultiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            style: TextStyle(color: Colors.grey[800], fontSize: 14),
            softWrap: true,
          ),
        ),
      ],
    );
  }


  Widget _buildRoutineSection(String title, List<RoutineStep> steps) {
     return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (steps.isEmpty)
           Padding(
            padding: const EdgeInsets.symmetric(vertical: 24.0),
            child: Center(
              child: Text(
                "No products could be recommended for this routine based on your profile.",
                style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
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
                            ? "No suitable products found for this step."
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
                            "Try adjusting your skin concerns to see recommendations.",
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
          onTap: () => _showProductDetailsModal(context, product),
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

  void _showProductDetailsModal(BuildContext context, RecommendedProduct product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      builder: (BuildContext bmsContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (BuildContext _, ScrollController scrollController) {
            return Container(
              padding: const EdgeInsets.all(20.0),
              child: ListView(
                controller: scrollController,
                children: <Widget>[
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
                  if (product.imageUrl != null && product.imageUrl!.isNotEmpty)
                    Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12.0),
                        child: Image.network(
                          product.imageUrl!,
                          height: 180,
                          width: 180,
                          fit: BoxFit.contain,
                           errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.broken_image, size: 100, color: Colors.grey),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    product.name,
                    style: Theme.of(bmsContext).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  if (product.brand != null)
                    Center(
                      child: Text(
                        "Brand: ${product.brand!}",
                        style: Theme.of(bmsContext).textTheme.titleMedium?.copyWith(color: Colors.grey[700]),
                      ),
                    ),
                  const SizedBox(height: 8),
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
                  const Divider(height: 32, thickness: 1),
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
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }
}