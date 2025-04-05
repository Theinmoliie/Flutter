import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'score_util.dart';
import 'compatibility_util.dart';
import 'package:provider/provider.dart';
import './providers/skin_profile_provider.dart';

class SafetyResultScreen extends StatefulWidget {
  final int productId;
  final String productName;
  final String brand;
  final String imageUrl;
  final VoidCallback onProfileRequested; // Add this


  const SafetyResultScreen({
    required this.productId,
    required this.productName,
    required this.brand,
    required this.imageUrl,
    required this.onProfileRequested, // Add this
    Key? key,
  }) : super(key: key);

  @override
  SafetyResultScreenState createState() => SafetyResultScreenState();
}

class SafetyResultScreenState extends State<SafetyResultScreen>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  late TabController _tabController;

  // Skin type and concern mappings
  final Map<int, String> skinTypeMap = {
    1: "Oily",
    2: "Dry",
    3: "Combination",
    4: "Sensitive",
    5: "Normal",
  };

  final Map<int, String> concernMap = {
    1: "Acne",
    2: "Pigmentation",
    3: "Post Blemish Scar",
    4: "Redness",
    5: "Aging",
    6: "Enlarged Pores",
    7: "Impaired Skin Barrier",
    8: "Uneven Skin Tone",
    9: "Texture",
    10: "Radiance",
    11: "Elasticity",
    12: "Dullness",
    13: "Blackheads",
  };

  // Product safety state
  double? safetyScore;
  List<Map<String, dynamic>> ingredients = [];
  bool isLoading = true;
  String? errorMessage;

  // Compatibility state
  List<Map<String, dynamic>> compatibilityResults = [];
  bool isLoadingCompatibility = true;
  double? _compatibilityScore;
  String _recommendationStatus = "";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    fetchIngredientDetails();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Helper methods for skin type and concern names
  String getSkinTypeName(int id) => skinTypeMap[id] ?? "Unknown";
  String getConcernName(int id) => concernMap[id] ?? "Unknown";

  Future<void> fetchIngredientDetails() async {
    try {
      final ingredientResponse = await supabase
          .from('product_ingredients')
          .select('ingredient_id')
          .eq('product_id', widget.productId);

      if (ingredientResponse.isEmpty) {
        setState(() {
          ingredients = [];
          safetyScore = null;
          isLoading = false;
        });
        return;
      }

      final ingredientIds =
          ingredientResponse
              .map<int>((ingredient) => ingredient['ingredient_id'] as int)
              .toList();

      final safetyResponse = await supabase
          .from('Safety Rating')
          .select(
            'Ingredient_Id, Ingredient_Name, Benefits, Score, Other_Concerns, '
            'Cancer_Concern, Allergies_Immunotoxicity, '
            'Developmental_Reproductive_Toxicity, Function, Comodogenic, Irritation',
          )
          .inFilter('Ingredient_Id', ingredientIds);

      setState(() {
        ingredients = safetyResponse;
        safetyScore = ProductScorer.calculateSafetyScore(ingredients);
        isLoading = false;
      });

      fetchCompatibilityDetails(ingredientIds);
    } catch (error) {
      setState(() {
        errorMessage = "Failed to fetch ingredient details";
        isLoading = false;
      });
    }
  }

  Future<void> fetchCompatibilityDetails(List<int> ingredientIds) async {
    try {
      if (ingredientIds.isEmpty) {
        setState(() {
          compatibilityResults = [];
          isLoadingCompatibility = false;
        });
        return;
      }

      final skinTypeResponse = await supabase
          .from('ingredient_skintype')
          .select('ingredient_id, skin_type_id, is_suitable')
          .inFilter('ingredient_id', ingredientIds);

      final skinConcernResponse = await supabase
          .from('ingredient_skinconcerns')
          .select('ingredient_id, concern_id, is_suitable')
          .inFilter('ingredient_id', ingredientIds);

      Map<int, String> ingredientNamesMap = {
        for (var ingredient in ingredients)
          ingredient['Ingredient_Id'] as int:
              ingredient['Ingredient_Name'] as String,
      };

      setState(() {
        compatibilityResults = [
          ...skinTypeResponse.map(
            (e) => {
              ...e,
              'type': 'skin_type',
              'ingredient_name':
                  ingredientNamesMap[e['ingredient_id']] ?? 'Unknown',
            },
          ),
          ...skinConcernResponse.map(
            (e) => {
              ...e,
              'type': 'skin_concern',
              'ingredient_name':
                  ingredientNamesMap[e['ingredient_id']] ?? 'Unknown',
            },
          ),
        ];
        isLoadingCompatibility = false;
      });

      print(
        'Compatibility results set. Total records: ${compatibilityResults.length}',
      );
      print(
        'Sample compatibility record: ${compatibilityResults.isNotEmpty ? compatibilityResults : "N/A"}',
      );

      print('Calling analyzeCompatibility...');
      analyzeCompatibility();
      print('=== COMPLETED fetchCompatibilityDetails ===');
    } catch (error) {
      print('!!! ERROR in fetchCompatibilityDetails !!!');
      print(error);
      print('Stack trace: ${StackTrace.current}');
      setState(() {
        isLoadingCompatibility = false;
      });
    }
  }

  void analyzeCompatibility() {
    print('\n=== STARTING analyzeCompatibility ===');
    final skinProfile = Provider.of<SkinProfileProvider>(
      context,
      listen: false,
    );
    final int userSkinTypeId = skinProfile.userSkinTypeId;
    final List<int> userConcernIds = skinProfile.userConcernIds;

    print('User Profile:');
    print('- Skin Type ID: $userSkinTypeId');
    print('- Concern IDs: $userConcernIds');
    print(
      'Total compatibility records to filter: ${compatibilityResults.length}',
    );

    final filteredResults =
        compatibilityResults.where((result) {
          if (result['type'] == 'skin_type') {
            return result['skin_type_id'] == userSkinTypeId;
          } else if (result['type'] == 'skin_concern') {
            return userConcernIds.contains(result['concern_id']);
          }
          return false;
        }).toList();

    print('Filtered ${filteredResults.length} relevant records');
    print(
      'Sample filtered record: ${filteredResults.isNotEmpty ? filteredResults : "N/A"}',
    );

    var skinTypeSuitability = {
      for (var e in filteredResults.where((e) => e['type'] == 'skin_type'))
        e['ingredient_id'] as int: e['is_suitable'] as bool,
    };
    print('Skin Type Suitability Map: $skinTypeSuitability');

    var skinConcernSuitability = {
      for (var e in filteredResults.where((e) => e['type'] == 'skin_concern'))
        e['ingredient_id'] as int: e['is_suitable'] as bool,
    };

    print('Skin Concern Suitability Map: $skinConcernSuitability');

    print('Calculating compatibility score...');
    double score = calculateCompatibilityScore(
      context: context,
      ingredients: ingredients,
      skinTypeSuitability: skinTypeSuitability,
      // skinConcernSuitability: skinConcernSuitability,
    );
    print('Calculated score: $score');

    setState(() {
      _compatibilityScore = score;
      _recommendationStatus = getRecommendationStatus(score);
      compatibilityResults = filteredResults;
    });

    print('NEW FILTERED: $compatibilityResults');
  }

  String getRecommendationStatus(double score) {
    if (score >= 65) {
      return "Recommended";
    } else if (score >= 40) {
      return "Neutral - Use with Caution";
    } else {
      return "Not Recommended";
    }
  }

  // Check if the ingredient has a safety warning
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Product Analysis"),
        backgroundColor: const Color.fromARGB(255, 170, 136, 176),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Safety Score'),
            Tab(text: 'Compatibility Analysis'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildSafetyTab(), _buildCompatibilityTab()],
      ),
    );
  }

  Widget _buildSafetyTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            widget.productName,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,

          ),
          const SizedBox(height: 10),
          Text(
            widget.brand,
            style: const TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 10),

          ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child:
                widget.imageUrl.isNotEmpty
                    ? Image.network(
                      widget.imageUrl,
                      height: 200,
                      fit: BoxFit.cover,
                    )
                    : Image.asset(
                      'assets/placeholder.png',
                      height: 200,
                      fit: BoxFit.cover,
                    ),
          ),

          if (isLoading)
            const CircularProgressIndicator()
          else if (errorMessage != null)
            Text(errorMessage!, style: const TextStyle(color: Colors.red))
          else if (safetyScore != null)
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: ProductScorer.getScoreColor(safetyScore!),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                "Safety Score: ${safetyScore!.toStringAsFixed(1)}/10",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),

          if (ingredients.isEmpty && !isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text("No ingredient data available"),
              ),
            )
          else
            ...ingredients.map(
              (ingredient) => _buildIngredientCard(ingredient),
            ),

          const Padding(
            padding: EdgeInsets.only(top: 20),
            child: Text(
              "Safety ratings from EWG's Skin Deep database",
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIngredientCard(Map<String, dynamic> ingredient) {
    final score = ingredient['Score'] as int? ?? 0;
    final isComedogenic = ingredient['Comodogenic'] == true;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: ProductScorer.getScoreColor(score.toDouble()),
          child: Text(
            "$score",
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                ingredient['Ingredient_Name'] ?? "Not Specified",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (isComedogenic)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange),
                ),
                child: const Text(
                  'Comedogenic',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Text(ingredient['Function'] ?? 'Not Specified'),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "🔬 Other Concerns: ${ingredient['Other_Concerns'] ?? 'Not Specified'}",
                ),
                ProductScorer.buildRiskIndicator(
                  "Cancer Concern",
                  ingredient['Cancer_Concern'],
                ),
                ProductScorer.buildRiskIndicator(
                  "Allergies",
                  ingredient['Allergies_Immunotoxicity'],
                ),
                ProductScorer.buildRiskIndicator(
                  "Developmental Toxicity",
                  ingredient['Developmental_Reproductive_Toxicity'],
                ),
                ProductScorer.buildRiskIndicator(
                  "Irritation",
                  ingredient['Irritation'],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompatibilityTab() {
    final skinProfile = Provider.of<SkinProfileProvider>(context);

    // Calculate ingredient categories
    final beneficialIngredients =
        ingredients.where((ingredient) {
          final results = compatibilityResults.where(
            (r) =>
                r['ingredient_name'] == ingredient['Ingredient_Name'] &&
                r['is_suitable'] == true,
          );
          return results.isNotEmpty;
        }).toList();

    final potentialHazards =
        ingredients.where((ingredient) {
          final results = compatibilityResults.where(
            (r) =>
                r['ingredient_name'] == ingredient['Ingredient_Name'] &&
                r['is_suitable'] == false,
          );
          return results.isNotEmpty || _hasSafetyWarning(ingredient);
        }).toList();

    final noDataIngredients =
        ingredients.where((ingredient) {
          return !compatibilityResults.any(
            (r) => r['ingredient_name'] == ingredient['Ingredient_Name'],
          );
        }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Product header
          _buildProductHeader(),
          const SizedBox(height: 20),

          if (skinProfile.userSkinTypeId == null ||
              skinProfile.userConcernIds.isEmpty)
            _buildProfileSetupPrompt()
          else if (isLoadingCompatibility)
            const CircularProgressIndicator()
          else
            Column(
              children: [
                // Score and recommendation
                _buildScoreSection(),
                const SizedBox(height: 10),

                Column(
                  children: [
                    _buildVerticalCard(
                      title: "Beneficial Ingredients",
                      count: beneficialIngredients.length,
                      icon: Icons.check_circle,
                      iconColor: Colors.green,
                      ingredients: beneficialIngredients,
                      isPositive: true,
                    ),
                    const SizedBox(height: 12),
                    _buildVerticalCard(
                      title: "Potential Hazards",
                      count: potentialHazards.length,
                      icon: Icons.warning,
                      iconColor: Colors.orange,
                      ingredients: potentialHazards,
                      isPositive: false,
                    ),
                    const SizedBox(height: 12),
                    _buildVerticalCard(
                      title: "No Data Available",
                      count: noDataIngredients.length,
                      icon: Icons.help_outline,
                      iconColor: Colors.grey,
                      ingredients: noDataIngredients,
                      isPositive: null,
                    ),
                  ],
                ),
              ],
            ),

            const Padding(
            padding: EdgeInsets.only(top: 20),
            child: Text(
              " Analysis is based on available data for ingredient suitability. Unanalyzed ingredients are not included. For accurate advice, consult a dermatologist.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.black54),
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
          widget.productName,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          widget.brand,
          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child:
              widget.imageUrl.isNotEmpty
                  ? Image.network(
                    widget.imageUrl,
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

  Widget _buildProfileSetupPrompt() {
      print("Callback received: ${widget.onProfileRequested != null}"); // Debug

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
            debugPrint("Attempting to switch tabs"); // Debug
            widget.onProfileRequested?.call(); // Call the callback
            Navigator.of(context).pop(); // Close the SafetyResultScreen
          }, // Use the callback directly
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color.fromARGB(255, 170, 136, 176),
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


 Widget _buildScoreSection() {
  final skinProfile = Provider.of<SkinProfileProvider>(
    context,
    listen: false,
  );
  final scoreColor = _compatibilityScore! >= 65
      ? Colors.green
      : _compatibilityScore! >= 40
          ? Colors.orange
          : Colors.red;

  return Column(
    children: [
      Text(
        "Analysis for ${getSkinTypeName(skinProfile.userSkinTypeId!)} skin with ${skinProfile.userConcernIds.map((id) => getConcernName(id)).join(", ")}",
        style: TextStyle(
          fontSize: 14,
          color: Colors.grey[600],
        ),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 12),

      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: scoreColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: scoreColor.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
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
                  _recommendationStatus,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: scoreColor,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: scoreColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "${_compatibilityScore!.toStringAsFixed(1)}%",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: scoreColor,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _compatibilityScore! >= 65
                        ? Icons.check_circle
                        : _compatibilityScore! >= 40
                            ? Icons.warning
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
      const SizedBox(height: 12),

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
}) {
  final benefits = ingredient['Benefits']?.toString() ?? 'No benefits data available';
  final warnings = _getWarnings(ingredient);
  final skinProfile = Provider.of<SkinProfileProvider>(context, listen: false);
  
  // Get compatibility results for this specific ingredient
  final ingredientResults = compatibilityResults.where(
    (r) => r['ingredient_name'] == ingredient['Ingredient_Name']
  ).toList();

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
        // Ingredient name
        Text(
          ingredient['Ingredient_Name'] ?? 'Unknown',
          style: const TextStyle(
            fontSize: 16, 
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        
        // Show suitability details if ingredient is positive
        if (isPositive == true) ...[
          ...ingredientResults.map((result) => Padding(
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
                              style: const TextStyle(
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )),
          const SizedBox(height: 8),
          ClipRRect(
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
        
        // Show incompatibility reasons if ingredient is negative
        if (isPositive == false) ...[
          ...ingredientResults.where((r) => r['is_suitable'] == false).map((result) => Padding(
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
                              style: const TextStyle(
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )),
          // Show additional safety warnings if they exist
          if (warnings.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...warnings.map((warning) => Padding(
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
                          Icons.warning,
                          color: Colors.orange[700],
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            warning,
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
            )),
          ],
        ],
        
        // Show message for no data
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
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
  List<String> _getWarnings(Map<String, dynamic> ingredient) {
    final warnings = <String>[];

    if (ingredient['Comodogenic'] == true) {
      warnings.add('Comedogenic: May clog pores');
    }

    final allergies =
        ingredient['Allergies_Immunotoxicity']?.toString().toLowerCase() ?? '';
    if (allergies.contains('moderate') || allergies.contains('high')) {
      warnings.add('Allergy risk: ${ingredient['Allergies_Immunotoxicity']}');
    }

    final irritation = ingredient['Irritation']?.toString().toLowerCase() ?? '';
    if (irritation.contains('moderate') || irritation.contains('high')) {
      warnings.add('Irritation risk: ${ingredient['Irritation']}');
    }

    return warnings;
  }
}
