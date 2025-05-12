import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'utils/theme.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class WorkoutSummaryScreen extends StatefulWidget {
  final double distance;
  final int duration;
  final double pace;
  final double calories;
  final List<Map<String, dynamic>> routePoints;

  const WorkoutSummaryScreen({
    Key? key,
    required this.distance,
    required this.duration,
    required this.pace,
    required this.calories,
    required this.routePoints,
  }) : super(key: key);

  @override
  State<WorkoutSummaryScreen> createState() => _WorkoutSummaryScreenState();
}

class _WorkoutSummaryScreenState extends State<WorkoutSummaryScreen> {
  bool isLiked = false;
  late GoogleMapController _mapController;
  final Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    _initializePolylines();
  }

  void _initializePolylines() {
    final List<LatLng> points = widget.routePoints.map((point) {
      return LatLng(point['latitude'], point['longitude']);
    }).toList();

    _polylines.add(
      Polyline(
        polylineId: const PolylineId('route'),
        points: points,
        color: Colors.blue,
        width: 8,
        patterns: [PatternItem.dash(30), PatternItem.gap(10)],
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        jointType: JointType.round,
      ),
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
        title: const Text('운동 완료'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: widget.routePoints.isNotEmpty
                      ? LatLng(
                          widget.routePoints.first['latitude'],
                          widget.routePoints.first['longitude'],
                        )
                      : const LatLng(37.5665, 126.9780),
                  zoom: 15,
                ),
                onMapCreated: (GoogleMapController controller) {
                  _mapController = controller;
                },
                polylines: _polylines,
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
                zoomControlsEnabled: true,
                mapToolbarEnabled: false,
              ),
            ),
            Stack(
              children: [
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        isLiked = !isLiked;
                      });
                    },
                    child: Icon(
                      isLiked ? Icons.favorite : Icons.favorite_border,
                      color: isLiked ? Colors.red : Colors.grey,
                      size: 32,
                    ),
                  ),
                ),
              ],
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(20),
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
                    _buildStatsGrid(),
                  ],
                ),
              ),
            ),
          ],
        ),
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
        _buildStatItem('시간', _formatDuration(Duration(seconds: widget.duration))),
        _buildStatItem('케이던스', '${widget.pace} spm'),
        _buildStatItem('평균 페이스', '${widget.pace} km/h'),
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
} 