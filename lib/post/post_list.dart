import 'package:flutter/material.dart';
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
    // 화면 크기 정보 가져오기
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;
    
    // 동적 크기 계산
    final mapHeight = screenHeight * 0.35; // 화면 높이의 35%
    final searchBarHeight = screenHeight * 0.06; // 화면 높이의 6%
    final padding = screenWidth * 0.04; // 화면 너비의 4%
    final titleFontSize = screenWidth * 0.05; // 화면 너비의 5%
    final subtitleFontSize = screenWidth * 0.035; // 화면 너비의 3.5%
    final tagFontSize = screenWidth * 0.035; // 화면 너비의 3.5%
    final thumbnailSize = screenWidth * 0.2; // 화면 너비의 20%

    return Scaffold(
      backgroundColor: const Color(0xFFCBF6FF),
      appBar: AppBar(
        automaticallyImplyLeading: true,
        backgroundColor: const Color(0xFFCBF6FF),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, size: screenWidth * 0.06),
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
            height: mapHeight,
            color: Colors.grey[300],
            child: const Center(
              child: Text('Google Maps will be displayed here'),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(padding),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: padding),
              height: searchBarHeight,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(searchBarHeight / 2),
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
                          fontSize: subtitleFontSize,
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
                              padding: EdgeInsets.only(right: screenWidth * 0.02),
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: screenWidth * 0.02,
                                  vertical: screenHeight * 0.005,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE7EFA2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      tag.name,
                                      style: TextStyle(fontSize: tagFontSize),
                                    ),
                                    SizedBox(width: screenWidth * 0.01),
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          selectedTags.remove(tag);
                                        });
                                      },
                                      child: Icon(
                                        Icons.close,
                                        size: tagFontSize,
                                      ),
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
                      padding: EdgeInsets.only(left: screenWidth * 0.02),
                      child: Icon(
                        Icons.search,
                        color: Colors.grey,
                        size: subtitleFontSize * 1.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: 10, // 임시 데이터
              padding: EdgeInsets.symmetric(horizontal: padding),
              itemBuilder: (context, index) {
                return Column(
                  children: [
                    const Divider(
                      thickness: 1,
                      color: Color(0xFFACE3FF),
                      height: 1,
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.symmetric(vertical: screenHeight * 0.01),
                      title: Text(
                        '게시글 ${index + 1}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: titleFontSize,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: screenHeight * 0.005),
                          Row(
                            children: [
                              Icon(Icons.route, size: subtitleFontSize),
                              SizedBox(width: screenWidth * 0.01),
                              Text(
                                '${((index + 1) * 2.0).toStringAsFixed(1)}km',
                                style: TextStyle(fontSize: subtitleFontSize),
                              ),
                              SizedBox(width: screenWidth * 0.04),
                              Icon(Icons.favorite, size: subtitleFontSize, color: Colors.red),
                              SizedBox(width: screenWidth * 0.01),
                              Text(
                                '${(index + 1) * 10}',
                                style: TextStyle(fontSize: subtitleFontSize),
                              ),
                            ],
                          ),
                          SizedBox(height: screenHeight * 0.005),
                          Wrap(
                            spacing: screenWidth * 0.01,
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: screenWidth * 0.02,
                                  vertical: screenHeight * 0.005,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE7EFA2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '태그길이에대응',
                                  style: TextStyle(fontSize: tagFontSize),
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: screenWidth * 0.02,
                                  vertical: screenHeight * 0.005,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE7EFA2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '태그2',
                                  style: TextStyle(fontSize: tagFontSize),
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: screenWidth * 0.02,
                                  vertical: screenHeight * 0.005,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE7EFA2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '태그3',
                                  style: TextStyle(fontSize: tagFontSize),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      trailing: Container(
                        width: thumbnailSize,
                        height: thumbnailSize,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.image,
                          color: Colors.grey,
                          size: thumbnailSize * 0.4,
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