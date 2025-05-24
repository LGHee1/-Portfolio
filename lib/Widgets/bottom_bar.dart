import 'package:flutter/material.dart';
import '../Post/post_list.dart';
import '../home_screen.dart';
import '../Running/workout_screen.dart';

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
        // 뒤로가기 시 홈 화면으로 이동하고 selectedIndex를 1로 설정
        onTabSelected(1);
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const ScreenHome()),
          (route) => false,
        );
        return false;
      },
      child: Container(
        height: 80,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            BottomAppBar(
              shape: const CircularNotchedRectangle(),
              notchMargin: 8.0,
              child: Container(
                height: 60,
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.directions_run,
                        color: selectedIndex == 0 ? Colors.amber : Colors.black,
                      ),
                      onPressed: () {
                        onTabSelected(0);
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => const WorkoutScreen()),
                        );
                      },
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.route,
                        color: selectedIndex == 2 ? Colors.amber : Colors.black,
                      ),
                      onPressed: () {
                        onTabSelected(2);
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => const PostListPage()),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 30,
              child: Container(
                height: 64,
                width: 64,
                child: FloatingActionButton(
                  backgroundColor: Colors.amber.shade100,
                  elevation: 4,
                  onPressed: () {
                    onTabSelected(1);
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => const ScreenHome()),
                      (route) => false,
                    );
                  },
                  child: Icon(
                    Icons.home,
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