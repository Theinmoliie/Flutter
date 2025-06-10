// lib/mode/decade_guide.dart
import 'dart:convert';
import 'ingredient.dart'; // Import the Ingredient model

class DecadeGuide {
  final String title;
  final String summary;
  final List<String> commonConcerns;
  final List<String> focusOn;
  final List<Ingredient> spotlightIngredients;

  DecadeGuide({
    required this.title,
    required this.summary,
    required this.commonConcerns,
    required this.focusOn,
    required this.spotlightIngredients,
  });

  factory DecadeGuide.fromMap(Map<String, dynamic> map) {
    // Handle the nested list of ingredients
    final ingredientsData = map['spotlight_ingredients'] as List<dynamic>? ?? [];
    final ingredientsList = ingredientsData
        .map((ingredientMap) => Ingredient.fromMap(ingredientMap))
        .toList();

    return DecadeGuide(
      title: map['title'] ?? 'No Title',
      summary: map['summary'] ?? 'No Summary',
      commonConcerns: List<String>.from(map['common_concerns'] ?? []),
      focusOn: List<String>.from(map['focus_on'] ?? []),
      spotlightIngredients: ingredientsList,
    );
  }

  factory DecadeGuide.fromJson(String source) =>
      DecadeGuide.fromMap(json.decode(source));
}