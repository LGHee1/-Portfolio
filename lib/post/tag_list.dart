import 'package:flutter/material.dart';
import '../models/tag.dart';

class TagListPage extends StatefulWidget {
  final Function(List<Tag>) onTagsSelected;
  final List<Tag> initialSelectedTags;
  
  const TagListPage({
    super.key,
    required this.onTagsSelected,
    this.initialSelectedTags = const [],
  });

  @override
  State<TagListPage> createState() => _TagListPageState();
}

class _TagListPageState extends State<TagListPage> {
  late List<Tag> selectedTags;
  final Map<TagCategory, bool> categoryExpanded = {
    TagCategory.location: true,
    TagCategory.exercise: true,
    TagCategory.surrounding: true,
    TagCategory.etc: true,
  };
  String? selectedRegion;  // 선택된 지역을 저장

  @override
  void initState() {
    super.initState();
    selectedTags = List.from(widget.initialSelectedTags);
  }

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
            Navigator.pop(context, selectedTags);
          },
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context, selectedTags);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF9800),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                '추가하기',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          const Divider(
            thickness: 1,
            color: Colors.grey,
            height: 1,
          ),
          // 선택된 태그들을 보여주는 부분
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            decoration: BoxDecoration(
              color: const Color(0xFFACE3FF),
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey,
                  width: 1.0,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
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
                ),
              ],
            ),
          ),
          // 카테고리별 태그 목록
          Expanded(
            child: ListView.builder(
              itemCount: TagCategory.values.length,
              itemBuilder: (context, index) {
                final category = TagCategory.values[index];
                final categoryTags = sampleTags
                    .where((tag) => tag.category == category)
                    .toList();

                if (category == TagCategory.location) {
                  // 지역 카테고리인 경우 가로 스크롤로 표시
                  final regions = categoryTags
                      .where((tag) => tag.parentRegion == null)
                      .toList();
                  
                  return Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFFACE3FF),
                    ),
                    child: ExpansionTile(
                      initiallyExpanded: categoryExpanded[category] ?? true,
                      onExpansionChanged: (expanded) {
                        setState(() {
                          categoryExpanded[category] = expanded;
                        });
                      },
                      title: Text(
                        _getCategoryName(category),
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              height: 50,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: regions.length,
                                itemBuilder: (context, index) {
                                  final region = regions[index];
                                  final isSelected = selectedRegion == region.name;
                                  return GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        selectedRegion = isSelected ? null : region.name;
                                      });
                                    },
                                    child: Container(
                                      width: 80,
                                      decoration: BoxDecoration(
                                        color: isSelected ? const Color(0xFFE7EFA2) : Colors.white,
                                        border: Border.all(
                                          color: isSelected ? const Color(0xFFE7EFA2) : Colors.grey,
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          region.name,
                                          style: TextStyle(
                                            color: isSelected ? Colors.black : Colors.grey,
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            if (selectedRegion != null) ...[
                              Container(
                                color: const Color(0xFFCBF6FF),
                                padding: const EdgeInsets.fromLTRB(16.0, 16.0, 0, 16.0),
                                width: double.infinity,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Wrap(
                                      spacing: 8.0,
                                      runSpacing: 8.0,
                                      children: categoryTags
                                          .where((tag) => tag.parentRegion == selectedRegion)
                                          .map((tag) {
                                        final isSelected = selectedTags.contains(tag);
                                        return GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              if (isSelected) {
                                                selectedTags.remove(tag);
                                              } else {
                                                selectedTags.add(tag);
                                              }
                                            });
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: isSelected ? const Color(0xFFE7EFA2) : const Color(0xFFE7EFA2),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(tag.name, style: const TextStyle(fontSize: 14)),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  );
                }

                // 지역외 카테고리
                return Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFACE3FF),
                  ),
                  child: ExpansionTile(
                    initiallyExpanded: categoryExpanded[category] ?? true,
                    onExpansionChanged: (expanded) {
                      setState(() {
                        categoryExpanded[category] = expanded;
                      });
                    },
                    title: Text(
                      _getCategoryName(category),
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    children: [
                      Container(
                        color: const Color(0xFFCBF6FF),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Wrap(
                              alignment: WrapAlignment.start,
                              crossAxisAlignment: WrapCrossAlignment.start,
                              spacing: 8.0,
                              runSpacing: 8.0,
                              children: categoryTags.map((tag) {
                                final isSelected = selectedTags.contains(tag);
                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      if (isSelected) {
                                        selectedTags.remove(tag);
                                      } else {
                                        selectedTags.add(tag);
                                      }
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isSelected ? const Color(0xFFE7EFA2) : const Color(0xFFE7EFA2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(tag.name, style: const TextStyle(fontSize: 14)),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _getCategoryName(TagCategory category) {
    switch (category) {
      case TagCategory.location:
        return '지역';
      case TagCategory.exercise:
        return '운동환경';
      case TagCategory.surrounding:
        return '주변환경';
      case TagCategory.etc:
        return '기타';
    }
  }
} 