import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../models/tag.dart';
import '../services/region_service.dart';

class TagListPage extends StatefulWidget {
  final Function(List<Tag>) onTagsSelected;
  
  const TagListPage({
    super.key,
    required this.onTagsSelected,
  });

  @override
  State<TagListPage> createState() => _TagListPageState();
}

class _TagListPageState extends State<TagListPage> {
  final List<Tag> selectedTags = [];
  final Map<TagCategory, bool> categoryExpanded = {
    TagCategory.location: true,
    TagCategory.exercise: true,
    TagCategory.surrounding: true,
    TagCategory.etc: true,
  };
  
  String? selectedParentRegion;  // 시/도
  String? selectedMiddleRegion;  // 시/군/구
  List<RegionTag> regions = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRegions();
  }

  Future<void> _loadRegions() async {
    final loadedRegions = await RegionService.loadRegions();
    setState(() {
      regions = loadedRegions;
      isLoading = false;
    });
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
          icon: Icon(Icons.arrow_back, size: 24.sp),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 8.w),
            child: ElevatedButton(
              onPressed: () {
                widget.onTagsSelected(selectedTags);
                Navigator.pop(context);
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
                '추가하기',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                const Divider(
                  thickness: 1,
                  color: Colors.grey,
                ),
                Expanded(
                  child: ListView(
                    children: [
                      _buildRegionSection(),
                      _buildOtherTagsSection(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildRegionSection() {
    final parentRegions = RegionService.getParentRegions(regions);
    
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFACE3FF),
      ),
      child: ExpansionTile(
        initiallyExpanded: categoryExpanded[TagCategory.location] ?? true,
        onExpansionChanged: (expanded) {
          setState(() {
            categoryExpanded[TagCategory.location] = expanded;
          });
        },
        title: Text(
          '지역',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 16.sp,
          ),
        ),
        children: [
          // 시/도 선택
          Container(
            height: 50.h,
            color: const Color(0xFFCBF6FF),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: parentRegions.length,
              itemBuilder: (context, index) {
                final region = parentRegions[index];
                final isSelected = selectedParentRegion == region.name;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedParentRegion = isSelected ? null : region.name;
                      selectedMiddleRegion = null;
                    });
                  },
                  child: Container(
                    width: 80.w,
                    margin: EdgeInsets.symmetric(horizontal: 4.w),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFE7EFA2) : Colors.white,
                      border: Border.all(
                        color: isSelected ? const Color(0xFFE7EFA2) : Colors.grey,
                      ),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Center(
                      child: Text(
                        region.name,
                        style: TextStyle(
                          color: isSelected ? Colors.black : Colors.grey,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 14.sp,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          
          // 시/군/구 선택
          if (selectedParentRegion != null) ...[
            Container(
              height: 50.h,
              color: const Color(0xFFCBF6FF),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: RegionService.getChildRegions(regions, selectedParentRegion!).length,
                itemBuilder: (context, index) {
                  final region = RegionService.getChildRegions(regions, selectedParentRegion!)[index];
                  final isSelected = selectedMiddleRegion == region.name;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedMiddleRegion = isSelected ? null : region.name;
                      });
                    },
                    child: Container(
                      width: 80.w,
                      margin: EdgeInsets.symmetric(horizontal: 4.w),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFE7EFA2) : Colors.white,
                        border: Border.all(
                          color: isSelected ? const Color(0xFFE7EFA2) : Colors.grey,
                        ),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Center(
                        child: Text(
                          region.name,
                          style: TextStyle(
                            color: isSelected ? Colors.black : Colors.grey,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 14.sp,
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
          if (selectedMiddleRegion != null) ...[
            Container(
              color: const Color(0xFFCBF6FF),
              padding: EdgeInsets.all(16.w),
              child: Wrap(
                spacing: 8.w,
                runSpacing: 8.h,
                children: RegionService.getChildRegions(regions, selectedMiddleRegion!)
                    .map((region) {
                  final isSelected = selectedTags.contains(region);
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          selectedTags.remove(region);
                        } else {
                          selectedTags.add(region);
                        }
                      });
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 3.h),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFE7EFA2) : Colors.white,
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(
                          color: isSelected ? const Color(0xFFE7EFA2) : Colors.grey,
                        ),
                      ),
                      child: Text(
                        region.name,
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: isSelected ? Colors.black : Colors.grey,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOtherTagsSection() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFACE3FF),
      ),
      child: ExpansionTile(
        initiallyExpanded: categoryExpanded[TagCategory.exercise] ?? true,
        onExpansionChanged: (expanded) {
          setState(() {
            categoryExpanded[TagCategory.exercise] = expanded;
          });
        },
        title: Text(
          '운동환경',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 16.sp,
          ),
        ),
        children: [
          Container(
            color: const Color(0xFFCBF6FF),
            padding: EdgeInsets.all(16.w),
            child: Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: sampleTags
                  .where((tag) => tag.category == TagCategory.exercise)
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
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 3.h),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFE7EFA2) : Colors.white,
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: isSelected ? const Color(0xFFE7EFA2) : Colors.grey,
                      ),
                    ),
                    child: Text(
                      tag.name,
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: isSelected ? Colors.black : Colors.grey,
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
  }
} 