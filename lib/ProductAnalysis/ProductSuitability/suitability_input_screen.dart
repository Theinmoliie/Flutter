// suitability_input_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'suitability_display_screen.dart'; // Adjust path

class SuitabilityInputScreen extends StatefulWidget {
  final VoidCallback onSwitchToProfile; // Crucial for suitability flow

  const SuitabilityInputScreen({Key? key, required this.onSwitchToProfile}) : super(key: key);

  @override
  _SuitabilityInputScreenState createState() => _SuitabilityInputScreenState();
}

class _SuitabilityInputScreenState extends State<SuitabilityInputScreen> {
  final _supabase = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (mounted) setState(() {}); // For clear icon
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchProducts(String query) async {
    if (query.isEmpty) {
      if (mounted) setState(() => _searchResults.clear());
      return;
    }
    try {
      final response = await _supabase
          .from('Products')
          .select('Product_Id, Product_Name, Brand, Image_Url') // Be specific
          .or('Product_Name.ilike.%$query%,Brand.ilike.%$query%')
          .limit(15);

      if (mounted) {
        setState(() {
          _searchResults = List<Map<String, dynamic>>.from(response);
        });
      }
    } catch (e) {
      print("Error in search: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to search products")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bool showClearIcon = _searchController.text.isNotEmpty;
    final screenWidth = MediaQuery.of(context).size.width;
    final double desiredImageWidth = screenWidth * 0.65;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Product Suitability Check",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: colorScheme.primary,
      ),
      body: Stack(
        children: [
          
          Column( // Main screen Column: Search Bar + Expanded section
            children: [
              // --- SEARCH BAR --- (Stays fixed at the top of this Column)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.black87),
                  decoration: InputDecoration(
                    labelText: "Search Product or Brand",
                    labelStyle: TextStyle(color: Colors.grey[700]),
                    hintText: "e.g. Soy Face Cleanser / Clinique",
                    hintStyle: TextStyle(color: Colors.grey[500]),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.95),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: Icon(Icons.search, color: Colors.grey[700]),
                    suffixIcon: showClearIcon
                        ? IconButton(
                            icon: Icon(Icons.clear, color: Colors.grey[600]),
                            tooltip: 'Clear search',
                            onPressed: () {
                              if (mounted) {
                                setState(() {
                                  _searchController.clear();
                                  _searchResults.clear();
                                });
                              }
                              FocusScope.of(context).unfocus();
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 15.0),
                  ),
                  onChanged: _searchProducts,
                  textInputAction: TextInputAction.search,
                  onSubmitted: _searchProducts,
                ),
              ),

              // --- EXPANDED SECTION FOR BUTTONS AND DECORATIVE IMAGE ---
              Expanded(
                // This Expanded widget will take the remaining vertical space
                // after the Search Bar.
                child: SingleChildScrollView( // Make the content INSIDE Expanded scrollable
                  padding: const EdgeInsets.symmetric(horizontal: 40.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center, // Center content if it's shorter than view
                    mainAxisSize: MainAxisSize.min, // Important for Column in SingleChildScrollView
                    children: [
                      const SizedBox(height: 25),


                    Text(
                        "Search for a product to check its suitability with your skin profile.",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),


                      Padding(
                        padding: const EdgeInsets.only(top: 160.0, bottom: 20.0),
                        child: Opacity(
                          opacity: 0.5,
                          child: SizedBox(
                            width: desiredImageWidth,
                            // height: 100, // Max height if needed, otherwise let it scale
                            child: Image.asset(
                              "assets/skincare.png",
                              fit: BoxFit.contain,
                              errorBuilder: (context, exception, stackTrace) {
                                print("Error loading decorative image: assets/skincare.png. $exception");
                                return const SizedBox.shrink();
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),


          // --- Search Results Overlay ---
          if (_searchResults.isNotEmpty)
            Positioned.fill(
              top: 65, // Below search bar (adjust based on AppBar and TextField height)
              left: 10, // Match horizontal padding of the Column
              right: 10, // Match horizontal padding of the Column
              child: GestureDetector(
                onTap: () {
                  if (mounted) setState(() => _searchResults.clear());
                  FocusScope.of(context).unfocus();
                },
                child: Container(
                  color: Colors.black.withOpacity(0.1), // For the area outside the results list
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      // Removed horizontal margin here as Positioned.fill with left/right handles it
                      margin: const EdgeInsets.only(top: 5),
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 12.0, bottom: 4.0),
                            child: Text(
                              "Search Results",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                            ),
                          ),
                          const Divider(height: 1, thickness: 1),
                          Flexible(
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              itemCount: _searchResults.length,
                              shrinkWrap: true,
                              separatorBuilder: (context, index) => const Divider(height: 1, indent: 10, endIndent: 10),
                              itemBuilder: (context, index) {
                                final product = _searchResults[index];
                                return ListTile(
                                  title: Text(
                                    product['Product_Name'] ?? 'Unknown Product',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    product['Brand'] ?? 'Unknown Brand',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  onTap: () {
                                    if (mounted) {
                                      setState(() {
                                        _searchResults.clear();
                                        FocusScope.of(context).unfocus();
                                      });
                                    }
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => SuitabilityDisplayScreen(
                                          productId: product['Product_Id'],
                                          productName: product['Product_Name'],
                                          brand: product['Brand'],
                                          imageUrl: product['Image_Url'] ?? '',
                                          onSwitchToProfile: widget.onSwitchToProfile,
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}