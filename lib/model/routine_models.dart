// models/routine_models.dart
class RecommendedProduct {
  final int productId;
  final String name;
  final String? brand;
  final double? price;
  final String? imageUrl;
  final String? description;
  final String productType; // To confirm it matches the step

  RecommendedProduct({
    required this.productId,
    required this.name,
    this.brand,
    this.price,
    this.imageUrl,
    this.description,
    required this.productType,
  });

  factory RecommendedProduct.fromJson(Map<String, dynamic> json, String expectedProductType) {
    return RecommendedProduct(
      productId: json['Product_Id'] as int,
      name: json['Product_Name'] as String? ?? 'Unknown Product',
      brand: json['Brand'] as String?,
      price: (json['Price'] as num?)?.toDouble(), // Handle potential integer
      imageUrl: json['Image_Url'] as String?,
      description: json['Product_Description'] as String?,
      productType: json['Product_Type'] as String? ?? expectedProductType,
    );
  }
}

class RoutineStep {
  final String stepName;
  final String productTypeExpected; // e.g., "Cleanser", "Serum"
  RecommendedProduct? recommendedProduct; // Null if no suitable product found

  RoutineStep({
    required this.stepName,
    required this.productTypeExpected,
    this.recommendedProduct,
  });
}

class SkincareRoutine {
  final List<RoutineStep> morningRoutine;
  final List<RoutineStep> nightRoutine;

  SkincareRoutine({required this.morningRoutine, required this.nightRoutine});
}