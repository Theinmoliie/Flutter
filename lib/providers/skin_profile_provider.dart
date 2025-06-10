// lib/providers/skin_profile_provider.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class SkinProfileProvider with ChangeNotifier {
  // --- All properties and getters are correct ---
  String? _userSkinType;
  int? _userSkinTypeId;
  List<String> _userConcerns = [];
  List<int> _userConcernIds = [];
  String? _userSensitivity;
  String? _username;
  DateTime? _dateOfBirth;

  List<Map<String, dynamic>> _allSkinTypes = [];
  List<Map<String, dynamic>> _allSkinConcerns = [];
  bool _isLoading = false;

  String? get userSkinType => _userSkinType;
  int? get userSkinTypeId => _userSkinTypeId;
  List<String> get userConcerns => _userConcerns;
  List<int> get userConcernIds => _userConcernIds;
  String? get userSensitivity => _userSensitivity;
  String? get username => _username;
  DateTime? get dateOfBirth => _dateOfBirth;
  List<Map<String, dynamic>> get allSkinTypes => _allSkinTypes;
  List<Map<String, dynamic>> get allSkinConcerns => _allSkinConcerns;
  bool get isLoading => _isLoading;

  SkinProfileProvider();

  // THIS IS THE CORRECTED FETCH METHOD
  Future<bool> fetchAndSetUserProfile() async {
    _isLoading = true;
    notifyListeners();

    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      _isLoading = false;
      notifyListeners();
      return false;
    }

    for (int i = 0; i < 3; i++) {
      try {
        final userProfile = await supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();

        final masterData = await Future.wait([
            supabase.from('Skin Types').select('skin_type_id, skin_type').order('skin_type_id'),
            supabase.from('Skin Concerns').select('concern_id, concern').order('concern_id'),
        ]);

        final skinTypesResponse = masterData[0] as List<dynamic>;
        final skinConcernsResponse = masterData[1] as List<dynamic>;

        _allSkinTypes = skinTypesResponse.cast<Map<String, dynamic>>();
        _allSkinConcerns = skinConcernsResponse.cast<Map<String, dynamic>>();
        
        // --- CORRECT DATA MAPPING ---

        // 1. Username and Date of Birth
        _username = userProfile['username'];
        if (userProfile['date_of_birth'] != null) {
          _dateOfBirth = DateTime.tryParse(userProfile['date_of_birth'].toString());
        }
        
        // 2. Skin Sensitivity (assuming 'skin_sensitivity' is a boolean in your DB)
        if (userProfile['skin_sensitivity'] != null) {
          _userSensitivity = userProfile['skin_sensitivity'] == true ? 'Yes' : 'No';
        } else {
          _userSensitivity = null;
        }

        // 3. Skin Type (fetch the ID, then find the name)
        _userSkinTypeId = userProfile['skin_type_id'];
        if (_userSkinTypeId != null) {
          // Find the corresponding skin type name from the master list
          try {
            _userSkinType = _allSkinTypes
                .firstWhere((type) => type['skin_type_id'] == _userSkinTypeId)['skin_type'];
          } catch (e) {
            _userSkinType = null; // Couldn't find a match
          }
        } else {
          _userSkinType = null;
        }

        // 4. Skin Concerns (fetch the array of IDs, then find the names)
        if (userProfile['skin_concerns_id'] != null) {
          final List<dynamic> concernIdsFromDb = userProfile['skin_concerns_id'];
          _userConcernIds = concernIdsFromDb.map((id) => id as int).toList();

          // Find the corresponding concern names from the master list
          _userConcerns = _allSkinConcerns
              .where((concern) => _userConcernIds.contains(concern['concern_id']))
              .map((concern) => concern['concern'] as String)
              .toList();
        } else {
          _userConcernIds = [];
          _userConcerns = [];
        }
        
        // --- END OF CORRECT DATA MAPPING ---

        _isLoading = false;
        notifyListeners();
        print("[Provider] Profile fetched successfully on attempt ${i + 1}.");
        return true;

      } catch (e) {
        print("[Provider] Error fetching profile on attempt ${i + 1}: $e");
        if (i < 2) {
          await Future.delayed(const Duration(milliseconds: 1500));
        }
      }
    }

    _isLoading = false;
    notifyListeners();
    print("[Provider] All attempts to fetch profile failed.");
    return false;
  }
  
  // No changes needed for the rest of the file...
  Map<String, dynamic>? getSkinTypeByName(String name) {
    try {
      return _allSkinTypes.firstWhere(
        (type) => (type['skin_type'] as String).toLowerCase() == name.toLowerCase(),
      );
    } catch (e) {
      return null;
    }
  }

  void updateUserProfile({
    String? username,
    DateTime? dob,
    String? skinType,
    int? skinTypeId,
    List<String>? concerns,
    List<int>? concernIds,
    String? sensitivity,
  }) {
    if (username != null) _username = username;
    if (dob != null) _dateOfBirth = dob;
    if (skinType != null) _userSkinType = skinType;
    if (skinTypeId != null) _userSkinTypeId = skinTypeId;
    if (concerns != null) _userConcerns = concerns;
    if (concernIds != null) _userConcernIds = concernIds;
    if (sensitivity != null) _userSensitivity = sensitivity;
    
    notifyListeners();
  }

  void clearProfile() {
    _userSkinType = null;
    _userSkinTypeId = null;
    _userConcerns = [];
    _userConcernIds = [];
    _userSensitivity = null;
    _username = null;
    _dateOfBirth = null;
    notifyListeners();
  }
}