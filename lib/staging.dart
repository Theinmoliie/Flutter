import 'package:flutter/material.dart';
import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:string_similarity/string_similarity.dart';
import 'score_util.dart'; // Import the utility file

class StagingScreen extends StatefulWidget {
  final File imageFile;
  StagingScreen({required this.imageFile});

  @override
  _StagingScreenState createState() => _StagingScreenState();
}

class _StagingScreenState extends State<StagingScreen> {
  String _recognizedText = "Processing...";
  List<Map<String, dynamic>> _matchedIngredients = [];
  List<String> _unmatchedIngredients = []; // Track unmatched ingredients
  double? averageScore; // Add this variable to store the average score

  @override
  void initState() {
    super.initState();
    _recognizeText();
  }

  Future<void> _recognizeText() async {
    final inputImage = InputImage.fromFile(widget.imageFile);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      final RecognizedText recognizedText = await textRecognizer.processImage(
        inputImage,
      );

      print("OCR Extracted Text: ${recognizedText.text}");

      if (recognizedText.text.isNotEmpty) {
        setState(() {
          _recognizedText = recognizedText.text;
        });
        await _fetchIngredientDetails(_recognizedText);
      } else {
        print("No text detected.");
        setState(() {
          _recognizedText = "No text found.";
        });
      }
    } catch (e) {
      print("Error during text recognition: $e");
      setState(() {
        _recognizedText = "Error recognizing text: $e";
      });
    } finally {
      textRecognizer.close();
    }
  }

  Future<void> _fetchIngredientDetails(String extractedText) async {
    final supabase = Supabase.instance.client;

    // Step 1: Clean and normalize OCR text
    String cleanedText =
        extractedText
            .replaceAll(
              RegExp(r'Ingredients:?', caseSensitive: false),
              '',
            ) // Remove headers
            .replaceAll(RegExp(r'\n'), ' ') // Replace new lines with spaces
            .replaceAll(RegExp(r'\s{2,}'), ' ') // Remove extra spaces
            .trim()
            .toLowerCase(); // Normalize case

    // Step 1.1: Remove everything before the first ':'
    final colonIndex = cleanedText.indexOf(':');
    if (colonIndex != -1) {
      cleanedText = cleanedText.substring(colonIndex + 1).trim();
    }

    print("📝 Cleaned OCR Text: $cleanedText");

    // Step 2: Extract ingredients
    final ingredients =
        cleanedText
            .split(RegExp(r'[,.;]')) // Split by common delimiters
            .map((e) => e.trim().toLowerCase()) // Trim spaces & lowercase
            .where((e) => e.isNotEmpty) // Remove empty items
            .toList();

    print("🔍 Parsed Ingredients: $ingredients");

    if (ingredients.isEmpty) {
      print("⚠️ No valid ingredients extracted.");
      return;
    }

    // Step 3: Match ingredients with the Safety Rating table
    try {
      final List<Map<String, dynamic>> matchedIngredients = [];
      final List<String> unmatchedIngredients = [];

      for (final ingredient in ingredients) {
        // Query Supabase for matching ingredient (case-insensitive)
        final response = await supabase
            .from('Safety Rating')
            .select('*')
            .ilike('Ingredient_Name', '$ingredient'); // Case-insensitive match

        if (response.isNotEmpty) {
          // Add matched ingredients to the list
          matchedIngredients.addAll(
            (response as List).cast<Map<String, dynamic>>(),
          );
        } else {
          // Add unmatched ingredients to the list
          unmatchedIngredients.add(ingredient);
        }
      }

      // Step 4: Update the state with matched ingredients
      setState(() {
        _matchedIngredients = matchedIngredients;
        _unmatchedIngredients =
            unmatchedIngredients; // Update unmatched ingredients

        averageScore = ProductScorer.calculateSafetyScore(
          _matchedIngredients,
        ); // Calculate average score
      });

      print("✅ Matched Ingredients: $_matchedIngredients");
      print("🔍 Unmatched Ingredients: $unmatchedIngredients");

      // Step 5: Apply fuzzy logic to unmatched ingredients
      if (unmatchedIngredients.isNotEmpty) {
        await _applyFuzzyLogic(unmatchedIngredients);
      }
    } catch (e) {
      print("❌ Error fetching ingredient details: $e");
      setState(() {
        _recognizedText = "Error fetching ingredient details: $e";
      });
    }
  }

  Future<void> _applyFuzzyLogic(List<String> unmatchedIngredients) async {
    final supabase = Supabase.instance.client;

    try {
      // Step 1: Fetch all ingredients from the Safety Rating table
      final response = await supabase.from('Safety Rating').select('*');

      if (response.isEmpty) {
        print("⚠️ No ingredients found in the Safety Rating table.");
        return;
      }

      final List<Map<String, dynamic>> allIngredients =
          (response as List).cast<Map<String, dynamic>>();

      // Step 2: Apply fuzzy logic to unmatched ingredients
      final List<Map<String, dynamic>> fuzzyMatches = [];
      final List<String> stillUnmatchedIngredients = [];
      final List<String> matchedOriginalIngredients =
          []; // Track matched original ingredient names

      for (final ingredient in unmatchedIngredients) {
        final bestMatch = _findBestFuzzyMatch(ingredient, allIngredients);

        if (bestMatch != null) {
          bestMatch['originalIngredient'] =
              ingredient; // Add original ingredient name
          bestMatch['similarityScore'] =
              bestMatch['similarityScore']; // Add similarity score
          fuzzyMatches.add(bestMatch);
          matchedOriginalIngredients.add(ingredient);
          print(
            "✅ Fuzzy Match for '$ingredient': ${bestMatch['Ingredient_Name']} (Score: ${bestMatch['similarityScore']})",
          );
        } else {
          stillUnmatchedIngredients.add(
            ingredient,
          ); // Add to still unmatched list
          print("⚠️ No fuzzy match found for '$ingredient'");
        }
      }

      // Step 3: Re-check still unmatched ingredients with ilike
      if (stillUnmatchedIngredients.isNotEmpty) {
        final List<Map<String, dynamic>> ilikeMatches = [];

        for (final ingredient in stillUnmatchedIngredients) {
          // Query Supabase with ilike
          final response = await supabase
              .from('Safety Rating')
              .select('*')
              .ilike(
                'Ingredient_Name',
                '%$ingredient%',
              ); // Use ilike for partial matches

          if (response.isNotEmpty) {
            // Find the best match among the ilike results using fuzzy logic
            final bestIlikeMatch = _findBestFuzzyMatch(
              ingredient,
              (response as List).cast<Map<String, dynamic>>(),
            );

            if (bestIlikeMatch != null) {
              bestIlikeMatch['originalIngredient'] =
                  ingredient; // Add original ingredient name
              bestIlikeMatch['similarityScore'] =
                  bestIlikeMatch['similarityScore']; // Add similarity score
              ilikeMatches.add(bestIlikeMatch);
              matchedOriginalIngredients.add(
                ingredient,
              ); // Track the original ingredient name
              print(
                "✅ Best ILike Match for '$ingredient': ${bestIlikeMatch['Ingredient_Name']} (Score: ${bestIlikeMatch['similarityScore']})",
              );
            } else {
              print(
                "⚠️ No good match found for '$ingredient' among ilike results",
              );
            }
          } else {
            print("⚠️ No ilike match found for '$ingredient'");
          }
        }

        // Add ilike matches to the fuzzy matches list
        fuzzyMatches.addAll(ilikeMatches);
      }

      // Step 4: Update the state with fuzzy and ilike matches
      setState(() {
        _matchedIngredients = [..._matchedIngredients, ...fuzzyMatches];

        // Remove matched ingredients from the unmatched list
        _unmatchedIngredients =
            _unmatchedIngredients
                .where(
                  (ingredient) =>
                      !matchedOriginalIngredients.contains(ingredient),
                )
                .toList();
      });

      print("✅ Updated Matched Ingredients: $_matchedIngredients");
      print("✅ Updated Unmatched Ingredients: $_unmatchedIngredients");
    } catch (e) {
      print("❌ Error applying fuzzy logic: $e");
    }
  }

  // Helper function to find the best fuzzy match
  Map<String, dynamic>? _findBestFuzzyMatch(
    String ingredient,
    List<Map<String, dynamic>> allIngredients,
  ) {
    Map<String, dynamic>? bestMatch;
    double highestScore = 0.0;

    for (final dbIngredient in allIngredients) {
      final dbIngredientName =
          dbIngredient['Ingredient_Name'].toString().toLowerCase();

      // Calculate similarity score
      final similarityScore = StringSimilarity.compareTwoStrings(
        ingredient,
        dbIngredientName,
      );

      // Check if the similarity score meets the threshold (0.7)
      if (similarityScore >= 0.7 && similarityScore > highestScore) {
        highestScore = similarityScore;
        bestMatch = dbIngredient;
        bestMatch['similarityScore'] =
            highestScore; // Add similarity score to the match
      }
    }

    return bestMatch;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Product Safety Details",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color.fromARGB(255, 170, 136, 176),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: SizedBox(
                  width: double.infinity,
                  height: 300,
                  child: Image.file(widget.imageFile, fit: BoxFit.contain),
                ),
              ),
              SizedBox(height: 10),

              // Text(
              //   "Extracted Text:",
              //   style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              // ),
              // SizedBox(height: 10),
              // Text(
              //   _recognizedText,
              //   style: TextStyle(fontSize: 16),
              //   textAlign: TextAlign.left,
              // ),
              // SizedBox(height: 20),
              // Safety Scale Image
              Container(
                margin: EdgeInsets.symmetric(vertical: 8),
                child: Image.asset(
                  'assets/SafetyScale.png',
                  height: 50,
                  width: double.infinity,
                ),
              ),
               SizedBox(height: 10),


              // Display Average Score
              if (averageScore != null)
                Center(
                  child: Container(
                    // margin: EdgeInsets.symmetric(vertical: 9),
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: ProductScorer.getScoreColor(averageScore!),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "Average Safety Score: ${averageScore!.toStringAsFixed(1)}",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              // Add a gap between Average Score and Matched Ingredients
              SizedBox(height: 20),

              Text(
                "Matched Ingredients:",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),

              _matchedIngredients.isEmpty
                  ? Text("No matching ingredients found.")
                  : ListView.builder(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: _matchedIngredients.length,
                    itemBuilder: (context, index) {
                      final ingredient = _matchedIngredients[index];
                      int score = ingredient['Score'] ?? 0;
                      double similarityScore =
                          ingredient['similarityScore'] ??
                          1.0; // Default to 1.0 if not set
                      String originalIngredient =
                          ingredient['originalIngredient'] ??
                          ingredient['Ingredient_Name'];

                      return Container(
                        margin: EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
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
                              tilePadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              backgroundColor: Colors.white,
                              collapsedBackgroundColor: Colors.white,
                              leading: Container(
                                width: 35,
                                height: 35,
                                decoration: BoxDecoration(
                                  color:  ProductScorer.getScoreColor(score.toDouble()),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    "$score",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              title: Text(
                                ingredient['Ingredient_Name'] ??
                                    "Not Specified", // Display matched Ingredient_Name
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle:
                                  similarityScore <
                                          1.0 // Show subtitle for non-exact matches
                                      ? Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Original: $originalIngredient",
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey,
                                            ),
                                          ),
                                          Wrap(
                                            children: [
                                              Text(
                                                "Similarity: ${(similarityScore * 100).toStringAsFixed(1)}%",
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                              SizedBox(width: 4),
                                              Tooltip(
                                                message:
                                                    "This ingredient was matched using fuzzy logic. The similarity score indicates how close the match is. For non-exact matches, we recommend confirming the analysis with other sources.",
                                                child: Text(
                                                  "⚠️ Not an exact match. Confirm with other sources.",
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
                                      : null, // No subtitle for exact matches
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.only(
                                      bottomLeft: Radius.circular(15),
                                      bottomRight: Radius.circular(15),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                      SizedBox(height: 5),
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

              // Display Unmatched Ingredients
              if (_unmatchedIngredients.isNotEmpty) ...[
                SizedBox(height: 20),
                Text(
                  "Unmatched Ingredients:",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),
                ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: _unmatchedIngredients.length,
                  itemBuilder: (context, index) {
                    final ingredient = _unmatchedIngredients[index];
                    return Card(
                      margin: EdgeInsets.symmetric(vertical: 5),
                      child: Padding(
                        padding: EdgeInsets.all(10),
                        child: Text(ingredient, style: TextStyle(fontSize: 16)),
                      ),
                    );
                  },
                ),

                // Display safety note at the bottom
                Padding(
                  padding: EdgeInsets.only(top: 20),
                  child: Text(
                    "All safety ratings displayed are referred from EWG's Skin Deep database.\n"
                    "The overall product's hazard score is an average of the ingredients’ hazard scores.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
