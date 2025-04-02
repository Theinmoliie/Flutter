import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/skin_profile_provider.dart';

double calculateCompatibilityScore({
  required BuildContext context,
  required List<Map<String, dynamic>> ingredients,
  required Map<int, bool> skinTypeSuitability,
  // required Map<int, bool> skinConcernSuitability,
}) {
  // Safely get user profile
  final skinProfile = Provider.of<SkinProfileProvider>(context, listen: false);
  final String userSkinType = skinProfile.userSkinType;
  final List<String> userConcerns = skinProfile.userConcerns ?? [];

  print('\n=== Starting Compatibility Calculation ===');
  print('User Skin Type: $userSkinType');
  print('User Concerns: $userConcerns');
  print('Number of Ingredients: ${ingredients.length}');

  // Initialize scores
  double skinTypeSum = 0.0;
  double comedogenicityPenalty = 0.0;
  double irritationPenalty = 0.0;
  int evaluatedSkinTypeCount = 0;
  int totalIngredients = ingredients.length;

  // Condition flags
  final bool isAcneProne = 
      userSkinType == "Oily" || 
      userConcerns.contains("Acne") || 
      userConcerns.contains("Enlarged Pores") || 
      userConcerns.contains("Blackheads");

  final bool isSensitive = 
      userSkinType == "Sensitive" || 
      userConcerns.contains("Redness") || 
      userConcerns.contains("Impaired Skin Barrier");

  print('Is Acne Prone: $isAcneProne');
  print('Is Sensitive: $isSensitive');

  // Analyze ingredients
  for (final ingredient in ingredients) {
    final int? ingredientId = ingredient['Ingredient_Id'] as int?;
    if (ingredientId == null) continue;

    final String ingredientName = ingredient['Ingredient_Name'] ?? 'Unknown';
    print('\nAnalyzing ingredient: $ingredientName (ID: $ingredientId)');
    
    // 1. Skin Type Suitability (70% weight)
    if (skinTypeSuitability.containsKey(ingredientId)) {
      evaluatedSkinTypeCount++;
      final bool? isSuitable = skinTypeSuitability[ingredientId];
      if (isSuitable != null) {
        final skinTypeValue = isSuitable ? 1 : -1;
        skinTypeSum += skinTypeValue;
        print(' - Skin Type Suitability: ${isSuitable ? 'Good' : 'Bad'} (value: $skinTypeValue)');
      }
    } else {
      print(' - Skin Type Suitability: No data');
    }

    // 2. Comedogenicity (15% weight)
    if (ingredient['Comodogenic'] == true) {
      final penalty = isAcneProne ? -1.5 : 
          (userSkinType == "Combination" || userSkinType == "Normal") ? -1.0 : -0.5;
      comedogenicityPenalty += penalty;
      print(' - Comedogenic: true (penalty: $penalty)');
    } else {
      print(' - Comedogenic: no data');
    }

    // 3. Irritation Potential (15% weight)
    final irritation = ingredient['Irritation']?.toString().toLowerCase();
    if (irritation != null) {
      final penalty = switch (irritation) {
        String s when s.contains('high') => 
          isSensitive ? -1.5 : (userSkinType == "Dry") ? -1.0 : -0.5,
        String s when s.contains('moderate') => 
          isSensitive ? -1.0 : (userSkinType == "Dry") ? -0.5 : -0.25,
        _ => 0.0,
      };
      irritationPenalty += penalty;
      print(' - Irritation: $irritation (penalty: $penalty)');
    } else {
      print(' - Irritation: No data');
    }
  }

  // Calculate confidence
  final double confidence = totalIngredients > 0 
      ? evaluatedSkinTypeCount / totalIngredients 
      : 0.0;

  print('\n=== Intermediate Calculations ===');
  print('Skin Type Sum: $skinTypeSum');
  print('Comedogenicity Penalty: $comedogenicityPenalty');
  print('Irritation Penalty: $irritationPenalty');
  print('Evaluated Skin Type Count: $evaluatedSkinTypeCount/$totalIngredients');
  print('Confidence: ${(confidence * 100).toStringAsFixed(1)}%');

  // Normalize scores with updated weights
  final double skinTypeScore = evaluatedSkinTypeCount > 0
      ? (skinTypeSum / evaluatedSkinTypeCount) * 70  // 70% weightage applied
      : 0.0;

  final double weightedComedogenicity = 
      (comedogenicityPenalty / totalIngredients) * 15;

  final double weightedIrritation = 
      (irritationPenalty / totalIngredients) * 15;  // 15% weightage applied

 

  print('\n=== Weighted Scores ===');
  print('Skin Type Score: ${skinTypeScore.toStringAsFixed(2)} (70% weight)');
  print('Comedogenicity Score: ${weightedComedogenicity.toStringAsFixed(2)} (15% weight)');
  print('Irritation Score: ${weightedIrritation.toStringAsFixed(2)} (15% weight)');

  // Combine scores
  final double rawScore = skinTypeScore + 
                        weightedComedogenicity + 
                        weightedIrritation;

const double minPossible = -107.5, maxPossible = 70.0;
  final double normalizedScore = 
      ((rawScore - minPossible) / (maxPossible - minPossible)) * 100;


  // Normalize to 0-100 range (different approach than before)
  final double finalScore = normalizedScore.clamp(0.0, 100.0);

  print('\n=== Final Calculations ===');
  print('Raw Score: ${rawScore.toStringAsFixed(2)}');
  print('Normalized Score: ${normalizedScore.toStringAsFixed(2)}');

  print('\n=== Result ===');
  print('Final Score: ${finalScore.toStringAsFixed(1)}');

  return finalScore;
}