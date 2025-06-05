  // ProductSafety/ocr_safety_display_screen.dart
  //LOGIC (OCR + matching) & DISPLAY for safety of UNKNOWN (scanned) products.
  
    import 'dart:io';
    import 'package:flutter/material.dart';
    import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
    import 'package:supabase_flutter/supabase_flutter.dart';
    import 'package:string_similarity/string_similarity.dart';
    import '../../util/safetyscore_util.dart'; // Adjust path
    import 'safety_guide_ui.dart';         // Adjust path

    class OcrSafetyDisplayScreen extends StatefulWidget {
      final File imageFile;
      // final VoidCallback onProfileRequested; // Not strictly needed for pure safety

      const OcrSafetyDisplayScreen({
        required this.imageFile,
        // required this.onProfileRequested,
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
            setStateIfMounted(() => _recognizedTextState = "Text recognized. Analyzing ingredients...");
            await _processAndFetchIngredientsSafety(recognizedTextContent);
          } else {
            setStateIfMounted(() {
              _recognizedTextState = "No text found.";
              _isLoadingIngredients = false;
              _errorMessage = "No text recognized in the image.";
              productSafetyGuidance = ProductScorer.getOverallProductGuidance([]);
            });
          }
        } catch (e) {
          print("Error during OCR: $e");
          setStateIfMounted(() {
            _recognizedTextState = "OCR Error.";
            _isLoadingIngredients = false;
            _errorMessage = "Error in OCR processing. Please try another image.";
            productSafetyGuidance = ProductScorer.getOverallProductGuidance([]);
          });
        } finally {
          textRecognizer.close();
        }
      }

      Future<void> _processAndFetchIngredientsSafety(String extractedText) async {
        setStateIfMounted(() {
          _isLoadingIngredients = true;
          _errorMessage = null;
        });
        String cleanedText = extractedText
            .replaceAll(RegExp(r'Ingredients:?', caseSensitive: false), '')
            .replaceAll(RegExp(r'\n'), ' ')
            .replaceAll(RegExp(r'\s{2,}'), ' ')
            .trim();
        final colonIndex = cleanedText.indexOf(':');
        if (colonIndex != -1) {
          cleanedText = cleanedText.substring(colonIndex + 1).trim();
        }
        final ocrIngredientsList = cleanedText
            .split(RegExp(r'[,.;)(]\s*|\s*[,.;)(]'))
            .map((e) => e.trim().toLowerCase())
            .where((e) => e.isNotEmpty && e.length > 2)
            .toList();

        if (ocrIngredientsList.isEmpty) {
          setStateIfMounted(() {
            _recognizedTextState = "No ingredients extracted from text.";
            _isLoadingIngredients = false;
            _errorMessage = "No ingredients could be clearly extracted from the recognized text.";
            productSafetyGuidance = ProductScorer.getOverallProductGuidance([]);
          });
          return;
        }
        print("OCR Ingredients: $ocrIngredientsList");

        try {
          List<Map<String, dynamic>> allDbIngredients = [];
          try {
            final response = await supabase.from('Safety Rating').select(
                'Ingredient_Id, Ingredient_Name, Score, Irritation, Comodogenic, Other_Concerns, Cancer_Concern, Allergies_Immunotoxicity, Developmental_Reproductive_Toxicity, Function, Benefits');
            allDbIngredients = (response as List).cast<Map<String, dynamic>>();
          } catch (e) {
            print("DB connection error for safety data: $e");
            setStateIfMounted(() {
              _isLoadingIngredients = false;
              _errorMessage = "Database connection error. Please try again later.";
              productSafetyGuidance = ProductScorer.getOverallProductGuidance([]);
            });
            return;
          }

          final List<Map<String, dynamic>> currentMatchedIngredients = [];
          final List<String> currentUnmatchedIngredients = [];
          for (final ocrIngredient in ocrIngredientsList) {
            final bestMatch = _findBestFuzzyMatch(ocrIngredient, allDbIngredients);
            if (bestMatch != null && bestMatch['similarityScore'] >= 0.7) { // Similarity threshold
              bestMatch['originalIngredient'] = ocrIngredient; // Store what was scanned
              currentMatchedIngredients.add(bestMatch);
            } else {
              currentUnmatchedIngredients.add(ocrIngredient);
            }
          }

          setStateIfMounted(() {
            _matchedIngredients = currentMatchedIngredients;
            _unmatchedIngredients = currentUnmatchedIngredients;
            productSafetyGuidance = ProductScorer.getOverallProductGuidance(_matchedIngredients);
            _isLoadingIngredients = false;
            _recognizedTextState = _matchedIngredients.isNotEmpty
                ? "Analysis Complete. Found ${_matchedIngredients.length} matching ingredients."
                : "Could not match any scanned text to ingredients in our database.";
            if (_matchedIngredients.isEmpty && _unmatchedIngredients.isNotEmpty) {
                 _errorMessage = "None of the scanned text items could be matched to ingredients in our database.";
            } else if (_matchedIngredients.isEmpty && _unmatchedIngredients.isEmpty && ocrIngredientsList.isNotEmpty){
                 _errorMessage = "No valid ingredients were extracted after cleaning the scanned text.";
            }

          });
        } catch (e) {
          print("Error analyzing ingredients: $e");
          setStateIfMounted(() {
            _isLoadingIngredients = false;
            _errorMessage = "An error occurred while analyzing ingredients.";
            productSafetyGuidance = ProductScorer.getOverallProductGuidance([]);
          });
        }
      }

      Map<String, dynamic>? _findBestFuzzyMatch(
          String ocrIngredient, List<Map<String, dynamic>> allDbIngredients) {
        Map<String, dynamic>? bestMatchData;
        double highestScore = 0.0;
        for (final dbIngredientMap in allDbIngredients) {
          final String dbIngredientName = dbIngredientMap['Ingredient_Name']?.toString().toLowerCase() ?? "";
          if (dbIngredientName.isEmpty) continue;
          final similarityScore = StringSimilarity.compareTwoStrings(ocrIngredient, dbIngredientName);
          if (similarityScore > highestScore) {
            highestScore = similarityScore;
            bestMatchData = Map<String, dynamic>.from(dbIngredientMap); // Create a new map
            bestMatchData['similarityScore'] = highestScore;
          }
        }
        return (highestScore >= 0.7) ? bestMatchData : null; // Use similarity threshold
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
                    Text(_recognizedTextState, textAlign: TextAlign.center),
                  ],
                ))
              : _errorMessage != null && _matchedIngredients.isEmpty // Show error prominently if no matches AND error exists
                  ? Center(
                      child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(_errorMessage!,
                          style: const TextStyle(color: Colors.red, fontSize: 16),
                          textAlign: TextAlign.center),
                    ))
                  : SafetyGuideUI( // Pass the data to the UI widget
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