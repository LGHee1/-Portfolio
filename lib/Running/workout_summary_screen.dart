import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../user_provider.dart';
import '../home_screen.dart';
import '../Utils/theme.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../Widgets/menu.dart';
import '../Post/post_create.dart';
import '../Widgets/bottom_bar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class WorkoutSummaryScreen extends StatefulWidget {
  final double distance;
  final Duration duration;
  final String pace;
  final int cadence;
  final int calories;
  final List<LatLng> routePoints;
  final List<LatLng> pausedRoutePoints;
  final List<LatLng> activeRoutePoints;
  final bool isRecommendedCourse;
  final List<LatLng> recommendedRoutePoints;
  final String recommendedCourseName;

  const WorkoutSummaryScreen({
    Key? key,
    required this.distance,
    required this.duration,
    required this.pace,
    required this.cadence,
    required this.calories,
    required this.routePoints,
    required this.pausedRoutePoints,
    required this.activeRoutePoints,
    this.isRecommendedCourse = false,
    required this.recommendedRoutePoints,
    required this.recommendedCourseName,
  }) : super(key: key);

  @override
  State<WorkoutSummaryScreen> createState() => _WorkoutSummaryScreenState();
}

class _WorkoutSummaryScreenState extends State<WorkoutSummaryScreen> {
  bool isLiked = false;
  int likeCount = 0;
  late GoogleMapController _mapController;
  final Set<Polyline> _polylines = {};
  final Set<Marker> _markers = {};
  LatLng? _initialPosition;
  bool _isLoading = true;
  String _userNickname = '';
  bool _hasExistingPost = false;

  @override
  void initState() {
    super.initState();
    _initializePolylines();
    _initializeMarkers();
    _determinePosition();
    _loadUserData();
    if (widget.isRecommendedCourse) {
      _loadLikeCount();
    }
    _checkExistingPost();
  }

  void _loadUserData() {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    setState(() {
      _userNickname = userProvider.nickname;
    });
  }

  void _initializePolylines() {
    if (widget.routePoints.isNotEmpty) {
      // 활성 경로 (보라색)
      if (widget.activeRoutePoints.isNotEmpty) {
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('activeRoute'),
            points: widget.activeRoutePoints,
            color: const Color(0xFF764BA2),
            width: 5,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
            jointType: JointType.round,
          ),
        );
      }

      // 일시정지 구간 경로 (회색)
      if (widget.pausedRoutePoints.isNotEmpty) {
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('pausedRoute'),
            points: widget.pausedRoutePoints,
            color: Colors.grey,
            width: 5,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
            jointType: JointType.round,
          ),
        );
      }
    }
  }

  void _initializeMarkers() {
    if (widget.routePoints.isNotEmpty) {
      // 시작점 마커
      _markers.add(
        Marker(
          markerId: const MarkerId('startLocation'),
          position: widget.routePoints.first,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(title: '시작'),
        ),
      );

      // 종료점 마커
      _markers.add(
        Marker(
          markerId: const MarkerId('endLocation'),
          position: widget.routePoints.last,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: '종료'),
        ),
      );
    } else if (_initialPosition != null) {
      // 운동 거리가 없을 때 현재 위치에 시작점과 종료점 마커 표시
      _markers.add(
        Marker(
          markerId: const MarkerId('startLocation'),
          position: _initialPosition!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(title: '시작'),
        ),
      );
      _markers.add(
        Marker(
          markerId: const MarkerId('endLocation'),
          position: _initialPosition!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: '종료'),
        ),
      );
    }
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.deniedForever || permission == LocationPermission.denied) {
        return;
      }
    }

    final position = await Geolocator.getCurrentPosition();
    setState(() {
      _initialPosition = LatLng(position.latitude, position.longitude);
      _isLoading = false;
    });
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (widget.routePoints.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.animateCamera(
          CameraUpdate.newLatLngBounds(
            _getBoundsFromLatLngList(widget.routePoints),
            50.0,
          ),
        );
      });
    } else if (_initialPosition != null) {
      // 운동 거리가 없을 때 현재 위치로 카메라 이동
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.animateCamera(
          CameraUpdate.newLatLngZoom(_initialPosition!, 15),
        );
      });
    }
  }

  void _moveCamera() {
    if (_initialPosition != null) {
      _mapController.animateCamera(
        CameraUpdate.newLatLngZoom(_initialPosition!, 15),
      );
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String hours = twoDigits(duration.inHours);
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }

  Future<void> _loadLikeCount() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final postDoc = await FirebaseFirestore.instance
          .collection('posts')
          .where('courseName', isEqualTo: widget.recommendedCourseName)
          .get();

      if (postDoc.docs.isNotEmpty) {
        setState(() {
          likeCount = postDoc.docs.first.data()['likes'] ?? 0;
        });
      }
    } catch (e) {
      print('좋아요 개수 로드 중 오류 발생: $e');
    }
  }

  Future<void> _checkExistingPost() async {
    if (widget.routePoints.isEmpty) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // 운동 데이터의 고유 식별자를 생성
      final workoutId = '${widget.distance}_${widget.duration.inSeconds}_${widget.routePoints.first.latitude}_${widget.routePoints.first.longitude}';

      // 사용자 하위 컬렉션에서 게시글 확인
      final postDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('Post_Data')
          .where('workoutId', isEqualTo: workoutId)
          .get();

      setState(() {
        _hasExistingPost = postDoc.docs.isNotEmpty;
      });
    } catch (e) {
      print('게시글 존재 여부 확인 중 오류 발생: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '$_userNickname님의 운동 완료',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
            color: Color(0xFF0066CC),
          ),
        ),
        backgroundColor: Color(0xFFD8F9FF),
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(
              Icons.menu,
              color: Color(0xFF0066CC),
              size: 24.w,
            ),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      drawer: const Menu(),
      body: SafeArea(
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF0066CC),
                  strokeWidth: 2.w,
                ),
              )
            : Stack(
                children: [
                  Column(
                    children: [
                      Expanded(
                        flex: 1,
                        child: Container(
                          margin: EdgeInsets.all(16.w),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20.r),
                            boxShadow: [
                              BoxShadow(
                                color: Color(0xFF0066CC).withOpacity(0.1),
                                blurRadius: 12,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20.r),
                            child: GoogleMap(
                              mapType: MapType.normal,
                              initialCameraPosition: CameraPosition(
                                target: widget.routePoints.isNotEmpty
                                    ? widget.routePoints.first
                                    : (_initialPosition ??
                                        const LatLng(37.5665, 126.9780)),
                                zoom: 15,
                              ),
                              onMapCreated: _onMapCreated,
                              polylines: {
                                if (widget.activeRoutePoints.isNotEmpty)
                                  Polyline(
                                    polylineId: const PolylineId('activeRoute'),
                                    points: widget.activeRoutePoints,
                                    color: const Color(0xFF764BA2),
                                    width: 5,
                                    startCap: Cap.roundCap,
                                    endCap: Cap.roundCap,
                                    jointType: JointType.round,
                                  ),
                                if (widget.pausedRoutePoints.isNotEmpty)
                                  Polyline(
                                    polylineId: const PolylineId('pausedRoute'),
                                    points: widget.pausedRoutePoints,
                                    color: Colors.grey,
                                    width: 5,
                                    startCap: Cap.roundCap,
                                    endCap: Cap.roundCap,
                                    jointType: JointType.round,
                                  ),
                                if (widget.isRecommendedCourse &&
                                    widget.recommendedRoutePoints.isNotEmpty)
                                  Polyline(
                                    polylineId:
                                        const PolylineId('recommendedRoute'),
                                    points: widget.recommendedRoutePoints,
                                    color: Colors.green,
                                    width: 5,
                                    startCap: Cap.roundCap,
                                    endCap: Cap.roundCap,
                                    jointType: JointType.round,
                                  ),
                              },
                              markers: _markers,
                              myLocationEnabled: true,
                              myLocationButtonEnabled: false,
                              zoomControlsEnabled: true,
                              mapToolbarEnabled: false,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Container(
                          padding: EdgeInsets.all(20.w),
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Color(0xFFD8F9FF),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(30.r),
                              topRight: Radius.circular(30.r),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '운동 정보',
                                style: TextStyle(
                                  fontSize: 20.sp,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0066CC),
                                  letterSpacing: -0.3,
                                ),
                              ),
                              SizedBox(height: 20.h),
                              Expanded(
                                child: _buildStatsGrid(),
                              ),
                              Padding(
                                padding: EdgeInsets.only(top: 16.h),
                                child: Align(
                                  alignment: Alignment.bottomCenter,
                                  child: ElevatedButton(
                                    onPressed: _hasExistingPost
                                        ? null
                                        : () {
                                            if (widget.routePoints.isEmpty) {
                                              showDialog(
                                                context: context,
                                                builder: (context) => AlertDialog(
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(20.r),
                                                  ),
                                                  content: Text(
                                                    '운동 경로가 없어 작성할 수 없습니다.',
                                                    style: TextStyle(
                                                      fontSize: 16.sp,
                                                      color: Color(0xFF0066CC),
                                                      letterSpacing: -0.2,
                                                    ),
                                                  ),
                                                  actions: [
                                                    Align(
                                                      alignment: Alignment.bottomRight,
                                                      child: TextButton(
                                                        onPressed: () => Navigator.of(context).pop(),
                                                        child: Text(
                                                          '확인',
                                                          style: TextStyle(
                                                            fontSize: 16.sp,
                                                            fontWeight: FontWeight.w600,
                                                            color: Color(0xFF0066CC),
                                                            letterSpacing: -0.2,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            } else {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) => PostCreatePage(
                                                    workoutData: {
                                                      'routePoints': widget.routePoints.map((point) => {
                                                        'latitude': point.latitude,
                                                        'longitude': point.longitude,
                                                      }).toList(),
                                                      'distance': widget.distance,
                                                      'duration': widget.duration.inSeconds,
                                                      'workoutId': '${widget.distance}_${widget.duration.inSeconds}_${widget.routePoints.first.latitude}_${widget.routePoints.first.longitude}',
                                                    },
                                                  ),
                                                ),
                                              ).then((_) {
                                                _checkExistingPost(); // 게시글 작성 후 상태 업데이트
                                              });
                                            }
                                          },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _hasExistingPost ? Colors.grey : Color(0xFF0066CC),
                                      foregroundColor: Colors.white,
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 24.w,
                                        vertical: 12.h,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16.r),
                                      ),
                                      elevation: 4,
                                      shadowColor: Color(0xFF0066CC).withOpacity(0.3),
                                    ),
                                    child: Text(
                                      _hasExistingPost ? '이미 게시글을 작성했습니다' : '현재 운동코스 게시글 작성',
                                      style: TextStyle(
                                        fontSize: 16.sp,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (widget.isRecommendedCourse)
                    Positioned(
                      top: MediaQuery.of(context).size.height / 3 - 30,
                      right: 24.w,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            isLiked = !isLiked;
                          });
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12.w,
                            vertical: 8.h,
                          ),
                          decoration: BoxDecoration(
                            color: Color(0xFFD8F9FF),
                            borderRadius: BorderRadius.circular(20.r),
                            boxShadow: [
                              BoxShadow(
                                color: Color(0xFF0066CC).withOpacity(0.1),
                                blurRadius: 8,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isLiked ? Icons.favorite : Icons.favorite_border,
                                color: isLiked
                                    ? Color(0xFF0066CC)
                                    : Color(0xFF0066CC).withOpacity(0.5),
                                size: 24.w,
                              ),
                              SizedBox(width: 4.w),
                              Text(
                                likeCount.toString(),
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w600,
                                  color: isLiked
                                      ? Color(0xFF0066CC)
                                      : Color(0xFF0066CC).withOpacity(0.5),
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
      ),
      bottomNavigationBar: BottomBar(
        selectedIndex: 1,
        onTabSelected: (index) {
          // 필요시 네비게이션 동작 추가
        },
      ),
    );
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: 2,
      childAspectRatio: 2,
      mainAxisSpacing: 16.h,
      crossAxisSpacing: 16.w,
      children: [
        _buildStatItem('거리', '${widget.distance.toStringAsFixed(2)} km'),
        _buildStatItem('시간', _formatDuration(widget.duration)),
        _buildStatItem('케이던스', '${widget.cadence} spm'),
        _buildStatItem('평균 페이스', widget.pace),
        _buildStatItem('칼로리', '${widget.calories} kcal'),
      ],
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: Color(0xFF0066CC).withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF0066CC).withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w500,
              color: Color(0xFF0066CC).withOpacity(0.8),
              letterSpacing: -0.2,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0066CC),
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
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
}