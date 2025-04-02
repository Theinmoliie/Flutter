import 'package:flutter/material.dart';

class SkinProfileProvider extends ChangeNotifier {
  String _userSkinType = "";
  int _userSkinTypeId = -1;
  List<String> _userConcerns = [];
  List<int> _userConcernIds = [];

  String get userSkinType => _userSkinType;
  int get userSkinTypeId => _userSkinTypeId;
  List<String> get userConcerns => _userConcerns;
  List<int> get userConcernIds => _userConcernIds;

  void updateSkinProfile(String skinType, int skinTypeId, List<String> concerns, List<int> concernIds) {
    _userSkinType = skinType;
    _userSkinTypeId = skinTypeId;
    _userConcerns = concerns;
    _userConcernIds = concernIds;
    notifyListeners();  // Notify widgets about the change
  }
}
