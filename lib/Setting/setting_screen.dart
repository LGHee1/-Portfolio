import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../Auth/login_screen.dart';
import '../Widgets/bottom_bar.dart';
import '../home_screen.dart';
import '../post/post_list.dart';
import '../Running/workout_screen.dart';
import '../profile/profile_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// 공통 스타일 정의
class AppStyles {
  // 텍스트 스타일
  static TextStyle titleStyle = TextStyle(
    fontSize: 20.sp,
    fontWeight: FontWeight.bold,
    color: Colors.black87,
    letterSpacing: 0.5,
  );

  static TextStyle subtitleStyle = TextStyle(
    fontSize: 16.sp,
    fontWeight: FontWeight.w600,
    color: Colors.black87,
    letterSpacing: 0.3,
  );

  static TextStyle bodyStyle = TextStyle(
    fontSize: 14.sp,
    color: Colors.black87,
    letterSpacing: 0.2,
  );

  static TextStyle captionStyle = TextStyle(
    fontSize: 12.sp,
    color: Colors.black54,
    letterSpacing: 0.1,
  );

  // 버튼 스타일
  static ButtonStyle primaryButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: const Color(0xFFB6F5E8),
    foregroundColor: Colors.black87,
    elevation: 2,
    shadowColor: Colors.black26,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12.r),
    ),
    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
    textStyle: TextStyle(
      fontSize: 14.sp,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.3,
    ),
  );

  static ButtonStyle dangerButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: Colors.red.shade50,
    foregroundColor: Colors.red,
    elevation: 2,
    shadowColor: Colors.black26,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12.r),
    ),
    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
    textStyle: TextStyle(
      fontSize: 14.sp,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.3,
    ),
  );

  // 카드 스타일
  static BoxDecoration cardDecoration = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16.r),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.05),
        blurRadius: 10,
        offset: const Offset(0, 2),
      ),
    ],
  );
}

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
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '정말로 탈퇴하시겠습니까?',
                style: TextStyle(fontSize: 16.sp),
              ),
              const SizedBox(height: 8),
              Text(
                '탈퇴 시 모든 데이터가 삭제되며 복구할 수 없습니다.',
                style: TextStyle(fontSize: 14.sp, color: Colors.red),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('취소', style: TextStyle(fontSize: 16.sp)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('탈퇴', style: TextStyle(fontSize: 16.sp, color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (shouldDelete == true) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final uid = user.uid;
          final firestore = FirebaseFirestore.instance;

          // ✅ 1. 다른 사람의 Friends_Data에서 나를 친구로 등록한 문서 제거
          final userDocs = await firestore.collection('users').get();
          for (final doc in userDocs.docs) {
            final otherUid = doc.id;
            if (otherUid == uid) continue;

            final friendRef = firestore
                .collection('users')
                .doc(otherUid)
                .collection('Friends_Data')
                .doc(uid);

            final friendSnap = await friendRef.get();
            if (friendSnap.exists) {
              await friendRef.delete();
            }
          }

          // ✅ 2. 내 하위 컬렉션 모두 삭제
          final subcollections = [
            'Friends_Data',
            'Sent_Requests',
            'Received_Requests',
            'Running_Data',
            'MyProfile',
            'Post_Data',
            'LikedPosts',
          ];

          for (final collection in subcollections) {
            final snapshot = await firestore
                .collection('users')
                .doc(uid)
                .collection(collection)
                .get();

            for (final doc in snapshot.docs) {
              await doc.reference.delete();
            }
          }

          // ✅ 3. 내 users 문서 삭제
          final batch = firestore.batch();
          batch.delete(firestore.collection('users').doc(uid));
          await batch.commit();

          // ✅ 4. Firebase 인증 계정 삭제
          await user.delete();

          if (context.mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
            );
          }
        }
      } catch (e) {
        print('회원 탈퇴 중 오류 발생: $e');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('회원 탈퇴 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요.')),
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
          style: AppStyles.titleStyle,
        ),
        backgroundColor: const Color(0xFFE5FBFF),
        elevation: 0,
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFFE5FBFF).withOpacity(0.5),
              Colors.white,
            ],
          ),
        ),
        child: ListView(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
          children: [
            _buildSection(
              title: '알림 설정',
              children: [
                _buildSwitchTile(
                  '알림 수신',
                  _isNotificationEnabled,
                  (value) {
                    setState(() {
                      _isNotificationEnabled = value;
                    });
                  },
                ),
              ],
            ),
            SizedBox(height: 16.h),
            _buildSection(
              title: '계정 관리',
              children: [
                _buildNavigationTile(
                  '차단한 사용자 목록',
                  Icons.block,
                  () {
                    // TODO: 차단한 사용자 목록 화면으로 이동
                  },
                ),
                _buildNavigationTile(
                  '문의하기',
                  Icons.help_outline,
                  () {
                    // TODO: 문의하기 화면으로 이동
                  },
                ),
              ],
            ),
            SizedBox(height: 16.h),
            _buildSection(
              title: '앱 정보',
              children: [
                _buildInfoTile('버전 정보', '1.0.0'),
                _buildNavigationTile(
                  '이용 약관',
                  Icons.description_outlined,
                  () {
                    // TODO: 이용 약관 화면으로 이동
                  },
                ),
                _buildNavigationTile(
                  '위치 기반 서비스 이용약관',
                  Icons.location_on_outlined,
                  () {
                    // TODO: 위치 기반 서비스 이용약관 화면으로 이동
                  },
                ),
                _buildNavigationTile(
                  '개인 정보 처리 방침',
                  Icons.privacy_tip_outlined,
                  () {
                    // TODO: 개인 정보 처리 방침 화면으로 이동
                  },
                ),
              ],
            ),
            SizedBox(height: 24.h),
            _buildDeleteAccountTile(),
          ],
        ),
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

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 8.w, bottom: 8.h),
          child: Text(title, style: AppStyles.subtitleStyle),
        ),
        Container(
          decoration: AppStyles.cardDecoration,
          child: Column(
            children: children.map((child) {
              return Column(
                children: [
                  child,
                  if (child != children.last)
                    Divider(height: 1, indent: 16.w, endIndent: 16.w),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchTile(String title, bool value, Function(bool) onChanged) {
    return SwitchListTile(
      title: Text(title, style: AppStyles.bodyStyle),
      value: value,
      onChanged: onChanged,
      activeColor: const Color(0xFFB6F5E8),
      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
    );
  }

  Widget _buildNavigationTile(String title, IconData icon, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, size: 20.sp, color: Colors.black87),
      title: Text(title, style: AppStyles.bodyStyle),
      trailing:
          Icon(Icons.arrow_forward_ios, size: 16.sp, color: Colors.black54),
      onTap: onTap,
      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
    );
  }

  Widget _buildInfoTile(String title, String subtitle) {
    return ListTile(
      title: Text(title, style: AppStyles.bodyStyle),
      trailing: Text(
        subtitle,
        style: AppStyles.captionStyle,
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
    );
  }

  Widget _buildDeleteAccountTile() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      child: ElevatedButton(
        onPressed: () => _deleteAccount(context),
        style: AppStyles.dangerButtonStyle,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_outline, size: 18.sp),
            SizedBox(width: 8.w),
            Text('회원 탈퇴'),
          ],
        ),
      ),
    );
  }
}