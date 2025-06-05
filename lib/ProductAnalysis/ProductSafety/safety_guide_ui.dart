 // ProductSafety/safety_guide_ui.dart
 // Responsible purely for rendering the visual representation of the product safety information.

    import 'dart:io';
    import 'package:flutter/material.dart';
    import '../../util/safetyscore_util.dart'; // Adjust import path as needed
    import '../product_header_widget.dart';   // Adjust import path

    class SafetyGuideUI extends StatelessWidget {
      final String productName;
      final String brand;
      final String? imageUrl;
      final File? imageFile;
      final ProductGuidance? productGuidance;
      final List<Map<String, dynamic>> matchedIngredients;
      final List<String> unmatchedIngredients;

      const SafetyGuideUI({
        Key? key,
        required this.productName,  
        required this.brand,
        this.imageUrl,
        this.imageFile,
        this.productGuidance,
        required this.matchedIngredients,
        required this.unmatchedIngredients,
      }) : super(key: key);

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

      @override
      Widget build(BuildContext context) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch, // Option 1: Make children stretch
        children: [
          Center( // <-- ADD THIS CENTER WIDGET
            child: ProductHeaderWidget(
              productName: productName,
              brand: brand,
              imageUrl: imageUrl,
              imageFile: imageFile,
            ),
          ),
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
                Center(child: Image.asset('assets/SafetyScale.png', height: 50, fit: BoxFit.fitHeight)),
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
    }
  