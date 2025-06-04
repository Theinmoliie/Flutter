// model/routine_models.dart

import 'package:flutter/foundation.dart';

class RecommendedProduct {
  final int productId;
  final String name;
  final String? brand;
  final double? price;
  final String? imageUrl;
  final String? description;
  final String productType;
  final double? similarityScore;

  RecommendedProduct({
    required this.productId,
    required this.name,
    this.brand,
    this.price,
    this.imageUrl,
    this.description,
    required this.productType,
    this.similarityScore,
  });

  factory RecommendedProduct.fromJson(Map<String, dynamic> json) {
    // Helper to get value trying both snake_case and PascalCase
    dynamic _getKeyValue(String snakeCaseKey, String pascalCaseKey) {
      if (json.containsKey(snakeCaseKey)) {
        return json[snakeCaseKey];
      }
      if (json.containsKey(pascalCaseKey)) {
        // If found PascalCase, log a warning so we know this fallback is being used.
        debugPrint("DART_PARSING_WARNING: Using PascalCase fallback for key '$pascalCaseKey'. Expected snake_case '$snakeCaseKey'. JSON: $json");
        return json[pascalCaseKey];
      }
      return null;
    }

    int _parseProductId(dynamic value, String productNameForError) {
      if (value is int) return value;
      if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed != null) return parsed;
      }
      debugPrint("DART_PARSING_ERROR: Product ID is null or invalid for product: $productNameForError. Value: $value. Full JSON product: $json");
      throw FormatException("Product ID is null or invalid for product: $productNameForError. Received: $value");
    }

    String _parseProductType(dynamic value, String productNameForError) {
        if (value is String && value.isNotEmpty) return value;
        debugPrint("DART_PARSING_ERROR: Product Type is null, empty or not a String for product: $productNameForError. Value: $value. Full JSON product: $json");
        throw FormatException("Product Type is null, empty or invalid for product: $productNameForError. Received: $value");
        // return "Unknown Type"; // Or return a default if you don't want to throw
    }


    String tempName = (_getKeyValue('name', 'Product_Name') as String?) ?? 'Unknown Product';

    return RecommendedProduct(
      productId: _parseProductId(_getKeyValue('product_id', 'Product_Id'), tempName),
      name: tempName,
      brand: _getKeyValue('brand', 'Brand') as String?,
      price: (_getKeyValue('price', 'Price') as num?)?.toDouble(),
      imageUrl: _getKeyValue('image_url', 'Image_Url') as String?,
      description: _getKeyValue('description', 'Product_Description') as String?,
      productType: _parseProductType(_getKeyValue('product_type', 'Product_Type'), tempName),
      similarityScore: (_getKeyValue('similarity_score', 'similarity_score') as num?)?.toDouble(), // similarity_score is likely always snake_case
    );
  }
}

// RoutineStep and SkincareRoutine fromJson methods should be okay
// as their direct keys are already snake_case from Python model field names.
// ... (RoutineStep and SkincareRoutine classes remain the same) ...
class RoutineStep {
  final String stepName;
  final String productTypeExpected;
  final List<RecommendedProduct> recommendedProducts;

  RoutineStep({
    required this.stepName,
    required this.productTypeExpected,
    this.recommendedProducts = const [],
  });

  factory RoutineStep.fromJson(Map<String, dynamic> json) {
    var productsList = json['recommended_products'] as List? ?? [];
    List<RecommendedProduct> products = productsList
        .map((p) => RecommendedProduct.fromJson(p as Map<String, dynamic>))
        .toList();
    return RoutineStep(
      stepName: json['step_name'] as String,
      productTypeExpected: json['product_type_expected'] as String,
      recommendedProducts: products,
    );
  }
}

class SkincareRoutine {
  final List<RoutineStep> morningRoutine;
  final List<RoutineStep> nightRoutine;

  SkincareRoutine({required this.morningRoutine, required this.nightRoutine});

  factory SkincareRoutine.fromJson(Map<String, dynamic> json) {
    var morningList = json['morning_routine'] as List? ?? [];
    List<RoutineStep> morning = morningList
        .map((s) => RoutineStep.fromJson(s as Map<String, dynamic>))
        .toList();
    var nightList = json['night_routine'] as List? ?? [];
    List<RoutineStep> night = nightList
        .map((s) => RoutineStep.fromJson(s as Map<String, dynamic>))
        .toList();
    return SkincareRoutine(
      morningRoutine: morning,
      nightRoutine: night,
    );
  }
}