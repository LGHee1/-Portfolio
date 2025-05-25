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

class WorkoutSummaryScreen extends StatefulWidget {
  final double distance;
  final Duration duration;
  final String pace;
  final int cadence;
  final int calories;
  final List<LatLng> routePoints;
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
  }

  void _loadUserData() {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    setState(() {
      _userNickname = userProvider.nickname;
    });
  }

  void _initializePolylines() {
    if (widget.routePoints.isNotEmpty) {
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: widget.routePoints,
          color: Colors.blue,
          width: 5,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round,
        ),
      );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$_userNickname님의 운동 완료'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.black),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      drawer: const Menu(),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Stack(
                children: [
                  Column(
                    children: [
                      // 지도 섹션 (1/3)
                      Expanded(
                        flex: 1,
                        child: GoogleMap(
                          mapType: MapType.normal,
                          initialCameraPosition: CameraPosition(
                            target: widget.routePoints.isNotEmpty
                                ? widget.routePoints.first
                                : (_initialPosition ?? const LatLng(37.5665, 126.9780)),
                            zoom: 15,
                          ),
                          onMapCreated: _onMapCreated,
                          polylines: {
                            // 실제 달린 경로 (파란색)
                            if (widget.routePoints.isNotEmpty)
                              Polyline(
                                polylineId: const PolylineId('route'),
                                points: widget.routePoints,
                                color: Colors.blue,
                                width: 5,
                              ),
                            // 추천 코스 (초록색)
                            if (widget.isRecommendedCourse && widget.recommendedRoutePoints.isNotEmpty)
                              Polyline(
                                polylineId: const PolylineId('recommendedRoute'),
                                points: widget.recommendedRoutePoints,
                                color: Colors.green,
                                width: 5,
                              ),
                          },
                          markers: _markers,
                          myLocationEnabled: true,
                          myLocationButtonEnabled: false,
                          zoomControlsEnabled: true,
                          mapToolbarEnabled: false,
                        ),
                      ),
                      // 운동 정보 섹션 (2/3)
                      Expanded(
                        flex: 2,
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          width: double.infinity,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '운동 정보',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF764BA2),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Expanded(
                                child: _buildStatsGrid(),
                              ),
                              // 게시글 작성 버튼
                              Padding(
                                padding: const EdgeInsets.only(top: 16.0),
                                child: Align(
                                  alignment: Alignment.bottomCenter,
                                  child: ElevatedButton(
                                    onPressed: () {
                                      if (widget.routePoints.isEmpty) {
                                        showDialog(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            content: const Text('운동 경로가 없어 작성할 수 없습니다.'),
                                            actions: [
                                              Align(
                                                alignment: Alignment.bottomRight,
                                                child: TextButton(
                                                  onPressed: () {
                                                    Navigator.of(context).pop();
                                                  },
                                                  child: const Text('확인'),
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
                                              },
                                            ),
                                          ),
                                        );
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF764BA2),
                                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                    ),
                                    child: const Text(
                                      '현재 운동코스 게시글 작성',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
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
                      right: 24,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            isLiked = !isLiked;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isLiked ? Icons.favorite : Icons.favorite_border,
                                color: isLiked ? Colors.red : Colors.grey,
                                size: 24,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                likeCount.toString(),
                                style: TextStyle(
                                  color: isLiked ? Colors.red : Colors.grey,
                                  fontWeight: FontWeight.bold,
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
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF764BA2).withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF764BA2),
              fontSize: 16,
              fontWeight: FontWeight.bold,
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