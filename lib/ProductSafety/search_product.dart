// search_product.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';

import '../util/safetyscore_util.dart';
import '../util/compatibilityscore_util.dart';
import '../providers/skin_profile_provider.dart';
import 'product_analysis.dart';

class SafetyResultScreen extends StatefulWidget {
  final int productId;
  final String productName;
  final String brand;
  final String imageUrl;

  const SafetyResultScreen({
    required this.productId,
    required this.productName,
    required this.brand,
    required this.imageUrl,
    Key? key,
  }) : super(key: key);

  @override
  SafetyResultScreenState createState() => SafetyResultScreenState();
}

class SafetyResultScreenState extends State<SafetyResultScreen> {
  final supabase = Supabase.instance.client;

  final Map<int, String> skinTypeMap = {1: "Oily", 2: "Dry", 3: "Combination", 4: "Sensitive", 5: "Normal"};
  final Map<int, String> concernMap = {1: "Acne", 2: "Hyperpigmentation", 3: "Post Blemish Scar", 4: "Redness", 5: "Aging", 6: "Enlarged Pores", 7: "Impaired Skin Barrier", 
  8: "Uneven Skin Tone", 9: "Texture", 10: "Radiance", 11: "Elasticity", 12: "Dullness", 13: "Blackheads", 15: "Dryness and dehydration", 19: "Dark circles", 20: "Puffiness"};

  ProductGuidance? productSafetyGuidance;
  List<Map<String, dynamic>> productIngredients = [];
  bool isLoadingSafety = true;
  String? safetyErrorMessage;

  ProductRecommendationResult? productCompatibilityRecommendation;
  bool isLoadingCompatibility = true;
  List<Map<String, dynamic>> _uiCompatibilityIngredientBreakdown = [];
  bool _hasFetchedUiCompatibilityData = false;
  Map<String, dynamic>? _currentProductDataForCompat;
  List<int> _currentProductAddressesConcernIdsForCompatDB = [];

  // NEW state variables for detailed insights
  List<String> _productAddressesTheseUserConcernsNames = [];
  List<Map<String, String>> _ingredientsAddressTheseUserConcernsDetails = [];
  bool _productDirectlyTargetsUserSelectedConcerns = false;
  bool _ingredientsTargetUserSelectedConcerns = false;


  @override
  void initState() {
    super.initState();
    _fetchAllProductData();
  }

  String getSkinTypeName(int id) => skinTypeMap[id] ?? "Unknown";
  String getConcernName(int id) => concernMap[id] ?? "Unknown";

  void setStateIfMounted(VoidCallback fn) {
    if (mounted) {
      setState(fn);
    }
  }

  void _handleProfileUpdateAndRefresh() {
    print("Profile update requested. Re-analyzing compatibility in SafetyResultScreenState.");
    setStateIfMounted(() {
      isLoadingCompatibility = true;
      _productAddressesTheseUserConcernsNames = [];
      _ingredientsAddressTheseUserConcernsDetails = [];
      _productDirectlyTargetsUserSelectedConcerns = false;
      _ingredientsTargetUserSelectedConcerns = false;
    });
    analyzeCompatibility();
  }

  Future<void> _fetchAllProductData() async {
    setStateIfMounted(() {
      isLoadingSafety = true; isLoadingCompatibility = true; safetyErrorMessage = null;
      productSafetyGuidance = null; productCompatibilityRecommendation = null;
      _hasFetchedUiCompatibilityData = false; _uiCompatibilityIngredientBreakdown = [];
      _currentProductDataForCompat = null; _currentProductAddressesConcernIdsForCompatDB = [];
      _productAddressesTheseUserConcernsNames = []; _ingredientsAddressTheseUserConcernsDetails = [];
      _productDirectlyTargetsUserSelectedConcerns = false; _ingredientsTargetUserSelectedConcerns = false;
    });

    try {
      try {
        final productResponse = await supabase.from('Products').select().eq('Product_Id', widget.productId).single();
        _currentProductDataForCompat = productResponse;
        final productConcernsResponse = await supabase.from('product_skinconcerns').select('concern_id').eq('product_id', widget.productId);
        _currentProductAddressesConcernIdsForCompatDB = productConcernsResponse.map<int>((c) => c['concern_id'] as int).toList();
        print("Fetched Product Direct Concern IDs from DB for Product ${widget.productId}: $_currentProductAddressesConcernIdsForCompatDB");
      } catch (e) {
        print("Error fetching product-level data for product ID ${widget.productId}: $e");
        setStateIfMounted(() { safetyErrorMessage = "Could not load product details."; isLoadingSafety = false; isLoadingCompatibility = false;});
        return;
      }

      final ingredientLinksResponse = await supabase.from('product_ingredients').select('ingredient_id').eq('product_id', widget.productId);
      if (ingredientLinksResponse.isEmpty) {
        setStateIfMounted(() {
          productIngredients = [];
          productSafetyGuidance = ProductScorer.getOverallProductGuidance([]);
          isLoadingSafety = false;
          _hasFetchedUiCompatibilityData = true;
        });
        analyzeCompatibility();
        return;
      }
      final ingredientIds = ingredientLinksResponse.map<int>((ing) => ing['ingredient_id'] as int).toList();

      List<Map<String, dynamic>> tempProductIngredients = [];
      if (ingredientIds.isNotEmpty) {
          final safetyDataResponse = await supabase.from('Safety Rating')
              .select('Ingredient_Id, Ingredient_Name, Score, Irritation, Comodogenic, Other_Concerns, Cancer_Concern, Allergies_Immunotoxicity, Developmental_Reproductive_Toxicity, Function, Benefits')
              .inFilter('Ingredient_Id', ingredientIds);

          final ingConcernSuitabilityResp = await supabase.from('ingredient_skinconcerns').select('ingredient_id, concern_id').inFilter('ingredient_id', ingredientIds).eq('is_suitable', true);
          Map<int, List<int>> ingToSuitableConcernsMap = {};
          for (var row in ingConcernSuitabilityResp) { ingToSuitableConcernsMap.putIfAbsent(row['ingredient_id'], () => []).add(row['concern_id']);}

          for (var safetyData in safetyDataResponse) {
              Map<String, dynamic> detailedIng = Map<String, dynamic>.from(safetyData);
              detailedIng['Suitable_For_Concern_Ids'] = ingToSuitableConcernsMap[safetyData['Ingredient_Id']] ?? [];
              tempProductIngredients.add(detailedIng);
          }
      }

      setStateIfMounted(() {
        productIngredients = tempProductIngredients;
        productSafetyGuidance = ProductScorer.getOverallProductGuidance(productIngredients);
        isLoadingSafety = false;
      });

      analyzeCompatibility();
      
      if (ingredientIds.isNotEmpty) {
        await _fetchUiCardCompatibilityData(ingredientIds);
      } else {
         setStateIfMounted(() => _hasFetchedUiCompatibilityData = true);
      }
    } catch (error) {
      print("Error fetching all product data: $error");
      setStateIfMounted(() { safetyErrorMessage = "Failed to load product analysis data."; isLoadingSafety = false; isLoadingCompatibility = false;});
    }
  }

  Future<void> _fetchUiCardCompatibilityData(List<int> ingredientIds) async {
    if (ingredientIds.isEmpty) {
        setStateIfMounted(() => _hasFetchedUiCompatibilityData = true);
        return;
    }
    try {
      final skinTypeResp = await supabase.from('ingredient_skintype').select('ingredient_id, skin_type_id, is_suitable').inFilter('ingredient_id', ingredientIds);
      final skinConcernResp = await supabase.from('ingredient_skinconcerns').select('ingredient_id, concern_id, is_suitable').inFilter('ingredient_id', ingredientIds);
      
      Map<int, String> ingNamesMap = {};
      if (productIngredients.isNotEmpty) {
        ingNamesMap = { for (var ing in productIngredients) ing['Ingredient_Id'] as int: ing['Ingredient_Name'] as String };
      }

      setStateIfMounted(() {
        _uiCompatibilityIngredientBreakdown = [
          ...skinTypeResp.map((e) => {...e, 'type': 'skin_type', 'ingredient_name': ingNamesMap[e['ingredient_id']] ?? 'Unknown Ing ID: ${e['ingredient_id']}'}),
          ...skinConcernResp.map((e) => {...e, 'type': 'skin_concern', 'ingredient_name': ingNamesMap[e['ingredient_id']] ?? 'Unknown Ing ID: ${e['ingredient_id']}'}),
        ];
        _hasFetchedUiCompatibilityData = true;
      });
    } catch (e) {
      print("Error fetching UI card compatibility data: $e");
       setStateIfMounted(() => _hasFetchedUiCompatibilityData = true);
    }
  }

  void analyzeCompatibility() {
    final skinProfile = Provider.of<SkinProfileProvider>(context, listen: false);
    print("User Selected Concern IDs for analyzeCompatibility: ${skinProfile.userConcernIds}");

    if (skinProfile.userSkinTypeId == null || skinProfile.userSensitivity == null) {
        print("User skin profile not fully set.");
        setStateIfMounted(() {
            isLoadingCompatibility = false;
            productCompatibilityRecommendation = ProductRecommendationResult(
                status: "Set Profile",
                reasons: ["Please complete your skin profile (skin type and sensitivity question)."]
            );
        });
        return;
    }

    if (_currentProductDataForCompat == null) {
        print("Product data not available for compatibility analysis.");
         setStateIfMounted(() {
            isLoadingCompatibility = false;
            productCompatibilityRecommendation = ProductRecommendationResult(status: "Error", reasons: ["Product details could not be loaded."]);
        });
        return;
    }

    bool userConsidersSensitive = (skinProfile.userSensitivity?.toLowerCase() == "yes");

    // --- Determine detailed insights for "Recommended" template ---
    List<String> tempProductAddressesUserConcernsNames = [];
    List<Map<String, String>> tempIngredientsAddressUserConcernsDetails = [];
    bool tempProductDirectlyTargets = false;
    bool tempIngredientsTarget = false;

    if (skinProfile.userConcernIds.isNotEmpty) {
      for (int userConcernId in skinProfile.userConcernIds) {
        if (_currentProductAddressesConcernIdsForCompatDB.contains(userConcernId)) {
          tempProductDirectlyTargets = true;
          if (!tempProductAddressesUserConcernsNames.contains(getConcernName(userConcernId))) {
            tempProductAddressesUserConcernsNames.add(getConcernName(userConcernId));
          }
        }
      }

      for (var ingredient in productIngredients) {
        List<int> suitableForConcernsByIngredient = (ingredient['Suitable_For_Concern_Ids'] as List<dynamic>?)?.cast<int>() ?? [];
        String ingredientName = ingredient['Ingredient_Name'] ?? 'Unknown Ingredient';
        for (int userConcernId in skinProfile.userConcernIds) {
          if (suitableForConcernsByIngredient.contains(userConcernId)) {
            tempIngredientsTarget = true;
            // Avoid adding duplicate ingredient-concernName pairs for the same user concern
            bool alreadyAdded = tempIngredientsAddressUserConcernsDetails.any((detail) => 
                detail['ingredientName'] == ingredientName && detail['concernName'] == getConcernName(userConcernId)
            );
            if (!alreadyAdded) {
                 tempIngredientsAddressUserConcernsDetails.add({
                    'ingredientName': ingredientName,
                    'concernName': getConcernName(userConcernId)
                 });
            }
          }
        }
      }
    }
    // --- End detailed insights determination ---

    ProductRecommendationResult recommendationResult =
        CompatibilityScorer.getProductRecommendation(
            userActualSkinTypeName: skinProfile.userSkinType,
            userConsidersSkinSensitive: userConsidersSensitive,
            userConcernIds: skinProfile.userConcernIds,
            productData: _currentProductDataForCompat!,
            productDirectlyAddressesConcernIds: _currentProductAddressesConcernIdsForCompatDB,
            productIngredientsWithConcernSuitability: productIngredients,
        );

    setStateIfMounted(() {
      productCompatibilityRecommendation = recommendationResult;
      // Store the detailed insights
      _productAddressesTheseUserConcernsNames = tempProductAddressesUserConcernsNames;
      _ingredientsAddressTheseUserConcernsDetails = tempIngredientsAddressUserConcernsDetails;
      _productDirectlyTargetsUserSelectedConcerns = tempProductDirectlyTargets;
      _ingredientsTargetUserSelectedConcerns = tempIngredientsTarget;
      
      isLoadingCompatibility = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoadingSafety || !_hasFetchedUiCompatibilityData || (_currentProductDataForCompat == null && !isLoadingSafety && safetyErrorMessage == null) ) {
      return Scaffold(appBar: AppBar(title: Text(widget.productName)), body: const Center(child: CircularProgressIndicator()));
    }
    if (safetyErrorMessage != null) {
        return Scaffold(appBar: AppBar(title: Text(widget.productName)), body: Center(child: Text(safetyErrorMessage!, style: const TextStyle(color: Colors.red, fontSize: 16))));
    }

    String currentRecommendationStatus = productCompatibilityRecommendation?.status ?? (isLoadingCompatibility ? "Loading..." : "Set Profile");
    List<String>? currentCompatibilityReasons = productCompatibilityRecommendation?.reasons ?? ((currentRecommendationStatus == "Set Profile") ? ["Please complete your skin profile for personalized advice."] : null); // Allow null for no reasons

    return ProductAnalysis(
      productName: widget.productName,
      brand: widget.brand,
      imageUrl: widget.imageUrl,
      productGuidance: productSafetyGuidance,
      matchedIngredients: productIngredients,
      unmatchedIngredients: const [],
      compatibilityResults: _uiCompatibilityIngredientBreakdown,
      isLoadingCompatibility: isLoadingCompatibility,
      recommendationStatus: currentRecommendationStatus,
      compatibilityReasons: currentCompatibilityReasons,
      onProfileRequested: _handleProfileUpdateAndRefresh,
      skinTypeMap: skinTypeMap,
      concernMap: concernMap,
      productAddressesTheseUserConcernsNames: _productAddressesTheseUserConcernsNames,
      ingredientsAddressTheseUserConcernsDetails: _ingredientsAddressTheseUserConcernsDetails,
      productDirectlyTargetsUserSelectedConcerns: _productDirectlyTargetsUserSelectedConcerns,
      ingredientsTargetUserSelectedConcerns: _ingredientsTargetUserSelectedConcerns,
    );
  }
}