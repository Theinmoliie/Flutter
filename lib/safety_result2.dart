// import 'package:flutter/material.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';
// import 'score_util.dart';
// import 'compatibility_util.dart';

// class SafetyResultScreen extends StatefulWidget {
//   final int productId;
//   final String productName;
//   final String brand;
//   final String imageUrl;

//   const SafetyResultScreen({
//     required this.productId,
//     required this.productName,
//     required this.brand,
//     required this.imageUrl,
//     Key? key,
//   }) : super(key: key);

//   @override
//   SafetyResultScreenState createState() => SafetyResultScreenState();
// }

// class SafetyResultScreenState extends State<SafetyResultScreen> 
//     with SingleTickerProviderStateMixin {
//   final supabase = Supabase.instance.client;
//   late TabController _tabController;

//   // Product safety state
//   double? safetyScore;
//   List<Map<String, dynamic>> ingredients = [];
//   bool isLoading = true;
//   String? errorMessage;
  
//   // Compatibility state
//   Map<String, dynamic>? compatibilityResult;
//   bool compatibilityLoading = false;
//   String? compatibilityError;

//   // User profile (hardcoded for example)
//   static const skinTypeId = 1; // Oily
//   static const skinTypeName = 'Oily';
//   static const concernIds = [1, 3]; // Acne, Redness
//   static const concernNames = {1: 'Acne', 3: 'Redness'};

//   @override
//   void initState() {
//     print('initState() - Initializing screen');
//     super.initState();
//     _tabController = TabController(length: 2, vsync: this);
//     fetchIngredientDetails();
//   }

//   @override
//   void dispose() {
//     print('dispose() - Cleaning up resources');
//     _tabController.dispose();
//     super.dispose();
//   }

//   Future<void> fetchIngredientDetails() async {
//     print('fetchIngredientDetails() - Starting fetch');
//     try {
//       final ingredientResponse = await supabase
//           .from('product_ingredients')
//           .select('ingredient_id')
//           .eq('product_id', widget.productId);

//       print('fetchIngredientDetails() - Got ${ingredientResponse.length} ingredients');

//       if (ingredientResponse.isEmpty) {
//         print('fetchIngredientDetails() - No ingredients found');
//         setState(() {
//           ingredients = [];
//           safetyScore = null;
//           isLoading = false;
//         });
//         return;
//       }

//       final ingredientIds = ingredientResponse
//           .map<int>((ingredient) => ingredient['ingredient_id'] as int)
//           .toList();
//       print('fetchIngredientDetails() - Ingredient IDs: $ingredientIds');

//       final safetyResponse = await supabase
//           .from('Safety Rating')
//           .select(
//             'Ingredient_Id, Ingredient_Name, Score, Other_Concerns, ' 
//             'Cancer_Concern, Allergies_Immunotoxicity, '
//             'Developmental_Reproductive_Toxicity, Function, Comodogenic, Irritation',
//           )
//           .inFilter('Ingredient_Id', ingredientIds);

//       print('fetchIngredientDetails() - Received safety data for ${safetyResponse.length} ingredients');
      
//       setState(() {
//         ingredients = safetyResponse;
//         safetyScore = ProductScorer.calculateSafetyScore(ingredients);
//         isLoading = false;
//       });

//       print('fetchIngredientDetails() - Calculated safety score: $safetyScore');

//     } catch (error) {
//       print('fetchIngredientDetails() - ERROR: $error');
//       setState(() {
//         errorMessage = "Failed to fetch ingredient details";
//         isLoading = false;
//       });
//     }
//   }

//   Future<void> fetchCompatibilityData() async {
//   print('fetchCompatibilityData() - Starting fetch');
  
//   if (compatibilityResult != null || compatibilityLoading) {
//     print('fetchCompatibilityData() - Already loaded or loading, skipping');
//     return;
//   }

//   setState(() => compatibilityLoading = true);
  
//   try {
//     print('fetchCompatibilityData() - Checking ${ingredients.length} ingredients');

//     final result = await CompatibilityUtil.calculateCompatibility(
//       ingredients: ingredients,
//       skinTypeId: skinTypeId,
//       concernIds: concernIds,
//     );

//     print('fetchCompatibilityData() - Calculated result: $result');
    
//     setState(() {
//       compatibilityResult = result;
//       compatibilityLoading = false;
//     });

//     print('fetchCompatibilityData() - Update complete');

//   } catch (error) {
//     print('fetchCompatibilityData() - ERROR: $error');
//     setState(() {
//       compatibilityError = "Failed to calculate compatibility: ${error.toString()}";
//       compatibilityLoading = false;
//     });
//   }
// }

//   @override
//   Widget build(BuildContext context) {
//     print('build() - Rebuilding widget');
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text("Product Analysis"),
//         backgroundColor: const Color.fromARGB(255, 170, 136, 176),
//         bottom: TabBar(
//           controller: _tabController,
//           tabs: const [
//             Tab(text: 'Safety Score'),
//             Tab(text: 'Compatibility'),
//           ],
//         ),
//       ),
//       body: TabBarView(
//         controller: _tabController,
//         children: [
//           _buildSafetyTab(),
//           _buildCompatibilityTab(),
//         ],
//       ),
//     );
//   }

//   Widget _buildSafetyTab() {
//     print('_buildSafetyTab() - Building safety tab');
//     return SingleChildScrollView(
//       padding: const EdgeInsets.all(16),
//       child: Column(
//         children: [
//           Text(
//             widget.productName,
//             style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
//             textAlign: TextAlign.center,
//           ),
//           const SizedBox(height: 10),
//           Text(widget.brand, style: const TextStyle(fontSize: 18, color: Colors.grey)),
//           const SizedBox(height: 10),
          
//           ClipRRect(
//             borderRadius: BorderRadius.circular(15),
//             child: widget.imageUrl.isNotEmpty
//                 ? Image.network(widget.imageUrl, height: 200, fit: BoxFit.cover)
//                 : Image.asset('assets/placeholder.png', height: 200, fit: BoxFit.cover),
//           ),
          
//           if (isLoading)
//             const CircularProgressIndicator()
//           else if (errorMessage != null)
//             Text(errorMessage!, style: const TextStyle(color: Colors.red))
//           else if (safetyScore != null)
//             Container(
//               margin: const EdgeInsets.symmetric(vertical: 12),
//               padding: const EdgeInsets.all(10),
//               decoration: BoxDecoration(
//                 color: ProductScorer.getScoreColor(safetyScore!),
//                 borderRadius: BorderRadius.circular(12),
//               ),
//               child: Text(
//                 "Safety Score: ${safetyScore!.toStringAsFixed(1)}/10",
//                 style: const TextStyle(
//                   fontSize: 18,
//                   fontWeight: FontWeight.bold,
//                   color: Colors.white,
//                 ),
//               ),
//             ),
          
//           if (ingredients.isEmpty && !isLoading)
//             const Center(child: Padding(
//               padding: EdgeInsets.all(20),
//               child: Text("No ingredient data available"),
//             ))
//           else
//             ...ingredients.map((ingredient) => _buildIngredientCard(ingredient)),
          
//           const Padding(
//             padding: EdgeInsets.only(top: 20),
//             child: Text(
//               "Safety ratings from EWG's Skin Deep database",
//               style: TextStyle(fontSize: 14, color: Colors.black54),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//  Widget _buildCompatibilityTab() {
//   print('_buildCompatibilityTab() - Building compatibility tab');
  
//   if (_tabController.index == 1 && compatibilityResult == null && !compatibilityLoading) {
//     print('fetchCompatibilityData() - First load, fetching data');
//     fetchCompatibilityData();
//   }

//   return SingleChildScrollView(
//     padding: const EdgeInsets.all(16),
//     child: Column(
//       children: [
//         Text(
//           widget.productName,
//           style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
//           textAlign: TextAlign.center,
//         ),
//         const SizedBox(height: 10),
//         Text(widget.brand, style: const TextStyle(fontSize: 18, color: Colors.grey)),
//         const SizedBox(height: 10),
        
//         if (compatibilityLoading)
//           const Center(child: CircularProgressIndicator())
//         else if (compatibilityError != null)
//           Text(compatibilityError!, style: const TextStyle(color: Colors.red))
//         else if (compatibilityResult != null && compatibilityResult!['score'] != null)
//           Column(
//             children: [
//               CompatibilityUtil.buildScoreChip(compatibilityResult!['score']),
//               const SizedBox(height: 16),
//               Container(
//                 padding: const EdgeInsets.all(16),
//                 decoration: BoxDecoration(
//                   color: Colors.grey[100],
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//                 child: Column(
//                   children: [
//                     const Text(
//                       "Your Skin Profile",
//                       style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
//                     ),
//                     const SizedBox(height: 8),
//                     ListTile(
//                       leading: const Icon(Icons.face_retouching_natural),
//                       title: const Text("Skin Type"),
//                       subtitle: Text(skinTypeName),
//                     ),
//                     ListTile(
//                       leading: const Icon(Icons.health_and_safety),
//                       title: const Text("Primary Concerns"),
//                       subtitle: Text(concernIds.map((id) => concernNames[id]).join(", ")),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
        
//         const SizedBox(height: 20),
//         if (ingredients.isNotEmpty) ...[
//           const Text(
//             "Ingredient Analysis",
//             style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
//           ),
//           const SizedBox(height: 8),
//           ...ingredients.map((ingredient) => _buildIngredientCompatibility(ingredient)),
//         ],
//       ],
//     ),
//   );
// }

//   Widget _buildIngredientCard(Map<String, dynamic> ingredient) {
//     print('_buildIngredientCard() - Building card for ${ingredient['Ingredient_Name']}');
//     final score = ingredient['Score'] as int? ?? 0;
    
//     return Container(
//       margin: const EdgeInsets.symmetric(vertical: 8),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(15),
//         boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
//       ),
//       child: ExpansionTile(
//         leading: CircleAvatar(
//           backgroundColor: ProductScorer.getScoreColor(score.toDouble()),
//           child: Text("$score", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
//         ),
//         title: Text(
//           ingredient['Ingredient_Name'] ?? "Not Specified",
//           style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//         ),
//         subtitle: Text(ingredient['Function'] ?? 'Not Specified'),
//         children: [
//           Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text("🔬 Other Concerns: ${ingredient['Other_Concerns'] ?? 'Not Specified'}"),
//                 ProductScorer.buildRiskIndicator("Cancer Concern", ingredient['Cancer_Concern']),
//                 ProductScorer.buildRiskIndicator("Allergies", ingredient['Allergies_Immunotoxicity']),
//                 ProductScorer.buildRiskIndicator(
//                   "Developmental Toxicity", 
//                   ingredient['Developmental_Reproductive_Toxicity'],
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildIngredientCompatibility(Map<String, dynamic> ingredient) {
//   print('_buildIngredientCompatibility() - Building for ${ingredient['Ingredient_Name']}');
  
//   if (compatibilityResult == null) {
//     print('_buildIngredientCompatibility() - No data yet, showing loader');
//     return _buildLoadingCompatibility(ingredient);
//   }

//   return Card(
//     margin: const EdgeInsets.symmetric(vertical: 8),
//     child: Padding(
//       padding: const EdgeInsets.all(12),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             ingredient['Ingredient_Name'] ?? "Unknown Ingredient",
//             style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
//           ),
//           const SizedBox(height: 8),
//           CompatibilityUtil.buildIngredientWarnings(
//             irritationLevel: ingredient['Irritation'] as String?,
//             isComedogenic: ingredient['Comedogenicity'],
//             allergyLevel: ingredient['Allergies_Immunotoxicity'] as String?,
//             skinTypeId: skinTypeId,
//             concernIds: concernIds,
//           ),
//         ],
//       ),
//     ),
//   );
// }

// Widget _buildLoadingCompatibility(Map<String, dynamic> ingredient) {
//   print('_buildLoadingCompatibility() - Showing loader for ${ingredient['Ingredient_Name']}');
//   return Card(
//     margin: const EdgeInsets.symmetric(vertical: 8),
//     child: ListTile(
//       title: Text(ingredient['Ingredient_Name'] ?? "Unknown Ingredient"),
//       trailing: const CircularProgressIndicator(),
//     ),
//   );
// }
// }