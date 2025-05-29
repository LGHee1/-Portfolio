import 'package:flutter/material.dart';
import 'post_list.dart';
import '../models/tag.dart';
import '../Widgets/bottom_bar.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../Running/workout_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';

class PostViewPage extends StatefulWidget {
  final Map<String, dynamic> postData;
  const PostViewPage({super.key, required this.postData});

  @override
  State<PostViewPage> createState() => _PostViewPageState();
}

class _PostViewPageState extends State<PostViewPage> {
  int _selectedIndex = 2;
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  bool _isLiked = false;

  @override
  void initState() {
    super.initState();
    _initializeMarkers();
    _initializePolylines();
    _checkIfLiked();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _initializeMarkers() {
    if (widget.postData['routePoints'] != null && (widget.postData['routePoints'] as List).isNotEmpty) {
      final routePoints = (widget.postData['routePoints'] as List).map((point) => LatLng(
        point['latitude'] as double,
        point['longitude'] as double,
      )).toList();

      // 시작점 마커
      _markers.add(
        Marker(
          markerId: const MarkerId('startLocation'),
          position: routePoints.first,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(title: '시작'),
        ),
      );

      // 종료점 마커
      _markers.add(
        Marker(
          markerId: const MarkerId('endLocation'),
          position: routePoints.last,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: '종료'),
        ),
      );
    }
  }

  void _initializePolylines() {
    if (widget.postData['routePoints'] != null && (widget.postData['routePoints'] as List).isNotEmpty) {
      final routePoints = (widget.postData['routePoints'] as List).map((point) => LatLng(
        point['latitude'] as double,
        point['longitude'] as double,
      )).toList();

      _polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: routePoints,
          color: const Color(0xFF764BA2),
          width: 8,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round,
        ),
      );
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (widget.postData['routePoints'] != null && (widget.postData['routePoints'] as List).isNotEmpty) {
      final routePoints = (widget.postData['routePoints'] as List).map((point) => LatLng(
        point['latitude'] as double,
        point['longitude'] as double,
      )).toList();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLngBounds(
            _getBoundsFromLatLngList(routePoints),
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

  Future<void> _checkIfLiked() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final likedPostDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('LikedPosts')
          .doc(widget.postData['id'])
          .get();

      if (mounted) {
        setState(() {
          _isLiked = likedPostDoc.exists;
        });
      }
    } catch (e) {
      print('좋아요 상태 확인 중 오류: $e');
    }
  }

  Future<void> _toggleLike() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // 게시글 작성자의 Post_Data 컬렉션 참조
      final postRef = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.postData['userId'])
          .collection('Post_Data')
          .doc(widget.postData['id']);

      // 현재 사용자의 LikedPosts 컬렉션 참조
      final likedPostRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('LikedPosts')
          .doc(widget.postData['id']);

      // 트랜잭션을 사용하여 좋아요 처리
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final postDoc = await transaction.get(postRef);
        if (!postDoc.exists) {
          throw Exception('게시물을 찾을 수 없습니다.');
        }

        final currentLikes = postDoc.data()?['likes'] ?? 0;
        
        if (_isLiked) {
          // 좋아요 취소
          if (currentLikes > 0) {
            transaction.update(postRef, {
              'likes': currentLikes - 1
            });
            transaction.delete(likedPostRef);
          }
        } else {
          // 좋아요 추가
          transaction.update(postRef, {
            'likes': currentLikes + 1
          });
          transaction.set(likedPostRef, {
            'timestamp': FieldValue.serverTimestamp()
          });
        }
      });

      // 상태 업데이트
      if (mounted) {
        setState(() {
          _isLiked = !_isLiked;
          widget.postData['likes'] = _isLiked 
              ? (widget.postData['likes'] ?? 0) + 1 
              : (widget.postData['likes'] ?? 1) - 1;
          
          // 좋아요 수가 음수가 되지 않도록 보장
          if (widget.postData['likes'] < 0) {
            widget.postData['likes'] = 0;
          }
        });
      }
    } catch (e) {
      print('좋아요 토글 중 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('좋아요 처리 중 오류가 발생했습니다. 다시 시도해주세요.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
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
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => WorkoutScreen(
                      isRecommendedCourse: true,
                      recommendedRoutePoints: (widget.postData['routePoints'] as List).map((point) => LatLng(
                        point['latitude'] as double,
                        point['longitude'] as double,
                      )).toList(),
                      recommendedCourseName: widget.postData['title'] ?? '추천 코스',
                    ),
                  ),
                );
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
                '적용하기',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 300.h,
              margin: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16.r),
                child: widget.postData['routePoints'] != null && (widget.postData['routePoints'] as List).isNotEmpty
                    ? GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: LatLng(
                            (widget.postData['routePoints'] as List).first['latitude'],
                            (widget.postData['routePoints'] as List).first['longitude'],
                          ),
                          zoom: 15,
                        ),
                        onMapCreated: _onMapCreated,
                        polylines: _polylines,
                        markers: _markers,
                        myLocationEnabled: false,
                        myLocationButtonEnabled: false,
                        zoomControlsEnabled: false,
                        mapToolbarEnabled: false,
                      )
                    : Container(
                        color: Colors.grey[300],
                        child: Center(
                          child: Text(
                            '운동 경로가 없습니다',
                            style: TextStyle(fontSize: 16.sp),
                          ),
                        ),
                      ),
              ),
            ),
            if (widget.postData['routePoints'] != null && (widget.postData['routePoints'] as List).isNotEmpty)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: ElevatedButton.icon(
                  onPressed: () {
                    final startPoint = (widget.postData['routePoints'] as List).first;
                    final url = 'https://www.google.com/maps/dir/?api=1&destination=${startPoint['latitude']},${startPoint['longitude']}';
                    launchUrl(Uri.parse(url));
                  },
                  icon: const Icon(Icons.directions),
                  label: const Text('시작점으로 길찾기'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF764BA2),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 45),
                  ),
                ),
              ),
            Padding(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.postData['title'] ?? '제목 없음',
                    style: TextStyle(
                      fontSize: 24.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16.r,
                        backgroundColor: Colors.grey,
                        child: Icon(Icons.person, size: 24.sp, color: Colors.white),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        widget.postData['nickname'] ?? '작성자',
                        style: TextStyle(fontSize: 16.sp),
                      ),
                      SizedBox(width: 16.w),
                      GestureDetector(
                        onTap: _toggleLike,
                        child: Container(
                          padding: EdgeInsets.all(6.w),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20.r),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            _isLiked ? Icons.favorite : Icons.favorite_border,
                            size: 24.sp,
                            color: _isLiked ? Colors.red : Colors.grey,
                          ),
                        ),
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        '${widget.postData['likes'] ?? 0}',
                        style: TextStyle(fontSize: 15.sp),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (widget.postData['tags'] != null && (widget.postData['tags'] as List).isNotEmpty)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: Wrap(
                  spacing: 8.w,
                  runSpacing: 8.h,
                  children: (widget.postData['tags'] as List).map<Widget>((tag) =>
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 3.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE7EFA2),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Text(
                        tag.toString(),
                        style: TextStyle(fontSize: 16.sp),
                      ),
                    )
                  ).toList(),
                ),
              ),
            Padding(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '세부 설명',
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
                    child: Text(
                      widget.postData['content'] ?? '설명 없음',
                      style: TextStyle(fontSize: 16.sp),
                    ),
                  ),
                ],
              ),
            ),
            if (widget.postData['imageUrls'] != null && (widget.postData['imageUrls'] as List).isNotEmpty)
              Padding(
                padding: EdgeInsets.all(16.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '등록된 이미지',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    SizedBox(
                      height: 125.h,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: (widget.postData['imageUrls'] as List).length,
                        itemBuilder: (context, index) {
                          final imageUrl = widget.postData['imageUrls'][index];
                          return Padding(
                            padding: EdgeInsets.only(right: 8.w),
                            child: GestureDetector(
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return _FullScreenImageViewer(
                                      images: List<String>.from(widget.postData['imageUrls']),
                                      initialIndex: index,
                                    );
                                  },
                                );
                              },
                              child: Container(
                                width: 125.w,
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  borderRadius: BorderRadius.circular(8.r),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8.r),
                                  child: Image.network(
                                    imageUrl,
                                    fit: BoxFit.cover,
                                    width: 125.w,
                                    height: 125.h,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
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
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
    );
  }
}

class _FullScreenImageViewer extends StatefulWidget {
  final List<String> images;
  final int initialIndex;
  const _FullScreenImageViewer({required this.images, required this.initialIndex});

  @override
  State<_FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<_FullScreenImageViewer> {
  late PageController _controller;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _controller = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: widget.images.length,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              itemBuilder: (context, index) {
                return Center(
                  child: Image.network(
                    widget.images[index],
                    fit: BoxFit.contain,
                    width: MediaQuery.of(context).size.width,
                    height: MediaQuery.of(context).size.height,
                  ),
                );
              },
            ),
            Positioned(
              bottom: 40.h,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.images.length, (index) {
                  return Container(
                    margin: EdgeInsets.symmetric(horizontal: 4.w),
                    width: 8.w,
                    height: 8.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentIndex == index ? Colors.white : Colors.white38,
                    ),
                  );
                }),
              ),
            ),
            Positioned(
              top: 40.h,
              right: 20.w,
              child: IconButton(
                icon: Icon(Icons.close, color: Colors.white, size: 30.sp),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 