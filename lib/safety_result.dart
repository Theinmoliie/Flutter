import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'score_util.dart';
import 'compatibility_util.dart';
import 'package:provider/provider.dart';
import './providers/skin_profile_provider.dart';
import 'compatibility_tab.dart';

class SafetyResultScreen extends StatefulWidget {
  final int productId;
  final String productName;
  final String brand;
  final String imageUrl;
  final VoidCallback onProfileRequested;

  const SafetyResultScreen({
    required this.productId,
    required this.productName,
    required this.brand,
    required this.imageUrl,
    required this.onProfileRequested,
    Key? key,
  }) : super(key: key);

  @override
  SafetyResultScreenState createState() => SafetyResultScreenState();
}

class SafetyResultScreenState extends State<SafetyResultScreen> {
  final supabase = Supabase.instance.client;

  // Skin type and concern mappings
  final Map<int, String> skinTypeMap = {
    1: "Oily",
    2: "Dry",
    3: "Combination",
    4: "Sensitive",
    5: "Normal",
  };

  final Map<int, String> concernMap = {
    1: "Acne", 2: "Pigmentation", 3: "Post Blemish Scar",
    4: "Redness", 5: "Aging", 6: "Enlarged Pores",
    7: "Impaired Skin Barrier", 8: "Uneven Skin Tone",
    9: "Texture", 10: "Radiance", 11: "Elasticity",
    12: "Dullness", 13: "Blackheads",
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
    fetchIngredientDetails();
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

      final ingredientIds = ingredientResponse
          .map<int>((ingredient) => ingredient['ingredient_id'] as int)
          .toList();

      final safetyResponse = await supabase
          .from('Safety Rating')
          .select('''
            Ingredient_Id, Ingredient_Name, Benefits, Score, Other_Concerns,
            Cancer_Concern, Allergies_Immunotoxicity,
            Developmental_Reproductive_Toxicity, Function, Comodogenic, Irritation
          ''')
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
          ingredient['Ingredient_Id'] as int: ingredient['Ingredient_Name'] as String,
      };

      setState(() {
        compatibilityResults = [
          ...skinTypeResponse.map((e) => {
            ...e,
            'type': 'skin_type',
            'ingredient_name': ingredientNamesMap[e['ingredient_id']] ?? 'Unknown',
          }),
          ...skinConcernResponse.map((e) => {
            ...e,
            'type': 'skin_concern',
            'ingredient_name': ingredientNamesMap[e['ingredient_id']] ?? 'Unknown',
          }),
        ];
        isLoadingCompatibility = false;
      });

      analyzeCompatibility();
    } catch (error) {
      setState(() {
        isLoadingCompatibility = false;
      });
    }
  }

  void analyzeCompatibility() {
    final skinProfile = Provider.of<SkinProfileProvider>(context, listen: false);
    final int userSkinTypeId = skinProfile.userSkinTypeId;
    final List<int> userConcernIds = skinProfile.userConcernIds;

    final filteredResults = compatibilityResults.where((result) {
      if (result['type'] == 'skin_type') {
        return result['skin_type_id'] == userSkinTypeId;
      } else if (result['type'] == 'skin_concern') {
        return userConcernIds.contains(result['concern_id']);
      }
      return false;
    }).toList();

    var skinTypeSuitability = {
      for (var e in filteredResults.where((e) => e['type'] == 'skin_type'))
        e['ingredient_id'] as int: e['is_suitable'] as bool,
    };

    double score = calculateCompatibilityScore(
      context: context,
      ingredients: ingredients,
      skinTypeSuitability: skinTypeSuitability,
    );

    setState(() {
      _compatibilityScore = score;
      _recommendationStatus = getRecommendationStatus(score);
      compatibilityResults = filteredResults;
    });
  }

  String getRecommendationStatus(double score) {
    if (score >= 65) return "Recommended";
    if (score >= 40) return "Neutral - Use with Caution";
    return "Not Recommended";
  }

  @override
  Widget build(BuildContext context) {
    return CompatibilityTab(
      productName: widget.productName,
      brand: widget.brand,
      imageUrl: widget.imageUrl,
      averageScore: safetyScore,
      matchedIngredients: ingredients,
      unmatchedIngredients: const [], // Not used in safety_result
      compatibilityResults: compatibilityResults,
      isLoadingCompatibility: isLoadingCompatibility,
      compatibilityScore: _compatibilityScore,
      recommendationStatus: _recommendationStatus,
      onProfileRequested: () {
        // This will trigger the callback chain back to MainScreen
        widget.onProfileRequested();
      },      
      skinTypeMap: skinTypeMap,
      concernMap: concernMap,
    );
  }
}