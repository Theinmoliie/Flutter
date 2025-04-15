// skin_profile_provider.dart
import 'package:flutter/material.dart';

class SkinProfileProvider extends ChangeNotifier {
  // Keep existing variables
  String? _userSkinType; // Make nullable for initial state
  int? _userSkinTypeId; // Make nullable
  List<String> _userConcerns = [];
  List<int> _userConcernIds = [];

  // --- MODIFIED: Make Sensitivity Level nullable ---
  String? _userSensitivityLevel; // Initialize as null (no default)
  // ---------------------------------------------

  // Keep existing getters
  String? get userSkinType => _userSkinType;
  int? get userSkinTypeId => _userSkinTypeId;
  List<String> get userConcerns => _userConcerns;
  List<int> get userConcernIds => _userConcernIds;

  // --- MODIFIED: Getter for nullable Sensitivity Level ---
  String? get userSensitivityLevel => _userSensitivityLevel;
  // ---------------------------------------------------

  // --- MODIFIED: Update updateSkinProfile method parameter ---
  void updateSkinProfile({
    String? skinType, // Allow null
    int? skinTypeId, // Allow null
    required List<String> concerns,
    required List<int> concernIds,
    required String? sensitivityLevel, // Allow null sensitivity level parameter
  }) {
    _userSkinType = skinType;
    _userSkinTypeId = skinTypeId;
    _userConcerns = concerns;
    _userConcernIds = concernIds;
    _userSensitivityLevel = sensitivityLevel; // Update sensitivity level
    notifyListeners(); // Notify widgets about the change
  }
  // ------------------------------------------------------

  // --- MODIFIED: Clear Method Update ---
  void clearProfile() {
    _userSkinType = null;
    _userSkinTypeId = null;
    _userConcerns = [];
    _userConcernIds = [];
    _userSensitivityLevel = null; // Reset to null (no selection) on clear
    notifyListeners();
  }
  // ------------------------------------
}