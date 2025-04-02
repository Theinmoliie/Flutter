import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class CompatibilityUtil {
  // Skin type constants
  static const int _sensitiveSkinId = 1;
  static const int _drySkinId = 2;
  static const int _normalSkinId = 3;
  static const int _combinationSkinId = 4;
  static const int _oilySkinId = 5;

  // Concern constants
  static const Set<int> _acneConcernIds = {1, 2}; // Acne-related concern IDs

  // -------------------------------
  // 1. DATABASE METHODS
  // -------------------------------

  static Future<Map<int, bool>> _fetchSkinTypeCompatibility(
    List<int> ingredientIds, 
    int skinTypeId,
  ) async {
    final res = await supabase
        .from('ingredient_skintype')
        .select('ingredient_id, is_suitable')
        .eq('skin_type_id', skinTypeId)
        .inFilter('ingredient_id', ingredientIds);

    return {for (var r in res) r['ingredient_id'] as int: r['is_suitable'] as bool};
  }

  static Future<Map<int, int>> _fetchConcernCompatibility(
    List<int> ingredientIds,
    List<int> concernIds,
  ) async {
    if (concernIds.isEmpty) return {};

    final res = await supabase
        .from('ingredient_skinconcerns')
        .select('ingredient_id, concern_id, is_suitable')
        .inFilter('concern_id', concernIds)
        .inFilter('ingredient_id', ingredientIds);

    final matches = <int, int>{};
    for (final r in res) {
      if (r['is_suitable'] as bool) {
        matches[r['ingredient_id'] as int] = 
            (matches[r['ingredient_id'] as int] ?? 0) + 1;
      }
    }
    return matches;
  }

  // -------------------------------
  // 2. CORE COMPATIBILITY SYSTEM
  // -------------------------------

  static Future<Map<String, dynamic>> calculateCompatibility({
    required List<Map<String, dynamic>> ingredients,
    required int skinTypeId,
    required List<int> concernIds,
  }) async {
    if (ingredients.isEmpty) return {'category': 'Unknown', 'score': null};

    final compatibilityData = await fetchAllCompatibilityData(
      ingredientIds: ingredients.map((i) => i['Ingredient_Id'] as int).toList(),
      skinTypeId: skinTypeId,
      concernIds: concernIds,
    );

    double totalScore = 0;
    int validIngredientsCount = 0;

    for (final ingredient in ingredients) {
      final id = ingredient['Ingredient_Id'] as int;
      if (!compatibilityData['skin_type'].containsKey(id)) continue;

      validIngredientsCount++;

      // Calculate component scores
      double skinScore = compatibilityData['skin_type'][id] ? 1.0 : 0.0;
      final irritationScore = _calculateIrritationImpact(
        ingredient['Irritation'] as String?,
        skinTypeId,
      );
      final comedogenicityImpact = _calculateComedogenicityImpact(
        ingredient['Comedogenicity'] as bool?,
        skinTypeId,
        concernIds,
      );
      
      // Combine skin factors multiplicatively
      skinScore *= irritationScore * comedogenicityImpact;

      final concernsScore = _calculateConcernsScore(
        compatibilityData['concerns'],
        id,
        concernIds.length,
      );

      final allergyScore = _calculateAllergyImpact(
        ingredient['Allergies_Immunotoxicity'] as String?,
      );

      // Apply weights (40/40/20)
      totalScore += (0.4 * skinScore) + 
                   (0.4 * concernsScore) + 
                   (0.2 * allergyScore);
    }

    if (validIngredientsCount == 0) return {'category': 'Unknown', 'score': null};

    final normalizedScore = (totalScore / validIngredientsCount);
    return {
      'score': normalizedScore,
      'category': _getCompatibilityCategory(normalizedScore),
    };
  }

  static Future<Map<String, dynamic>> fetchAllCompatibilityData({
    required List<int> ingredientIds,
    required int skinTypeId,
    required List<int> concernIds,
  }) async {
    final results = await Future.wait([
      _fetchSkinTypeCompatibility(ingredientIds, skinTypeId),
      _fetchConcernCompatibility(ingredientIds, concernIds),
    ]);

    return {
      'skin_type': results[0], // Map<int, bool>
      'concerns': results[1],  // Map<int, int>
    };
  }

  // ---------------------------
  // 3. SCORING HELPERS
  // ---------------------------

  static double _calculateConcernsScore(
    Map<int, int> concernData,
    int ingredientId,
    int numConcerns,
  ) {
    if (numConcerns == 0) return 1.0;
    return ((concernData[ingredientId] ?? 0) / numConcerns).clamp(0.0, 1.0);
  }


   static double _calculateIrritationImpact(String? irritationLevel, int skinTypeId) {
  // Return neutral impact (1.0) for low or null irritation
  if (irritationLevel == null || irritationLevel.toLowerCase() == 'low') {
    return 1.0;
  }
  
  // Only calculate impact for moderate/high irritation
  double impact = switch (irritationLevel.toLowerCase()) {
    'high' => 0.3,
    'moderate' => 0.6,
    _ => 1.0, // Fallback (shouldn't be needed due to above check)
  };

  return impact * switch (skinTypeId) {
    _sensitiveSkinId => 0.6,
    _drySkinId => 0.8,
    _normalSkinId => 0.95,
    _combinationSkinId => 0.9,
    _oilySkinId => 1.0,
    _ => 1.0,
  };
}

  static double _calculateComedogenicityImpact(
    bool? isComedogenic,
    int skinTypeId,
    List<int> concernIds,
  ) {
    if (!_shouldCheckComedogenicity(skinTypeId, concernIds)) return 1.0;
    return (isComedogenic ?? false) ? 0.3 : 1.0;
  }

  static double _calculateAllergyImpact(String? level) => switch (level?.toUpperCase()) {
    'HIGH' => 0.3,
    'MODERATE' => 0.6,
    _ => 1.0
  };

  static bool _shouldCheckComedogenicity(int skinTypeId, List<int> concernIds) {
    return skinTypeId == _oilySkinId || 
           skinTypeId == _combinationSkinId ||
           concernIds.any(_acneConcernIds.contains);
  }

  // ---------------------------
  // 4. CATEGORIZATION & UI
  // ---------------------------

  static String _getCompatibilityCategory(double score) {
    return switch (score) {
      >= 0.7 => 'Match',
      >= 0.4=> 'Use with caution',
      _ =>  'Not Recommended',  
    };
  }

  static Color getScoreColor(double score) {
    return switch (score) {
      >= 0.7 => Colors.green,
      >= 0.4 => Colors.orange,
      _ => Colors.red,
    };
  }

  static Widget buildScoreChip(double score) {
    return Chip(
      label: Text(
        _getCompatibilityCategory(score),
        style: TextStyle(color: Colors.white),
      ),
      backgroundColor: getScoreColor(score),
    );
  }

  // Add this new method to the CompatibilityUtil class
static Widget buildAllergyWarning(String? allergyLevel) {
  return switch (allergyLevel?.toUpperCase()) {
    'HIGH' => _buildWarningRow('High allergy risk', Colors.red),
    'MODERATE' => _buildWarningRow('Moderate allergy risk', Colors.orange),
    _ => Container(),
  };
}

  // Update the buildIngredientWarnings method to include allergies
static Widget buildIngredientWarnings({
  required String? irritationLevel,
  required bool? isComedogenic,
  required String? allergyLevel,
  required int skinTypeId,
  required List<int> concernIds,
}) {
  // Skip irritation warnings entirely for low/null irritation
  if (irritationLevel == null || irritationLevel.toLowerCase() == 'low') {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_shouldCheckComedogenicity(skinTypeId, concernIds) && (isComedogenic ?? false))
          _buildWarningRow('May clog pores', Colors.brown),
        buildAllergyWarning(allergyLevel),
      ],
    );
  }

  // Only calculate for moderate/high irritation
  final irritationImpact = _calculateIrritationImpact(irritationLevel, skinTypeId);
  final checkComedo = _shouldCheckComedogenicity(skinTypeId, concernIds);
  
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (irritationImpact < 0.5)
        _buildWarningRow('High irritation risk', Colors.red),
      if (irritationImpact >= 0.5 && irritationImpact < 0.8)
        _buildWarningRow('Moderate irritation risk', Colors.orange),
      if (checkComedo && (isComedogenic ?? false))
        _buildWarningRow('May clog pores', Colors.brown),
      buildAllergyWarning(allergyLevel),
    ],
  );
}

  static Widget _buildWarningRow(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
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
          Text(text, style: TextStyle(color: color)),
        ],
      ),
    );
  }
}
