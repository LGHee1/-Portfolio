import 'package:flutter/material.dart';
import '../models/tag.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:firebase_database/firebase_database.dart'; // Import Firebase Realtime Database

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

  // 지역 선택 관련 상태
  RegionTag? selectedLevel1;  // 시/도
  RegionTag? selectedLevel2;  // 시/군/구
  RegionTag? selectedLevel3;  // 읍/면/동
  List<RegionTag>? level1Regions;  // 시/도 목록
  List<RegionTag>? level2Regions;  // 시/군/구 목록
  List<RegionTag>? level3Regions;  // 읍/면/동 목록

  @override
  void initState() {
    super.initState();
    selectedTags = List.from(widget.initialSelectedTags);
    print('TagListPage 초기화');
    _loadRegionData();
  }

  Future<void> _loadRegionData() async {
    try {
      print('Firebase Realtime Database에서 지역 데이터 로드 시작');
      // Firebase Realtime Database 인스턴스 가져오기
      final databaseRef = FirebaseDatabase.instance.ref('태그'); // 이미지에서 확인한 '태그' 노드 사용

      final snapshot = await databaseRef.get();

      if (snapshot.exists) {
        print('Firebase에서 데이터 로드 완료');
        final Map<dynamic, dynamic>? data = snapshot.value as Map<dynamic, dynamic>?;
        List<RegionTag> allRegions = [];

        if (data != null) {
          // Firebase에서 가져온 데이터를 RegionTag 객체 리스트로 변환
          data.forEach((key, value) {
            if (value is Map<dynamic, dynamic>) {
              try {
                RegionTag region = _parseRegionTagFromFirebase(key.toString(), Map<String, dynamic>.from(value));
                allRegions.add(region);
              } catch (e) {
                print('지역 데이터 파싱 중 오류 발생: $e');
              }
            }
          });
        }

        setState(() {
          level1Regions = allRegions;
          print('전체 시/도 목록 생성 완료: ${level1Regions!.length}개');
        });
      } else {
        print('Firebase에 \'태그\' 데이터가 없습니다.');
        setState(() {
          level1Regions = [];
        });
      }
    } catch (e, stackTrace) {
      print('Firebase 지역 데이터 로드 실패: $e');
      print('스택 트레이스: $stackTrace');
      setState(() {
        level1Regions = [];
      });
    }
  }

  // Helper function to parse Firebase data into RegionTag
  RegionTag _parseRegionTagFromFirebase(String name, Map<String, dynamic> data) {
    List<RegionTag>? subRegions;

    // 'code'와 'name' 필드는 현재 데이터 맵에 직접 있다고 가정
    String code = data['code']?.toString() ?? '';
    // level은 코드 길이에 따라 추정
    int level = code.length == 2 ? 1 : code.length == 5 ? 2 : 3;

    // 'children' 노드가 리스트 형태로 하위 지역들을 담고 있는지 확인
    if (data['children'] != null && data['children'] is List) {
      subRegions = (data['children'] as List)
          .map((item) {
            // 리스트의 각 항목이 Map 형태인지 확인하고 재귀 호출
            if (item is Map<dynamic, dynamic>) {
               // 하위 지역의 이름은 Map 내의 'name' 필드에서 가져옵니다.
               String subName = item['name']?.toString() ?? '알 수 없음';
               return _parseRegionTagFromFirebase(subName, Map<String, dynamic>.from(item));
            }
            return null; // Map이 아니면 null 반환 (필터링될 것임)
          })
          .whereType<RegionTag>() // null이 아닌 RegionTag 객체만 필터링
          .toList();
      // 만약 subRegions 리스트가 비어있다면 null로 설정
      if (subRegions.isEmpty) {
          subRegions = null;
      }
    }

    return RegionTag(
      name: name,
      level: level,
      code: code,
      subRegions: subRegions,
    );
  }

  void _selectLevel1(RegionTag region) {
    setState(() {
      selectedLevel1 = region;
      selectedLevel2 = null;
      selectedLevel3 = null;
      level2Regions = region.subRegions;
      level3Regions = null;
      // 1단계 지역이 바뀌면 지역 태그 초기화
      selectedTags.removeWhere((tag) => tag.category == TagCategory.location);
    });
  }

  void _selectLevel2(RegionTag region) {
    setState(() {
      if (selectedLevel1?.name == '세종특별자치시') {
        // 여러 개 동을 동시에 선택/해제(토글)
        if (selectedTags.contains(region)) {
          selectedTags.remove(region);
        } else {
          selectedTags.add(region);
        }
        // 세종시 2단계에서는 selectedLevel2, level3Regions 사용하지 않음
        selectedLevel2 = null;
        selectedLevel3 = null;
        level3Regions = null;
      } else {
        selectedLevel2 = region;
        selectedLevel3 = null;
        level3Regions = region.subRegions;
      }
    });
  }

  void _selectLevel3(RegionTag region) {
    setState(() {
      // 여러 개 읍/면/동을 동시에 선택/해제(토글)
      if (selectedTags.contains(region)) {
        selectedTags.remove(region);
      } else {
        selectedTags.add(region);
      }
      // 3단계에서는 selectedLevel3 사용하지 않음
      selectedLevel3 = null;
    });
  }

  Widget _buildRegionSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 시/도 선택
        const Padding(
          padding: EdgeInsets.all(8.0),
        ),
        Container(
          height: 50,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: level1Regions?.length ?? 0,
            itemBuilder: (context, index) {
              if (level1Regions == null) return Container();
              final region = level1Regions![index];
              final isSelected = selectedLevel1?.code == region.code;
              return GestureDetector(
                onTap: () => _selectLevel1(region),
                child: Container(
                  width: 100,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFE7EFA2) : Colors.white,
                    border: Border.all(
                      color: isSelected ? const Color(0xFFE7EFA2) : Colors.grey,
                    ),
                    borderRadius: BorderRadius.circular(8),
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

        // 시/군/구 선택
        if (level2Regions != null && level2Regions!.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.all(8.0),
          ),
          Container(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: level2Regions!.length,
              itemBuilder: (context, index) {
                final region = level2Regions![index];
                final isSelected = (selectedLevel1?.name == '세종특별자치시')
                    ? selectedTags.contains(region)
                    : selectedLevel2?.code == region.code;
                return GestureDetector(
                  onTap: () => _selectLevel2(region),
                  child: Container(
                    width: 100,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFE7EFA2) : Colors.white,
                      border: Border.all(
                        color: isSelected ? const Color(0xFFE7EFA2) : Colors.grey,
                      ),
                      borderRadius: BorderRadius.circular(8),
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
        ],

        // 읍/면/동 선택
        if (level3Regions != null && level3Regions!.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.all(8.0),
          ),
          Container(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: level3Regions!.length,
              itemBuilder: (context, index) {
                final region = level3Regions![index];
                final isSelected = selectedTags.contains(region);
                return GestureDetector(
                  onTap: () => _selectLevel3(region),
                  child: Container(
                    width: 100,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFE7EFA2) : Colors.white,
                      border: Border.all(
                        color: isSelected ? const Color(0xFFE7EFA2) : Colors.grey,
                      ),
                      borderRadius: BorderRadius.circular(8),
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
        ],
      ],
    );
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
                widget.onTagsSelected(selectedTags);
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
          Expanded(
            child: ListView.builder(
              itemCount: TagCategory.values.length,
              itemBuilder: (context, index) {
                final category = TagCategory.values[index];
                final categoryTags = sampleTags
                    .where((tag) => tag.category == category)
                    .toList();

                if (category == TagCategory.location) {
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildRegionSelector(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // 지역 외 카테고리
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