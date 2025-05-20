import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'post_list.dart';
import '../models/tag.dart';
import '../Widgets/bottom_bar.dart';

class PostViewPage extends StatefulWidget {
  const PostViewPage({super.key});

  @override
  State<PostViewPage> createState() => _PostViewPageState();
}

class _PostViewPageState extends State<PostViewPage> {
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
              MaterialPageRoute(builder: (context) => const PostListPage()),
            );
          },
        ),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 8.w),
            child: ElevatedButton(
              onPressed: () {
                // TODO: 적용하기 기능 구현
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF9800),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
              child: Text(
                '적용하기',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 지도 영역
            Container(
              height: 300.h,
              color: Colors.grey[300],
              child: Center(
                child: Text(
                  'Google Maps will be displayed here',
                  style: TextStyle(fontSize: 16.sp),
                ),
              ),
            ),
            // 제목 및 작성자 정보
            Padding(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '게시글 제목',
                    style: TextStyle(
                      fontSize: 24.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16.r,
                        backgroundColor: Colors.grey,
                        child: Icon(Icons.person, size: 24.sp, color: Colors.white),
                      ),
                      SizedBox(width: 8.w),
                      Text('작성자닉네임', style: TextStyle(fontSize: 16.sp)),
                      SizedBox(width: 16.w),
                      Icon(Icons.favorite, size: 24.sp, color: Colors.red),
                      SizedBox(width: 4.w),
                      Text('10', style: TextStyle(fontSize: 15.sp)),
                    ],
                  ),
                ],
              ),
            ),
            // 태그 목록
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Wrap(
                spacing: 8.w,
                runSpacing: 8.h,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 3.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE7EFA2),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Text('태그1', style: TextStyle(fontSize: 16.sp)),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 3.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE7EFA2),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Text('태그2', style: TextStyle(fontSize: 16.sp)),
                  ),
                ],
              ),
            ),
            // 세부 설명
            Padding(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '세부 설명',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Text(
                      '여기에 게시글의 세부 설명이 들어갑니다. 코스의 특징이나 주의사항 등을 자세히 설명할 수 있습니다. 좀더 길게 써야할 경우를 확인하는중입니다 한 몇줄은 거 길게 가야하는데 그냥 한단어로 가보게습니다 ㅇㅇㅇㅇㅇㅇㅇㅇㅇㅇㅇㅇㅇㅇㅇㅇㅇㅇㅇㅇㅇㅇㅇㅇㅇㅇㅇㅇㅇㅇㅇㅇㅇ',
                      style: TextStyle(fontSize: 16.sp),
                    ),
                  ),
                ],
              ),
            ),
            // 이미지 목록
            Padding(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '등록된 이미지',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  SizedBox(
                    height: 125.h,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: 3,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: EdgeInsets.only(right: 8.w),
                          child: Container(
                            width: 125.w,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8.r),
                              child: Image.network(
                                'https://picsum.photos/200/200?random=$index',
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomBar(
        selectedIndex: _selectedIndex,
        onTabSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
    );
  }
}

class _FullScreenImageViewer extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  const _FullScreenImageViewer({required this.images, required this.initialIndex});

  @override
  State<_FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<_FullScreenImageViewer> {
  late PageController _controller;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _controller = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: widget.images.length,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              itemBuilder: (context, index) {
                return Center(
                  child: Image.network(
                    widget.images[index],
                    fit: BoxFit.contain,
                    width: 400.w,
                    height: 600.h,
                  ),
                );
              },
            ),
            Positioned(
              bottom: 40,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.images.length, (index) {
                  return Container(
                    margin: EdgeInsets.symmetric(horizontal: 4.w),
                    width: 8.w,
                    height: 8.h,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentIndex == index ? Colors.white : Colors.white38,
                    ),
                  );
                }),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: Icon(Icons.close, color: Colors.white, size: 30.sp),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 