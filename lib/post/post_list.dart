import 'package:flutter/material.dart';
import 'post_view.dart';
import 'tag_list.dart';
import '../models/tag.dart';

class PostListPage extends StatefulWidget {
  const PostListPage({super.key});

  @override
  State<PostListPage> createState() => _PostListPageState();
}

class _PostListPageState extends State<PostListPage> {
  List<Tag> selectedTags = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFCBF6FF),
      appBar: AppBar(
        automaticallyImplyLeading: true,
        backgroundColor: const Color(0xFFCBF6FF),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Column(
        children: [
          Container(
            height: 300,
            color: Colors.grey[300],
            child: const Center(
              child: Text('Google Maps will be displayed here'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              height: 50,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: Colors.grey[400]!),
              ),
              child: Row(
                children: [
                  if (selectedTags.isEmpty)
                    const Expanded(
                      child: Text(
                        '원하는 태그를 추가하세요',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  else
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: selectedTags.map((tag) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE7EFA2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(tag.name, style: const TextStyle(fontSize: 14)),
                                    const SizedBox(width: 4),
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          selectedTags.remove(tag);
                                        });
                                      },
                                      child: const Icon(Icons.close, size: 16),
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
                    child: const Padding(
                      padding: EdgeInsets.only(left: 8.0),
                      child: Icon(Icons.search, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: 10, // 임시 데이터
              padding: const EdgeInsets.symmetric(horizontal: 18.0),
              itemBuilder: (context, index) {
                return Column(
                  children: [
                    const Divider(
                      thickness: 1,
                      color: Color(0xFFACE3FF),
                      height: 1,
                    ),
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 8.0),
                      title: Text(
                        '게시글 ${index + 1}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.route, size: 16),
                              const SizedBox(width: 4),
                              Text('${((index + 1) * 2.0).toStringAsFixed(1)}km'),
                              const SizedBox(width: 16),
                              const Icon(Icons.favorite, size: 16, color: Colors.red),
                              const SizedBox(width: 4),
                              Text('${(index + 1) * 10}'),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 4,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE7EFA2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text('태그길이에대응', style: TextStyle(fontSize: 14)),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE7EFA2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text('태그2', style: TextStyle(fontSize: 14)),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE7EFA2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text('태그3', style: TextStyle(fontSize: 14)),
                              ),
                            ],
                          ),
                        ],
                      ),
                      trailing: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Icon(Icons.image, color: Colors.grey),
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
    );
  }
} 