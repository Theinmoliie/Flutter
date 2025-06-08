// lib/providers/skin_profile_provider.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Get the Supabase client instance
final supabase = Supabase.instance.client;

class SkinProfileProvider with ChangeNotifier {
  // --- PRIVATE STATE VARIABLES ---
  String? _userSkinType;
  int? _userSkinTypeId;
  List<String> _userConcerns = [];
  List<int> _userConcernIds = [];
  String? _userSensitivity;

  // --- NEW: Add lists to hold all possible options fetched from the database ---
  List<Map<String, dynamic>> _allSkinTypes = [];
  List<Map<String, dynamic>> _allSkinConcerns = [];
  bool _isLoading = false;

  // --- PUBLIC GETTERS ---
  String? get userSkinType => _userSkinType;
  int? get userSkinTypeId => _userSkinTypeId;
  List<String> get userConcerns => _userConcerns;
  List<int> get userConcernIds => _userConcernIds;
  String? get userSensitivity => _userSensitivity;
  
  // --- NEW: Public getters for all available options ---
  List<Map<String, dynamic>> get allSkinTypes => _allSkinTypes;
  List<Map<String, dynamic>> get allSkinConcerns => _allSkinConcerns;
  bool get isLoading => _isLoading;

  SkinProfileProvider() {
    // Fetch initial data when the provider is first created
    _fetchInitialData();
  }

  // --- NEW: Method to fetch all master data from Supabase ---
  Future<void> _fetchInitialData() async {
    _isLoading = true;
    notifyListeners();
    try {
      // Fetch both sets of master data in parallel
      final responses = await Future.wait([
        supabase.from('Skin Types').select('skin_type_id, skin_type').order('skin_type_id'),
        supabase.from('Skin Concerns').select('concern_id, concern').order('concern_id'),
      ]);

      // Assign the results to our private variables
      _allSkinTypes = List<Map<String, dynamic>>.from(responses[0]);
      _allSkinConcerns = List<Map<String, dynamic>>.from(responses[1]);
      
      print("[Provider] Fetched ${_allSkinTypes.length} skin types and ${_allSkinConcerns.length} concerns.");

    } catch (e) {
      print("[Provider] Error fetching initial data: $e");
      // Handle error state if necessary
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- NEW: Helper method to find a skin type by name ---
  Map<String, dynamic>? getSkinTypeByName(String name) {
    try {
      // Use firstWhere to find the matching type, case-insensitive
      return _allSkinTypes.firstWhere(
        (type) => (type['skin_type'] as String).toLowerCase() == name.toLowerCase(),
      );
    } catch (e) {
      // firstWhere throws an error if no element is found
      return null;
    }
  }

  /// **MODIFIED: Update method now accepts nullable parameters for partial updates.**
  /// This allows you to update just one part of the profile (e.g., only sensitivity)
  /// without needing to provide all the other values again.
  void updateSkinProfile({
    String? skinType,
    int? skinTypeId,
    List<String>? concerns,
    List<int>? concernIds,
    String? sensitivity,
  }) {
    // Only update values if they are not null
    if (skinType != null) _userSkinType = skinType;
    if (skinTypeId != null) _userSkinTypeId = skinTypeId;
    if (concerns != null) _userConcerns = concerns;
    if (concernIds != null) _userConcernIds = concernIds;
    if (sensitivity != null) _userSensitivity = sensitivity;
    
    notifyListeners(); // Notify widgets about the change
  }

  void clearProfile() {
    _userSkinType = null;
    _userSkinTypeId = null;
    _userConcerns = [];
    _userConcernIds = [];
    _userSensitivity = null;
    notifyListeners();
  }
}