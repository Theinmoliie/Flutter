// capture_product.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:string_similarity/string_similarity.dart';
import '../util/safetyscore_util.dart';
import 'product_analysis.dart';

class StagingScreen extends StatefulWidget {
  final File imageFile;
  final VoidCallback onProfileRequested;

  const StagingScreen({required this.imageFile, required this.onProfileRequested, Key? key}) : super(key: key);

  @override
  _StagingScreenState createState() => _StagingScreenState();
}

class _StagingScreenState extends State<StagingScreen> {
  final supabase = Supabase.instance.client;
  String _recognizedTextState = "Processing text from image...";
  List<Map<String, dynamic>> _matchedIngredients = [];
  List<String> _unmatchedIngredients = [];
  ProductGuidance? productSafetyGuidance;
  bool _isLoadingIngredients = true;
  String? _errorMessage;

  final String _ocrCompatibilityStatus = "Product Not Identified in Database";
  final List<String> _ocrCompatibilityReasons = [
    "The ingredients below have been analyzed for general EWG safety.",
    "For a personalized compatibility check, please search for this product in our database after identifying its name and brand."
  ];
  final bool _isLoadingCompatibilityStub = false;

  final Map<int, String> skinTypeMap = {1: "Oily", 2: "Dry", 3: "Combination", 4: "Sensitive", 5: "Normal"};
  final Map<int, String> concernMap = {1: "Acne", 2: "Pigmentation", 3: "Post Blemish Scar", 4: "Redness", 5: "Aging", 6: "Enlarged Pores", 7: "Impaired Skin Barrier", 8: "Uneven Skin Tone", 9: "Texture", 10: "Radiance", 11: "Elasticity", 12: "Dullness", 13: "Blackheads"};

  @override
  void initState() { super.initState(); _recognizeTextAndFetchDetails(); }

  void setStateIfMounted(VoidCallback fn) {
    if (mounted) {
      setState(fn);
    }
  }

  void _handleProfileUpdateAndRefreshForOcr() {
    print("Profile update requested from ProductAnalysis within StagingScreen (OCR).");
    if (mounted) {
      setState(() {}); // Rebuild to reflect any minor UI changes in ProductAnalysis based on profile
    }
    widget.onProfileRequested(); // Call the original callback passed to StagingScreen
  }

  Future<void> _recognizeTextAndFetchDetails() async {
    // ... (no changes in this method)
    final inputImage = InputImage.fromFile(widget.imageFile);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    String recognizedTextContent = "";
    try {
      final RecognizedText recognizedTextResult = await textRecognizer.processImage(inputImage);
      recognizedTextContent = recognizedTextResult.text;
      if (recognizedTextContent.isNotEmpty) {
        setStateIfMounted(() => _recognizedTextState = "Text recognized. Analyzing ingredients...");
        await _processAndFetchIngredientsSafety(recognizedTextContent);
      } else {
        setStateIfMounted(() { _recognizedTextState = "No text found."; _isLoadingIngredients = false; _errorMessage = "No text recognized."; productSafetyGuidance = ProductScorer.getOverallProductGuidance([]);});
      }
    } catch (e) { 
      print("Error during OCR: $e");
      setStateIfMounted(() {_recognizedTextState = "OCR Error."; _isLoadingIngredients = false; _errorMessage = "Error in OCR processing."; productSafetyGuidance = ProductScorer.getOverallProductGuidance([]);});
    } finally { 
      textRecognizer.close(); 
    }
  }

  Future<void> _processAndFetchIngredientsSafety(String extractedText) async {
    // ... (no changes in this method)
    setStateIfMounted(() { _isLoadingIngredients = true; _errorMessage = null;});
    String cleanedText = extractedText.replaceAll(RegExp(r'Ingredients:?',caseSensitive:false),'').replaceAll(RegExp(r'\n'),' ').replaceAll(RegExp(r'\s{2,}'),' ').trim();
    final colonIndex=cleanedText.indexOf(':');if(colonIndex!=-1){cleanedText=cleanedText.substring(colonIndex+1).trim();}
    final ocrIngredientsList=cleanedText.split(RegExp(r'[,.;)(]\s*|\s*[,.;)(]')).map((e)=>e.trim().toLowerCase()).where((e)=>e.isNotEmpty&&e.length>2).toList();

    if (ocrIngredientsList.isEmpty) {
      setStateIfMounted(() { _recognizedTextState = "No ingredients extracted from text."; _isLoadingIngredients = false; _errorMessage = "No ingredients extracted from the recognized text."; productSafetyGuidance = ProductScorer.getOverallProductGuidance([]);});
      return;
    }
    print("OCR Ingredients: $ocrIngredientsList");

    try {
      List<Map<String, dynamic>> allDbIngredients = [];
      try {
          final response = await supabase.from('Safety Rating').select('Ingredient_Id, Ingredient_Name, Score, Irritation, Comodogenic, Other_Concerns, Cancer_Concern, Allergies_Immunotoxicity, Developmental_Reproductive_Toxicity, Function, Benefits');
          allDbIngredients = (response as List).cast<Map<String, dynamic>>();
      } catch (e) { 
        print("DB connection error for safety data: $e");
        setStateIfMounted(() {_isLoadingIngredients = false; _errorMessage = "Database connection error while fetching ingredient safety data."; productSafetyGuidance = ProductScorer.getOverallProductGuidance([]);}); return;}

      final List<Map<String, dynamic>> currentMatchedIngredients = [];
      final List<String> currentUnmatchedIngredients = [];
      for (final ocrIngredient in ocrIngredientsList) {
        final bestMatch = _findBestFuzzyMatch(ocrIngredient, allDbIngredients);
        if (bestMatch != null && bestMatch['similarityScore'] >= 0.7) {
          bestMatch['originalIngredient'] = ocrIngredient;
          currentMatchedIngredients.add(bestMatch);
        } else { currentUnmatchedIngredients.add(ocrIngredient); }
      }

      setStateIfMounted(() {
        _matchedIngredients = currentMatchedIngredients;
        _unmatchedIngredients = currentUnmatchedIngredients;
        productSafetyGuidance = ProductScorer.getOverallProductGuidance(_matchedIngredients);
        _isLoadingIngredients = false;
        _recognizedTextState = _matchedIngredients.isNotEmpty
            ? "Analysis Complete. Found ${_matchedIngredients.length} matching ingredients."
            : "Could not match any scanned text to ingredients in our database.";
      });
    } catch (e) { 
      print("Error analyzing ingredients: $e");
      setStateIfMounted(() {_isLoadingIngredients = false; _errorMessage = "An error occurred while analyzing ingredients."; productSafetyGuidance = ProductScorer.getOverallProductGuidance([]);});}
  }

  Map<String, dynamic>? _findBestFuzzyMatch(String ocrIngredient, List<Map<String, dynamic>> allDbIngredients) {
    // ... (no changes in this method)
    Map<String, dynamic>? bestMatchData; double highestScore = 0.0;
    for (final dbIngredientMap in allDbIngredients) {
      final String dbIngredientName = dbIngredientMap['Ingredient_Name']?.toString().toLowerCase() ?? "";
      if (dbIngredientName.isEmpty) continue;
      final similarityScore = StringSimilarity.compareTwoStrings(ocrIngredient, dbIngredientName);
      if (similarityScore > highestScore) {
        highestScore = similarityScore;
        bestMatchData = Map<String, dynamic>.from(dbIngredientMap);
        bestMatchData['similarityScore'] = highestScore;
      }
    }
    return (highestScore >= 0.7) ? bestMatchData : null;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingIngredients) {
      return Scaffold(appBar: AppBar(title: const Text("Analyzing Image...")),
                      body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const CircularProgressIndicator(), const SizedBox(height: 20), Text(_recognizedTextState)])));
    }
    if (_errorMessage != null) {
      return Scaffold(appBar: AppBar(title: const Text("Analysis Error")),
                      body: Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 16), textAlign: TextAlign.center))));
    }

    return ProductAnalysis(
      productName: "Scanned Product",
      brand: "From Image",
      imageFile: widget.imageFile,
      productGuidance: productSafetyGuidance,
      matchedIngredients: _matchedIngredients,
      unmatchedIngredients: _unmatchedIngredients,
      compatibilityResults: const [], 
      isLoadingCompatibility: _isLoadingCompatibilityStub,
      recommendationStatus: _ocrCompatibilityStatus,
      compatibilityReasons: _ocrCompatibilityReasons,
      onProfileRequested: _handleProfileUpdateAndRefreshForOcr,
      skinTypeMap: skinTypeMap,
      concernMap: concernMap,
      // For OCR'd products, these detailed insights are not applicable/available
      productAddressesTheseUserConcernsNames: const [],
      ingredientsAddressTheseUserConcernsDetails: const [],
      productDirectlyTargetsUserSelectedConcerns: false,
      ingredientsTargetUserSelectedConcerns: false,
    );
  }
}