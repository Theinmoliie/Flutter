// compatibilityscore_util.dart

import 'package:flutter/material.dart';

// Data Class for Recommendation Result
class ProductRecommendationResult {
  final String status; // "Recommended", "Neutral", "Not Recommended"
  final List<String> reasons;

  ProductRecommendationResult({required this.status, required this.reasons});
}

class CompatibilityScorer {
  static ProductRecommendationResult getProductRecommendation({
    // User Profile Data
    required String? userActualSkinTypeName,
    required bool userConsidersSkinSensitive,
    required List<int> userConcernIds,

    // Product Data
    required Map<String, dynamic>? productData,
    required List<int> productDirectlyAddressesConcernIds,
    required List<Map<String, dynamic>> productIngredientsWithConcernSuitability,
  }) {
    List<String> tempReasons = []; // Use a temporary list to build reasons in order
    String displayUserSkinType = userActualSkinTypeName ?? "Not Set";

    if (productData == null) {
      tempReasons.add("Product details could not be loaded for analysis.");
      return ProductRecommendationResult(status: "Neutral", reasons: tempReasons);
    }

    // --- Product Flags ---
    bool isProductGenerallySuitableForSensitiveDB = (productData['Sensitive'] == 1);

    // --- 1. Skin Type Matching & Reason ---
    bool productMatchesUserActualSkinType = false;
    bool isProductForAllPrimarySkinTypes = (productData['Oily'] == 1 &&
                                       productData['Dry'] == 1 &&
                                       productData['Combination'] == 1 &&
                                       productData['Normal'] == 1);

    if (userActualSkinTypeName != null) {
      if (productData[userActualSkinTypeName] == 1) {
        productMatchesUserActualSkinType = true;
        tempReasons.add("Suitable for your skin type ($displayUserSkinType).");
      } else if (isProductForAllPrimarySkinTypes) {
        productMatchesUserActualSkinType = true;
        tempReasons.add("Product is suitable for various skin types, including yours ($displayUserSkinType).");
      } else {
        tempReasons.add("Not indicated as suitable for your skin type ($displayUserSkinType).");
      }
    } else {
      if (isProductForAllPrimarySkinTypes) {
          productMatchesUserActualSkinType = true;
          tempReasons.add("Product is generally for all skin types. Your skin type is not set for specific comparison.");
      } else {
          tempReasons.add("Your skin type is not set; specific type match cannot be confirmed.");
      }
    }

    // --- 2. Sensitivity Reason (if user is sensitive) ---
    if (userConsidersSkinSensitive) {
        if (isProductGenerallySuitableForSensitiveDB) {
            tempReasons.add("Indicated as suitable for sensitive skin.");
        } else {
            tempReasons.add("Not indicated as suitable for sensitive skin by product flag.");
        }
    }

    // --- 3. Concern Matching & Reason ---
    bool productDirectlyTargetsUserConcern = false;
    if (userConcernIds.isNotEmpty) {
      for (int userConcernId in userConcernIds) {
        if (productDirectlyAddressesConcernIds.contains(userConcernId)) {
          productDirectlyTargetsUserConcern = true;
          break;
        }
      }
    }
    print("productDirectlyTargetsUserConcern: $productDirectlyTargetsUserConcern");

    bool ingredientsTargetUserConcern = false;
    if (userConcernIds.isNotEmpty && productIngredientsWithConcernSuitability.isNotEmpty) {
      for (final ingredientData in productIngredientsWithConcernSuitability) {
        List<int> suitableIngredientConcerns =
            (ingredientData['Suitable_For_Concern_Ids'] as List<dynamic>?)?.cast<int>() ?? [];
        for (int userConcernId in userConcernIds) {
          if (suitableIngredientConcerns.contains(userConcernId)) {
            ingredientsTargetUserConcern = true;
            break;
          }
        }
        if (ingredientsTargetUserConcern) break;
      }
    }
    
    bool effectivelyAddressesConcerns = userConcernIds.isEmpty || productDirectlyTargetsUserConcern || ingredientsTargetUserConcern;

    if (userConcernIds.isNotEmpty) {
        if (effectivelyAddressesConcerns) {
            tempReasons.add("Product or its ingredients may address one or more of your selected concerns.");
        } else {
            tempReasons.add("Does not appear to strongly target your selected skin concerns.");
        }
    } else {
        tempReasons.add("You have no specific concerns listed to target.");
    }


    // --- Recommendation Logic based on your specified cases ---
    String finalStatus;

    if (userConsidersSkinSensitive) {
      if (!productMatchesUserActualSkinType || !isProductGenerallySuitableForSensitiveDB) {
        finalStatus = "Not Recommended";
      } else if (effectivelyAddressesConcerns) {
        finalStatus = "Recommended";
      } else {
        finalStatus = "Neutral";
      }
    } else { // User is NOT sensitive
      if (!productMatchesUserActualSkinType) {
        finalStatus = "Not Recommended";
      } else if (effectivelyAddressesConcerns) {
        finalStatus = "Recommended";
      } else {
        finalStatus = "Neutral";
      }
    }
    
    // Deduplication is good practice, though with sequential addition, exact duplicates are less likely unless logic paths converge.
    List<String> uniqueReasons = tempReasons.toSet().toList();

    return ProductRecommendationResult(status: finalStatus, reasons: uniqueReasons);
  }

  static Color getRecommendationStatusColor(String status) {
    switch (status) {
      case "Recommended": return Colors.green.shade600;
      case "Neutral": return Colors.orange.shade700;
      case "Not Recommended": return Colors.red.shade700;
      default: return Colors.grey.shade600;
    }
  }
}