// product_analysis.dart
import 'dart:io';
// import 'dart:ui'; // Not explicitly used
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../util/safetyscore_util.dart';
import '../util/compatibilityscore_util.dart';
import '../providers/skin_profile_provider.dart';
import '../UserProfile/multi_screen.dart';

class ProductAnalysis extends StatelessWidget {
  final String productName;
  final String brand;
  final String? imageUrl;
  final File? imageFile;
  final ProductGuidance? productGuidance;
  final List<Map<String, dynamic>> matchedIngredients;
  final List<String> unmatchedIngredients;

  final List<Map<String, dynamic>> compatibilityResults;
  final bool isLoadingCompatibility;
  final String recommendationStatus;
  final List<String>? compatibilityReasons;

  final VoidCallback? onProfileRequested;
  final Map<int, String> skinTypeMap;
  final Map<int, String> concernMap;

  final List<String> productAddressesTheseUserConcernsNames;
  final List<Map<String, String>> ingredientsAddressTheseUserConcernsDetails;
  final bool productDirectlyTargetsUserSelectedConcerns;
  final bool ingredientsTargetUserSelectedConcerns;


  const ProductAnalysis({
    super.key,
    required this.productName,
    required this.brand,
    this.imageUrl,
    this.imageFile,
    this.productGuidance,
    required this.matchedIngredients,
    required this.unmatchedIngredients,
    required this.compatibilityResults,
    required this.isLoadingCompatibility,
    required this.recommendationStatus,
    this.compatibilityReasons,
    this.onProfileRequested,
    required this.skinTypeMap,
    required this.concernMap,
    this.productAddressesTheseUserConcernsNames = const [],
    this.ingredientsAddressTheseUserConcernsDetails = const [],
    this.productDirectlyTargetsUserSelectedConcerns = false,
    this.ingredientsTargetUserSelectedConcerns = false,
  });

  String getSkinTypeName(int id) => skinTypeMap[id] ?? "Unknown";
  String getConcernName(int id) => concernMap[id] ?? "Unknown";

  String _formatNameList(List<String> names) {
    if (names.isEmpty) return "";
    if (names.length == 1) return names.first;
    if (names.length == 2) return "${names.first} and ${names.last}";
    return "${names.sublist(0, names.length - 1).join(', ')}, and ${names.last}";
  }

  void _showSafetyGuidanceDetails(BuildContext context, ProductGuidance guidance) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: RichText(
          text: TextSpan(
            style: TextStyle(
                fontSize: Theme.of(dialogContext).textTheme.titleLarge?.fontSize ?? 20,
                color: Colors.black,
                fontWeight: FontWeight.bold),
            children: <TextSpan>[
              const TextSpan(text: 'Safety Guidance: '),
              TextSpan(
                text: guidance.category.toUpperCase(),
                style: TextStyle(color: ProductScorer.getCategoryColor(guidance.category)))
            ],
          ),
        ),
        content: SingleChildScrollView(
          child: ListBody(children: <Widget>[
            Text(guidance.actionableAdvice, style: TextStyle(fontSize: 15, color: Colors.grey[800], height: 1.4)),
            if (guidance.detail.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(guidance.detail, style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: Colors.grey[600]))
            ]
          ]),
        ),
        actions: <Widget>[
          TextButton(child: const Text('OK'), onPressed: () => Navigator.of(dialogContext).pop())
        ],
      ),
    );
  }

  bool _hasSafetyWarning(Map<String, dynamic> ingredient) {
    final allergies = ingredient['Allergies_Immunotoxicity']?.toString().toLowerCase() ?? '';
    final irritation = ingredient['Irritation']?.toString().toLowerCase() ?? '';
    final isComedogenic = ingredient['Comodogenic'] == true;
    return allergies.contains('moderate') || allergies.contains('high') ||
           irritation.contains('moderate') || irritation.contains('high') ||
           isComedogenic;
  }

  List<Map<String, dynamic>> _getWarnings(Map<String, dynamic> ingredient) {
    final warnings = <Map<String, dynamic>>[];
    if (ingredient['Comodogenic'] == true) {
      warnings.add({'text': 'Comedogenic: May clog pores', 'color': Colors.purple, 'icon': Icons.face});
    }
    final allergies = ingredient['Allergies_Immunotoxicity']?.toString().toLowerCase() ?? '';
    if (allergies.contains('high') || allergies.contains('moderate')) {
      final isHigh = allergies.contains('high');
      warnings.add({
        'text': 'Allergy risk: ${ingredient['Allergies_Immunotoxicity']?.toString().toUpperCase() ?? ''}',
        'color': isHigh ? Colors.red : Colors.orange,
        'icon': isHigh ? Icons.dangerous : Icons.warning,
      });
    }
    final irritation = ingredient['Irritation']?.toString().toLowerCase() ?? '';
    if (irritation.contains('high') || irritation.contains('moderate')) {
      final isHigh = irritation.contains('high');
      warnings.add({
        'text': 'Irritation risk: ${ingredient['Irritation']?.toString().toUpperCase() ?? ''}',
        'color': isHigh ? Colors.red : Colors.orange,
        'icon': isHigh ? Icons.dangerous : Icons.warning,
      });
    }
    return warnings;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Product Analysis", style: TextStyle(color: Colors.white)),
          backgroundColor: colorScheme.primary,
          iconTheme: const IconThemeData(color: Colors.white),
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [Tab(text: 'Safety Guide'), Tab(text: 'Compatibility')],
          ),
        ),
        body: TabBarView(children: [ _buildSafetyTab(context), _buildCompatibilityTab(context) ]),
      ),
    );
  }

  Widget _buildProductHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(productName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(brand, style: TextStyle(fontSize: 16, color: Colors.grey[600]), textAlign: TextAlign.center),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 200, width: 200,
            child: (imageUrl != null && imageUrl!.isNotEmpty)
                ? Image.network(
                    imageUrl!,
                    fit: BoxFit.cover,
                    loadingBuilder: (ctx, child, prog) => prog == null
                        ? child
                        : Center(child: CircularProgressIndicator(
                            value: prog.expectedTotalBytes != null ? prog.cumulativeBytesLoaded / prog.expectedTotalBytes! : null,
                            strokeWidth: 2.0,
                          )),
                    errorBuilder: (ctx, err, st) => Image.asset('assets/placeholder.png', fit: BoxFit.cover),
                  )
                : imageFile != null
                    ? Image.file(imageFile!, fit: BoxFit.cover,
                        errorBuilder: (ctx, err, st) => Image.asset('assets/placeholder.png', fit: BoxFit.cover))
                    : Image.asset('assets/placeholder.png', fit: BoxFit.cover),
          ),
        ),
      ],
    );
  }

  Widget _buildSafetyTab(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProductHeader(),
          const SizedBox(height: 24),
          if (productGuidance != null) ...[
            Center(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _showSafetyGuidanceDetails(context, productGuidance!),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 270,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: ProductScorer.getCategoryColor(productGuidance!.category).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(50),
                      border: Border.all(
                        color: ProductScorer.getCategoryColor(productGuidance!.category).withOpacity(0.3),
                        width: 1,
                      ),
                      boxShadow: [ BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 1, blurRadius: 3, offset: const Offset(0, 1))]),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            productGuidance!.category.toUpperCase(),
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: ProductScorer.getCategoryColor(productGuidance!.category)),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.info_outline,
                          color: ProductScorer.getCategoryColor(productGuidance!.category).withOpacity(0.8),
                          size: 18,
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(child: Image.asset('assets/SafetyScale.png', height: 50, fit: BoxFit.contain)),
            const SizedBox(height: 24),
          ] else Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20.0),
              child: Column(
                children: [
                  CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary)),
                  const SizedBox(height: 12),
                  const Text("Determining safety guidance..."),
                ],
              ),
            ),
          ),
          const Text("Ingredients Analysis:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          matchedIngredients.isEmpty && unmatchedIngredients.isEmpty
            ? const Center(child: Padding(padding: EdgeInsets.all(8.0), child: Text("No ingredients listed or recognized for analysis.")))
            : Column(
                children: [
                  if (matchedIngredients.isNotEmpty)
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: matchedIngredients.length,
                      itemBuilder: (context, index) {
                        final ing = matchedIngredients[index];
                        String? scoreStr = ing['Score']?.toString();
                        String dispScore = "?";
                        if (scoreStr!=null && scoreStr.isNotEmpty && !scoreStr.toLowerCase().contains("n/a") && !scoreStr.toLowerCase().contains("not found")) {
                          try{ dispScore = int.parse(scoreStr).toString(); } catch(e){}
                        }
                        double simScore = ing['similarityScore'] ?? 1.0;
                        String origIng = ing['originalIngredient'] ?? ing['Ingredient_Name'];
                        bool isCom = ing['Comodogenic'] == true;
                        return Container(
                          margin:const EdgeInsets.symmetric(vertical:4),
                          decoration:BoxDecoration(
                            color:Colors.white,
                            borderRadius:BorderRadius.circular(12),
                            boxShadow:const [BoxShadow(color:Colors.black12,blurRadius:3,offset:Offset(0,1))]),
                          child:Theme(
                            data:Theme.of(context).copyWith(dividerColor:Colors.transparent),
                            child:ClipRRect(
                              borderRadius:BorderRadius.circular(12),
                              child:ExpansionTile(
                                tilePadding:const EdgeInsets.symmetric(horizontal:16,vertical:8),
                                leading:Container(
                                  width:35,height:35,
                                  decoration:BoxDecoration(color:ProductScorer.getEwgScoreColor(scoreStr),shape:BoxShape.circle),
                                  child:Center(child:Text(dispScore,style:const TextStyle(color:Colors.white,fontWeight:FontWeight.bold)))
                                ),
                                title:Column(
                                  crossAxisAlignment:CrossAxisAlignment.start,
                                  mainAxisSize:MainAxisSize.min,
                                  children:[
                                    if(isCom) Padding(
                                      padding:const EdgeInsets.only(bottom:4.0),
                                      child:Chip(
                                        label:const Text('Comedogenic'),
                                        labelStyle:const TextStyle(fontSize:10,color:Colors.white),
                                        backgroundColor:Colors.purple.withOpacity(0.85),
                                        padding:const EdgeInsets.symmetric(horizontal:4,vertical:0),
                                        materialTapTargetSize:MaterialTapTargetSize.shrinkWrap,
                                        visualDensity:VisualDensity.compact,side:BorderSide.none)),
                                    Text(ing['Ingredient_Name']?? "N/A",style:const TextStyle(fontSize:16,fontWeight:FontWeight.w500))
                                  ]),
                                subtitle:simScore<1.0&&ing['originalIngredient']!=null
                                  ? Column(
                                      crossAxisAlignment:CrossAxisAlignment.start,
                                      children:[
                                        Text("Scanned as: $origIng",style:const TextStyle(fontSize:13,color:Colors.grey)),
                                        Wrap(children:[
                                          Text("Match: ${(simScore*100).toStringAsFixed(0)}%",style:const TextStyle(fontSize:13,color:Colors.grey)),
                                          const SizedBox(width:4),
                                          const Tooltip(message:"Matched from scanned text.",child:Text("⚠️",style:TextStyle(fontSize:13,color:Colors.orange)))
                                        ])
                                      ])
                                  : null,
                                children:[
                                  Container(
                                    padding:const EdgeInsets.all(16),
                                    child:Column(
                                      crossAxisAlignment:CrossAxisAlignment.start,
                                      children:[
                                        Text("Benefits: ${ing['Benefits']??'Not Specified'}",style:const TextStyle(fontSize:14)),
                                        const SizedBox(height:8),
                                        Text("Other Concerns: ${ing['Other_Concerns']??'Not Specified'}",style:const TextStyle(fontSize:14)),
                                        ProductScorer.buildRiskIndicator("Cancer",ing['Cancer_Concern']),
                                        ProductScorer.buildRiskIndicator("Allergies",ing['Allergies_Immunotoxicity']),
                                        ProductScorer.buildRiskIndicator("Developmental",ing['Developmental_Reproductive_Toxicity']),
                                        const SizedBox(height:5)
                                      ]))
                                  ])
                              )
                            )
                          );
                      },
                    ),
                  if (unmatchedIngredients.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Text("Could Not Analyze:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.deepOrangeAccent)),
                    const SizedBox(height: 8),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: unmatchedIngredients.length,
                      itemBuilder: (context, index) => Card(
                        elevation: 1,
                        color: Colors.grey[100],
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Text(unmatchedIngredients[index], style: const TextStyle(fontSize: 15)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
          const Padding(
            padding:EdgeInsets.fromLTRB(0,24,0,8),
            child:Center(
              child:Text(
                "Safety ratings and ingredient data are sourced from EWG's Skin Deep® database. This analysis is for informational purposes and not medical advice.",
                textAlign:TextAlign.center,
                style:TextStyle(fontSize:12,color:Colors.black54)
              )
            )
          )
        ],
      ),
    );
  }

  Widget _buildRecommendationInsight(BuildContext context) {
    List<Widget> insightWidgets = [];
    bool productHelps = productDirectlyTargetsUserSelectedConcerns;
    bool ingredientsHelp = ingredientsTargetUserSelectedConcerns;

    TextStyle headingStyle = const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: Colors.black87, height: 1.5);
    TextStyle detailStyle = const TextStyle(fontSize: 14, color: Colors.black87, height: 1.4);
    TextStyle ingredientNameStyle = const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87);


    if (productHelps) {
      insightWidgets.add(
        Text(
          "This product is specifically formulated to address your concern${productAddressesTheseUserConcernsNames.length != 1 ? 's' : ''} of:",
          style: headingStyle,
        ),
      );
      insightWidgets.add(const SizedBox(height: 6));
      for (String concernName in productAddressesTheseUserConcernsNames) {
        insightWidgets.add(
          Padding(
            padding: const EdgeInsets.only(left: 8.0, top: 2.0, bottom: 2.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("– ", style: detailStyle),
                Expanded(child: Text(concernName, style: detailStyle)),
              ],
            ),
          )
        );
      }
    }

    if (ingredientsHelp) {
      if (productHelps) {
        insightWidgets.add(const SizedBox(height: 12));
        insightWidgets.add(
          Text(
            "Additionally, it contains ingredients beneficial for your skin needs:",
            style: headingStyle,
          )
        );
      } else {
         insightWidgets.add(
          Text(
            "This product contains ingredients beneficial for your skin needs:",
            style: headingStyle,
          )
        );
      }
      insightWidgets.add(const SizedBox(height: 6));
      for (var detail in ingredientsAddressTheseUserConcernsDetails) {
        insightWidgets.add(
          Padding(
            padding: const EdgeInsets.only(left: 8.0, top: 2.0, bottom: 2.0),
             child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("– ", style: detailStyle),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: detailStyle, // Default style for this RichText
                      children: [
                        TextSpan(text: detail['ingredientName'], style: ingredientNameStyle),
                        TextSpan(text: ", which helps with ${detail['concernName']}"),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          )
        );
      }
    }

    if (!productHelps && !ingredientsHelp && recommendationStatus == "Recommended") {
      insightWidgets.add(
        Text(
          "This product is generally recommended for your profile based on an overall assessment.",
          style: detailStyle,
        )
      );
    }
    
    if (insightWidgets.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16), // Add some margin below
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.05), // Slightly more subtle background
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green.withOpacity(0.25), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2.0), // Align icon better with first line of text
            child: Icon(Icons.task_alt_rounded, color: Colors.green.shade600, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: insightWidgets,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCompatibilityTab(BuildContext context) {
    final skinProfile = Provider.of<SkinProfileProvider>(context, listen: false);

    List<Map<String, dynamic>> userSpecificPotentialHazards = [];
    if (skinProfile.userSkinTypeId != null && skinProfile.userSensitivity != null) {
      userSpecificPotentialHazards = matchedIngredients.where((ing) {
        bool isNotSuitableForProfile = compatibilityResults.any((r) =>
            r['ingredient_name'] == ing['Ingredient_Name'] &&
            r['is_suitable'] == false &&
            ((r['type'] == 'skin_type' && r['skin_type_id'] == skinProfile.userSkinTypeId) ||
             (r['type'] == 'skin_concern' && (skinProfile.userConcernIds).contains(r['concern_id']))));
        return isNotSuitableForProfile || _hasSafetyWarning(ing);
      }).toList();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildProductHeader(),
          const SizedBox(height: 20),
          _buildCompatibilityRecommendationSection(context), // This shows overall status and general reasons
          const SizedBox(height: 12), // Adjusted spacing

          if (isLoadingCompatibility && recommendationStatus != "Set Profile" && recommendationStatus != "Loading...")
            const Center(child: CircularProgressIndicator())
          else if (recommendationStatus != "Set Profile" &&
                   recommendationStatus != "Identify Product for Full Compatibility Analysis" &&
                   recommendationStatus != "Product Not Identified in Database")
            Column(
              children: [
                // Detailed insight for "Recommended" products is now shown here
                if (recommendationStatus == "Recommended")
                  _buildRecommendationInsight(context),

                // Problematic ingredients card
                if (recommendationStatus == "Not Recommended" && userSpecificPotentialHazards.isNotEmpty) ...[
                  _buildVerticalCard(
                      title: "Potentially Problematic For Your Profile",
                      count: userSpecificPotentialHazards.length,
                      icon: Icons.warning_amber_rounded,
                      iconColor: Colors.orange,
                      ingredients: userSpecificPotentialHazards,
                      isPositive: false,
                      context: context),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          const Padding(
            padding: EdgeInsets.fromLTRB(0, 24, 0, 8),
            child: Center(
              child: Text(
                "Compatibility analysis considers your skin profile. For specific concerns, consult a dermatologist.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileSetupPrompt(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.person_search_rounded, size: 48, color: Theme.of(context).colorScheme.primary.withOpacity(0.7)),
        const SizedBox(height: 12),
        const Text("Personalize Your Analysis", style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
        const SizedBox(height: 8),
        const Text("Set your skin profile to see how this product aligns with your skin type and concerns.", style: TextStyle(fontSize: 14, color: Colors.grey), textAlign: TextAlign.center),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          icon: const Icon(Icons.edit_note_rounded, color: Colors.white),
          label: const Text("Set Skin Profile", style: TextStyle(color: Colors.white)),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (routeContext) => MultiPageSkinProfileScreen(
                  onProfileSaved: (profileData) {
                    Navigator.of(routeContext).pop(); 
                    if (onProfileRequested != null) {
                      onProfileRequested!(); 
                    }
                  },
                  onBackPressed: () {
                     Navigator.of(routeContext).pop(); 
                  }
                ),
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  Widget _buildCompatibilityRecommendationSection(BuildContext context) {
    final skinProfile = Provider.of<SkinProfileProvider>(context, listen: false);

    if (recommendationStatus.isEmpty ||
        recommendationStatus == "Loading..." ||
        (recommendationStatus == "Set Profile" && onProfileRequested == null)) {
      return const Center(child: Padding(padding: EdgeInsets.all(8.0), child: Text("Analyzing compatibility...")));
    }
    if (recommendationStatus == "Set Profile") {
        return _buildProfileSetupPrompt(context);
    }

    // For OCR'd products, we show the specific message here and not the general reasons box.
    if (recommendationStatus == "Identify Product for Full Compatibility Analysis" ||
        recommendationStatus == "Product Not Identified in Database") {
         return Padding(
           padding: const EdgeInsets.all(16.0),
           child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off_rounded, size: 48, color: Colors.blueGrey.withOpacity(0.7)),
              const SizedBox(height: 12),
              Text(recommendationStatus, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.blueGrey), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              // compatibilityReasons are generally for specific product analysis, not these statuses.
              // If you have specific reasons for these statuses, they would be handled differently or passed distinctly.
              // For now, the static text below serves as the main "reason".
              if(compatibilityReasons != null && compatibilityReasons!.isNotEmpty)
                 ...compatibilityReasons!.map((reason) => Padding(
                   padding: const EdgeInsets.only(top: 4.0),
                   child: Text(reason, style: const TextStyle(fontSize: 14, color: Colors.grey), textAlign: TextAlign.center),
                 )),

              const SizedBox(height: 16),
              if (recommendationStatus == "Identify Product for Full Compatibility Analysis")
                Text("For a personalized compatibility check, please search for this product in our database after identifying its name and brand.", style: TextStyle(fontSize: 14, color: Colors.grey[600]), textAlign: TextAlign.center,),
              if (recommendationStatus == "Product Not Identified in Database" && productName == "Scanned Product") // Specific to OCR
                 Text("The ingredients were analyzed for safety. For personalized compatibility, please search for this product by its name.", style: TextStyle(fontSize: 14, color: Colors.grey[600]), textAlign: TextAlign.center,),

            ],
           ),
         );
    }


    Color statusColor = CompatibilityScorer.getRecommendationStatusColor(recommendationStatus);
    String profileSummary = "For Your Profile";
    if (skinProfile.userSkinType != null) {
        profileSummary = "For ${skinProfile.userSkinType} Skin";
        bool isUserSensitive = (skinProfile.userSensitivity?.toLowerCase() == "yes");
        if (isUserSensitive) {
            profileSummary += " (Sensitive)";
        }
        if (skinProfile.userConcerns.isNotEmpty) {
          // To avoid duplicating concern info if it's in the detailed insight,
          // we might conditionally add this or just rely on the detailed insight.
          // For now, let's keep it simple and show it here always.
          profileSummary += "\nTargeting: ${_formatNameList(skinProfile.userConcerns)}";
        }
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 0), // Reduced margin if detailed insight is shown below
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.25), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.center,
            child: Text(
              profileSummary,
              style: TextStyle(fontSize: 13, color: Colors.grey[600], fontStyle: FontStyle.italic),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              recommendationStatus.toUpperCase(),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: statusColor),
              textAlign: TextAlign.center,
            ),
          ),
          // Show general compatibilityReasons from the scorer ALWAYS
          if (compatibilityReasons != null && compatibilityReasons!.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Divider(height: 1, thickness: 0.5),
            const SizedBox(height: 10),
            ...compatibilityReasons!.map((reason) => Padding(
              padding: const EdgeInsets.only(top: 5.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.label_important_outline, size: 17, color: statusColor.withOpacity(0.8)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(reason, style: TextStyle(fontSize: 14, color: Colors.grey[700], height: 1.3))),
                ],
              ),
            )).toList(),
          ]
        ],
      ),
    );
  }

  Widget _buildVerticalCard({
    required String title,
    required int count,
    required IconData icon,
    required Color iconColor,
    required List<Map<String, dynamic>> ingredients,
    required bool? isPositive, 
    required BuildContext context 
  }) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
         onTap: () => _showIngredientsDetails(
          title: title,
          ingredientsToShow: ingredients,    
          isPositiveForThisCard: isPositive, 
          context: context 
      ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row( 
            children: [
              Container(width: 48, height: 48, decoration: BoxDecoration(color: iconColor.withOpacity(0.15), shape: BoxShape.circle), child: Icon(icon, size: 24, color: iconColor)),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4), Text("$count ingredients", style: TextStyle(fontSize: 14, color: Colors.grey[600])),
              ])),
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)), child: Text("$count", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: iconColor))),
            ]
          ),
        ),
      ),
    );
  }

  void _showIngredientsDetails({
    required String title,
    required List<Map<String, dynamic>> ingredientsToShow, 
    required bool? isPositiveForThisCard, 
    required BuildContext context 
  }) {
    showModalBottomSheet(
      context: context, 
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext btmSheetContext) => DraggableScrollableSheet( 
          initialChildSize: 0.6, minChildSize: 0.3, maxChildSize: 0.9,
          builder: (BuildContext draggableScrollableContext, ScrollController controller) => Container(
              decoration: BoxDecoration(
                color: Theme.of(btmSheetContext).canvasColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  ),
                  Expanded(
                    child: ingredientsToShow.isEmpty
                        ? const Center(child: Text("No specific ingredients found in this category for your profile."))
                        : ListView.separated(
                            controller: controller,
                            itemCount: ingredientsToShow.length,
                            separatorBuilder: (BuildContext separatorContext, int index) => const Divider(height: 1, indent: 16, endIndent: 16),
                            itemBuilder: (BuildContext itemBuilderContext, int index) => _buildIngredientListItem(
                                context: itemBuilderContext,
                                ingredient: ingredientsToShow[index],
                                isPositiveForThisCard: isPositiveForThisCard
                            ),
                          ),
                  ),
                ],
              ),
            ),
        ),
    );
  }

  Widget _buildIngredientListItem({
    required Map<String, dynamic> ingredient,
    required bool? isPositiveForThisCard, 
    required BuildContext context 
  }) {
    final benefits = ingredient['Benefits']?.toString() ?? 'No benefits data available.';
    final warnings = _getWarnings(ingredient); 
    final skinProfile = Provider.of<SkinProfileProvider>(context, listen: false);

    final ingredientSpecificCompatibilityResults = compatibilityResults
        .where((r) => r['ingredient_name'] == ingredient['Ingredient_Name'])
        .toList();

    // Style for problematic reasons/warnings
    TextStyle problematicItemStyle = TextStyle(fontSize: 13.5, color: Colors.grey.shade800, height: 1.4);
    TextStyle warningHeaderStyle = TextStyle(fontWeight:FontWeight.w600, color: Colors.orange.shade800, fontSize: 13.5);


    return ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        title: Text(ingredient['Ingredient_Name'] ?? 'Unknown Ingredient', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        children: <Widget>[
            Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16), // Adjusted padding
                color: Colors.grey.shade50.withOpacity(0.5), // Subtle background for expanded content
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        if (isPositiveForThisCard == true) ...[ 
                            if (benefits != 'No benefits data available.') Text("General Benefit: $benefits", style: const TextStyle(fontSize: 14)),
                             ...ingredientSpecificCompatibilityResults
                                .where((r) => r['is_suitable'] == true &&
                                             ((r['type'] == 'skin_type' && r['skin_type_id'] == skinProfile.userSkinTypeId) ||
                                              (r['type'] == 'skin_concern' && skinProfile.userConcernIds.contains(r['concern_id']))))
                                .map((result) => Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Icon(Icons.check, color: Colors.green.shade600, size: 18),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                              result['type'] == 'skin_type'
                                                  ? "Suitable for your ${getSkinTypeName(result['skin_type_id'])} skin."
                                                  : "Helps with your concern: ${getConcernName(result['concern_id'])}.",
                                              style: TextStyle(fontSize: 14, color: Colors.green.shade700)
                                          ),
                                        ),
                                      ],
                                    ),
                                )),
                             if (ingredientSpecificCompatibilityResults.where((r) => r['is_suitable'] == true && ((r['type'] == 'skin_type' && r['skin_type_id'] == skinProfile.userSkinTypeId) || (r['type'] == 'skin_concern' && skinProfile.userConcernIds.contains(r['concern_id'])))).isEmpty)
                                const Text("No specific positive compatibility notes found for your profile.", style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: Colors.grey)),

                        ] else if (isPositiveForThisCard == false) ...[ 
                            // Specific reasons why it's not suitable for the profile
                            ...ingredientSpecificCompatibilityResults
                                .where((r) => r['is_suitable'] == false &&
                                             ((r['type'] == 'skin_type' && r['skin_type_id'] == skinProfile.userSkinTypeId) ||
                                              (r['type'] == 'skin_concern' && skinProfile.userConcernIds.contains(r['concern_id']))))
                                .map((result) => Padding(
                                    padding: const EdgeInsets.only(bottom: 6.0),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Icon(Icons.cancel_outlined, color: Colors.red.shade700, size: 18),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                              result['type'] == 'skin_type'
                                                  ? "Not generally suitable for your ${getSkinTypeName(result['skin_type_id'])} skin."
                                                  : "May potentially worsen your concern: ${getConcernName(result['concern_id'])}.",
                                              style: problematicItemStyle.copyWith(color: Colors.red.shade800)
                                          ),
                                        ),
                                      ],
                                    ),
                                )),
                            // General Safety Warnings (if any)
                            if (warnings.isNotEmpty) ...[ 
                                if (ingredientSpecificCompatibilityResults.where((r) => r['is_suitable'] == false && ((r['type'] == 'skin_type' && r['skin_type_id'] == skinProfile.userSkinTypeId) || (r['type'] == 'skin_concern' && skinProfile.userConcernIds.contains(r['concern_id'])))).isNotEmpty)
                                  const SizedBox(height: 8), // Add space if profile reasons were shown
                                
                                Text("General Safety Warnings:", style: warningHeaderStyle),
                                const SizedBox(height: 4),
                                ...warnings.map((warning) => Padding(
                                    padding: const EdgeInsets.only(top: 4.0, left: 0.0), // Align with header
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Icon(warning['icon'], color: warning['color'], size: 18),
                                        const SizedBox(width: 8),
                                        Expanded(child: Text(warning['text'], style: problematicItemStyle.copyWith(color: warning['color']))),
                                    ]),
                                )),
                            ],
                             if (ingredientSpecificCompatibilityResults.where((r) => r['is_suitable'] == false && ((r['type'] == 'skin_type' && r['skin_type_id'] == skinProfile.userSkinTypeId) || (r['type'] == 'skin_concern' && skinProfile.userConcernIds.contains(r['concern_id'])))).isEmpty && warnings.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Text("No specific negative compatibility flags for your profile. Listed here due to overall product assessment or general safety data.", style: problematicItemStyle.copyWith(fontStyle: FontStyle.italic)),
                                ),
                        ],
                        const SizedBox(height: 12),
                        Text("EWG Score: ${ingredient['Score'] ?? 'N/A'}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        if(ingredient['Other_Concerns'] != null && (ingredient['Other_Concerns'] as String).isNotEmpty)
                            Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text("EWG Other Concerns: ${ingredient['Other_Concerns']}", style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                            ),
                    ],
                ),
            )
        ],
    );
  }
}