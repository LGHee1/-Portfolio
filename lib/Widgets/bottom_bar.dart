import 'package:flutter/material.dart';
import '../Post/post_list.dart';
import '../home_screen.dart';
import '../workout_screen.dart';

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
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        BottomAppBar(
          shape: const CircularNotchedRectangle(),
          notchMargin: 8.0,
          child: Container(
            padding: EdgeInsets.only(
              left: 32,
              right: 32,
              bottom: bottomPadding,
              top: 8,
            ),
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
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const WorkoutScreen()),
                    );
                  },
                ),
                IconButton(
                  icon: Icon(
                    Icons.star_border,
                    color: selectedIndex == 2 ? Colors.amber : Colors.black,
                  ),
                  onPressed: () {
                    onTabSelected(2);
                    Navigator.push(
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
          bottom: bottomPadding + 8,
          child: FloatingActionButton(
            backgroundColor: Colors.amber.shade100,
            onPressed: () {
              onTabSelected(1);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const ScreenHome()),
              );
            },
            child: Icon(
              Icons.home,
              color: selectedIndex == 1 ? Colors.black : Colors.grey,
            ),
          ),
        ),
      ],
    );
  }
} 