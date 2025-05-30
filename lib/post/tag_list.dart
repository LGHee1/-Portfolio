import 'package:flutter/material.dart';
import '../models/tag.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

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
  // UI Constants
  static const double _kDefaultPadding = 16.0;
  static const double _kDefaultBorderRadius = 12.0;
  static const double _kButtonHeight = 40.0;
  static const double _kTagHeight = 32.0;
  static const double _kCardElevation = 2.0;

  // Text Styles
  static const TextStyle _kTitleStyle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: Colors.black87,
    letterSpacing: 0.2,
  );

  static const TextStyle _kSubtitleStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: Colors.black54,
    letterSpacing: 0.1,
  );

  static const TextStyle _kTagStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: Colors.black87,
    letterSpacing: 0.1,
  );

  late List<Tag> selectedTags;
  int _selectedCategoryIndex = 0;
  final Map<TagCategory, bool> categoryExpanded = {
    TagCategory.location: true,
    TagCategory.exercise: true,
    TagCategory.surrounding: true,
    TagCategory.etc: true,
  };

  // 지역 선택 관련 상태
  RegionTag? selectedLevel1; // 시/도
  RegionTag? selectedLevel2; // 시/군/구
  RegionTag? selectedLevel3; // 읍/면/동
  List<RegionTag>? level1Regions; // 시/도 목록
  List<RegionTag>? level2Regions; // 시/군/구 목록
  List<RegionTag>? level3Regions; // 읍/면/동 목록

  @override
  void initState() {
    super.initState();
    selectedTags = List.from(widget.initialSelectedTags);
    print('TagListPage 초기화');
    _loadRegionData();
  }

  Future<void> _loadRegionData() async {
    try {
      print('지역 데이터 로드 시작');
      List<RegionTag> allRegions = [];

      // 17개 시도 파일 목록
      final regionFiles = [
        '서울특별시.json',
        '부산광역시.json',
        '대구광역시.json',
        '인천광역시.json',
        '광주광역시.json',
        '대전광역시.json',
        '울산광역시.json',
        '세종특별자치시.json',
        '경기도.json',
        '강원특별자치도.json',
        '충청북도.json',
        '충청남도.json',
        '전북특별자치도.json',
        '전라남도.json',
        '경상북도.json',
        '경상남도.json',
        '제주특별자치도.json',
      ];

      // 각 시도 파일에서 데이터 로드
      for (final file in regionFiles) {
        try {
          final String jsonString =
              await rootBundle.loadString('assets/data/$file');
          final Map<String, dynamic> jsonData = json.decode(jsonString);
          final RegionTag region = RegionTag.fromJson(jsonData);
          allRegions.add(region);
          print('$file 로드 완료: ${region.name}');
        } catch (e) {
          print('$file 로드 실패: $e');
        }
      }

      setState(() {
        level1Regions = allRegions;
        print('전체 시/도 목록 생성 완료: ${level1Regions!.length}개');
      });
    } catch (e, stackTrace) {
      print('지역 데이터 로드 실패: $e');
      print('스택 트레이스: $stackTrace');
      setState(() {
        level1Regions = [];
      });
    }
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

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.height < 700;

    return Scaffold(
      backgroundColor: const Color(0xFFE5FBFF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFE5FBFF),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87, size: 24),
          onPressed: () => Navigator.pop(context, selectedTags),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        title: Text(
          '태그 선택',
          style: _kTitleStyle,
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: _kDefaultPadding),
            child: ElevatedButton(
              onPressed: () {
                widget.onTagsSelected(selectedTags);
                Navigator.pop(context, selectedTags);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB6F5E8),
                foregroundColor: Colors.black87,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                    horizontal: _kDefaultPadding, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(_kDefaultBorderRadius),
                ),
              ),
              child: Text(
                '추가하기',
                style: _kSubtitleStyle.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
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
            height: isSmallScreen ? 50 : 60,
            padding: const EdgeInsets.symmetric(
                horizontal: _kDefaultPadding, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
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
                              height: _kTagHeight,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE7EFA2),
                                borderRadius: BorderRadius.circular(
                                    _kDefaultBorderRadius),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 2,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    tag.name,
                                    style: _kTagStyle,
                                  ),
                                  const SizedBox(width: 4),
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        selectedTags.remove(tag);
                                      });
                                    },
                                    child: const Icon(
                                      Icons.close,
                                      size: 16,
                                      color: Colors.black54,
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
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: _kDefaultPadding),
              itemCount: TagCategory.values.length,
              itemBuilder: (context, index) {
                final category = TagCategory.values[index];
                final categoryTags = sampleTags
                    .where((tag) => tag.category == category)
                    .toList();

                if (category == TagCategory.location) {
                  return Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: _kDefaultPadding,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(_kDefaultBorderRadius),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
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
                        style: _kTitleStyle,
                      ),
                      children: [
                        Container(
                          color: const Color(0xFFE5FBFF),
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
                  margin: const EdgeInsets.symmetric(
                    horizontal: _kDefaultPadding,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(_kDefaultBorderRadius),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
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
                      style: _kTitleStyle,
                    ),
                    children: [
                      Container(
                        color: const Color(0xFFE5FBFF),
                        padding: const EdgeInsets.all(_kDefaultPadding),
                        child: Wrap(
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
                                height: _kTagHeight,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFFE7EFA2)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(
                                      _kDefaultBorderRadius),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFFE7EFA2)
                                        : Colors.grey.shade300,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color:
                                                Colors.black.withOpacity(0.05),
                                            blurRadius: 2,
                                            offset: const Offset(0, 1),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Text(
                                  tag.name,
                                  style: _kTagStyle.copyWith(
                                    color: isSelected
                                        ? Colors.black87
                                        : Colors.black54,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
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

  Widget _buildRegionSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Container(
          height: 50,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: _kDefaultPadding),
            itemCount: level1Regions?.length ?? 0,
            itemBuilder: (context, index) {
              if (level1Regions == null) return Container();
              final region = level1Regions![index];
              final isSelected = selectedLevel1?.code == region.code;
              return GestureDetector(
                onTap: () => _selectLevel1(region),
                child: Container(
                  width: 100,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFE7EFA2) : Colors.white,
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFFE7EFA2)
                          : Colors.grey.shade300,
                    ),
                    borderRadius: BorderRadius.circular(_kDefaultBorderRadius),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 2,
                              offset: const Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      region.name,
                      style: _kTagStyle.copyWith(
                        color: isSelected ? Colors.black87 : Colors.black54,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (level2Regions != null && level2Regions!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: _kDefaultPadding),
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
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color:
                          isSelected ? const Color(0xFFE7EFA2) : Colors.white,
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFFE7EFA2)
                            : Colors.grey.shade300,
                      ),
                      borderRadius:
                          BorderRadius.circular(_kDefaultBorderRadius),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 2,
                                offset: const Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        region.name,
                        style: _kTagStyle.copyWith(
                          color: isSelected ? Colors.black87 : Colors.black54,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
        if (level3Regions != null && level3Regions!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: _kDefaultPadding),
              itemCount: level3Regions!.length,
              itemBuilder: (context, index) {
                final region = level3Regions![index];
                final isSelected = selectedTags.contains(region);
                return GestureDetector(
                  onTap: () => _selectLevel3(region),
                  child: Container(
                    width: 100,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color:
                          isSelected ? const Color(0xFFE7EFA2) : Colors.white,
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFFE7EFA2)
                            : Colors.grey.shade300,
                      ),
                      borderRadius:
                          BorderRadius.circular(_kDefaultBorderRadius),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 2,
                                offset: const Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        region.name,
                        style: _kTagStyle.copyWith(
                          color: isSelected ? Colors.black87 : Colors.black54,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
        const SizedBox(height: 8),
      ],
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