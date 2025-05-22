import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../Auth/login_screen.dart';
import '../Widgets/bottom_bar.dart';
import '../home_screen.dart';
import '../post/post_list.dart';
import '../Running/workout_screen.dart';
import '../profile/profile_screen.dart';

class SettingScreen extends StatefulWidget {
  const SettingScreen({super.key});

  @override
  State<SettingScreen> createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen> {
  bool _isNotificationEnabled = true;
  int _selectedIndex = 1;

  Future<void> _signOut(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            '로그아웃',
            style: TextStyle(fontSize: 18.sp),
          ),
          content: Text(
            '정말 로그아웃 하시겠습니까?',
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
                '확인',
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

    if (shouldLogout == true) {
      try {
        await FirebaseAuth.instance.signOut();
        if (context.mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
          );
        }
      } catch (e) {
        print('로그아웃 중 오류 발생: $e');
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
          _buildLogoutTile(),
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

  Widget _buildLogoutTile() {
    return ListTile(
      title: Text(
        '로그아웃',
        style: TextStyle(
          fontSize: 16.sp,
          color: Colors.red,
        ),
      ),
      onTap: () => _signOut(context),
    );
  }
} 