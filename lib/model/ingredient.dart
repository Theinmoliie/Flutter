// lib/model/ingredient.dart
import 'dart:convert';

class Ingredient {
  final String name;
  final String tagline;
  final String description;

  Ingredient({
    required this.name,
    required this.tagline,
    required this.description,
  });

  // The 'fromMap' factory now uses the correct keys from the JSON
  factory Ingredient.fromMap(Map<String, dynamic> map) {
    return Ingredient(
      name: map['name'] ?? '',
      tagline: map['tagline'] ?? '',
      description: map['description'] ?? '',
    );
  }

  factory Ingredient.fromJson(String source) =>
      Ingredient.fromMap(json.decode(source));
}