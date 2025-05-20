import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';
import '../models/tag.dart';

class RegionService {
  static List<RegionTag>? _cachedRegions;

  static Future<List<RegionTag>> loadRegions() async {
    if (_cachedRegions != null) {
      return _cachedRegions!;
    }

    try {
      final String data = await rootBundle.loadString('assets/data/region_20240805.csv');
      List<List<dynamic>> csvTable = const CsvToListConverter().convert(data);
      
      _cachedRegions = csvTable.where((row) => row[2] == '존재').map((row) {
        String code = row[0].toString();
        String name = row[1].toString();
        
        // 법정동코드로 레벨 판단 (앞 2자리가 시도, 5자리가 시군구)
        int level = 3; // 기본값은 읍/면/동
        if (code.length >= 2) {
          if (code.substring(2) == '00000000') {
            level = 1; // 시도
          } else if (code.substring(5) == '00000') {
            level = 2; // 시군구
          }
        }

        // 상위 지역명 찾기
        String? parentRegion;
        if (level > 1) {
          String parentCode = level == 2 
              ? code.substring(0, 2) + '00000000'  // 시도 코드
              : code.substring(0, 5) + '00000';    // 시군구 코드
          
          var parentRow = csvTable.firstWhere(
            (r) => r[0].toString() == parentCode && r[2] == '존재',
            orElse: () => ['', '', ''],
          );
          if (parentRow[1] != '') {
            parentRegion = parentRow[1].toString();
          }
        }

        return RegionTag(
          name: name,
          level: level,
          parentRegion: parentRegion,
        );
      }).toList();

      return _cachedRegions!;
    } catch (e) {
      print('지역 데이터 로드 중 오류 발생: $e');
      return [];
    }
  }

  static List<RegionTag> getRegionsByLevel(List<RegionTag> regions, int level) {
    return regions.where((region) => region.level == level).toList();
  }

  static List<RegionTag> getChildRegions(List<RegionTag> regions, String parentName) {
    return regions.where((region) => region.parentRegion == parentName).toList();
  }

  static List<RegionTag> getParentRegions(List<RegionTag> regions) {
    return regions.where((region) => region.level == 1).toList();
  }

  static List<RegionTag> getMiddleRegions(List<RegionTag> regions) {
    return regions.where((region) => region.level == 2).toList();
  }

  static List<RegionTag> getBottomRegions(List<RegionTag> regions) {
    return regions.where((region) => region.level == 3).toList();
  }
} 