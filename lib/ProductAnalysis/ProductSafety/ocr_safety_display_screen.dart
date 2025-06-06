// ProductSafety/ocr_safety_display_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:string_similarity/string_similarity.dart';
import '../../util/safetyscore_util.dart'; // Adjust path
import 'safety_guide_ui.dart';         // Adjust path

class OcrSafetyDisplayScreen extends StatefulWidget {
  final File imageFile;

  const OcrSafetyDisplayScreen({
    required this.imageFile,
    Key? key,
  }) : super(key: key);

  @override
  _OcrSafetyDisplayScreenState createState() => _OcrSafetyDisplayScreenState();
}

class _OcrSafetyDisplayScreenState extends State<OcrSafetyDisplayScreen> {
  final supabase = Supabase.instance.client;
  String _recognizedTextState = "Processing text from image...";
  List<Map<String, dynamic>> _matchedIngredients = [];
  List<String> _unmatchedIngredients = [];
  ProductGuidance? productSafetyGuidance;
  bool _isLoadingIngredients = true;
  String? _errorMessage;

  // REMOVED: final List<String> _debugIngredients = [ ... ];

  @override
  void initState() {
    super.initState();
    _recognizeTextAndFetchDetails();
  }

  void setStateIfMounted(VoidCallback fn) {
    if (mounted) setState(fn);
  }

  Future<void> _recognizeTextAndFetchDetails() async {
    final inputImage = InputImage.fromFile(widget.imageFile);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    String recognizedTextContent = "";
    try {
      final RecognizedText recognizedTextResult = await textRecognizer.processImage(inputImage);
      recognizedTextContent = recognizedTextResult.text;
      if (recognizedTextContent.isNotEmpty) {
        setStateIfMounted(() => _recognizedTextState = "Text recognized. Fetching safety data & analyzing ingredients...");
        await _processAndFetchIngredientsSafety(recognizedTextContent);
      } else {
        setStateIfMounted(() {
          _recognizedTextState = "No text found in image.";
          _isLoadingIngredients = false;
          _errorMessage = "No text recognized in the image. Please try a clearer image or different angle.";
          productSafetyGuidance = ProductScorer.getOverallProductGuidance([]);
        });
      }
    } catch (e) {
      print("Error during OCR: $e");
      setStateIfMounted(() {
        _recognizedTextState = "OCR Error.";
        _isLoadingIngredients = false;
        _errorMessage = "Error in OCR processing. Please try another image or check permissions.";
        productSafetyGuidance = ProductScorer.getOverallProductGuidance([]);
      });
    } finally {
      textRecognizer.close();
    }
  }

  String _cleanIngredientString(String text) {
    return text
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toLowerCase();
  }

  Future<void> _processAndFetchIngredientsSafety(String extractedText) async {
    setStateIfMounted(() {
      _isLoadingIngredients = true;
      _errorMessage = null;
      _recognizedTextState = "Text recognized. Fetching safety data from database...";
    });

    String textAfterInitialClean = extractedText
        .replaceAll(RegExp(r'Ingredients:?', caseSensitive: false), '')
        .replaceAll(RegExp(r'\n'), ' ')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();

    final colonIndex = textAfterInitialClean.indexOf(':');
    if (colonIndex != -1) {
      textAfterInitialClean = textAfterInitialClean.substring(colonIndex + 1).trim();
    }
    // Optional: Keep this for basic logging if needed, or remove for production
    // print("Text after initial cleaning and colon strip: \"$textAfterInitialClean\"");

    final ocrIngredientsList = textAfterInitialClean
        .split(RegExp(r'[,.;)(]\s*|\s*[,.;)(]'))
        .map((e) => _cleanIngredientString(e))
        .where((e) => e.isNotEmpty && e.length > 2 && e.length < 60)
        .toList();

    if (ocrIngredientsList.isEmpty) {
      setStateIfMounted(() {
        _recognizedTextState = "No valid ingredients extracted from text.";
        _isLoadingIngredients = false;
        _errorMessage = "No ingredients could be clearly extracted. Please ensure the ingredients list is clear in the image.";
        productSafetyGuidance = ProductScorer.getOverallProductGuidance([]);
      });
      return;
    }
    // Optional: Keep this for basic logging or remove
    // print("Cleaned OCR Ingredients (${ocrIngredientsList.length}): $ocrIngredientsList");

    try {
      List<Map<String, dynamic>> allDbIngredients = [];
      int offset = 0;
      const int pageSize = 1000;
      bool hasMore = true;
      int pageCount = 0;

      // print("Starting to fetch all ingredients from DB with pagination (page size: $pageSize)..."); // Optional

      while (hasMore) {
        pageCount++;
        setStateIfMounted(() {
           _recognizedTextState = "Fetching safety data... (Page $pageCount)";
        });
        try {
          final response = await supabase
              .from('Safety Rating')
              .select(
                  'Ingredient_Id, Ingredient_Name, Score, Irritation, Comodogenic, Other_Concerns, Cancer_Concern, Allergies_Immunotoxicity, Developmental_Reproductive_Toxicity, Function, Benefits')
              .range(offset, offset + pageSize - 1);

          List<Map<String, dynamic>> pageResults = List<Map<String, dynamic>>.from(response);
          allDbIngredients.addAll(pageResults);
          // Optional: print("Fetched page $pageCount: ${pageResults.length} ingredients. Total fetched so far: ${allDbIngredients.length}");

          if (pageResults.length < pageSize) {
            hasMore = false;
          } else {
            offset += pageSize;
          }
        } catch (e) {
          print("DB connection error during pagination (Offset: $offset, Page: $pageCount): $e");
          setStateIfMounted(() {
            _isLoadingIngredients = false;
            _errorMessage = "Database error while fetching ingredients (page $pageCount). Some data may be missing.";
          });
          hasMore = false;
        }
      }
      print("Finished fetching. Total ingredients from DB: ${allDbIngredients.length}"); // Good to keep
      if (allDbIngredients.isEmpty && _errorMessage == null) {
          print("WARNING: No ingredients fetched from the database despite pagination attempts!");
          _errorMessage = "Could not retrieve any ingredient safety data from the database.";
      }

      if (allDbIngredients.isEmpty && _errorMessage != null) {
          setStateIfMounted(() {
              _isLoadingIngredients = false;
              productSafetyGuidance = ProductScorer.getOverallProductGuidance([]);
          });
          return;
      }
      
      setStateIfMounted(() {
         _recognizedTextState = "Analyzing ${ocrIngredientsList.length} potential ingredients..."; // Updated
      });

      final List<Map<String, dynamic>> currentMatchedIngredients = [];
      final List<String> currentUnmatchedIngredients = [];

      for (final ocrIngredient in ocrIngredientsList) {
        final bestMatch = _findBestFuzzyMatch(ocrIngredient, allDbIngredients);
        if (bestMatch != null && bestMatch['similarityScore'] >= 0.7) {
          bestMatch['originalIngredient'] = ocrIngredient;
          currentMatchedIngredients.add(bestMatch);
        } else {
          currentUnmatchedIngredients.add(ocrIngredient);
          // REMOVED: if (_debugIngredients.contains(ocrIngredient)) { ... }
        }
      }

      setStateIfMounted(() {
        _matchedIngredients = currentMatchedIngredients;
        _unmatchedIngredients = currentUnmatchedIngredients;
        productSafetyGuidance = ProductScorer.getOverallProductGuidance(_matchedIngredients);
        _isLoadingIngredients = false;
        
        if (_errorMessage != null) {
            _recognizedTextState = "Analysis complete (with potential data fetching issues).";
        } else if (_matchedIngredients.isNotEmpty) {
            _recognizedTextState = "Analysis Complete. Found ${_matchedIngredients.length} matching ingredients.";
        } else if (ocrIngredientsList.isNotEmpty) {
             _recognizedTextState = "Could not match any scanned text to ingredients in our database.";
            _errorMessage = "None of the ${ocrIngredientsList.length} potential ingredient terms found in the image could be matched to our database."; // Removed unmatched list from here for brevity
        } else {
            _recognizedTextState = "No ingredients to analyze.";
            _errorMessage = "No valid ingredients were extracted from the image.";
        }
      });

    } catch (e) {
      print("Error analyzing ingredients (outer try-catch): $e");
      setStateIfMounted(() {
        _isLoadingIngredients = false;
        _errorMessage = "An unexpected error occurred during analysis. Please try again.";
        productSafetyGuidance = ProductScorer.getOverallProductGuidance([]);
      });
    }
  }

  Map<String, dynamic>? _findBestFuzzyMatch(
      String ocrIngredient, List<Map<String, dynamic>> allDbIngredients) {
    Map<String, dynamic>? bestMatchData;
    double highestScore = 0.0;
    // String bestMatchingDbTerm = ""; // Not strictly needed if not debugging
    // REMOVED: bool isDebuggingThisIngredient = _debugIngredients.contains(ocrIngredient);
    // REMOVED: if (isDebuggingThisIngredient) { ... }

    for (final dbIngredientMap in allDbIngredients) {
      final String dbRawName = dbIngredientMap['Ingredient_Name']?.toString() ?? "";
      final String dbCleanedName = _cleanIngredientString(dbRawName);

      if (dbCleanedName.isEmpty) continue;

      // REMOVED: DEEP DEBUG BLOCK
      // REMOVED: Verbose comparison logging for debug ingredients

      final similarityScore = StringSimilarity.compareTwoStrings(ocrIngredient, dbCleanedName);

      if (similarityScore > highestScore) {
        highestScore = similarityScore;
        bestMatchData = Map<String, dynamic>.from(dbIngredientMap);
        bestMatchData['similarityScore'] = highestScore;
        // bestMatchingDbTerm = dbCleanedName; // Not strictly needed
      }
    }

    // REMOVED: Final debug block for isDebuggingThisIngredient
    
    return (highestScore >= 0.7) ? bestMatchData : null;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isLoadingIngredients ? "Analyzing Image..." : "Product Safety Rating",
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: colorScheme.primary,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoadingIngredients
          ? Center(
              child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Text(_recognizedTextState, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
                ),
              ],
            ))
          : _errorMessage != null && _matchedIngredients.isEmpty
              ? Center(
                  child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 50),
                      const SizedBox(height: 16),
                      Text(_errorMessage!,
                          style: const TextStyle(color: Colors.redAccent, fontSize: 17, fontWeight: FontWeight.w500),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 20),
                      if (!_isLoadingIngredients && _recognizedTextState.isNotEmpty && !_recognizedTextState.toLowerCase().contains("complete")) // Show state if not an error related to completion
                        Text(
                          _recognizedTextState, 
                          style: TextStyle(color: Colors.grey[600], fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                    ],
                  ),
                ))
              : SafetyGuideUI(
                  productName: "Scanned Product",
                  brand: "From Image",
                  imageFile: widget.imageFile,
                  productGuidance: productSafetyGuidance,
                  matchedIngredients: _matchedIngredients,
                  unmatchedIngredients: _unmatchedIngredients,
                ),
    );
  }
}