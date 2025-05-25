import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../user_provider.dart';
import '../Auth/login_screen.dart';
import '../Profile/profile_screen.dart';
import '../Rank/ranking_screen.dart';
import '../Calendar/calendar_screen.dart';
import '../Friends/friends_screen.dart';
import '../Setting/setting_screen.dart';
import '../main.dart';

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
            MaterialPageRoute(builder: (context) => const StartScreen()),
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
      width: 240.w,
      backgroundColor: const Color(0xFFE5FBFF),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 16.h),
          Padding(
            padding: EdgeInsets.only(left: 16.w),
            child: IconButton(
              icon: Icon(Icons.menu, color: Colors.black, size: 24.sp),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          SizedBox(height: 8.h),
          Center(
            child: GestureDetector(
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ProfileScreen()),
                );
              },
              child: Column(
                children: [
                  Container(
                    width: 100.w,
                    height: 100.h,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(color: Colors.black26),
                    ),
                    child: Consumer<UserProvider>(
                      builder: (context, userProvider, child) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(20.r),
                          child: userProvider.photoUrl != null
                              ? Image.network(
                                  userProvider.photoUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Icon(Icons.account_circle, size: 36.sp, color: Colors.grey);
                                  },
                                )
                              : Icon(Icons.account_circle, size: 36.sp, color: Colors.grey),
                        );
                      },
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Consumer<UserProvider>(
                    builder: (context, userProvider, child) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            userProvider.nickname,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16.sp,
                            ),
                          ),
                          SizedBox(width: 4.w),
                          Icon(Icons.arrow_forward_ios, size: 12.sp, color: Colors.grey),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 20.h),
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
          _buildMenuItem(
            context,
            '환경 설정',
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingScreen()),
            ),
          ),
          const Spacer(),
          Padding(
            padding: EdgeInsets.only(left: 16.w, bottom: 12.h),
            child: InkWell(
              onTap: () => _signOut(context),
              child: Row(
                children: [
                  Icon(Icons.logout, color: Colors.red, size: 24.sp),
                  SizedBox(width: 8.w),
                  Text(
                    '로그아웃',
                    style: TextStyle(
                      fontSize: 16.sp,
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
      padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 20.w),
      child: InkWell(
        onTap: () {
          Navigator.pop(context);
          onTap();
        },
        child: Text(
          title,
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
} 