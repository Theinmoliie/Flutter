// ProductSafety/suitability_display_screen.dart
// Responsible for fetching all necessary data, performing the suitability analysis against the user's skin profile, and displaying the results.

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';

import '../../util/compatibilityscore_util.dart'; // For ProductRecommendationResult, CompatibilityScorer
import '../../providers/skin_profile_provider.dart';
import 'compatibility_ui.dart';                // The new UI widget

class SuitabilityDisplayScreen extends StatefulWidget {
  final int productId;
  final String productName;
  final String brand;
  final String imageUrl;
  final VoidCallback onSwitchToProfile; // Essential for re-analysis

  const SuitabilityDisplayScreen({
    required this.productId,
    required this.productName,
    required this.brand,
    required this.imageUrl,
    required this.onSwitchToProfile,
    Key? key,
  }) : super(key: key);

  @override
  _SuitabilityDisplayScreenState createState() => _SuitabilityDisplayScreenState();
}

class _SuitabilityDisplayScreenState extends State<SuitabilityDisplayScreen> {
  final supabase = Supabase.instance.client;

  // Utility maps (could be moved to a central util file)
  final Map<int, String> skinTypeMap = {1: "Oily", 2: "Dry", 3: "Combination", 4: "Sensitive", 5: "Normal"};
  final Map<int, String> concernMap = {1: "Acne", 2: "Hyperpigmentation", 3: "Post Blemish Scar", 4: "Redness", 5: "Aging", 6: "Enlarged Pores", 7: "Impaired Skin Barrier", 8: "Uneven Skin Tone", 9: "Texture", 10: "Radiance", 11: "Elasticity", 12: "Dullness", 13: "Blackheads", 15: "Dryness and dehydration", 19: "Dark circles", 20: "Puffiness"};

  // State for data fetching and analysis
  List<Map<String, dynamic>> _productIngredientsForAnalysis = []; // Safety data + suitability flags
  bool _isLoadingAllData = true;
  String? _dataErrorMessage;

  ProductRecommendationResult? _productCompatibilityRecommendation;
  List<Map<String, dynamic>> _uiCompatibilityIngredientBreakdown = []; // For ingredient cards
  bool _hasFetchedUiCompatibilityData = false;

  Map<String, dynamic>? _currentProductDataForCompatDB; // From Products table
  List<int> _currentProductAddressesConcernIdsForCompatDB = []; // From product_skinconcerns table

  // State for detailed insights
  List<String> _productAddressesTheseUserConcernsNames = [];
  List<Map<String, String>> _ingredientsAddressTheseUserConcernsDetails = [];
  bool _productDirectlyTargetsUserSelectedConcerns = false;
  bool _ingredientsTargetUserSelectedConcerns = false;

  @override
  void initState() {
    super.initState();
    _fetchAllProductDataForSuitability();
  }

  void setStateIfMounted(VoidCallback fn) {
    if (mounted) setState(fn);
  }

  // This method is called when the user updates their profile via the prompt
  void _handleProfileUpdateAndRefresh() {
    print("Profile update requested. Re-analyzing compatibility in SuitabilityDisplayScreen.");
    // No need to call widget.onSwitchToProfile here as this screen IS the destination after profile update.
    // The actual profile switch is handled by the MultiPageSkinProfileScreen's onProfileSaved callback.
    // We just need to re-fetch/re-analyze.

    setStateIfMounted(() {
      _isLoadingAllData = true; // Show loading indicator
      // Reset derived states before re-analysis
      _productCompatibilityRecommendation = null;
      _productAddressesTheseUserConcernsNames = [];
      _ingredientsAddressTheseUserConcernsDetails = [];
      _productDirectlyTargetsUserSelectedConcerns = false;
      _ingredientsTargetUserSelectedConcerns = false;
    });
    // Re-fetch all data because user profile (which influences everything) has changed.
    _fetchAllProductDataForSuitability();
  }


  Future<void> _fetchAllProductDataForSuitability() async {
    setStateIfMounted(() {
      _isLoadingAllData = true;
      _dataErrorMessage = null;
      _productCompatibilityRecommendation = null;
      _hasFetchedUiCompatibilityData = false;
      _uiCompatibilityIngredientBreakdown = [];
      _currentProductDataForCompatDB = null;
      _currentProductAddressesConcernIdsForCompatDB = [];
      _productIngredientsForAnalysis = [];
      _productAddressesTheseUserConcernsNames = [];
      _ingredientsAddressTheseUserConcernsDetails = [];
      _productDirectlyTargetsUserSelectedConcerns = false;
      _ingredientsTargetUserSelectedConcerns = false;
    });

    try {
      // 1. Fetch basic product data and product-level concerns
      try {
        final productResponse = await supabase.from('Products').select().eq('Product_Id', widget.productId).single();
        _currentProductDataForCompatDB = productResponse;

        final productConcernsResponse = await supabase.from('product_skinconcerns').select('concern_id').eq('product_id', widget.productId);
        _currentProductAddressesConcernIdsForCompatDB = productConcernsResponse.map<int>((c) => c['concern_id'] as int).toList();
          print("Fetched Product Direct Concern IDs from DB for Product ${widget.productId}: $_currentProductAddressesConcernIdsForCompatDB");
      } catch (e) {
        print("Error fetching product-level data for product ID ${widget.productId}: $e");
        setStateIfMounted(() {
          _dataErrorMessage = "Could not load product details for suitability analysis.";
          _isLoadingAllData = false;
        });
        return;
      }

      // 2. Fetch ingredient links
      final ingredientLinksResponse = await supabase.from('product_ingredients').select('ingredient_id').eq('product_id', widget.productId);
      if (ingredientLinksResponse.isEmpty) {
          setStateIfMounted(() {
          _productIngredientsForAnalysis = [];
          _hasFetchedUiCompatibilityData = true; // No ingredients to fetch UI data for
        });
        // analyzeCompatibility will be called at the end, which will set _isLoadingAllData = false
      } else {
        final ingredientIds = ingredientLinksResponse.map<int>((ing) => ing['ingredient_id'] as int).toList();

        // 3. Fetch ingredient safety data AND their suitability for concerns (for CompatibilityScorer)
        List<Map<String, dynamic>> tempProductIngredients = [];
        if (ingredientIds.isNotEmpty) {
            // Fetch safety data (useful for ingredient names, and _getWarnings in CompatibilityUI)
            final safetyDataResponse = await supabase.from('Safety Rating')
                .select('Ingredient_Id, Ingredient_Name, Score, Irritation, Comodogenic, Other_Concerns, Cancer_Concern, Allergies_Immunotoxicity, Developmental_Reproductive_Toxicity, Function, Benefits') // Include all fields for _getWarnings
                .inFilter('Ingredient_Id', ingredientIds);

            // Fetch which concerns each ingredient is suitable for
            final ingConcernSuitabilityResp = await supabase.from('ingredient_skinconcerns')
                .select('ingredient_id, concern_id')
                .inFilter('ingredient_id', ingredientIds)
                .eq('is_suitable', true); // Only get suitable ones for this map

            Map<int, List<int>> ingToSuitableConcernsMap = {};
            for (var row in ingConcernSuitabilityResp) {
              ingToSuitableConcernsMap.putIfAbsent(row['ingredient_id'], () => []).add(row['concern_id']);
            }

            for (var safetyData in safetyDataResponse) {
                Map<String, dynamic> detailedIng = Map<String, dynamic>.from(safetyData);
                detailedIng['Suitable_For_Concern_Ids'] = ingToSuitableConcernsMap[safetyData['Ingredient_Id']] ?? [];
                tempProductIngredients.add(detailedIng);
            }
        }
        _productIngredientsForAnalysis = tempProductIngredients;

        // 4. Fetch UI card compatibility data (for the ingredient breakdown cards)
        if (ingredientIds.isNotEmpty) {
          await _fetchUiCardCompatibilityData(ingredientIds, tempProductIngredients);
        } else {
          setStateIfMounted(() => _hasFetchedUiCompatibilityData = true);
        }
      }


      // 5. Analyze compatibility (now that all data is fetched or confirmed empty)
      analyzeCompatibility(); // This will set _isLoadingAllData to false internally

    } catch (error) {
      print("Error fetching all product data for suitability: $error");
      setStateIfMounted(() {
        _dataErrorMessage = "Failed to load full product analysis data.";
        _isLoadingAllData = false;
      });
    }
  }

  Future<void> _fetchUiCardCompatibilityData(List<int> ingredientIds, List<Map<String,dynamic>> productIngredientsSource) async {
    if (ingredientIds.isEmpty) {
      setStateIfMounted(() => _hasFetchedUiCompatibilityData = true);
      return;
    }
    try {
      // Fetch ALL suitability, not just 'is_suitable = true' for UI cards
      final skinTypeResp = await supabase.from('ingredient_skintype')
          .select('ingredient_id, skin_type_id, is_suitable')
          .inFilter('ingredient_id', ingredientIds);
      final skinConcernResp = await supabase.from('ingredient_skinconcerns')
          .select('ingredient_id, concern_id, is_suitable')
          .inFilter('ingredient_id', ingredientIds);

      Map<int, String> ingNamesMap = {};
      if (productIngredientsSource.isNotEmpty) { // Use the source passed
        ingNamesMap = { for (var ing in productIngredientsSource) ing['Ingredient_Id'] as int: ing['Ingredient_Name'] as String };
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
      setStateIfMounted(() => _hasFetchedUiCompatibilityData = true); // Ensure loading finishes
    }
  }

  void analyzeCompatibility() {
    final skinProfile = Provider.of<SkinProfileProvider>(context, listen: false);
    print("User Selected Concern IDs for analyzeCompatibility: ${skinProfile.userConcernIds}");

    if (skinProfile.userSkinTypeId == null || skinProfile.userSensitivity == null) {
        print("User skin profile not fully set.");
        setStateIfMounted(() {
            _isLoadingAllData = false; // Done "loading" data part
            _productCompatibilityRecommendation = ProductRecommendationResult(
                status: "Set Profile",
                reasons: ["Please complete your skin profile (skin type and sensitivity question)."]
            );
        });
        return;
    }

    if (_currentProductDataForCompatDB == null) {
        print("Product data not available for compatibility analysis.");
        setStateIfMounted(() {
            _isLoadingAllData = false;
            _productCompatibilityRecommendation = ProductRecommendationResult(status: "Error", reasons: ["Product details could not be loaded."]);
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
          // CORRECTED: Use the local concernMap
          String concernName = concernMap[userConcernId] ?? "Unknown Concern ID: $userConcernId";
          if (!tempProductAddressesUserConcernsNames.contains(concernName)) {
            tempProductAddressesUserConcernsNames.add(concernName);
          }
        }
      }

      for (var ingredient in _productIngredientsForAnalysis) { // Use the fetched ingredients
        List<int> suitableForConcernsByIngredient = (ingredient['Suitable_For_Concern_Ids'] as List<dynamic>?)?.cast<int>() ?? [];
        String ingredientName = ingredient['Ingredient_Name'] ?? 'Unknown Ingredient';
        for (int userConcernId in skinProfile.userConcernIds) {
          if (suitableForConcernsByIngredient.contains(userConcernId)) {
            tempIngredientsTarget = true;
            // CORRECTED: Use the local concernMap
            String concernNameForIngredient = concernMap[userConcernId] ?? "Unknown Concern ID: $userConcernId";
            bool alreadyAdded = tempIngredientsAddressUserConcernsDetails.any((detail) =>
                detail['ingredientName'] == ingredientName && detail['concernName'] == concernNameForIngredient
            );
            if (!alreadyAdded) {
                tempIngredientsAddressUserConcernsDetails.add({
                    'ingredientName': ingredientName,
                    // CORRECTED: Use the local concernMap
                    'concernName': concernNameForIngredient
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
            productData: _currentProductDataForCompatDB!,
            productDirectlyAddressesConcernIds: _currentProductAddressesConcernIdsForCompatDB,
            productIngredientsWithConcernSuitability: _productIngredientsForAnalysis, // Pass the fetched list
        );

    setStateIfMounted(() {
      _productCompatibilityRecommendation = recommendationResult;
      _productAddressesTheseUserConcernsNames = tempProductAddressesUserConcernsNames;
      _ingredientsAddressTheseUserConcernsDetails = tempIngredientsAddressUserConcernsDetails;
      _productDirectlyTargetsUserSelectedConcerns = tempProductDirectlyTargets;
      _ingredientsTargetUserSelectedConcerns = tempIngredientsTarget;
      _isLoadingAllData = false; // Analysis complete
    });
  }


  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    String currentRecommendationStatus = _productCompatibilityRecommendation?.status ?? (_isLoadingAllData ? "Loading..." : "Set Profile");

    // Ensure loading indicator shows if critical data for compatibility UI isn't ready
    if (_isLoadingAllData || !_hasFetchedUiCompatibilityData || (_currentProductDataForCompatDB == null && !_isLoadingAllData && _dataErrorMessage == null)) {
      // The only exception is if status is "Set Profile", then we don't need product data yet.
       if (currentRecommendationStatus == "Set Profile" && !_isLoadingAllData){
          // Allow to proceed to show "Set Profile" prompt
       } else {
        return Scaffold(
            appBar: AppBar(
                title: Text(widget.productName, style: const TextStyle(color: Colors.white)),
                backgroundColor: colorScheme.primary,
                iconTheme: const IconThemeData(color: Colors.white),
            ),
            body: const Center(child: CircularProgressIndicator())
        );
       }
    }

    if (_dataErrorMessage != null && currentRecommendationStatus != "Set Profile") { // Don't show data error if profile needs setting
        return Scaffold(
            appBar: AppBar(
                title: Text(widget.productName, style: const TextStyle(color: Colors.white)),
                backgroundColor: colorScheme.primary,
                iconTheme: const IconThemeData(color: Colors.white),
            ),
            body: Center(child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(_dataErrorMessage!, style: const TextStyle(color: Colors.red, fontSize: 16), textAlign: TextAlign.center),
            ))
        );
    }
    
    List<String>? currentCompatibilityReasons = _productCompatibilityRecommendation?.reasons ?? ((currentRecommendationStatus == "Set Profile") ? ["Please complete your skin profile for personalized advice."] : null);


    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isLoadingAllData && currentRecommendationStatus != "Set Profile" ? "Loading Suitability..." : "Product Suitability",
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: colorScheme.primary,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: CompatibilityUI(
        productName: widget.productName,
        brand: widget.brand,
        imageUrl: widget.imageUrl,
        matchedIngredients: _productIngredientsForAnalysis, // For _getWarnings and hazard calculation
        compatibilityResults: _uiCompatibilityIngredientBreakdown, // For ingredient cards
        isLoadingCompatibility: _isLoadingAllData && currentRecommendationStatus != "Set Profile", // Reflects overall data loading for this screen
        recommendationStatus: currentRecommendationStatus,
        compatibilityReasons: currentCompatibilityReasons,
        onProfileRequested: _handleProfileUpdateAndRefresh, // Use the local handler
        skinTypeMap: skinTypeMap, // Pass local maps
        concernMap: concernMap,   // Pass local maps
        productAddressesTheseUserConcernsNames: _productAddressesTheseUserConcernsNames,
        ingredientsAddressTheseUserConcernsDetails: _ingredientsAddressTheseUserConcernsDetails,
        productDirectlyTargetsUserSelectedConcerns: _productDirectlyTargetsUserSelectedConcerns,
        ingredientsTargetUserSelectedConcerns: _ingredientsTargetUserSelectedConcerns,
      ),
    );
  }
}