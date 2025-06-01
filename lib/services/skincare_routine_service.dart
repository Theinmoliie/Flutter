// services/skincare_routine_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../model/routine_models.dart'; // Your models from above

class SkincareRoutineService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // --- Configuration for Routine Steps ---
  final List<Map<String, String>> _morningStepsConfig = [
    {'step_name': 'Cleanser', 'product_type': 'Cleanser'},
    {'step_name': 'Toner', 'product_type': 'Toner'},
    {'step_name': 'Serum', 'product_type': 'Serum'},
    {'step_name': 'Moisturizer', 'product_type': 'Moisturizer'},
    {'step_name': 'Sunscreen', 'product_type': 'Sunscreen'},
  ];

  final List<Map<String, String>> _nightStepsConfig = [
    {'step_name': 'Cleanser', 'product_type': 'Cleanser'}, // You might want to differentiate (e.g., Oil Cleanser, Foam Cleanser later)
    {'step_name': 'Toner', 'product_type': 'Toner'},
    {'step_name': 'Serum', 'product_type': 'Serum'},
    {'step_name': 'Moisturizer', 'product_type': 'Moisturizer'},
    {'step_name': 'Eye Cream', 'product_type': 'Eye Cream'},
  ];

  // --- Helper to get Skin Type Name from ID ---
  Future<String?> _getSkinTypeName(int skinTypeId) async {
    try {
      final response = await _supabase
          .from('Skin Types')
          .select('skin_type')
          .eq('skin_type_id', skinTypeId)
          .limit(1)
          .single(); // Use .single() if you expect exactly one or error
      return response['skin_type'] as String?;
    } catch (e) {
      print("Error fetching skin type name for ID $skinTypeId: $e");
      return null;
    }
  }

  // --- Helper to get Concern Names/Details from IDs ---
  // This helps map concern IDs to the direct columns "Acne-prone" and "Mature"
  Future<List<Map<String, dynamic>>> _getConcernDetails(Set<int> concernIds) async {
    if (concernIds.isEmpty) return [];
    try {
      final response = await _supabase
          .from('Skin Concerns')
          .select('concern_id, concern')
          .inFilter('concern_id', concernIds.toList());
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      print("Error fetching concern details for IDs $concernIds: $e");
      return [];
    }
  }


  Future<RecommendedProduct?> _recommendProductForStep({
    required String productTypeForStep,
    required String? dbSkinTypeColumn, // e.g., "Oily", "Dry" (column name in Products table)
    required bool isSensitive,
    required Set<int> userConcernIds,
    required List<Map<String, dynamic>> allUserConcernDetails, // Fetched once
  }) async {
    if (dbSkinTypeColumn == null) return null; // Cannot proceed without a valid skin type mapping

    // Base query for skin type, sensitivity, and product type
    var query = _supabase
        .from('Products')
        .select('*') // Select all columns to build RecommendedProduct
        .eq('Product_Type', productTypeForStep)
        .eq(dbSkinTypeColumn, 1); // Assuming 1 means suitable

    if (isSensitive) {
      query = query.eq('Sensitive', 1);
    }

    // --- Initial Fetch based on core criteria ---
    List<dynamic> candidateProductsData;
    try {
        candidateProductsData = await query;
    } catch (e) {
        print("Error fetching candidate products for $productTypeForStep: $e");
        return null; // Or handle error appropriately
    }

    if (candidateProductsData.isEmpty) {
      print("No candidate products found for $productTypeForStep with skin type $dbSkinTypeColumn and sensitivity $isSensitive.");
      return null;
    }

    List<Map<String, dynamic>> candidateProducts = List<Map<String, dynamic>>.from(candidateProductsData);


    // --- If no concerns, pick the cheapest from candidates ---
    if (userConcernIds.isEmpty) {
      candidateProducts.sort((a, b) => (a['Price'] as num? ?? double.infinity).compareTo(b['Price'] as num? ?? double.infinity));
      if (candidateProducts.isNotEmpty) {
        return RecommendedProduct.fromJson(candidateProducts.first, productTypeForStep);
      }
      return null;
    }

    // --- Filter and Score products based on concerns ---
    List<Map<String, dynamic>> productsWithScores = [];

    // Identify direct concern column names from user's selected concerns
    Set<String> directConcernColumnsForUser = {};
    List<int> otherConcernIdsForUser = [];

    for (var concernDetail in allUserConcernDetails) {
      final String concernName = concernDetail['concern'];
      if (concernName == 'Acne-prone' || concernName == 'Mature') {
        // Assuming column names in 'Products' table are 'Acne-prone' and 'Mature'
        directConcernColumnsForUser.add(concernName);
      } else {
        otherConcernIdsForUser.add(concernDetail['concern_id'] as int);
      }
    }

    // Fetch product_ids linked to user's "other" concerns (if any)
    Set<int> productIdsMatchingOtherConcerns = {};
    if (otherConcernIdsForUser.isNotEmpty) {
      try {
        final concernLinksResponse = await _supabase
            .from('product_skinconcerns')
            .select('product_id')
            .inFilter('concern_id', otherConcernIdsForUser);

        for (var link in List<Map<String, dynamic>>.from(concernLinksResponse as List)) {
          productIdsMatchingOtherConcerns.add(link['product_id'] as int);
        }
      } catch (e) {
        print("Error fetching product_skinconcerns links: $e");
        // Continue without this filter, or handle error
      }
    }

    for (var productData in candidateProducts) {
      int score = 0;
      bool matchesAtLeastOneConcern = false;

      // Check direct concern columns
      for (String directConcernCol in directConcernColumnsForUser) {
        if (productData[directConcernCol] == 1) {
          score++;
          matchesAtLeastOneConcern = true;
        }
      }

      // Check "other" concerns via the fetched links
      if (productIdsMatchingOtherConcerns.contains(productData['Product_Id'] as int)) {
        score++; // Could give more weight or just count as one match
        matchesAtLeastOneConcern = true;
      }

      if (matchesAtLeastOneConcern) { // Only consider products that match at least one of the user's concerns
         productsWithScores.add({...productData, '_score': score});
      }
    }

    // If no products specifically match concerns, fallback to the cheapest initial candidate
    if (productsWithScores.isEmpty && candidateProducts.isNotEmpty) {
      print("No products matched specific concerns for $productTypeForStep. Falling back to cheapest general candidate.");
      candidateProducts.sort((a, b) => (a['Price'] as num? ?? double.infinity).compareTo(b['Price'] as num? ?? double.infinity));
      return RecommendedProduct.fromJson(candidateProducts.first, productTypeForStep);
    }


    // Sort by score (descending), then by price (ascending)
    productsWithScores.sort((a, b) {
      int scoreComparison = (b['_score'] as int).compareTo(a['_score'] as int);
      if (scoreComparison != 0) {
        return scoreComparison;
      }
      return (a['Price'] as num? ?? double.infinity).compareTo(b['Price'] as num? ?? double.infinity);
    });

    if (productsWithScores.isNotEmpty) {
      return RecommendedProduct.fromJson(productsWithScores.first, productTypeForStep);
    }

    return null; // No suitable product found
  }


  Future<SkincareRoutine?> buildRoutine({
    required int? skinTypeId,
    required String? sensitivity, // "Yes" or "No"
    required Set<int> concernIds,
  }) async {
    if (skinTypeId == null || sensitivity == null) {
      print("Skin type ID or sensitivity is null. Cannot build routine.");
      return null;
    }

    final String? skinTypeName = await _getSkinTypeName(skinTypeId);
    if (skinTypeName == null) {
      print("Could not fetch skin type name for ID $skinTypeId.");
      return null;
    }

    // Map skin type name to database column name (case-sensitive from your DB)
    // This assumes your 'Skin Types'.skin_type are like 'Oily', 'Dry', etc.
    // And your 'Products' table columns are 'Oily', 'Dry', etc.
    final String? dbSkinTypeColumn = skinTypeName; // Directly use if names match
                                                  // Or use a map:
                                                  // final Map<String, String> skinTypeToColumn = {
                                                  //   'Oily': 'Oily', 'Dry': 'Dry', ...
                                                  // };
                                                  // final String? dbSkinTypeColumn = skinTypeToColumn[skinTypeName];


    final bool isSensitive = sensitivity.toLowerCase() == 'yes';
    final List<Map<String, dynamic>> allUserConcernDetails = await _getConcernDetails(concernIds);

    List<RoutineStep> morningRoutine = [];
    for (var stepConfig in _morningStepsConfig) {
      final product = await _recommendProductForStep(
        productTypeForStep: stepConfig['product_type']!,
        dbSkinTypeColumn: dbSkinTypeColumn,
        isSensitive: isSensitive,
        userConcernIds: concernIds,
        allUserConcernDetails: allUserConcernDetails,
      );
      morningRoutine.add(RoutineStep(
        stepName: stepConfig['step_name']!,
        productTypeExpected: stepConfig['product_type']!,
        recommendedProduct: product,
      ));
    }

    List<RoutineStep> nightRoutine = [];
    for (var stepConfig in _nightStepsConfig) {
      final product = await _recommendProductForStep(
        productTypeForStep: stepConfig['product_type']!,
        dbSkinTypeColumn: dbSkinTypeColumn,
        isSensitive: isSensitive,
        userConcernIds: concernIds,
        allUserConcernDetails: allUserConcernDetails,
      );
      nightRoutine.add(RoutineStep(
        stepName: stepConfig['step_name']!,
        productTypeExpected: stepConfig['product_type']!,
        recommendedProduct: product,
      ));
    }

    return SkincareRoutine(morningRoutine: morningRoutine, nightRoutine: nightRoutine);
  }
}