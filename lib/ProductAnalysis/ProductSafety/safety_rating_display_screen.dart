// ProductSafety/safety_rating_display_screen.dart
//LOGIC & DISPLAY for safety of KNOWN (searched) products.

    import 'package:flutter/material.dart';
    import 'package:supabase_flutter/supabase_flutter.dart';
    import '../../util/safetyscore_util.dart'; // Adjust path
    import 'safety_guide_ui.dart';         // Adjust path

    class SafetyRatingDisplayScreen extends StatefulWidget {
      final int productId;
      final String productName;
      final String brand;
      final String imageUrl;

      const SafetyRatingDisplayScreen({
        required this.productId,
        required this.productName,
        required this.brand,
        required this.imageUrl,
        Key? key,
      }) : super(key: key);

      @override
      _SafetyRatingDisplayScreenState createState() => _SafetyRatingDisplayScreenState();
    }

    class _SafetyRatingDisplayScreenState extends State<SafetyRatingDisplayScreen> {
      final supabase = Supabase.instance.client;

      ProductGuidance? productSafetyGuidance;
      List<Map<String, dynamic>> productIngredients = [];
      bool isLoadingSafety = true;
      String? safetyErrorMessage;

      @override
      void initState() {
        super.initState();
        _fetchProductSafetyData();
      }

      void setStateIfMounted(VoidCallback fn) {
        if (mounted) setState(fn);
      }

      Future<void> _fetchProductSafetyData() async {
        setStateIfMounted(() {
          isLoadingSafety = true;
          safetyErrorMessage = null;
          productSafetyGuidance = null;
          productIngredients = [];
        });

        try {
          // 1. Fetch ingredient links for the product
          final ingredientLinksResponse = await supabase
              .from('product_ingredients')
              .select('ingredient_id')
              .eq('product_id', widget.productId);

          if (ingredientLinksResponse.isEmpty) {
            setStateIfMounted(() {
              productIngredients = [];
              productSafetyGuidance = ProductScorer.getOverallProductGuidance([]);
              isLoadingSafety = false;
              // safetyErrorMessage = "No ingredients found for this product."; // Optional: specific message
            });
            return;
          }
          final ingredientIds = ingredientLinksResponse.map<int>((ing) => ing['ingredient_id'] as int).toList();

          // 2. Fetch safety data for these ingredients
          List<Map<String, dynamic>> tempProductIngredients = [];
          if (ingredientIds.isNotEmpty) {
            final safetyDataResponse = await supabase
                .from('Safety Rating')
                .select('Ingredient_Id, Ingredient_Name, Score, Irritation, Comodogenic, Other_Concerns, Cancer_Concern, Allergies_Immunotoxicity, Developmental_Reproductive_Toxicity, Function, Benefits')
                .inFilter('Ingredient_Id', ingredientIds);
            tempProductIngredients = List<Map<String, dynamic>>.from(safetyDataResponse);
          }

          setStateIfMounted(() {
            productIngredients = tempProductIngredients;
            productSafetyGuidance = ProductScorer.getOverallProductGuidance(productIngredients);
            isLoadingSafety = false;
             if (productIngredients.isEmpty && ingredientIds.isNotEmpty) {
                // This means links existed but no safety data was found for those IDs
                safetyErrorMessage = "Ingredient safety details not found for this product.";
            }
          });

        } catch (error) {
          print("Error fetching product safety data: $error");
          setStateIfMounted(() {
            safetyErrorMessage = "Failed to load product safety analysis.";
            isLoadingSafety = false;
          });
        }
      }

      @override
      Widget build(BuildContext context) {
        final colorScheme = Theme.of(context).colorScheme;
        return Scaffold(
          appBar: AppBar(
            title: Text(
              isLoadingSafety ? "Loading Safety..." : "Product Safety Rating",
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            backgroundColor: colorScheme.primary,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: isLoadingSafety
              ? const Center(child: CircularProgressIndicator())
              : safetyErrorMessage != null
                  ? Center(child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(safetyErrorMessage!, style: const TextStyle(color: Colors.red, fontSize: 16), textAlign: TextAlign.center),
                  ))
                  : SafetyGuideUI(
                      productName: widget.productName,
                      brand: widget.brand,
                      imageUrl: widget.imageUrl,
                      productGuidance: productSafetyGuidance,
                      matchedIngredients: productIngredients,
                      unmatchedIngredients: const [], // No OCR unmatched for searched products
                    ),
        );
      }
    }