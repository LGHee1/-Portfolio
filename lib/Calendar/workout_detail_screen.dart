import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../models/workout_record.dart';
import '../../utils/theme.dart';
import 'package:intl/intl.dart';
import '../Post/post_create.dart';
import '../Post/post_list.dart';
import '../Running/workout_screen.dart';
import '../home_screen.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../Widgets/bottom_bar.dart';

class WorkoutDetailScreen extends StatefulWidget {
  final WorkoutRecord record;

  const WorkoutDetailScreen({Key? key, required this.record}) : super(key: key);

  @override
  State<WorkoutDetailScreen> createState() => _WorkoutDetailScreenState();
}

class _WorkoutDetailScreenState extends State<WorkoutDetailScreen> {
  late GoogleMapController _mapController;
  final Set<Polyline> _polylines = {};
  LatLng? _initialPosition;
  int _selectedIndex = 1;

  @override
  void initState() {
    super.initState();
    _initializePolylines();
  }

  void _initializePolylines() {
    if (widget.record.routePoints.isNotEmpty) {
      final List<LatLng> points = widget.record.routePoints
          .map((point) => LatLng(point['latitude']!, point['longitude']!))
          .toList();

      _polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: points,
          color: const Color(0xFF764BA2),
          width: 8,
          patterns: [PatternItem.dash(30), PatternItem.gap(10)],
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round,
        ),
      );

      // Set initial position to the first point of the route
      _initialPosition = points.first;
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (widget.record.routePoints.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.animateCamera(
          CameraUpdate.newLatLngBounds(
            _getBoundsFromLatLngList(_polylines.first.points),
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
      if (minLng == null || latLng.longitude < minLng)
        minLng = latLng.longitude;
      if (maxLng == null || latLng.longitude > maxLng)
        maxLng = latLng.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(minLat!, minLng!),
      northeast: LatLng(maxLat!, maxLng!),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String hours = twoDigits(duration.inHours);
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          DateFormat('yyyy년 M월 d일').format(widget.record.date),
          style: TextStyle(fontSize: 18.sp),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 16.w),
            child: ElevatedButton(
              onPressed: () {
                if (widget.record.routePoints.isEmpty) {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      content: const Text('운동 경로가 없어 게시글을 작성할 수 없습니다.'),
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
                  return;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PostCreatePage(
                      workoutData: {
                        'routePoints': widget.record.routePoints,
                        'date': widget.record.date,
                        'distance': widget.record.distance,
                        'duration': widget.record.duration.inSeconds,
                      },
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
                '게시글 작성',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            height: 250.h,
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
              child: _initialPosition == null
                  ? Center(
                      child: Text(
                        '경로 데이터가 없습니다',
                        style: TextStyle(
                          color: AppTheme.lightTextColor,
                          fontSize: 16.sp,
                        ),
                      ),
                    )
                  : GoogleMap(
                      onMapCreated: _onMapCreated,
                      initialCameraPosition: CameraPosition(
                        target: _initialPosition!,
                        zoom: 15,
                      ),
                      polylines: _polylines,
                      myLocationEnabled: false,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                      mapToolbarEnabled: false,
                    ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '운동 정보',
                      style: TextStyle(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.darkTextColor,
                      ),
                    ),
                    SizedBox(height: 16.h),
                    _buildStatsGrid(),
                    SizedBox(height: 20.h),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomBar(
        selectedIndex: _selectedIndex,
        onTabSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
          if (index == 0) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const WorkoutScreen()),
            );
          } else if (index == 1) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const ScreenHome()),
            );
          } else if (index == 2) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const PostListPage()),
            );
          }
        },
      ),
    );
  }

  Widget _buildStatsGrid() {
    return Column(
      children: [
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 2,
          mainAxisSpacing: 16.h,
          crossAxisSpacing: 16.w,
          children: [
            _buildStatItem('거리', '${widget.record.distance.toStringAsFixed(2)} km'),
            _buildStatItem('시간', _formatDuration(widget.record.duration)),
            _buildStatItem('케이던스', '${widget.record.cadence} spm'),
            _buildStatItem('평균 페이스', '${widget.record.pace.toStringAsFixed(2)} /km'),
            _buildStatItem('칼로리', '${widget.record.calories} kcal'),
          ],
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppTheme.lightTextColor,
              fontSize: 14.sp,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            value,
            style: TextStyle(
              color: AppTheme.darkTextColor,
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}