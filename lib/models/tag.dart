enum TagCategory {
  location,    // 지역
  exercise,    // 운동환경
  surrounding, // 주변환경
  etc         // 기타
}

class Tag {
  final String name;
  final TagCategory category;
  final String? parentRegion;  // 상위 지역 (지역 카테고리에서만 사용)

  const Tag({
    required this.name,
    required this.category,
    this.parentRegion,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'category': category.toString().split('.').last,
    };
  }

  factory Tag.fromJson(Map<String, dynamic> json) {
    return Tag(
      name: json['name'] as String,
      category: TagCategory.values.firstWhere(
        (e) => e.toString() == 'TagCategory.${json['category']}',
        orElse: () => TagCategory.etc,
      ),
    );
  }
}

class RegionTag extends Tag {
  final int level;  // 지역 레벨 (1: 시/도, 2: 시/군/구, 3: 읍/면/동)
  final String code;  // 법정동 코드
  final List<RegionTag>? subRegions;  // 하위 지역 목록

  const RegionTag({
    required String name,
    required this.level,
    required this.code,
    String? parentRegion,
    this.subRegions,
  }) : super(
    name: name,
    category: TagCategory.location,
    parentRegion: parentRegion,
  );

  // JSON에서 RegionTag 객체로 변환하는 팩토리 메서드
  factory RegionTag.fromJson(Map<String, dynamic> json) {
    return RegionTag(
      name: json['name'] as String,
      level: json['code'].toString().length == 2 ? 1 : 
             json['code'].toString().length == 5 ? 2 : 3,
      code: json['code'] as String,
      parentRegion: null,  // 상위 지역 정보는 나중에 설정
      subRegions: json['children'] != null
          ? (json['children'] as List)
              .map((e) => RegionTag.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
    );
  }

  // RegionTag 객체를 JSON으로 변환하는 메서드
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'level': level,
      'code': code,
      'parentRegion': parentRegion,
      'subRegions': subRegions?.map((e) => e.toJson()).toList(),
    };
  }

  // 여러 지역 데이터를 한번에 파싱하는 팩토리 메서드
  static List<RegionTag> fromJsonList(List<dynamic> jsonList) {
    return jsonList.map((json) => RegionTag.fromJson(json as Map<String, dynamic>)).toList();
  }
}

final List<Tag> sampleTags = [
  // 운동환경 태그
  const Tag(name: '트랙', category: TagCategory.exercise),
  const Tag(name: '아스팔트', category: TagCategory.exercise),
  const Tag(name: '보도블럭', category: TagCategory.exercise),
  const Tag(name: '잔디', category: TagCategory.exercise),
  const Tag(name: '자전거도로', category: TagCategory.exercise),
  const Tag(name: '산책로', category: TagCategory.exercise),
  const Tag(name: '등산로', category: TagCategory.exercise),
  const Tag(name: '흙길', category: TagCategory.exercise),
  const Tag(name: '계단', category: TagCategory.exercise),
  const Tag(name: '오르막길', category: TagCategory.exercise),
  const Tag(name: '내리막길', category: TagCategory.exercise),
  const Tag(name: '다리', category: TagCategory.exercise),
  const Tag(name: '호수', category: TagCategory.exercise),
  const Tag(name: '하천', category: TagCategory.exercise),
  const Tag(name: '개울', category: TagCategory.exercise),
  const Tag(name: '강가', category: TagCategory.exercise),
  const Tag(name: '분수', category: TagCategory.exercise),
  const Tag(name: '수목원', category: TagCategory.exercise),
  const Tag(name: '공원', category: TagCategory.exercise),
  const Tag(name: '경기장', category: TagCategory.exercise),
  const Tag(name: '운동장', category: TagCategory.exercise),
  const Tag(name: '학교', category: TagCategory.exercise),
  const Tag(name: '실내', category: TagCategory.exercise),
  const Tag(name: '실외', category: TagCategory.exercise),

  // 주변환경 태그
  const Tag(name: '화장실', category: TagCategory.surrounding),
  const Tag(name: '식수대', category: TagCategory.surrounding),
  const Tag(name: '카페', category: TagCategory.surrounding),
  const Tag(name: '편의점', category: TagCategory.surrounding),
  const Tag(name: '마트', category: TagCategory.surrounding),
  const Tag(name: '식당', category: TagCategory.surrounding),
  const Tag(name: '주차장', category: TagCategory.surrounding),
  const Tag(name: '노래방', category: TagCategory.surrounding),
  const Tag(name: '놀이터', category: TagCategory.surrounding),
  const Tag(name: '야외운동기구', category: TagCategory.surrounding),
  const Tag(name: '쉼터', category: TagCategory.surrounding),

  // 기타 태그
  const Tag(name: '24시간', category: TagCategory.etc),
  const Tag(name: '무료', category: TagCategory.etc),
  const Tag(name: '데이트추천', category: TagCategory.etc),
  const Tag(name: '포토존', category: TagCategory.etc),
  const Tag(name: '반려동물동반', category: TagCategory.etc),
  const Tag(name: '초보자추천', category: TagCategory.etc),
  const Tag(name: '이벤트행사', category: TagCategory.etc),
]; 