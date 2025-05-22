import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../Auth/login_screen.dart';

class SettingScreen extends StatefulWidget {
  const SettingScreen({super.key});

  @override
  State<SettingScreen> createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen> {
  bool _isNotificationEnabled = true;

  Future<void> _signOut(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('로그아웃'),
          content: const Text('정말 로그아웃 하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(
                '확인',
                style: TextStyle(color: Colors.red),
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
        title: const Text('환경 설정'),
        backgroundColor: const Color(0xFFE5FBFF),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 16),
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
    );
  }

  Widget _buildSwitchTile(String title, bool value, Function(bool) onChanged) {
    return SwitchListTile(
      title: Text(title),
      value: value,
      onChanged: onChanged,
      activeColor: Colors.blue,
    );
  }

  Widget _buildNavigationTile(String title, VoidCallback onTap) {
    return ListTile(
      title: Text(title),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }

  Widget _buildInfoTile(String title, String subtitle) {
    return ListTile(
      title: Text(title),
      trailing: Text(
        subtitle,
        style: const TextStyle(color: Colors.grey),
      ),
    );
  }

  Widget _buildLogoutTile() {
    return ListTile(
      title: const Text(
        '로그아웃',
        style: TextStyle(color: Colors.red),
      ),
      onTap: () => _signOut(context),
    );
  }
} 