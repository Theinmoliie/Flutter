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

  const SafetyResultScreen({
    required this.productId,
    required this.productName,
    required this.brand,
    required this.imageUrl,
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
            'Ingredient_Id, Ingredient_Name, Score, Other_Concerns, '
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

    print('NEW FILTERED: $compatibilityResults')  ;
  }

  String getRecommendationStatus(double score) {
    if (score >= 65) {
      return "✅ Recommended";
    } else if (score >= 40) {
      return "🟡 Neutral - Use with Caution";
    } else {
      return "❌ Not Recommended";
    }
  }


  // Check if the ingredient has a safety warning
bool _hasSafetyWarning(Map<String, dynamic> ingredient) {
  final allergies = ingredient['Allergies_Immunotoxicity']?.toString().toLowerCase() ?? '';
  final irritation = ingredient['Irritation']?.toString().toLowerCase() ?? '';
  final isComedogenic = ingredient['Comodogenic'] == true;
  
  return allergies.contains('moderate') || allergies.contains('high') ||
         irritation.contains('moderate') || irritation.contains('high') ||
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
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
          child: widget.imageUrl.isNotEmpty
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
        const SizedBox(height: 20),

        if (skinProfile.userSkinTypeId == null || skinProfile.userConcernIds.isEmpty)
          Column(
            children: [
              const Text(
                "Please set your skin profile to view compatibility analysis",
                style: TextStyle(fontSize: 16, color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  // Navigate to skin profile setup
                  // Navigator.push(context, MaterialPageRoute(builder: (_) => SkinProfileScreen()));
                },
                child: const Text("Set Skin Profile"),
              ),
            ],
          )
        else if (isLoadingCompatibility)
          const CircularProgressIndicator()
        else
          Column(
            children: [
              if (_compatibilityScore != null)
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _compatibilityScore! >= 65
                        ? Colors.green
                        : _compatibilityScore! >= 40
                            ? Colors.orange
                            : Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "Compatibility Score: ${_compatibilityScore!.toStringAsFixed(1)}%",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              Text(
                _recommendationStatus,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                "Analysis for:",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                "Skin Type: ${getSkinTypeName(skinProfile.userSkinTypeId!)}",
                style: const TextStyle(fontSize: 16),
              ),
              Text(
                "Skin Concerns: ${skinProfile.userConcernIds.map((id) => getConcernName(id)).join(", ")}",
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),

              // Show all ingredients with their compatibility data
              ...ingredients.map((ingredient) {
                // Find compatibility results for this ingredient
                final results = compatibilityResults
                    .where((r) => r['ingredient_name'] == ingredient['Ingredient_Name'])
                    .toList();

                
                return _buildCompatibilityCard(
                  ingredient['Ingredient_Name'] ?? 'Unknown',
                  results,
                  ingredient,
                );
              }).toList(),
            ],
          ),
      ],
    ),
  );
}
  Map<String, List<Map<String, dynamic>>> _groupCompatibilityByIngredient() {
    Map<String, List<Map<String, dynamic>>> groupedData = {};

    for (var result in compatibilityResults) {
      String ingredientName = result['ingredient_name'] ?? 'Unknown';
      if (!groupedData.containsKey(ingredientName)) {
        groupedData[ingredientName] = [];
      }
      groupedData[ingredientName]!.add(result);
    }

    return groupedData;
  }


Widget _buildCompatibilityCard(
  String ingredientName, 
  List<Map<String, dynamic>> results,
  Map<String, dynamic> ingredient,
) {
  final hasCompatibilityData = results.isNotEmpty;
  final isSuitableOverall = !results.any((r) => r['is_suitable'] == false);
  final hasSafetyWarning = _hasSafetyWarning(ingredient);

  return Container(
    margin: const EdgeInsets.symmetric(vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
    ),
    child: ExpansionTile(
      leading: CircleAvatar(
        backgroundColor: hasCompatibilityData
            ? (isSuitableOverall ? Colors.green[300]! : Colors.red[300]!)
            : (hasSafetyWarning ? Colors.orange[300]! : Colors.grey[300]!),
        child: Icon(
          hasCompatibilityData
              ? (isSuitableOverall ? Icons.check : Icons.warning)
              : (hasSafetyWarning ? Icons.warning_amber : Icons.help_outline),
          color: Colors.white,
        ),
      ),
      title: Text(
        ingredientName,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        hasCompatibilityData
            ? (isSuitableOverall ? "Suitable for your profile" : "May not be suitable for you")
            : (hasSafetyWarning ? "Safety warning - check details" : "No compatibility data available"),
        style: TextStyle(
          color: hasCompatibilityData
              ? (isSuitableOverall ? Colors.green[700] : Colors.red[700])
              : (hasSafetyWarning ? Colors.orange[700] : Colors.grey[700]),
        ),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Show all compatibility results in consistent format
              ...results.map(_buildCompatibilityResult),
              
              // Safety warnings without divider
              if (hasSafetyWarning) ...[
                _buildSafetyWarning('Allergies/Immunotoxicity', ingredient['Allergies_Immunotoxicity']),
                _buildSafetyWarning('Irritation', ingredient['Irritation']),
                _buildSafetyWarning('Comedogenic', ingredient['Comodogenic']),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _buildCompatibilityResult(Map<String, dynamic> result) {
  final isSuitable = result['is_suitable'] == true;
  final isSkinType = result['type'] == 'skin_type';

  return ListTile(
    leading: Icon(
      isSuitable ? Icons.check_circle : Icons.cancel,
      color: isSuitable ? Colors.green : Colors.red,
    ),
    title: Text(
      isSkinType
          ? "For your skin type: ${getSkinTypeName(result['skin_type_id'])}"
          : "For your concern: ${getConcernName(result['concern_id'])}",
    ),
    subtitle: Text(
      isSuitable ? "This ingredient is suitable" : "This ingredient may cause issues",
    ),
  );
}

Widget _buildSafetyWarning(String label, dynamic value) {
  // Handle null values (except for Comedogenic which is handled separately)
  if (value == null && label != 'Comedogenic') {
    return const SizedBox.shrink();
  }

  // Determine warning level and content
  String? warningText;
  Color? warningColor;
  IconData warningIcon = Icons.warning_amber;
  
  if (label == 'Comedogenic') {
    if (value != true) return const SizedBox.shrink();
    warningText = 'Comedogenic: May clog pores';
    warningColor = Colors.purple;
    warningIcon = Icons.face;
    
      } else {
    final String valueStr = value.toString().toLowerCase();
    if (!valueStr.contains('moderate') && !valueStr.contains('high')) {
      return const SizedBox.shrink();
    }
    warningText = '$label: ${value.toString().toUpperCase()}';
    warningColor = valueStr.contains('high') ? Colors.red : Colors.orange;
  }

  // Get the appropriate background color shade
  final backgroundColor = warningColor == Colors.red 
      ? Colors.red.shade50 
       : warningColor == Colors.purple  // Add this check
      ? Colors.purple.shade50
      : Colors.orange.shade50;


  // Consistent styling for all warnings
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
    margin: const EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(
        color: warningColor.withOpacity(0.3),
        width: 1,
      ),
    ),
    child: Row(
      children: [
        Icon(
          warningIcon,
          color: warningColor,
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            warningText,
            style: TextStyle(
              fontSize: 15,
              color: warningColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}
}
