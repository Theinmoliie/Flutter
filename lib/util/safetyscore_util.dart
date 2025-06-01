// safetyscore_util.dart
import 'package:flutter/material.dart';

// --- Data Class for Guidance Result ---
class ProductGuidance {
  final String category; // "Safe", "Good", "Caution advised", "Unsafe", "Indeterminate", "No Data"
  final String actionableAdvice;
  final String detail;
  final Map<String, dynamic>? determiningIngredient;

  ProductGuidance({
    required this.category,
    required this.actionableAdvice,
    required this.detail,
    this.determiningIngredient,
  });
}

class ProductScorer {

  // Helper to convert EWG score string (e.g., '01', '5', '10') to an internal category and a severity level.
  // Severity order (lower is better numerically, but "worse" in impact):
  // 1: Safe
  // 2: Good
  // 3: Caution advised
  // 4: Unsafe
  // 0: Unknown/Data N/A/Error (least impact on determining overall score unless all are this)
  static Map<String, dynamic> _getIngredientCategoryAndSeverity(String? scoreStr) {
    if (scoreStr == null || 
        scoreStr.toLowerCase() == "n/a" || 
        scoreStr.toLowerCase().contains("not found") || // Broader check for "not found"
        scoreStr.isEmpty) {
      return {"category": "Unknown", "severity": 0}; // Use "Unknown" category
    }
    try {
      int score = int.parse(scoreStr); // EWG scores are 1-10 (sometimes 0 for very safe like water)
                                      // Or you might have your own mapping for '01'-'10'
      
      // Your defined mapping:
      // 0–2 Safe
      // 3–4 Good (Previously Moderately Safe)
      // 5–6 Caution advised (Previously Potentially Unsafe)
      // 7–10 Unsafe

      if (score == 0) { // Explicitly handle 0 as Safe
      return {"category": "Unknown", "severity": 0}; 
      } else if (score >= 1 && score <= 2) {
        return {"category": "Safe", "severity": 1};
      } else if (score >= 3 && score <= 4) {
        return {"category": "Good", "severity": 2}; // NEW LABEL
      } else if (score >= 5 && score <= 6) {
        return {"category": "Caution advised", "severity": 3}; // NEW LABEL
      } else if (score >= 7 && score <= 10) {
        return {"category": "Unsafe", "severity": 4};
      } else {
        // This case should ideally not be hit if EWG scores are always 0-10
        print("Warning: Score '$scoreStr' is outside expected 1-10 range.");
        return {"category": "Unknown Score Range", "severity": 0}; 
      }
    } catch (e) {
      // This catches errors if scoreStr is not a valid integer (e.g., textual like "Low")
      print("Error converting ingredient score '$scoreStr' to int: $e");
      return {"category": "Data Error", "severity": 0}; 
    }
  }

  // --- METHOD for "Weakest Link" Product Guidance ---
  static ProductGuidance getOverallProductGuidance(List<Map<String, dynamic>> ingredients) {
    if (ingredients.isEmpty) {
      return ProductGuidance(
        category: "No Data",
        actionableAdvice: "Cannot assess product safety as no ingredient information is available.",
        detail: "No ingredients were provided for analysis.",
      );
    }

    String overallCategory = "Safe"; // Default to best
    int maxSeverity = 1; // Severity for "Safe" (lowest numerical severity is best category)
    Map<String, dynamic>? determiningIngredientData;
    int unknownScoreCount = 0;

    for (final ingredient in ingredients) {
      final String? scoreValue = ingredient['Score']?.toString();
      
      final ingredientAssessment = _getIngredientCategoryAndSeverity(scoreValue);
      final String currentCategory = ingredientAssessment['category'];
      final int currentSeverity = ingredientAssessment['severity'];

      if (currentSeverity == 0) { // Tracks ingredients with "Unknown", "Data N/A", "Data Error"
          unknownScoreCount++;
      }

      // If current ingredient's severity is WORSE (higher number) than maxSeverity found so far
      if (currentSeverity > maxSeverity) {
        maxSeverity = currentSeverity;
        overallCategory = currentCategory;
        determiningIngredientData = ingredient; 
      }
    }

    String actionableAdvice = "";
    String detailText = "";

    final String determiningIngredientName = 
        determiningIngredientData?['Ingredient_Name'] ?? (ingredients.isNotEmpty ? "an ingredient" : "N/A");
    // Get score of determining ingredient, or score of first ingredient if all were 'Safe'
    final String determiningIngredientScoreOrFirstScore =
        determiningIngredientData?['Score']?.toString() ?? 
        (ingredients.isNotEmpty ? ingredients.first['Score']?.toString() ?? "N/A" : "N/A");


    if (maxSeverity == 0 && unknownScoreCount == ingredients.length) {
      // All ingredients had unknown/error scores
      overallCategory = "Indeterminate"; // Or "Unknown"
      actionableAdvice = "Product safety cannot be determined due to missing or uninterpretable EWG scores for all ingredients. Please review manually.";
      detailText = "The assessment could not be completed as no valid EWG scores were found for the ingredients.";
    } else if (determiningIngredientData != null) { // A "worse" ingredient determined the category
       detailText = "This assessment is based on '$determiningIngredientName' (EWG Score: $determiningIngredientScoreOrFirstScore), which presents the highest relative concern in this product according to EWG's ingredient hazard ratings.";
    } else { // All ingredients were processed, and none were worse than "Safe" (maxSeverity remained 1)
       detailText = "All scored ingredients in this product fall into EWG's low hazard category ('Safe').";
    }


    switch (overallCategory) {
      case "Unsafe": // Severity 4
        actionableAdvice = "This product contains one or more high-hazard ingredients. Avoiding this product is recommended, or consult a specialist if use is necessary.";
        break;
      case "Caution advised": // Severity 3
        actionableAdvice = "This product contains ingredients in the upper-moderate hazard range according to EWG. Review the specific ingredients of concern and consider alternatives, especially if you have sensitivities.";
        break;
      case "Good": // Severity 2
        actionableAdvice = "Ingredients in this product generally fall into the lower-moderate hazard range according to EWG. While generally considered safer, always review the ingredient list for any personal sensitivities.";
        break;
      case "Safe": // Severity 1
        actionableAdvice = "Based on EWG ingredient hazard scores, this product is primarily composed of low-hazard ingredients.";
        // Ensure detailText is appropriate if all were safe (already handled above)
        break;
      default: // Handles "Indeterminate", "Unknown", "Data N/A", "Data Error", "Unknown Score Range"
        if (overallCategory == "Indeterminate") {
            // Actionable advice already set above
        } else { // For "Unknown", "Data N/A", "Data Error", etc.
            actionableAdvice = "Could not fully assess product safety due to issues with ingredient data for one or more components. Please review the ingredient list carefully on EWG's website.";
            detailText = "One or more ingredients had '$overallCategory' EWG scores, preventing a complete assessment. The determining factor was '$determiningIngredientName' (Score: $determiningIngredientScoreOrFirstScore).";
        }
        break;
    }

    return ProductGuidance(
      category: overallCategory,
      actionableAdvice: actionableAdvice,
      detail: detailText,
      determiningIngredient: determiningIngredientData,
    );
  }

  // --- UI UTILITIES ---
  static Color getCategoryColor(String category) {
    // Your new labels: Safe, Good, Caution advised, Unsafe
    switch (category) {
      case "Safe":
        return Colors.green.shade600; // Slightly darker green
      case "Good":
        return const Color.fromARGB(255, 205, 189, 38); // Amber/Dark Yellow
      case "Caution advised":
        return Colors.orange.shade700; // Darker Orange
      case "Unsafe":
        return Colors.red.shade700; // Darker Red
      case "Indeterminate":
      case "Unknown": // Added Unknown from getIngredientCategoryAndSeverity
      case "Data N/A":
      case "Data Error":
      case "Unknown Score Range": // Added from getIngredientCategoryAndSeverity
      default:
        return Colors.grey.shade600; // Darker Grey
    }
  }
  
  static Color getEwgScoreColor(String? scoreStr) {
     if (scoreStr == null || scoreStr.toLowerCase() == "n/a" || scoreStr.toLowerCase().contains("not found") || scoreStr.isEmpty) {
      return Colors.grey;
    }
    try {
      int score = int.parse(scoreStr);
      // Using your defined score to category mapping for colors
      if (score >= 0 && score <= 2) return Colors.green.shade600;       // Safe
      if (score >= 3 && score <= 4) return Colors.yellow.shade700;  // Good
      if (score >= 5 && score <= 6) return Colors.orange.shade700;  // Caution advised
      if (score >= 7 && score <= 10) return Colors.red.shade700;    // Unsafe
      return Colors.grey; // Default for scores outside 0-10
    } catch (e) {
      return Colors.grey; // Default for unparsable scores
    }
  }

  static Widget buildRiskIndicator(String label, String? level) {
    final displayValue = level ?? "Not Specified";
    final color = switch (level?.toUpperCase()) {
      'HIGH' => Colors.red,
      'MODERATE' => Colors.orange,
      'LOW' => Colors.green,
      _ => Colors.grey,
    };
    return Row(children: [
      Container(width: 10, height: 10, margin: const EdgeInsets.only(right: 8), decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      Text("$label: $displayValue"),
    ]);
  }
}