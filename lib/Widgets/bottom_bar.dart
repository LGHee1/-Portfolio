import 'package:flutter/material.dart';
import '../Post/post_list.dart';
import '../home_screen.dart';
import '../Running/workout_screen.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class BottomBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onTabSelected;

  const BottomBar({
    Key? key,
    required this.selectedIndex,
    required this.onTabSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // 일반적인 뒤로가기 동작을 허용
        return true;
      },
      child: Container(
        height: 80.h,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            BottomAppBar(
              shape: const CircularNotchedRectangle(),
              notchMargin: 8.h,
              child: Container(
                height: 60.h,
                padding: EdgeInsets.symmetric(horizontal: 32.w),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.directions_run,
                        size: 24.sp,
                        color: selectedIndex == 0 ? Colors.amber : Colors.black,
                      ),
                      onPressed: () {
                        onTabSelected(0);
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const WorkoutScreen()),
                        );
                      },
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.route,
                        size: 24.sp,
                        color: selectedIndex == 2 ? Colors.amber : Colors.black,
                      ),
                      onPressed: () {
                        onTabSelected(2);
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const PostListPage()),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 30.h,
              child: Container(
                height: 64.h,
                width: 64.w,
                child: FloatingActionButton(
                  backgroundColor: Colors.amber.shade100,
                  elevation: 4,
                  onPressed: () {
                    onTabSelected(1);
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const ScreenHome()),
                      (route) => false,
                    );
                  },
                  child: Icon(
                    Icons.home,
                    size: 28.sp,
                    color: selectedIndex == 1 ? Colors.black : Colors.grey,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}