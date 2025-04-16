// compatibilityscore_util.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/skin_profile_provider.dart';

double calculateCompatibilityScore({
  required BuildContext context,
  required List<Map<String, dynamic>> ingredients,
  required Map<int, bool> skinTypeSuitability,
  // required Map<int, bool> skinConcernSuitability, // Keep commented if not used
}) {
  // --- NEW: Define Weights ---
  const double weightSkinType = 60.0;
  const double weightIrritation = 25.0;
  const double weightComedogenicity = 15.0;
  // -------------------------

  // Safely get user profile
  final skinProfile = Provider.of<SkinProfileProvider>(context, listen: false);
  final String? userSkinType = skinProfile.userSkinType; // Nullable
  final List<String> userConcerns = skinProfile.userConcerns; // Already a list
  final String? userSensitivityLevel = skinProfile.userSensitivityLevel; // Non-null from provider

  // ... (Keep print statements and initialization) ...
  print('\n=== Starting Compatibility Calculation ===');
  print('Applying Weights: Skin Type=${weightSkinType}%, Irritation=${weightIrritation}%, Comedogenicity=${weightComedogenicity}%');
  print('User Skin Type: ${userSkinType ?? 'Not Set'}');
  print('User Sensitivity Level: $userSensitivityLevel');
  print('User Concerns: $userConcerns');
  print('Number of Ingredients: ${ingredients.length}');


  double skinTypeSum = 0.0;
  double comedogenicityPenalty = 0.0;
  double irritationPenalty = 0.0;
  int evaluatedSkinTypeCount = 0;
  int totalIngredients = ingredients.length;
  if (totalIngredients == 0) return 50.0;

  // --- Condition Flags (Keep as before) ---
  final bool isAcneProne =
      userSkinType == "Oily" ||
      userConcerns.contains("Acne") ||
      userConcerns.contains("Enlarged Pores") ||
      userConcerns.contains("Blackheads");
  final bool isHighlySensitiveLevel = userSensitivityLevel == 'High';
  final bool isModeratelySensitiveLevel = userSensitivityLevel == 'Medium';
  final bool hasSensitivityConcern =
      userConcerns.contains("Redness") ||
      userConcerns.contains("Impaired Skin Barrier");
  final bool isConsideredSensitive = isHighlySensitiveLevel || isModeratelySensitiveLevel || hasSensitivityConcern;
  // ... (Keep flag print statements) ...
  print('Is Acne Prone: $isAcneProne');
  print('Is Highly Sensitive Level: $isHighlySensitiveLevel');
  print('Is Moderately Sensitive Level: $isModeratelySensitiveLevel');
  print('Has Sensitivity Concern (Redness/Barrier): $hasSensitivityConcern');
  print('Is Considered Sensitive (Overall): $isConsideredSensitive');

  // --- Analyze ingredients (Keep logic for calculating penalties/sums as before) ---
  for (final ingredient in ingredients) {
    final int? ingredientId = ingredient['Ingredient_Id'] as int?;
    if (ingredientId == null) continue;
    final String ingredientName = ingredient['Ingredient_Name'] ?? 'Unknown';
    print('\nAnalyzing ingredient: $ingredientName (ID: $ingredientId)');

    // 1. Skin Type Suitability (Calculation Logic - unchanged)
    if (skinTypeSuitability.containsKey(ingredientId)) {
       // ... (logic to calculate skinTypeValue with extra penalty) ...
        evaluatedSkinTypeCount++;
        final bool? isSuitable = skinTypeSuitability[ingredientId];
        if (isSuitable != null) {
            double skinTypeValue = isSuitable ? 1.0 : -1.0;
            if (!isSuitable && isConsideredSensitive) {
                double extraPenalty = isHighlySensitiveLevel ? -1.5 : isModeratelySensitiveLevel? -1 : -0.25;
                skinTypeValue += extraPenalty;
                print('   - Extra Penalty (Sensitivity): $extraPenalty');
            }
            skinTypeSum += skinTypeValue;
            print(' - Skin Type Suitability: ${isSuitable ? 'Good' : 'Bad'} (final value: $skinTypeValue)');
        } else {
            print(' - Skin Type Suitability: No data from map');
        }
    } else {
      print(' - Skin Type Suitability: Ingredient ID not in map');
    }


    // 2. Comedogenicity (Calculation Logic - unchanged)
     final isComedogenic = ingredient['Comodogenic'] == true;
    if (isComedogenic) {
        // ... (logic to calculate penalty based on acne/oily/combo etc.) ...
         double penalty;
         if (isAcneProne) { penalty = -2.0 ; print('   - Reason: Acne Prone'); }
         else if (userSkinType == "Combination") { penalty = -1.5; print('   - Reason: Combination Skin Type'); }
         else if (userSkinType == "Normal") { penalty = -0.75; print('   - Reason: Normal Skin Type'); }
         else { penalty = -0.5; print('   - Reason: Other Skin Type'); }
         comedogenicityPenalty += penalty;
         print(' - Comedogenic: true (penalty: $penalty)');
    } else {
         print(' - Comedogenic: no data / false');
    }


    // 3. Irritation Potential (Calculation Logic - unchanged)
    final irritation = ingredient['Irritation']?.toString().toLowerCase();
    if (irritation != null) {
        // ... (logic using switch and sensitivity flags to calculate penalty) ...
         final penalty = switch (irritation) {
            String s when s.contains('high') =>
                isHighlySensitiveLevel ? -2.0 : isConsideredSensitive ? -1.5 : (userSkinType == "Dry") ? -1.0 : -0.5,
            String s when s.contains('moderate') =>
                isHighlySensitiveLevel ? -1.5 : isConsideredSensitive ? -1.0 : (userSkinType == "Dry") ? -0.5 : -0.25,
            _ => 0.0,
        };
        irritationPenalty += penalty;
        print(' - Irritation: $irritation (penalty based on overall sensitivity: $penalty)');
    } else {
      print(' - Irritation: No data');
    }

  } // End ingredient loop

  // Calculate confidence (no change)
  final double confidence = totalIngredients > 0
      ? evaluatedSkinTypeCount / totalIngredients
      : 0.0;
  // ... (Keep intermediate print statements) ...
    print('\n=== Intermediate Calculations ===');
    print('Skin Type Sum (Adjusted for Sensitivity): $skinTypeSum');
    print('Comedogenicity Penalty Sum: $comedogenicityPenalty');
    print('Irritation Penalty Sum (Adjusted for Sensitivity): $irritationPenalty');
    print('Evaluated Skin Type Count: $evaluatedSkinTypeCount/$totalIngredients');
    print('Confidence: ${(confidence * 100).toStringAsFixed(1)}%');


  // --- Normalize scores with NEW weights ---
  final double skinTypeScore = evaluatedSkinTypeCount > 0
      ? (skinTypeSum / evaluatedSkinTypeCount) * weightSkinType // Use new weight
      : 0.0;

  final double weightedComedogenicity = totalIngredients > 0
      ? (comedogenicityPenalty / totalIngredients) * weightComedogenicity // Use new weight
      : 0.0;

  final double weightedIrritation = totalIngredients > 0
      ? (irritationPenalty / totalIngredients) * weightIrritation // Use new weight
      : 0.0;
  // ------------------------------------------

  print('\n=== Weighted Scores ===');
  print('Skin Type Score: ${skinTypeScore.toStringAsFixed(2)} (${weightSkinType}% weight)');
  print('Comedogenicity Score: ${weightedComedogenicity.toStringAsFixed(2)} (${weightComedogenicity}% weight)');
  print('Irritation Score: ${weightedIrritation.toStringAsFixed(2)} (${weightIrritation}% weight)');

  // Combine scores (no change)
  final double rawScore = skinTypeScore +
                        weightedComedogenicity +
                        weightedIrritation;

  // --- UPDATE Normalization Bounds (Recalculated with NEW weights) ---
  // Max Score: All suitable (+1 avg * weightSkinType) = +60
  // Min Score:
  //   - Skin Type: Worst case (-1.5 avg) * 60 = -90
  //   - Comedogenicity: Worst case (-1.5 avg) * 15 = -22.5
  //   - Irritation: Worst case (-1.7 avg) * 25 = -42.5
  //   - Total Min = -90 - 22.5 - 42.5 = -155.0
  const double minPossible = -155.0;
  const double maxPossible = 60.0;
  // ------------------------------------------------------------------

  // Perform normalization (no change in formula)
  final double normalizedScore = (maxPossible == minPossible)
      ? 50.0
      : ((rawScore - minPossible) / (maxPossible - minPossible)) * 100;


  // Clamp to 0-100 range (no change)
  final double finalScore = normalizedScore.clamp(0.0, 100.0);
  // ... (Keep final print statements) ...
    print('\n=== Final Calculations ===');
    print('Raw Score: ${rawScore.toStringAsFixed(2)}');
    print('Normalized Score: ${normalizedScore.toStringAsFixed(2)} (Range: $minPossible to $maxPossible)');
    print('\n=== Result ===');
    print('Final Score: ${finalScore.toStringAsFixed(1)}');


  return finalScore;
}