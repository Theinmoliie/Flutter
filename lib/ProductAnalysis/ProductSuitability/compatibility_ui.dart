// ProductSafety/compatibility_ui.dart
// Reusable UI for PRESENTING suitability results, insights, and profile prompts.

    import 'dart:io';
    import 'package:flutter/material.dart';
    import 'package:provider/provider.dart';
    import '../../util/compatibilityscore_util.dart'; // Adjust import path
    import '../../providers/skin_profile_provider.dart'; // Adjust import path
    import '../../UserProfile/multi_screen.dart';     // Adjust import path
    import '../product_header_widget.dart';           // Adjust import path


    class CompatibilityUI extends StatelessWidget {
      final String productName;
      final String brand;
      final String? imageUrl;
      final File? imageFile;
      final List<Map<String, dynamic>> matchedIngredients; // For _hasSafetyWarning, userSpecificPotentialHazards
      final List<Map<String, dynamic>> compatibilityResults; // For _buildIngredientListItem & userSpecificPotentialHazards
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

      const CompatibilityUI({
        Key? key,
        required this.productName,
        required this.brand,
        this.imageUrl,
        this.imageFile,
        required this.matchedIngredients,
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
      }) : super(key: key);

      String getSkinTypeName(int id) => skinTypeMap[id] ?? "Unknown";
      String getConcernName(int id) => concernMap[id] ?? "Unknown";

      String _formatNameList(List<String> names) {
        if (names.isEmpty) return "";
        if (names.length == 1) return names.first;
        if (names.length == 2) return "${names.first} and ${names.last}";
        return "${names.sublist(0, names.length - 1).join(', ')}, and ${names.last}";
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
                    builder: (routeContext) => MultiPageSkinProfileScreen( // Ensure this screen exists and is imported
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

        if (recommendationStatus == "Identify Product for Full Compatibility Analysis" ||
            recommendationStatus == "Product Not Identified in Database") { // This case should ideally not occur if compatibility is only for searched DB products
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search_off_rounded, size: 48, color: Colors.blueGrey.withOpacity(0.7)),
                  const SizedBox(height: 12),
                  Text(recommendationStatus, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.blueGrey), textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  if(compatibilityReasons != null && compatibilityReasons!.isNotEmpty)
                    ...compatibilityReasons!.map((reason) => Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(reason, style: const TextStyle(fontSize: 14, color: Colors.grey), textAlign: TextAlign.center),
                    )),
                  const SizedBox(height: 16),
                  // Simplified message for suitability context
                   Text("This product was not found in our database, or full compatibility analysis is unavailable for OCR'd items.", style: TextStyle(fontSize: 14, color: Colors.grey[600]), textAlign: TextAlign.center,),
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
              profileSummary += "\nTargeting: ${_formatNameList(skinProfile.userConcerns)}";
            }
        }

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 0),
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
        required bool? isPositive, // Note: For suitability, this might always be 'false' if it's for "problematic"
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
                  Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:5),decoration:BoxDecoration(color:iconColor.withOpacity(0.1),borderRadius:BorderRadius.circular(20)),child:Text("$count", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: iconColor))),
                ]
              ),
            ),
          ),
        );
      }

      void _showIngredientsDetails({
        required String title,
        required List<Map<String, dynamic>> ingredientsToShow,
        required bool? isPositiveForThisCard, // If always problematic, can be hardcoded to false
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
                          isPositiveForThisCard: isPositiveForThisCard ?? false // Default to false if null
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
        required bool isPositiveForThisCard,
        required BuildContext context
      }) {
        // final benefits = ingredient['Benefits']?.toString() ?? 'No benefits data available.'; // Less relevant for pure "problematic" list
        final warnings = _getWarnings(ingredient); // General safety warnings
        final skinProfile = Provider.of<SkinProfileProvider>(context, listen: false);

        final ingredientSpecificCompatibilityResults = compatibilityResults // This prop holds the UI breakdown
            .where((r) => r['ingredient_name'] == ingredient['Ingredient_Name'])
            .toList();

        TextStyle problematicItemStyle = TextStyle(fontSize: 13.5, color: Colors.grey.shade800, height: 1.4);
        TextStyle warningHeaderStyle = TextStyle(fontWeight:FontWeight.w600, color: Colors.orange.shade800, fontSize: 13.5);

        return ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            title: Text(ingredient['Ingredient_Name'] ?? 'Unknown Ingredient', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            children: <Widget>[
                Container(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                    color: Colors.grey.shade50.withOpacity(0.5),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                            // For a "Potentially Problematic" list, we focus on negative flags
                            if (!isPositiveForThisCard) ...[
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
                                if (warnings.isNotEmpty) ...[
                                    if (ingredientSpecificCompatibilityResults.where((r) => r['is_suitable'] == false && ((r['type'] == 'skin_type' && r['skin_type_id'] == skinProfile.userSkinTypeId) || (r['type'] == 'skin_concern' && skinProfile.userConcernIds.contains(r['concern_id'])))).isNotEmpty)
                                      const SizedBox(height: 8),
                                    Text("General Safety Warnings:", style: warningHeaderStyle),
                                    const SizedBox(height: 4),
                                    ...warnings.map((warning) => Padding(
                                        padding: const EdgeInsets.only(top: 4.0, left: 0.0),
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
                                      child: Text("No specific negative compatibility flags for your profile. General safety or overall assessment might be why this product is not recommended.", style: problematicItemStyle.copyWith(fontStyle: FontStyle.italic)),
                                    ),
                            ] else ... [
                                // This 'else' branch for positive is less likely if the card itself is for "problematic"
                                // but kept for completeness if _buildVerticalCard is used for positive lists elsewhere
                                const Text("Details for positively matched ingredients would go here.", style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic)),
                            ],
                            const SizedBox(height: 12),
                            Text("EWG Score: ${ingredient['Score'] ?? 'N/A'}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), // Still show EWG for context
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

      @override
      Widget build(BuildContext context) {
        final skinProfile = Provider.of<SkinProfileProvider>(context, listen: false);

        List<Map<String, dynamic>> userSpecificPotentialHazards = [];
        if (skinProfile.userSkinTypeId != null && skinProfile.userSensitivity != null) {
          userSpecificPotentialHazards = matchedIngredients.where((ing) {
            bool isNotSuitableForProfile = compatibilityResults.any((r) =>
                r['ingredient_name'] == ing['Ingredient_Name'] &&
                r['is_suitable'] == false &&
                ((r['type'] == 'skin_type' && r['skin_type_id'] == skinProfile.userSkinTypeId) ||
                (r['type'] == 'skin_concern' && (skinProfile.userConcernIds).contains(r['concern_id']))));
            return isNotSuitableForProfile || _hasSafetyWarning(ing); // _hasSafetyWarning uses general safety flags
          }).toList();
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              ProductHeaderWidget(
                productName: productName,
                brand: brand,
                imageUrl: imageUrl,
                imageFile: imageFile,
              ),
              const SizedBox(height: 20),
              _buildCompatibilityRecommendationSection(context),
              const SizedBox(height: 12),
              if (isLoadingCompatibility && recommendationStatus != "Set Profile" && recommendationStatus != "Loading...")
                const Center(child: CircularProgressIndicator())
              else if (recommendationStatus != "Set Profile" ) // Removed OCR specific checks, as this screen is for searched products
                Column(
                  children: [
                    if (recommendationStatus == "Recommended")
                      _buildRecommendationInsight(context),
                    if (recommendationStatus == "Not Recommended" && userSpecificPotentialHazards.isNotEmpty) ...[
                      _buildVerticalCard(
                          title: "Potentially Problematic For Your Profile",
                          count: userSpecificPotentialHazards.length,
                          icon: Icons.warning_amber_rounded,
                          iconColor: Colors.orange,
                          ingredients: userSpecificPotentialHazards,
                          isPositive: false, // This card is for problematic items
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
    }