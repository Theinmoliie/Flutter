import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:string_similarity/string_similarity.dart';
import 'package:provider/provider.dart';
import './providers/skin_profile_provider.dart';
import 'score_util.dart';
import 'compatibility_util.dart';
import 'main_screen.dart';
import 'compatibility_tab.dart';

class StagingScreen extends StatefulWidget {
  final File imageFile;
  const StagingScreen({required this.imageFile, Key? key}) : super(key: key);

  @override
  _StagingScreenState createState() => _StagingScreenState();
}

class _StagingScreenState extends State<StagingScreen> {
  final supabase = Supabase.instance.client;
  String _recognizedText = "Processing...";
  List<Map<String, dynamic>> _matchedIngredients = [];
  List<String> _unmatchedIngredients = [];
  double? averageScore;
  
  // Compatibility state
  List<Map<String, dynamic>> compatibilityResults = [];
  bool isLoadingCompatibility = true;
  double? _compatibilityScore;
  String _recommendationStatus = "";
  bool _hasFetchedCompatibility = false;

  // Skin type and concern mappings
  final Map<int, String> skinTypeMap = {
    1: "Oily", 2: "Dry", 3: "Combination", 4: "Sensitive", 5: "Normal",
  };

  final Map<int, String> concernMap = {
    1: "Acne", 2: "Pigmentation", 3: "Post Blemish Scar",
    4: "Redness", 5: "Aging", 6: "Enlarged Pores",
    7: "Impaired Skin Barrier", 8: "Uneven Skin Tone",
    9: "Texture", 10: "Radiance", 11: "Elasticity",
    12: "Dullness", 13: "Blackheads",
  };

  @override
  void initState() {
    super.initState();
    _recognizeText();
  }

  Future<void> _recognizeText() async {
    final inputImage = InputImage.fromFile(widget.imageFile);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      if (recognizedText.text.isNotEmpty) {
        setState(() => _recognizedText = recognizedText.text);
        await _fetchIngredientDetails(_recognizedText);
      } else {
        setState(() => _recognizedText = "No text found.");
      }
    } catch (e) {
      setState(() => _recognizedText = "Error recognizing text: $e");
    } finally {
      textRecognizer.close();
    }
  }

  Future<void> _fetchIngredientDetails(String extractedText) async {
    String cleanedText = extractedText
        .replaceAll(RegExp(r'Ingredients:?', caseSensitive: false), '')
        .replaceAll(RegExp(r'\n'), ' ')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim()
        .toLowerCase();

    final colonIndex = cleanedText.indexOf(':');
    if (colonIndex != -1) {
      cleanedText = cleanedText.substring(colonIndex + 1).trim();
    }

    final ingredients = cleanedText
        .split(RegExp(r'[,.;]'))
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toList();

    if (ingredients.isEmpty) return;

    try {
      final List<Map<String, dynamic>> matchedIngredients = [];
      final List<String> unmatchedIngredients = [];

      for (final ingredient in ingredients) {
        final response = await supabase
            .from('Safety Rating')
            .select('*')
            .ilike('Ingredient_Name', '$ingredient');

        if (response.isNotEmpty) {
          matchedIngredients.addAll((response as List).cast<Map<String, dynamic>>());
        } else {
          unmatchedIngredients.add(ingredient);
        }
      }

      setState(() {
        _matchedIngredients = matchedIngredients;
        _unmatchedIngredients = unmatchedIngredients;
        averageScore = ProductScorer.calculateSafetyScore(_matchedIngredients);
      });

      if (unmatchedIngredients.isNotEmpty) {
        await _applyFuzzyLogic(unmatchedIngredients);
      }

      await _fetchCompatibilityDetails();
    } catch (e) {
      setState(() => _recognizedText = "Error fetching details: $e");
    }
  }

  Future<void> _fetchCompatibilityDetails() async {
    if (_matchedIngredients.isEmpty || _hasFetchedCompatibility) return;

    try {
      final ingredientIds = _matchedIngredients
          .map<int>((ingredient) => ingredient['Ingredient_Id'] as int)
          .toList();

      final skinTypeResponse = await supabase
          .from('ingredient_skintype')
          .select('ingredient_id, skin_type_id, is_suitable')
          .inFilter('ingredient_id', ingredientIds);

      final skinConcernResponse = await supabase
          .from('ingredient_skinconcerns')
          .select('ingredient_id, concern_id, is_suitable')
          .inFilter('ingredient_id', ingredientIds);

      Map<int, String> ingredientNamesMap = {
        for (var ingredient in _matchedIngredients)
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
        _hasFetchedCompatibility = true;
      });

      analyzeCompatibility();
    } catch (e) {
      setState(() => isLoadingCompatibility = false);
    }
  }

  Future<void> _applyFuzzyLogic(List<String> unmatchedIngredients) async {
    try {
      final response = await supabase.from('Safety Rating').select('*');
      final List<Map<String, dynamic>> allIngredients = 
          (response as List).cast<Map<String, dynamic>>();

      final List<Map<String, dynamic>> fuzzyMatches = [];
      final List<String> matchedOriginalIngredients = [];

      for (final ingredient in unmatchedIngredients) {
        final bestMatch = _findBestFuzzyMatch(ingredient, allIngredients);
        if (bestMatch != null) {
          bestMatch['originalIngredient'] = ingredient;
          bestMatch['similarityScore'] = bestMatch['similarityScore'];
          fuzzyMatches.add(bestMatch);
          matchedOriginalIngredients.add(ingredient);
        }
      }

      setState(() {
        _matchedIngredients = [..._matchedIngredients, ...fuzzyMatches];
        _unmatchedIngredients = _unmatchedIngredients
            .where((ingredient) => !matchedOriginalIngredients.contains(ingredient))
            .toList();
      });
    } catch (e) {
      print("Error applying fuzzy logic: $e");
    }
  }

  Map<String, dynamic>? _findBestFuzzyMatch(
    String ingredient, 
    List<Map<String, dynamic>> allIngredients
  ) {
    Map<String, dynamic>? bestMatch;
    double highestScore = 0.0;

    for (final dbIngredient in allIngredients) {
      final dbIngredientName = dbIngredient['Ingredient_Name'].toString().toLowerCase();
      final similarityScore = StringSimilarity.compareTwoStrings(
        ingredient, 
        dbIngredientName
      );

      if (similarityScore >= 0.7 && similarityScore > highestScore) {
        highestScore = similarityScore;
        bestMatch = dbIngredient;
        bestMatch!['similarityScore'] = highestScore;
      }
    }

    return bestMatch;
  }

  void analyzeCompatibility() {
    final skinProfile = Provider.of<SkinProfileProvider>(context, listen: false);
    final int userSkinTypeId = skinProfile.userSkinTypeId ?? 0;
    final List<int> userConcernIds = skinProfile.userConcernIds ?? [];

    if (userSkinTypeId == 0 || userConcernIds.isEmpty) {
      setState(() => isLoadingCompatibility = false);
      return;
    }

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
      ingredients: _matchedIngredients,
      skinTypeSuitability: skinTypeSuitability,
    );

    setState(() {
      _compatibilityScore = score;
      _recommendationStatus = getRecommendationStatus(score);
      compatibilityResults = filteredResults;
      isLoadingCompatibility = false;
    });
  }

  String getRecommendationStatus(double score) {
    if (score >= 65) return "Recommended";
    if (score >= 40) return "Neutral - Use with Caution";
    return "Not Recommended";
  }

  String getSkinTypeName(int id) => skinTypeMap[id] ?? "Unknown";
  String getConcernName(int id) => concernMap[id] ?? "Unknown";

  @override
  Widget build(BuildContext context) {
    return CompatibilityTab(
      productName: "Recognized Product",
      brand: "Unknown Brand",
      imageFile: widget.imageFile,
      averageScore: averageScore,
      matchedIngredients: _matchedIngredients,
      unmatchedIngredients: _unmatchedIngredients,
      compatibilityResults: compatibilityResults,
      isLoadingCompatibility: isLoadingCompatibility,
      compatibilityScore: _compatibilityScore,
      recommendationStatus: _recommendationStatus,
      onProfileRequested: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MainScreen(),
            settings: const RouteSettings(arguments: 1),
          ),
        );
      },
      skinTypeMap: skinTypeMap,
      concernMap: concernMap,
    );
  }
}