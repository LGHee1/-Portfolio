import 'package:flutter/material.dart';
import 'tag_list.dart';
import '../models/tag.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path/path.dart' as path;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../Widgets/bottom_bar.dart';
import 'package:profanity_filter/profanity_filter.dart';

class PostCreatePage extends StatefulWidget {
  final Map<String, dynamic>? postData;
  final String? postId;
  final Map<String, dynamic>? workoutData;

  const PostCreatePage({
    Key? key, 
    this.postData, 
    this.postId,
    this.workoutData,
  }) : super(key: key);

  @override
  State<PostCreatePage> createState() => _PostCreatePageState();
}

class _PostCreatePageState extends State<PostCreatePage> {
  List<Tag> selectedTags = [];
  List<File> selectedImages = [];
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  bool _isLoading = false;
  late GoogleMapController _mapController;
  final Set<Polyline> _polylines = {};
  final Set<Marker> _markers = {};
  List<LatLng> _routePoints = [];
  bool _isMapLoading = true;
  int _selectedIndex = 1;
  bool isEditMode = false;

  // 욕설 필터 인스턴스 생성
  final ProfanityFilter _profanityFilter = ProfanityFilter();

  // 부적절한 단어 체크 함수
  bool _containsInappropriateWords(String text) {
    return _profanityFilter.hasProfanity(text);
  }

  @override
  void initState() {
    super.initState();
    if (widget.postData != null) {
      isEditMode = true;
      _titleController.text = widget.postData!['title'] ?? '';
      _contentController.text = widget.postData!['content'] ?? '';
      
      // 기존 태그 데이터 로드
      if (widget.postData!['tags'] != null) {
        final List<dynamic> tagNames = widget.postData!['tags'];
        selectedTags = tagNames.map((tagName) => Tag(
          name: tagName.toString(),
          category: TagCategory.etc, // 기본 카테고리 설정
        )).toList();
      }
    }
    
    if (widget.workoutData != null) {
      _loadWorkoutData();
    } else if (widget.postData != null && widget.postData!['routePoints'] != null) {
      // 게시글 수정 시 기존 운동 데이터 로드
      final List<dynamic> routePointsData = widget.postData!['routePoints'] ?? [];
      setState(() {
        _routePoints = routePointsData.map((point) => LatLng(
          point['latitude'] as double,
          point['longitude'] as double,
        )).toList();
        _isMapLoading = false;
      });
      if (_routePoints.isNotEmpty) {
        _initializePolylines();
        _initializeMarkers();
      }
    }
  }

  Future<void> _loadLatestWorkoutData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('Running_Data')
          .orderBy('date', descending: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final workoutData = querySnapshot.docs.first.data();
        final List<dynamic> routePointsData = workoutData['routePoints'] ?? [];
        
        setState(() {
          _routePoints = routePointsData.map((point) => LatLng(
            point['latitude'] as double,
            point['longitude'] as double,
          )).toList();
          _isMapLoading = false;
        });

        if (_routePoints.isNotEmpty) {
          _initializePolylines();
          _initializeMarkers();
        } else if (workoutData['routePoints'] != null && workoutData['routePoints'].isNotEmpty) {
          // 경로가 없는 경우 마지막 위치만 마커로 표시
          final lastPoint = workoutData['routePoints'].last;
          final lastPosition = LatLng(
            lastPoint['latitude'] as double,
            lastPoint['longitude'] as double,
          );
          _markers.add(
            Marker(
              markerId: const MarkerId('endLocation'),
              position: lastPosition,
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
              infoWindow: const InfoWindow(title: '종료'),
            ),
          );
        }
      }
    } catch (e) {
      print('운동 데이터 로드 중 오류 발생: $e');
      setState(() {
        _isMapLoading = false;
      });
    }
  }

  Future<void> _loadWorkoutData() async {
    try {
      if (widget.workoutData == null) return;

      final List<dynamic> routePointsData = widget.workoutData!['routePoints'] ?? [];
      
      setState(() {
        _routePoints = routePointsData.map((point) => LatLng(
          point['latitude'] as double,
          point['longitude'] as double,
        )).toList();
        _isMapLoading = false;
      });

      if (_routePoints.isNotEmpty) {
        _initializePolylines();
        _initializeMarkers();
      }
    } catch (e) {
      print('운동 데이터 로드 중 오류 발생: $e');
      setState(() {
        _isMapLoading = false;
      });
    }
  }

  void _initializePolylines() {
    if (_routePoints.isNotEmpty) {
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: _routePoints,
          color: const Color(0xFF764BA2),
          width: 8,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round,
        ),
      );
    }
  }

  void _initializeMarkers() {
    if (_routePoints.isNotEmpty) {
      // 시작점 마커
      _markers.add(
        Marker(
          markerId: const MarkerId('startLocation'),
          position: _routePoints.first,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(title: '시작'),
        ),
      );

      // 종료점 마커
      _markers.add(
        Marker(
          markerId: const MarkerId('endLocation'),
          position: _routePoints.last,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: '종료점'),
        ),
      );
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (_routePoints.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.animateCamera(
          CameraUpdate.newLatLngBounds(
            _getBoundsFromLatLngList(_routePoints),
            50.0,
          ),
        );
      });
    }
  }

  LatLngBounds _getBoundsFromLatLngList(List<LatLng> list) {
    double? minLat, maxLat, minLng, maxLng;

    for (LatLng latLng in list) {
      if (minLat == null || latLng.latitude < minLat) minLat = latLng.latitude;
      if (maxLat == null || latLng.latitude > maxLat) maxLat = latLng.latitude;
      if (minLng == null || latLng.longitude < minLng) minLng = latLng.longitude;
      if (maxLng == null || latLng.longitude > maxLng) maxLng = latLng.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(minLat!, minLng!),
      northeast: LatLng(maxLat!, maxLng!),
    );
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage();
    
    if (images.isNotEmpty) {
      setState(() {
        selectedImages.addAll(images.map((image) => File(image.path)));
      });
    }
  }

  Future<List<String>> _uploadImages() async {
    List<String> imageUrls = [];
    for (File image in selectedImages) {
      String fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(image.path)}';
      Reference ref = FirebaseStorage.instance.ref().child('post_images/$fileName');
      await ref.putFile(image);
      String downloadUrl = await ref.getDownloadURL();
      imageUrls.add(downloadUrl);
    }
    return imageUrls;
  }

  Future<void> _savePost() async {
    if (_titleController.text.isEmpty || _contentController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('제목과 내용을 모두 입력해주세요')),
      );
      return;
    }

    if (_containsInappropriateWords(_titleController.text) || _containsInappropriateWords(_contentController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('부적절한 단어가 포함되어 있습니다')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // 이미지 업로드 및 URL 가져오기
      List<String> imageUrls = [];
      for (var image in selectedImages) {
        final fileName = path.basename(image.path);
        final storageRef = FirebaseStorage.instance.ref().child('post_images/$fileName');
        await storageRef.putFile(image);
        final downloadUrl = await storageRef.getDownloadURL();
        imageUrls.add(downloadUrl);
      }

      // 게시글 데이터 생성
      final postData = {
        'userId': user.uid,
        'title': _titleController.text,
        'content': _contentController.text,
        'images': imageUrls,
        'tags': selectedTags.map((tag) => tag.name).toList(),
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
        'likes': 0, // 좋아요 초기값 추가
      };

      // 운동 데이터가 있는 경우 추가
      if (widget.workoutData != null) {
        postData.addAll({
          'routePoints': widget.workoutData!['routePoints'],
          'distance': widget.workoutData!['distance'],
          'duration': widget.workoutData!['duration'],
          'workoutId': widget.workoutData!['workoutId'],
        });
      }

      // 게시글 저장 (사용자 하위 컬렉션에 저장)
      await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('Post_Data').add(postData);

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      print('게시글 저장 중 오류 발생: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('게시글 저장 중 오류가 발생했습니다')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
        title: Text(
          isEditMode ? '게시글 수정' : '게시글 작성',
          style: TextStyle(fontSize: 24.sp),
        ),
        actions: [
          if (isEditMode)
            TextButton(
              onPressed: _isLoading ? null : _savePost,
              child: _isLoading
                  ? SizedBox(
                      width: 20.w,
                      height: 20.h,
                      child: CircularProgressIndicator(strokeWidth: 2.w),
                    )
                  : Text('수정', style: TextStyle(fontSize: 16.sp)),
            )
          else
            TextButton(
              onPressed: _isLoading ? null : _savePost,
              child: _isLoading
                  ? SizedBox(
                      width: 20.w,
                      height: 20.h,
                      child: CircularProgressIndicator(strokeWidth: 2.w),
                    )
                  : Text('게시', style: TextStyle(fontSize: 16.sp)),
            ),
        ],
      ),
      backgroundColor: const Color(0xFFCBF6FF),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '제목',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(horizontal: 12.w),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: TextField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        hintText: '제목을 입력하세요',
                        border: InputBorder.none,
                        hintStyle: TextStyle(fontSize: 16.sp),
                        helperText: '부적절한 단어는 사용할 수 없습니다.',
                        helperStyle: TextStyle(fontSize: 12.sp, color: Colors.grey),
                      ),
                      style: TextStyle(fontSize: 16.sp),
                      maxLines: 1,
                      onChanged: (value) {
                        if (_containsInappropriateWords(value)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('부적절한 단어가 포함되어 있습니다.'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '운동 코스',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Container(
                    width: double.infinity,
                    height: 200.h,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: _isMapLoading
                        ? Center(child: CircularProgressIndicator())
                        : _routePoints.isEmpty
                            ? Center(
                                child: Text(
                                  '운동 기록이 없습니다',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 16.sp,
                                  ),
                                ),
                              )
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(8.r),
                                child: GoogleMap(
                                  initialCameraPosition: CameraPosition(
                                    target: _routePoints.first,
                                    zoom: 15,
                                  ),
                                  onMapCreated: _onMapCreated,
                                  polylines: _polylines,
                                  markers: _markers,
                                  myLocationEnabled: false,
                                  myLocationButtonEnabled: false,
                                  zoomControlsEnabled: false,
                                  mapToolbarEnabled: false,
                                ),
                              ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '태그',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (selectedTags.isNotEmpty)
                          Wrap(
                            spacing: 8.w,
                            runSpacing: 8.h,
                            children: selectedTags.map((tag) {
                              return Container(
                                margin: EdgeInsets.only(right: 8.w, bottom: 8.h),
                                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE7EFA2),
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      tag.name,
                                      style: TextStyle(fontSize: 16.sp),
                                    ),
                                    SizedBox(width: 4.w),
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          selectedTags.remove(tag);
                                        });
                                      },
                                      child: Icon(Icons.close, size: 16.sp),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        GestureDetector(
                          onTap: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => TagListPage(
                                  onTagsSelected: (tags) {
                                    setState(() {
                                      final merged = [...selectedTags, ...tags];
                                      final unique = <Tag>[];
                                      for (final tag in merged) {
                                        if (!unique.any((t) => t.name == tag.name)) {
                                          unique.add(tag);
                                        }
                                      }
                                      selectedTags = unique;
                                    });
                                  },
                                ),
                              ),
                            );
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE7EFA2),
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            child: Text(
                              '태그 추가',
                              style: TextStyle(
                                fontSize: 16.sp,
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '내용',
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
                    child: TextField(
                      controller: _contentController,
                      decoration: InputDecoration(
                        hintText: '내용을 입력하세요',
                        border: InputBorder.none,
                        hintStyle: TextStyle(fontSize: 16.sp),
                        helperText: '부적절한 단어는 사용할 수 없습니다.',
                        helperStyle: TextStyle(fontSize: 12.sp, color: Colors.grey),
                      ),
                      style: TextStyle(fontSize: 16.sp),
                      maxLines: 5,
                      onChanged: (value) {
                        if (_containsInappropriateWords(value)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('부적절한 단어가 포함되어 있습니다.'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '이미지',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _pickImage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 16.h),
                      ),
                      child: Text(
                        '사진 업로드',
                        style: TextStyle(fontSize: 16.sp),
                      ),
                    ),
                  ),
                  if (selectedImages.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: 12.h),
                      child: Wrap(
                        spacing: 8.w,
                        runSpacing: 8.h,
                        children: List.generate(selectedImages.length, (index) {
                          return Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8.r),
                                child: Image.file(
                                  selectedImages[index],
                                  width: 120.w,
                                  height: 120.h,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: 0,
                                right: 0,
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      selectedImages.removeAt(index);
                                    });
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(12.r),
                                    ),
                                    child: Icon(Icons.close, color: Colors.white, size: 18.sp),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }),
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
          setState(() => _selectedIndex = index);
          if (index == 0) {
            Navigator.pushReplacementNamed(context, '/workout');
          } else if (index == 1) {
            Navigator.pushReplacementNamed(context, '/post');
          } else if (index == 2) {
            Navigator.pushReplacementNamed(context, '/profile');
          }
        },
      ),
    );
  }
} 