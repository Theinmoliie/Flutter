import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../util/safetyscore_util.dart';
import '../providers/skin_profile_provider.dart';

class CompatibilityTab extends StatelessWidget {
  final String productName;
  final String brand;
  final String? imageUrl;
  final File? imageFile;
  final double? averageScore;
  final List<Map<String, dynamic>> matchedIngredients;
  final List<String> unmatchedIngredients;
  final List<Map<String, dynamic>> compatibilityResults;
  final bool isLoadingCompatibility;
  final double? compatibilityScore;
  final String recommendationStatus;
  final VoidCallback? onProfileRequested;
  final Map<int, String> skinTypeMap;
  final Map<int, String> concernMap;

  const CompatibilityTab({
    super.key,
    required this.productName,
    required this.brand,
    this.imageUrl,
    this.imageFile,
    this.averageScore,
    required this.matchedIngredients,
    required this.unmatchedIngredients,
    required this.compatibilityResults,
    required this.isLoadingCompatibility,
    this.compatibilityScore,
    required this.recommendationStatus,
    this.onProfileRequested,
    required this.skinTypeMap,
    required this.concernMap,
  });

  String getSkinTypeName(int id) => skinTypeMap[id] ?? "Unknown";
  String getConcernName(int id) => concernMap[id] ?? "Unknown";

  bool _hasSafetyWarning(Map<String, dynamic> ingredient) {
    final allergies =
        ingredient['Allergies_Immunotoxicity']?.toString().toLowerCase() ?? '';
    final irritation = ingredient['Irritation']?.toString().toLowerCase() ?? '';
    final isComedogenic = ingredient['Comodogenic'] == true;

    return allergies.contains('moderate') ||
        allergies.contains('high') ||
        irritation.contains('moderate') ||
        irritation.contains('high') ||
        isComedogenic;
  }

List<Map<String, dynamic>> _getWarnings(Map<String, dynamic> ingredient) {
    final warnings = <Map<String, dynamic>>[];

     if (ingredient['Comodogenic'] == true) {
    warnings.add({
      'text': 'Comedogenic: May clog pores',
      'color': Colors.purple,  // Purple color
      'icon': Icons.face,      // Face icon
    });
  }

   // Allergy warnings
  final allergies = ingredient['Allergies_Immunotoxicity']?.toString().toLowerCase() ?? '';
  if (allergies.contains('high') ||
      allergies.contains('moderate')) {
    final isHigh = allergies.contains('high');
    warnings.add({
      'text': 'Allergy risk: ${ingredient['Allergies_Immunotoxicity']?.toString().toUpperCase() ?? ''}',
      'color': isHigh ? Colors.red : Colors.orange,
      'icon': isHigh ? Icons.dangerous : Icons.warning,
    });
  }

  // Irritation warnings
  final irritation = ingredient['Irritation']?.toString().toLowerCase() ?? '';
  if (irritation.contains('high') ||
      irritation.contains('moderate')) {
    final isHigh = irritation.contains('high');
    warnings.add({
      'text': 'Irritation risk: ${ingredient['Irritation']?.toString().toUpperCase() ?? ''}',
      'color': isHigh ? Colors.red : Colors.orange,
      'icon': isHigh ? Icons.dangerous : Icons.warning,
    });
  }

    return warnings;
  }

  @override
  Widget build(BuildContext context) {
    // Use theme colors
    final colorScheme = Theme.of(context).colorScheme;
    
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            "Product Analysis",
            style: TextStyle(color: Colors.white), // Explicit white text
          ),

          backgroundColor: colorScheme.primary,
          bottom: const TabBar(
            labelColor: Colors.white, // Active tab text
            unselectedLabelColor: Colors.white70, // Inactive tab text
            tabs: [Tab(text: 'Safety Score'), Tab(text: 'Compatibility')],
          ),
        ),
        body: TabBarView(
          children: [
            _buildSafetyTab(context), // Pass context here
            _buildCompatibilityTab(context), // Pass context here
          ],
        ),
      ),
    );
  }

  Widget _buildSafetyTab(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        Column(
          children: [
            Text(
              productName,
              style: const TextStyle(
                fontSize: 22, 
                fontWeight: FontWeight.bold
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              brand,
              style: TextStyle(
                fontSize: 16, 
                color: Colors.grey[600]
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
          ],
        ),
        
          Center(
            child: SizedBox(
              width: double.infinity,
              height: 300,
              child:
                  imageFile != null
                      ? Image.file(imageFile!, fit: BoxFit.contain)
                      : (imageUrl?.isNotEmpty ?? false)
                      ? Image.network(imageUrl!, fit: BoxFit.contain)
                      : Image.asset(
                        'assets/placeholder.png',
                        fit: BoxFit.contain,
                      ),
            ),
          ),
          const SizedBox(height: 10),

          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: Image.asset(
              'assets/SafetyScale.png',
              height: 50,
              width: double.infinity,
            ),
          ),
          const SizedBox(height: 10),

          if (averageScore != null)
            Center(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: ProductScorer.getScoreColor(averageScore!),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "Average Safety Score: ${averageScore!.toStringAsFixed(1)}",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 20),

          Text(
            "Matched Ingredients:",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),

          matchedIngredients.isEmpty
              ? const Text("No matching ingredients found.")
              : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: matchedIngredients.length,
                itemBuilder: (context, index) {
                  final ingredient = matchedIngredients[index];
                  int score = ingredient['Score'] ?? 0;
                  double similarityScore = ingredient['similarityScore'] ?? 1.0;
                  String originalIngredient =
                      ingredient['originalIngredient'] ??
                      ingredient['Ingredient_Name'];

                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Theme(
                      data: Theme.of(
                        context,
                      ).copyWith(dividerColor: Colors.transparent),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: ExpansionTile(
                          tilePadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          backgroundColor: Colors.white,
                          collapsedBackgroundColor: Colors.white,
                          leading: Container(
                            width: 35,
                            height: 35,
                            decoration: BoxDecoration(
                              color: ProductScorer.getScoreColor(
                                score.toDouble(),
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                "$score",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          title: Text(
                            ingredient['Ingredient_Name'] ?? "Not Specified",
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle:
                              similarityScore < 1.0
                                  ? Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Original: $originalIngredient",
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      Wrap(
                                        children: [
                                          Text(
                                            "Similarity: ${(similarityScore * 100).toStringAsFixed(1)}%",
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          const Tooltip(
                                            message:
                                                "This ingredient was matched using fuzzy logic.",
                                            child: Text(
                                              "⚠️ Not an exact match",
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.orange,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  )
                                  : null,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.only(
                                  bottomLeft: Radius.circular(15),
                                  bottomRight: Radius.circular(15),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "🔬 Other Concerns: ${ingredient['Other_Concerns'] ?? 'Not Specified'}",
                                  ),
                                  ProductScorer.buildRiskIndicator(
                                    " Cancer Concern",
                                    ingredient['Cancer_Concern'],
                                  ),
                                  ProductScorer.buildRiskIndicator(
                                    " Allergies",
                                    ingredient['Allergies_Immunotoxicity'],
                                  ),
                                  ProductScorer.buildRiskIndicator(
                                    " Developmental Toxicity",
                                    ingredient['Developmental_Reproductive_Toxicity'],
                                  ),
                                  const SizedBox(height: 5),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),

          if (unmatchedIngredients.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text(
              "Unmatched Ingredients:",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: unmatchedIngredients.length,
              itemBuilder: (context, index) {
                final ingredient = unmatchedIngredients[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 5),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text(
                      ingredient,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                );
              },
            ),
          ],

          const Padding(
            padding: EdgeInsets.only(top: 20),
            child: Text(
              "Safety ratings from EWG's Skin Deep database",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompatibilityTab(BuildContext context) {
    final skinProfile = Provider.of<SkinProfileProvider>(context);

    // Calculate ingredient categories
    final beneficialIngredients =
        matchedIngredients.where((ingredient) {
          final results = compatibilityResults.where(
            (r) =>
                r['ingredient_name'] == ingredient['Ingredient_Name'] &&
                r['is_suitable'] == true,
          );
          return results.isNotEmpty;
        }).toList();

    final potentialHazards =
        matchedIngredients.where((ingredient) {
          final results = compatibilityResults.where(
            (r) =>
                r['ingredient_name'] == ingredient['Ingredient_Name'] &&
                r['is_suitable'] == false,
          );
          return results.isNotEmpty || _hasSafetyWarning(ingredient);
        }).toList();

    final noDataIngredients =
        matchedIngredients.where((ingredient) {
          return !compatibilityResults.any(
            (r) => r['ingredient_name'] == ingredient['Ingredient_Name'],
          );
        }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildProductHeader(),
          const SizedBox(height: 20),

          if (skinProfile.userSkinTypeId == null || skinProfile.userSensitivityLevel == null)
            _buildProfileSetupPrompt(context)
          else if (isLoadingCompatibility)
            const CircularProgressIndicator()
          else
            Column(
              children: [
                _buildScoreSection(context),
                const SizedBox(height: 20),

                Column(
                  children: [
                    _buildVerticalCard(
                      title: "Beneficial Ingredients",
                      count: beneficialIngredients.length,
                      icon: Icons.check_circle,
                      iconColor: Colors.green,
                      ingredients: beneficialIngredients,
                      isPositive: true,
                      context: context, // Add this
                    ),
                    const SizedBox(height: 12),
                    _buildVerticalCard(
                      title: "Potential Hazards",
                      count: potentialHazards.length,
                      icon: Icons.warning,
                      iconColor: Colors.orange,
                      ingredients: potentialHazards,
                      isPositive: false,
                      context: context, // Add this
                    ),
                    const SizedBox(height: 12),
                    _buildVerticalCard(
                      title: "No Data Available",
                      count: noDataIngredients.length,
                      icon: Icons.help_outline,
                      iconColor: Colors.grey,
                      ingredients: noDataIngredients,
                      isPositive: null,
                      context: context, // Add this
                    ),
                  ],
                ),
              ],
            ),

          const Padding(
            padding: EdgeInsets.only(top: 20),
            child: Text(
              "Analysis is based on available data for ingredient suitability. "
              "Unanalyzed ingredients are not included. For accurate advice, consult a dermatologist.",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductHeader() {
    return Column(
      children: [
        Text(
          productName,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(brand, style: TextStyle(fontSize: 16, color: Colors.grey[600])),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child:
              imageFile != null
                  ? Image.file(
                    imageFile!,
                    height: 180,
                    width: 180,
                    fit: BoxFit.cover,
                  )
                  : (imageUrl?.isNotEmpty ?? false)
                  ? Image.network(
                    imageUrl!,
                    height: 180,
                    width: 180,
                    fit: BoxFit.cover,
                  )
                  : Image.asset(
                    'assets/placeholder.png',
                    height: 180,
                    width: 180,
                    fit: BoxFit.cover,
                  ),
        ),
      ],
    );
  }

  Widget _buildProfileSetupPrompt(BuildContext context) {
    return Column(
      children: [
        const Text(
          "Please set your skin profile to view compatibility analysis",
          style: TextStyle(fontSize: 16, color: Colors.red),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        ElevatedButton(
           onPressed: () {
          if (onProfileRequested != null) {
            onProfileRequested!();
            // Add this to ensure the profile screen is shown immediately
            Navigator.of(context, rootNavigator: true).pop();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Navigation not available')),
            );
          }
        },        
            style: ElevatedButton.styleFrom(
            backgroundColor:  Colors.brown[900],
            
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: const Text(
            "Set Skin Profile",
            style: TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }

   // product_analysis.dart

  // ... (other parts of the CompatibilityTab class) ...

  // product_analysis.dart

// ... (imports and other parts of the class)

  Widget _buildScoreSection(BuildContext context) {
    final skinProfile = Provider.of<SkinProfileProvider>(
      context,
      listen: false,
    );

    if (skinProfile.userSkinTypeId == null) {
        // ... (existing profile setup prompt logic) ...
         return Column(
            children: [
                const Text(
                    "Please set your skin profile first.",
                    style: TextStyle(fontSize: 16, color: Colors.orange),
                    textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                 ElevatedButton(
                    onPressed: onProfileRequested,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.brown[900],
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Text(
                        "Set Skin Profile",
                        style: TextStyle(color: Colors.white),
                    ),
                 ),
            ]
        );
    }

    if (compatibilityScore == null) {
        // ... (existing score not available logic) ...
        return const Center(
            child: Text(
                "Compatibility score not available yet.",
                style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
        );
    }

    final scoreColor =
        compatibilityScore! >= 65
            ? Colors.green
            : compatibilityScore! >= 40
            ? Colors.orange
            : Colors.red;

    // Get descriptive names for profile items
    final skinTypeName = getSkinTypeName(skinProfile.userSkinTypeId!);
    final sensitivityLevel = skinProfile.userSensitivityLevel ?? 'Unknown'; // Handle potential null from provider

    // --- MODIFIED: Handle empty concern list ---
    final String concernText;
    if (skinProfile.userConcernIds.isEmpty) {
        concernText = "no specific concerns selected"; // Text for 'None' case
    } else {
        concernText = "concerns of ${skinProfile.userConcernIds.map((id) => getConcernName(id)).join(", ")}"; // Original text
    }
    // --- END MODIFIED ---

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Text(
            // --- UPDATED: Use concernText variable ---
            "Analysis for $skinTypeName skin "
            "($sensitivityLevel Sensitivity) with $concernText.",
            // --- END UPDATED ---
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 12),

        // --- The Score Display Container (No changes needed here) ---
        Container(
           // ... (rest of the score container code) ...
           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
           decoration: BoxDecoration(
             color: scoreColor.withOpacity(0.1),
             borderRadius: BorderRadius.circular(12),
             border: Border.all(color: scoreColor.withOpacity(0.3), width: 1),
           ),
           child: Row(
             mainAxisAlignment: MainAxisAlignment.spaceBetween,
             children: [
               Expanded(
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Text(
                       "COMPATIBILITY",
                       style: TextStyle(
                         fontSize: 12,
                         color: Colors.grey[600],
                         fontWeight: FontWeight.bold,
                         letterSpacing: 0.5,
                       ),
                     ),
                     const SizedBox(height: 4),
                     Text(
                       recommendationStatus,
                       style: TextStyle(
                         fontSize: 16,
                         fontWeight: FontWeight.bold,
                         color: scoreColor,
                       ),
                       maxLines: 2,
                       overflow: TextOverflow.ellipsis,
                     ),
                   ],
                 ),
               ),
               Container(
                 padding: const EdgeInsets.symmetric(
                   horizontal: 12,
                   vertical: 8,
                 ),
                 decoration: BoxDecoration(
                   color: scoreColor.withOpacity(0.2),
                   borderRadius: BorderRadius.circular(20),
                 ),
                 child: Row(
                   mainAxisSize: MainAxisSize.min,
                   children: [
                     Text(
                       "${compatibilityScore!.toStringAsFixed(1)}%",
                       style: TextStyle(
                         fontSize: 18,
                         fontWeight: FontWeight.bold,
                         color: scoreColor,
                       ),
                     ),
                     const SizedBox(width: 4),
                     Icon(
                       compatibilityScore! >= 65
                           ? Icons.check_circle
                           : compatibilityScore! >= 40
                           ? Icons.warning_amber_rounded
                           : Icons.error_outline,
                       size: 18,
                       color: scoreColor,
                     ),
                   ],
                 ),
               ),
             ],
           ),
        ),
      ],
    );
  }

  Widget _buildVerticalCard({
    required String title,
    required int count,
    required IconData icon,
    required Color iconColor,
    required List<Map<String, dynamic>> ingredients,
    required bool? isPositive,
    required BuildContext context, // Add context parameter
  }) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          _showIngredientsDetails(
            title: title,
            ingredients: ingredients,
            isPositive: isPositive,
            context: context,
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 24, color: iconColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "$count ingredients found",
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "$count",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: iconColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showIngredientsDetails({
    required String title,
    required List<Map<String, dynamic>> ingredients,
    required bool? isPositive,
    required BuildContext context, // Add context parameter
  }) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  children:
                      ingredients.isEmpty
                          ? [
                            const Text("No ingredients found in this category"),
                          ]
                          : ingredients
                              .map(
                                (ingredient) => _buildIngredientListItem(
                                  context: context, // Pass context here
                                  ingredient: ingredient,
                                  isPositive: isPositive,
                                ),
                              )
                              .toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildIngredientListItem({
    required Map<String, dynamic> ingredient,
    required bool? isPositive,
    required BuildContext context,
  }) {
    final benefits = ingredient['Benefits']?.toString() ?? 'No benefits data';
    final warnings = _getWarnings(ingredient);
    final skinProfile = Provider.of<SkinProfileProvider>(
      context,
      listen: false,
    );

    final ingredientResults =
        compatibilityResults
            .where((r) => r['ingredient_name'] == ingredient['Ingredient_Name'])
            .toList();

    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ingredient['Ingredient_Name'] ?? 'Unknown',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          if (isPositive == true) ...[
            ...ingredientResults.map(
              (result) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green[50]?.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Colors.green[700],
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  result['type'] == 'skin_type'
                                      ? "Good for ${getSkinTypeName(skinProfile.userSkinTypeId!)} skin"
                                      : "Helps with ${getConcernName(result['concern_id'])}",
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            benefits == 'No benefits data'
                ? Text(
                  benefits,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                )
                : ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50]?.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        benefits,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                ),
          ],

          if (isPositive == false) ...[
            ...ingredientResults
                .where((r) => r['is_suitable'] == false)
                .map(
                  (result) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red[50]?.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.dangerous,
                                color: Colors.red[700],
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      result['type'] == 'skin_type'
                                          ? "Not ideal for ${getSkinTypeName(skinProfile.userSkinTypeId!)} skin"
                                          : "May worsen ${getConcernName(result['concern_id'])}",
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            if (warnings.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...warnings.map(
                (warning) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange[50]?.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              warning['icon'],
                              color: warning['color']?[700],
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                warning['text'],  // Convert here
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],

          if (isPositive == null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[200]?.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    "We're still gathering insights for this ingredient",
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
