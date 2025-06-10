// lib/services/skincare_service.dart
import 'package:flutter/services.dart' show rootBundle;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import '../model/decade_guide.dart'; // Import the new model

class SkincareService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // CHANGE: The method now returns a Future<DecadeGuide>
  Future<DecadeGuide> getDecadeGuide() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw 'User is not logged in.';

      final response = await _supabase
          .from('profiles')
          .select('date_of_birth')
          .eq('id', user.id)
          .single();

      final dobString = response['date_of_birth'];
      if (dobString == null) throw 'Date of birth not set for this user.';

      final birthDate = DateTime.parse(dobString);
      final age = _calculateAge(birthDate);
      final decadeKey = _getDecadeKeyFromAge(age);
      
      final String jsonString = await rootBundle.loadString('assets/skin_compass/decadeGuides.json'); // Make sure this is the correct path
      final Map<String, dynamic> allDecadeData = json.decode(jsonString);

      final jsonKey = _getJsonKeyForDecade(decadeKey);
      final guideDataMap = allDecadeData[jsonKey];

      if (guideDataMap == null) {
        throw 'Could not find a guide for your age group.';
      }
      
      // CHANGE: Create and return the full DecadeGuide object
      return DecadeGuide.fromMap(guideDataMap);

    } catch (e) {
      print('Error in getDecadeGuide: $e');
      rethrow;
    }
  }

  // --- Helper functions are unchanged ---
  String _getJsonKeyForDecade(String decadeKey) {
    switch (decadeKey.toLowerCase()) {
      case 'teens': return 'teens';
      case '20s': return 'twenties';
      case '30s': return 'thirties';
      case '40s': return 'forties';
      case '50s+': return 'fifties_plus';
      default: return 'unknown';
    }
  }

  int _calculateAge(DateTime birthDate) {
    final DateTime now = DateTime.now();
    int age = now.year - birthDate.year;
    if (now.month < birthDate.month || (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  String _getDecadeKeyFromAge(int age) {
    if (age >= 13 && age <= 19) return 'Teens';
    if (age >= 20 && age <= 29) return '20s';
    if (age >= 30 && age <= 39) return '30s';
    if (age >= 40 && age <= 49) return '40s';
    if (age >= 50) return '50s+';
    return 'unknown';
  }
}