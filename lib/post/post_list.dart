import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'post_view.dart';
import 'tag_list.dart';
import '../models/tag.dart';
import '../Widgets/bottom_bar.dart';
import '../home_screen.dart';
import '../Running/workout_screen.dart';

class PostListPage extends StatefulWidget {
  const PostListPage({super.key});

  @override
  State<PostListPage> createState() => _PostListPageState();
}

class _PostListPageState extends State<PostListPage> {
  List<Tag> selectedTags = [];
  int _selectedIndex = 2;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFCBF6FF),
      appBar: AppBar(
        automaticallyImplyLeading: true,
        backgroundColor: const Color(0xFFCBF6FF),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, size: 24.sp),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const ScreenHome()),
            );
          },
        ),
      ),
      body: Column(
        children: [
          Container(
            height: 300.h,
            color: Colors.grey[300],
            child: Center(
              child: Text('Google Maps will be displayed here', style: TextStyle(fontSize: 16.sp)),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              height: 50.h,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(25.r),
                border: Border.all(color: Colors.grey[400]!),
              ),
              child: Row(
                children: [
                  if (selectedTags.isEmpty)
                    Expanded(
                      child: Text(
                        '원하는 태그를 추가하세요',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 14.sp,
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: selectedTags.map((tag) {
                            return Padding(
                              padding: EdgeInsets.only(right: 8.w),
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE7EFA2),
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      tag.name,
                                      style: TextStyle(fontSize: 14.sp),
                                    ),
                                    SizedBox(width: 4.w),
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          selectedTags.remove(tag);
                                        });
                                      },
                                      child: Icon(Icons.close, size: 16.sp),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TagListPage(
                            onTagsSelected: (tags) {
                              setState(() {
                                selectedTags = tags;
                              });
                            },
                          ),
                        ),
                      );
                    },
                    child: Padding(
                      padding: EdgeInsets.only(left: 8.w),
                      child: Icon(
                        Icons.search,
                        color: Colors.grey,
                        size: 24.sp,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: 10,
              padding: EdgeInsets.symmetric(horizontal: 18.w),
              itemBuilder: (context, index) {
                return Column(
                  children: [
                    Divider(
                      thickness: 1,
                      color: const Color(0xFFACE3FF),
                      height: 1.h,
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.symmetric(vertical: 8.h),
                      title: Text(
                        '게시글 ${index + 1}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20.sp,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 4.h),
                          Row(
                            children: [
                              Icon(Icons.route, size: 16.sp),
                              SizedBox(width: 4.w),
                              Text('${((index + 1) * 2.0).toStringAsFixed(1)}km', style: TextStyle(fontSize: 14.sp)),
                              SizedBox(width: 16.w),
                              Icon(Icons.favorite, size: 16.sp, color: Colors.red),
                              SizedBox(width: 4.w),
                              Text(
                                '${(index + 1) * 10}',
                                style: TextStyle(fontSize: 14.sp),
                              ),
                            ],
                          ),
                          SizedBox(height: 4.h),
                          Wrap(
                            spacing: 4.w,
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8.w,
                                  vertical: 2.h,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE7EFA2),
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                child: Text('태그길이에대응', style: TextStyle(fontSize: 14.sp)),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE7EFA2),
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                child: Text('태그2', style: TextStyle(fontSize: 14.sp)),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE7EFA2),
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                child: Text('태그3', style: TextStyle(fontSize: 14.sp)),
                              ),
                            ],
                          ),
                        ],
                      ),
                      trailing: Container(
                        width: 80.w,
                        height: 80.h,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Center(
                          child: Icon(Icons.image, color: Colors.grey, size: 24.sp),
                        ),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const PostViewPage(),
                          ),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomBar(
        selectedIndex: _selectedIndex,
        onTabSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
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
              MaterialPageRoute(builder: (context) => const PostListPage()),
            );
          }
        },
      ),
    );
  }
} 