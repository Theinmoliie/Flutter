// ProductSafety/ocr_safety_display_screen.dart
import 'dart:io';
// import 'dart:ui' as dart_ui; // Not directly used here, but fine to keep if other files need it
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

  final List<String> _debugIngredients = [
      "aqua", "water", "caprylic/capric triglyceride", "cetylalcohol propanediol",
      "stearyl alcohol glycerin", "sodium hyaluronate", "arginine", "aspartic acid",
      "glycine", "alanine", "serine", "valine", "isoleucine", "proline",
      "threonine", "histidine", "phenylalanine", "glucose", "maltose",
      "fructose", "trehalose", "sodium pca", "pca", "sodium lactate", "urea",
      "allantoin", "allanton", "linoleic acid", "oleic acid",
      "phytosteryl canola glycerides", "pal mitic acid", "palmitic acid"
  ];

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
        setStateIfMounted(() => _recognizedTextState = "Text recognized. Fetching safety data & analyzing ingredients..."); // Updated state
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
      // Update loading text for fetching phase
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
    print("Text after initial cleaning and colon strip: \"$textAfterInitialClean\"");

    // Using the simpler splitting logic that was working better for multi-word ingredients
    final ocrIngredientsList = textAfterInitialClean
        .split(RegExp(r'[,.;)(]\s*|\s*[,.;)(]')) // Split by common delimiters
        .map((e) => _cleanIngredientString(e))
        .where((e) => e.isNotEmpty && e.length > 2 && e.length < 60) // Filter
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
    print("Cleaned OCR Ingredients (${ocrIngredientsList.length}): $ocrIngredientsList");

    try {
      // --- PAGINATED DATABASE FETCH ---
      List<Map<String, dynamic>> allDbIngredients = [];
      int offset = 0;
      const int pageSize = 1000; // Supabase default limit per query if not specified by .limit()
                                // .range() uses this page size implicitly.
      bool hasMore = true;
      int pageCount = 0;

      print("Starting to fetch all ingredients from DB with pagination (page size: $pageSize)...");

      while (hasMore) {
        pageCount++;
        setStateIfMounted(() { // Update UI with fetching progress
           _recognizedTextState = "Fetching safety data... (Page $pageCount)";
        });
        try {
          final response = await supabase
              .from('Safety Rating')
              .select(
                  'Ingredient_Id, Ingredient_Name, Score, Irritation, Comodogenic, Other_Concerns, Cancer_Concern, Allergies_Immunotoxicity, Developmental_Reproductive_Toxicity, Function, Benefits')
              .range(offset, offset + pageSize - 1); // Fetch in ranges

          // No explicit error check here, assuming Supabase client throws on network/auth errors
          List<Map<String, dynamic>> pageResults = List<Map<String, dynamic>>.from(response);
          
          allDbIngredients.addAll(pageResults);
          print("Fetched page $pageCount: ${pageResults.length} ingredients. Total fetched so far: ${allDbIngredients.length}");

          if (pageResults.length < pageSize) {
            hasMore = false; // This was the last page
          } else {
            offset += pageSize; // Prepare for next page
          }
        } catch (e) {
          print("DB connection error during pagination (Offset: $offset, Page: $pageCount): $e");
          setStateIfMounted(() {
            _isLoadingIngredients = false;
            _errorMessage = "Database error while fetching ingredients (page $pageCount). Some data may be missing.";
            // Decide if you want to proceed with partial data or fully fail
            // For now, we'll proceed with what we have, but set an error message.
            // productSafetyGuidance = ProductScorer.getOverallProductGuidance([]); // Or process partial
          });
          hasMore = false; // Stop fetching on error
          // return; // Uncomment if you want to completely stop on any pagination error
        }
      }
      print("Finished fetching. Total ingredients from DB: ${allDbIngredients.length}");
      if (allDbIngredients.isEmpty && _errorMessage == null) { // If no error but list is empty
          print("WARNING: No ingredients fetched from the database despite pagination attempts!");
          _errorMessage = "Could not retrieve any ingredient safety data from the database.";
      }
      // --- END OF PAGINATED FETCH ---

      // If there was a critical error fetching, and allDbIngredients is empty, stop.
      if (allDbIngredients.isEmpty && _errorMessage != null) {
          setStateIfMounted(() {
              _isLoadingIngredients = false;
              // _errorMessage is already set
              productSafetyGuidance = ProductScorer.getOverallProductGuidance([]);
          });
          return;
      }
      
      setStateIfMounted(() { // Update UI state after fetching, before matching
         _recognizedTextState = "Analyzing ${_matchedIngredients.length} ingredients...";
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
          if (_debugIngredients.contains(ocrIngredient)) {
            print("'$ocrIngredient' ended up in UNMATCHED. Best match details logged in _findBestFuzzyMatch.");
          }
        }
      }

      setStateIfMounted(() {
        _matchedIngredients = currentMatchedIngredients;
        _unmatchedIngredients = currentUnmatchedIngredients;
        productSafetyGuidance = ProductScorer.getOverallProductGuidance(_matchedIngredients);
        _isLoadingIngredients = false; // Finally, loading is complete
        
        if (_errorMessage != null) { // If a non-critical pagination error occurred but we have some data
            _recognizedTextState = "Analysis complete (with potential data fetching issues).";
        } else if (_matchedIngredients.isNotEmpty) {
            _recognizedTextState = "Analysis Complete. Found ${_matchedIngredients.length} matching ingredients.";
        } else if (ocrIngredientsList.isNotEmpty) {
             _recognizedTextState = "Could not match any scanned text to ingredients in our database.";
            _errorMessage = "None of the ${ocrIngredientsList.length} potential ingredient terms found in the image could be matched to our database. Unmatched items: ${_unmatchedIngredients.join(', ')}";
        } else { // ocrIngredientsList was empty (already handled, but for completeness)
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
    // ... (This function remains exactly the same as your last provided version with the DEEP DEBUG block)
    Map<String, dynamic>? bestMatchData;
    double highestScore = 0.0;
    String bestMatchingDbTerm = "";
    bool isDebuggingThisIngredient = _debugIngredients.contains(ocrIngredient);

    if (isDebuggingThisIngredient) {
      print("\n--- Debugging Fuzzy Match for OCR: '$ocrIngredient' ---");
    }

    for (final dbIngredientMap in allDbIngredients) {
      final String dbRawName = dbIngredientMap['Ingredient_Name']?.toString() ?? "";
      final String dbCleanedName = _cleanIngredientString(dbRawName);

      if (dbCleanedName.isEmpty) continue;

      if (isDebuggingThisIngredient) {
          if (ocrIngredient == dbCleanedName ) {
              print("DEEP DEBUG ('$ocrIngredient'): Exact match found! DB_Raw: '$dbRawName' -> DB_Cleaned: '$dbCleanedName'. Comparing now.");
          } else if (ocrIngredient.contains(" ") && dbRawName.trim().toLowerCase() == ocrIngredient && dbCleanedName != ocrIngredient){
              print("DEEP DEBUG ('$ocrIngredient'): OCR term matches raw DB term ('$dbRawName') but cleaned DB is different ('$dbCleanedName'). Investigate cleaning of this DB entry.");
          } else if (!ocrIngredient.contains(" ") && dbRawName.trim().toLowerCase() == ocrIngredient && dbCleanedName != ocrIngredient && dbCleanedName.replaceAll(" ", "") == ocrIngredient) {
              print("DEEP DEBUG ('$ocrIngredient'): OCR is single word, matches raw DB ('$dbRawName'), but cleaned DB ('$dbCleanedName') has spaces. Cleaned DB w/o spaces: '${dbCleanedName.replaceAll(" ", "")}'");
          }
      }

      final similarityScore = StringSimilarity.compareTwoStrings(ocrIngredient, dbCleanedName);

      if (isDebuggingThisIngredient) {
        if (similarityScore > 0.6 || dbCleanedName.contains(ocrIngredient) || ocrIngredient.contains(dbCleanedName)) {
          print("Comparing OCR:'$ocrIngredient' with DB_Raw:'$dbRawName' -> DB_Cleaned:'$dbCleanedName', Score: $similarityScore");
        }
      }

      if (similarityScore > highestScore) {
        highestScore = similarityScore;
        bestMatchData = Map<String, dynamic>.from(dbIngredientMap);
        bestMatchData['similarityScore'] = highestScore;
        bestMatchingDbTerm = dbCleanedName;
      }
    }

    if (isDebuggingThisIngredient) {
       if (bestMatchData != null) {
          print("Best match for OCR:'$ocrIngredient' is DB:'${bestMatchData['Ingredient_Name']}' (Cleaned: '$bestMatchingDbTerm'), Final Score: $highestScore");
       } else {
          print("No suitable match found for OCR:'$ocrIngredient' with threshold >= 0.7. Highest score was $highestScore (against '$bestMatchingDbTerm' if any).");
       }
       print("--- End Debug for '$ocrIngredient' ---\n");
    }
    return (highestScore >= 0.7) ? bestMatchData : null;
  }

  @override
  Widget build(BuildContext context) {
    // ... (Build method remains the same) ...
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
          : _errorMessage != null && _matchedIngredients.isEmpty // Show error prominently if no matches AND error exists
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