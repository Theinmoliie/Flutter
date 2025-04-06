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


     // Weights based on EWG standards
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