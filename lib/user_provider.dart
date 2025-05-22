import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserProvider with ChangeNotifier {
  String _nickname = '';
  String get nickname => _nickname;

  String? _photoUrl;
  String? get photoUrl => _photoUrl;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  Future<void> initializeUserData() async {
    if (_isInitialized) return;
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      print('현재 로그인된 사용자: ${user?.uid}');
      
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        
        print('Firestore에서 가져온 사용자 데이터: ${userDoc.data()}');
        
        if (userDoc.exists) {
          _nickname = userDoc.data()?['nickname'] ?? '';
          _photoUrl = userDoc.data()?['photoUrl'];
          print('설정된 photoUrl: $_photoUrl');
          _isInitialized = true;
          notifyListeners();
        } else {
          print('사용자 문서가 존재하지 않습니다.');
        }
      }
    } catch (e) {
      print('사용자 데이터 초기화 중 오류 발생: $e');
    }
  }

  void setNickname(String nickname) {
    _nickname = nickname;
    notifyListeners();
  }

  void setPhotoUrl(String? photoUrl) {
    _photoUrl = photoUrl;
    notifyListeners();
  }
} 