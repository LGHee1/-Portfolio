import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class SettingScreen extends StatelessWidget {
  const SettingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFD8F9FF),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black, size: 24.sp),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          '환경 설정',
          style: TextStyle(color: Colors.black, fontSize: 18.sp),
        ),
      ),
      body: ListView(
        children: [
          _buildSettingItem(
            context,
            '알림 설정',
            Icons.notifications_outlined,
            () {
              // 알림 설정 화면으로 이동
            },
          ),
          _buildSettingItem(
            context,
            '개인정보 처리방침',
            Icons.privacy_tip_outlined,
            () {
              // 개인정보 처리방침 화면으로 이동
            },
          ),
          _buildSettingItem(
            context,
            '이용약관',
            Icons.description_outlined,
            () {
              // 이용약관 화면으로 이동
            },
          ),
          _buildSettingItem(
            context,
            '버전 정보',
            Icons.info_outline,
            () {
              // 버전 정보 화면으로 이동
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem(
    BuildContext context,
    String title,
    IconData icon,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Colors.grey.withOpacity(0.2),
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 24.sp, color: Colors.black87),
            SizedBox(width: 16.w),
            Text(
              title,
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.arrow_forward_ios,
              size: 16.sp,
              color: Colors.grey,
            ),
          ],
        ),
      ),
    );
  }
} 