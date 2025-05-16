import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../user_provider.dart';
import '../Auth/login_screen.dart';
import '../Profile/profile_screen.dart';
import '../Rank/ranking_screen.dart';
import '../Calendar/calendar_screen.dart';
import '../friends_screen.dart';

class Menu extends StatelessWidget {
  const Menu({super.key});

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
    return Drawer(
      width: 240,
      backgroundColor: const Color(0xFFE5FBFF),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(left: 16.0),
            child: IconButton(
              icon: const Icon(Icons.menu, color: Colors.black),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Column(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.black26),
                  ),
                  child: Consumer<UserProvider>(
                    builder: (context, userProvider, child) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: userProvider.photoUrl != null
                            ? Image.network(
                                userProvider.photoUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(Icons.account_circle, size: 36, color: Colors.grey);
                                },
                              )
                            : const Icon(Icons.account_circle, size: 36, color: Colors.grey),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Consumer<UserProvider>(
                  builder: (context, userProvider, child) {
                    return Text(
                      userProvider.nickname,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildMenuItem(
            context,
            '내정보',
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ProfileScreen()),
            ),
          ),
          _buildMenuItem(
            context,
            '랭킹',
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => RankingScreen()),
            ),
          ),
          _buildMenuItem(
            context,
            '기록',
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => CalendarScreen()),
            ),
          ),
          _buildMenuItem(
            context,
            '친구관리',
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const FriendsScreen()),
            ),
          ),
          _buildMenuItem(context, '문의', () {}),
          _buildMenuItem(context, '환경 설정', () {}),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(left: 16.0, bottom: 12),
            child: InkWell(
              onTap: () => _signOut(context),
              child: const Row(
                children: [
                  Icon(Icons.logout, color: Colors.red),
                  SizedBox(width: 8),
                  Text(
                    '로그아웃',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, String title, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 20),
      child: InkWell(
        onTap: () {
          Navigator.pop(context);
          onTap();
        },
        child: Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
} 