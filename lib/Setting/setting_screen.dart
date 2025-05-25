import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../Auth/login_screen.dart';
import '../Widgets/bottom_bar.dart';
import '../home_screen.dart';
import '../main.dart';
import '../post/post_list.dart';
import '../Running/workout_screen.dart';
import '../profile/profile_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SettingScreen extends StatefulWidget {
  const SettingScreen({super.key});

  @override
  State<SettingScreen> createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen> {
  bool _isNotificationEnabled = true;
  int _selectedIndex = 1;

  Future<void> _deleteAccount(BuildContext context) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            '회원 탈퇴',
            style: TextStyle(fontSize: 18.sp),
          ),
          content: Text(
            '정말로 탈퇴하시겠습니까?\n탈퇴 시 모든 데이터가 삭제되며 복구할 수 없습니다.',
            style: TextStyle(fontSize: 16.sp),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                '취소',
                style: TextStyle(fontSize: 16.sp),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                '탈퇴',
                style: TextStyle(
                  fontSize: 16.sp,
                  color: Colors.red,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (shouldDelete == true) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final userId = user.uid;
          final batch = FirebaseFirestore.instance.batch();
          final userDoc = FirebaseFirestore.instance.collection('users').doc(userId);
          
          // 삭제할 하위 컬렉션 목록
          final subCollections = [
            'Friends_Data',
            'Sent_Requests',
            'Received_Requests',
            'Running_Data',
            'MyProfile',
            'Post_Data',
            'LikedPosts'
          ];
          
          // 모든 하위 컬렉션의 문서 삭제
          for (String collection in subCollections) {
            final snapshot = await userDoc.collection(collection).get();
            for (var doc in snapshot.docs) {
              batch.delete(doc.reference);
            }
          }
          
          // 사용자 문서 삭제
          batch.delete(userDoc);
          
          // 배치 작업 실행
          await batch.commit();
          
          // Firebase Auth 계정 삭제
          await user.delete();
          
          if (context.mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const StartScreen()),
              (route) => false,
            );
          }
        }
      } on FirebaseAuthException catch (e) {
        String errorMessage = '회원 탈퇴 중 오류가 발생했습니다.';
        if (e.code == 'requires-recent-login') {
          errorMessage = '보안을 위해 다시 로그인해주세요.';
        }
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('회원 탈퇴 중 오류가 발생했습니다: $e'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '환경 설정',
          style: TextStyle(fontSize: 18.sp),
        ),
        backgroundColor: const Color(0xFFE5FBFF),
      ),
      body: ListView(
        children: [
          SizedBox(height: 16.h),
          _buildSwitchTile(
            '알림 수신',
            _isNotificationEnabled,
            (value) {
              setState(() {
                _isNotificationEnabled = value;
              });
            },
          ),
          const Divider(),
          _buildNavigationTile(
            '차단한 사용자 목록',
            () {
              // TODO: 차단한 사용자 목록 화면으로 이동
            },
          ),
          const Divider(),
          _buildNavigationTile(
            '문의하기',
            () {
              // TODO: 문의하기 화면으로 이동
            },
          ),
          const Divider(),
          _buildInfoTile('버전 정보', '1.0.0'),
          _buildNavigationTile(
            '이용 약관',
            () {
              // TODO: 이용 약관 화면으로 이동
            },
          ),
          _buildNavigationTile(
            '위치 기반 서비스 이용약관',
            () {
              // TODO: 위치 기반 서비스 이용약관 화면으로 이동
            },
          ),
          _buildNavigationTile(
            '개인 정보 처리 방침',
            () {
              // TODO: 개인 정보 처리 방침 화면으로 이동
            },
          ),
          const Divider(),
          _buildDeleteAccountTile(),
        ],
      ),
      bottomNavigationBar: BottomBar(
        selectedIndex: _selectedIndex,
        onTabSelected: (index) {
          setState(() => _selectedIndex = index);
          if (index == 0) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const WorkoutScreen()),
            );
          } else if (index == 1) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const ScreenHome()),
            );
          } else if (index == 2) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const ProfileScreen()),
            );
          }
        },
      ),
    );
  }

  Widget _buildSwitchTile(String title, bool value, Function(bool) onChanged) {
    return SwitchListTile(
      title: Text(
        title,
        style: TextStyle(fontSize: 16.sp),
      ),
      value: value,
      onChanged: onChanged,
      activeColor: Colors.blue,
    );
  }

  Widget _buildNavigationTile(String title, VoidCallback onTap) {
    return ListTile(
      title: Text(
        title,
        style: TextStyle(fontSize: 16.sp),
      ),
      trailing: Icon(Icons.arrow_forward_ios, size: 16.sp),
      onTap: onTap,
    );
  }

  Widget _buildInfoTile(String title, String subtitle) {
    return ListTile(
      title: Text(
        title,
        style: TextStyle(fontSize: 16.sp),
      ),
      trailing: Text(
        subtitle,
        style: TextStyle(
          fontSize: 14.sp,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildDeleteAccountTile() {
    return ListTile(
      title: Text(
        '회원 탈퇴',
        style: TextStyle(
          fontSize: 16.sp,
          color: Colors.red,
        ),
      ),
      onTap: () => _deleteAccount(context),
    );
  }
} 