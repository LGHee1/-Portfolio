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
      
      _cachedRegions = [];
      Map<String, String> sidoMap = {};  // 시도 코드 -> 시도 이름
      Map<String, String> sigunguMap = {};  // 시군구 코드 -> 시군구 이름
      
      // 먼저 존재하는 지역만 필터링
      var validRows = csvTable.where((row) => row[2] == '존재').toList();
      
      // 시도 레벨 처리 (2자리 코드)
      for (var row in validRows) {
        String code = row[0].toString();
        String name = row[1].toString();
        
        if (code.length == 2) {
          sidoMap[code] = name;
          _cachedRegions!.add(RegionTag(
            name: name,
            level: 1,
            parentRegion: null,
            code: code,
          ));
        }
      }
      
      // 시군구 레벨 처리 (5자리 코드)
      for (var row in validRows) {
        String code = row[0].toString();
        String name = row[1].toString();
        
        if (code.length == 5) {
          String sidoCode = code.substring(0, 2);
          sigunguMap[code] = name;
          _cachedRegions!.add(RegionTag(
            name: name,
            level: 2,
            parentRegion: sidoMap[sidoCode],
            code: code,
          ));
        }
      }
      
      // 읍면동 레벨 처리 (10자리 코드)
      for (var row in validRows) {
        String code = row[0].toString();
        String name = row[1].toString();
        
        if (code.length == 10) {
          String sigunguCode = code.substring(0, 5);
          _cachedRegions!.add(RegionTag(
            name: name,
            level: 3,
            parentRegion: sigunguMap[sigunguCode],
            code: code,
          ));
        }
      }

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