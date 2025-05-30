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

  // UI Constants
  static const double _kMenuWidth = 280.0;
  static const double _kProfileImageSize = 100.0;
  static const double _kMenuItemHeight = 48.0;
  static const double _kIconSize = 24.0;
  static const double _kSmallIconSize = 16.0;
  static const double _kBorderRadius = 16.0;
  static const double _kDefaultPadding = 16.0;

  // Colors
  static const Color _kPrimaryColor = Color(0xFFE5FBFF);
  static const Color _kAccentColor = Color(0xFFB6F5E8);
  static const Color _kTextPrimaryColor = Color(0xFF2C3E50);
  static const Color _kTextSecondaryColor = Color(0xFF7F8C8D);
  static const Color _kErrorColor = Color(0xFFFF6B6B);

  // Text Styles
  static const TextStyle _kTitleStyle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: _kTextPrimaryColor,
    letterSpacing: 0.2,
  );

  static const TextStyle _kSubtitleStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: _kTextSecondaryColor,
    letterSpacing: 0.1,
  );

  static const TextStyle _kMenuItemStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: _kTextPrimaryColor,
    letterSpacing: 0.1,
  );

  static const TextStyle _kLogoutStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: _kErrorColor,
    letterSpacing: 0.1,
  );

  Future<void> _signOut(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('로그아웃', style: _kTitleStyle),
          content: Text('정말 로그아웃 하시겠습니까?', style: _kSubtitleStyle),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_kBorderRadius),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(
                foregroundColor: _kTextSecondaryColor,
                padding:
                    const EdgeInsets.symmetric(horizontal: _kDefaultPadding),
              ),
              child: Text('취소', style: _kMenuItemStyle),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: _kErrorColor,
                padding:
                    const EdgeInsets.symmetric(horizontal: _kDefaultPadding),
              ),
              child: Text('확인', style: _kLogoutStyle),
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
      width: _kMenuWidth.w,
      backgroundColor: _kPrimaryColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: MediaQuery.of(context).padding.top + 16.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: _kDefaultPadding.w),
            child: IconButton(
              icon: Icon(Icons.menu,
                  color: _kTextPrimaryColor, size: _kIconSize.sp),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          SizedBox(height: 24.h),
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
                    width: _kProfileImageSize.w,
                    height: _kProfileImageSize.h,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(_kBorderRadius.r),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Consumer<UserProvider>(
                      builder: (context, userProvider, child) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(_kBorderRadius.r),
                          child: userProvider.photoUrl != null
                              ? Image.network(
                                  userProvider.photoUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Icon(Icons.account_circle,
                                        size: _kIconSize * 1.5.sp,
                                        color: _kTextSecondaryColor);
                                  },
                                )
                              : Icon(Icons.account_circle,
                                  size: _kIconSize * 1.5.sp,
                                  color: _kTextSecondaryColor),
                        );
                      },
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Consumer<UserProvider>(
                    builder: (context, userProvider, child) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            userProvider.nickname,
                            style: _kTitleStyle,
                          ),
                          SizedBox(width: 4.w),
                          Icon(Icons.arrow_forward_ios,
                              size: _kSmallIconSize.sp,
                              color: _kTextSecondaryColor),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 32.h),
          _buildMenuItem(
            context,
            '랭킹',
            Icons.leaderboard_outlined,
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => RankingScreen()),
            ),
          ),
          _buildMenuItem(
            context,
            '기록',
            Icons.calendar_today_outlined,
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => CalendarScreen()),
            ),
          ),
          _buildMenuItem(
            context,
            '친구관리',
            Icons.people_outline,
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const FriendsScreen()),
            ),
          ),
          _buildMenuItem(
            context,
            '문의',
            Icons.help_outline,
            () {},
          ),
          _buildMenuItem(
            context,
            '환경 설정',
            Icons.settings_outlined,
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingScreen()),
            ),
          ),
          const Spacer(),
          Padding(
            padding: EdgeInsets.all(_kDefaultPadding.w),
            child: InkWell(
              onTap: () => _signOut(context),
              borderRadius: BorderRadius.circular(_kBorderRadius.r),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                child: Row(
                  children: [
                    Icon(Icons.logout,
                        color: _kErrorColor, size: _kIconSize.sp),
                    SizedBox(width: 12.w),
                    Text(
                      '로그아웃',
                      style: _kLogoutStyle,
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16.h),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
      BuildContext context, String title, IconData icon, VoidCallback onTap) {
    return Padding(
      padding:
          EdgeInsets.symmetric(horizontal: _kDefaultPadding.w, vertical: 4.h),
      child: InkWell(
        onTap: () {
          Navigator.pop(context);
          onTap();
        },
        borderRadius: BorderRadius.circular(_kBorderRadius.r),
        child: Container(
          height: _kMenuItemHeight.h,
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Row(
            children: [
              Icon(icon, size: _kIconSize.sp, color: _kTextPrimaryColor),
              SizedBox(width: 12.w),
              Text(
                title,
                style: _kMenuItemStyle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}