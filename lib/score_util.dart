import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class ProductScorer {
  // ---------------------------
  // 1. SAFETY SCORE CALCULATION
  // ---------------------------
  static double? calculateSafetyScore(List<Map<String, dynamic>> ingredients) {
    if (ingredients.isEmpty) return null;

    // Weights based on toxicology standards
    // const double W_s = 1.0;  // Safety Score weight
    // const double W_c = 0.5;  // Cancer Concern weight   0.5
    // const double W_a = 0.3;  // Allergy Concern weight  0.3
    // const double W_d = 0.4;  // Developmental Toxicity weight  0.4
    // const double P_h = 1.5;  // High-risk penalty (EWG ≥7)
    // const double P_c = 0.5;  // Comedogenic penalty


     // Weights based on toxicology standards
    const double W_s = 1.0;  // Safety Score weight
    const double W_c = 1.0;  // Cancer Concern weight   0.5
    const double W_a = 1.0;  // Allergy Concern weight  0.3
    const double W_d = 1.0;  // Developmental Toxicity weight  0.4
    const double P_h = 2.0;  // High-risk penalty (EWG ≥7)
    const double P_c = 0.5;  // Comedogenic penalty

    double totalScore = 0;
    int highRiskCount = 0;
    int comedogenicCount = 0;

    for (final ingredient in ingredients) {
      if (ingredient['Score'] == null) continue;

      // Convert concern levels (HIGH=3, MODERATE=2, LOW=1)
      final scores = {
        'base': ingredient['Score'].toDouble(),
        'cancer': _convertConcernLevel(ingredient['Cancer_Concern']),
        'allergy': _convertConcernLevel(ingredient['Allergies_Immunotoxicity']),
        'developmental': _convertConcernLevel(
            ingredient['Developmental_Reproductive_Toxicity']),
      };

      // Apply weights
      totalScore += scores['base']! * W_s +
                   scores['cancer']! * W_c +
                   scores['allergy']! * W_a +
                   scores['developmental']! * W_d;

      // Count penalties
      if (ingredient['Score'] >= 7) highRiskCount++;
      if (ingredient['Comodogenic'] == true) comedogenicCount++;
    }

    // Apply penalties
    final rawScore = totalScore + 
                    (highRiskCount * P_h) + 
                    (comedogenicCount * P_c);

    // Normalize to 1-10 scale
    final maxBaseScore = ingredients.length * 
                        (10 * W_s + 3 * W_c + 3 * W_a + 3 * W_d);
    final maxPenalties = ingredients.length * (P_h + P_c);
    return (rawScore / (maxBaseScore + maxPenalties)) * 10;
  }

  // -------------------------------
  // 2. COMPATIBILITY SYSTEM
  // -------------------------------
  
  /// Batch fetches all compatibility data in 2 parallel queries
  // static Future<Map<String, dynamic>> fetchAllCompatibilityData({
  //   required List<int> ingredientIds,
  //   required int skinTypeId,
  //   required List<int> concernIds,
  // }) async {
  //   final results = await Future.wait([
  //     _fetchSkinTypeCompatibility(ingredientIds, skinTypeId),
  //     _fetchConcernCompatibility(ingredientIds, concernIds),
  //   ]);

  //   return {
  //     'skin_type': results[0], // Map<int, bool>
  //     'concerns': results[1],  // Map<int, int>
  //   };
  // }

  // /// Calculates overall compatibility score (uses batch data)
  // static Future<double?> calculateCompatibilityScore({
  //   required List<Map<String, dynamic>> ingredients,
  //   required int skinTypeId,
  //   required List<int> concernIds,
  // }) async {
  //   if (ingredients.isEmpty) return null;

  //   final compatibilityData = 
  //       await fetchAllCompatibilityData(
  //         ingredientIds: ingredients.map((i) => i['Ingredient_Id'] as int).toList(),
  //         skinTypeId: skinTypeId,
  //         concernIds: concernIds,
  //       );

  //   double totalScore = 0;
  //   final numConcerns = concernIds.length;

  //   for (final ingredient in ingredients) {
  //     final id = ingredient['Ingredient_Id'] as int;
      
  //     final scores = {
  //       'skin_type': (compatibilityData['skin_type'][id] as bool?) ?? false ? 1.0 : 0.0,
  //       'concerns': numConcerns > 0 
  //           ? ((compatibilityData['concerns'][id] as int?) ?? 0) / numConcerns 
  //           : 0.0,
  //       'allergy': _calculateAllergyImpact(
  //         ingredient['Allergies_Immunotoxicity'] as String?,
         
  //       ),
  //     };

  //     totalScore += (0.4 * scores['skin_type']!) + 
  //                  (0.4 * scores['concerns']!) + 
  //                  (0.2 * scores['allergy']!);
  //   }

  //   return (totalScore / ingredients.length) * 10;
  // }

  // /// Gets detailed compatibility for a single ingredient (uses pre-fetched data)
  // static Map<String, dynamic> getIngredientCompatibility({
  //   required int ingredientId,
  //   required Map<int, bool> skinTypeData,
  //   required Map<int, int> concernData,
  //   required List<int> userConcernIds,
  //   String? allergyLevel,
  // }) {
  //   return {
  //     'skin_type': skinTypeData[ingredientId] ?? false,
  //     'concerns': {
  //       for (final concernId in userConcernIds)
  //         concernId: _isConcernCompatible(ingredientId, concernId, concernData),
  //     },
  //     'allergy_safe': _calculateAllergyImpact(
  //       allergyLevel,
  //     ),
  //   };
  // }

  // ---------------------------
  // 3. HELPER METHODS
  // ---------------------------
  static double _convertConcernLevel(String? level) {
    switch (level?.toUpperCase()) {
      case 'HIGH': return 3.0;
      case 'MODERATE': return 2.0;
      case 'LOW': return 1.0;
      default: return 1.0;
    }
  }

  // static Future<Map<int, bool>> _fetchSkinTypeCompatibility(
  //   List<int> ingredientIds, 
  //   int skinTypeId,
  // ) async {
  //   final res = await supabase
  //       .from('ingredient_skintype')
  //       .select('ingredient_id, is_suitable')
  //       .eq('skin_type_id', skinTypeId)
  //       .inFilter('ingredient_id', ingredientIds);

  //   return {for (var r in res) r['ingredient_id'] as int: r['is_suitable'] as bool};
  // }

  // static Future<Map<int, int>> _fetchConcernCompatibility(
  //   List<int> ingredientIds,
  //   List<int> concernIds,
  // ) async {
  //   if (concernIds.isEmpty) return {};

  //   final res = await supabase
  //       .from('ingredient_skinconcerns')
  //       .select('ingredient_id, is_suitable')
  //       .inFilter('concern_id', concernIds)
  //       .inFilter('ingredient_id', ingredientIds);

  //   final matches = <int, int>{};
  //   for (final r in res) {
  //     if (r['is_suitable'] as bool) {
  //       matches[r['ingredient_id'] as int] = (matches[r['ingredient_id'] as int] ?? 0) + 1;
  //     }
  //   }
  //   return matches;
  // }

  // static bool _isConcernCompatible(
  //   int ingredientId,
  //   int concernId,
  //   Map<int, int> concernData,
  // ) {
  //   return (concernData[ingredientId] ?? 0) > 0;
  // }

  // static double _calculateAllergyImpact(
  //   String? allergyLevel
  // ) {
    
  //   switch (allergyLevel?.toUpperCase()) {
  //     case 'HIGH': return 0.3;
  //     case 'MODERATE': return 0.7;
  //     default: return 1.0;
  //   }
  // }

  // ---------------------------
  // 4. UI UTILITIES
  // ---------------------------
  static Color getScoreColor(double score) {
    if (score <= 3.0) return Colors.green;
    if (score <= 7.0) return Colors.orange;
    return Colors.red;
  }

  static Widget buildRiskIndicator(String label, String? level) {
    final displayValue = level ?? "Not Specified";
    final color = switch (level?.toUpperCase()) {
      'HIGH' => Colors.red,
      'MODERATE' => Colors.orange,
      'LOW' => Colors.green,
      _ => Colors.grey,
    };

    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        Text("$label: $displayValue"),
      ],
    );
  }
}