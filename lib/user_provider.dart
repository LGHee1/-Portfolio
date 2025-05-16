import 'package:flutter/material.dart';

class UserProvider with ChangeNotifier {
  String _nickname = '';
  String get nickname => _nickname;

  String? _photoUrl;
  String? get photoUrl => _photoUrl;

  void setNickname(String nickname) {
    _nickname = nickname;
    notifyListeners();
  }

  void setPhotoUrl(String? photoUrl) {
    _photoUrl = photoUrl;
    notifyListeners();
  }
} 