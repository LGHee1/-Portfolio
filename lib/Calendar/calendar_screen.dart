import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../models/workout_record.dart';
import '../../utils/theme.dart';
import 'workout_detail_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class CalendarScreen extends StatefulWidget {
  @override
  _CalendarScreenState createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _focusedDay;
  late DateTime _firstDay;
  late DateTime _lastDay;
  DateTime? _selectedDay;
  WorkoutRecord? _selectedRecord;
  String _currentUser = '나';
  final List<String> _friends = ['나', '친구1', '친구2', '친구3', '친구4', '친구5'];
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<WorkoutRecord> _workoutRecords = [];

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    _firstDay = DateTime(_focusedDay.year - 1, 1, 1);
    _lastDay = DateTime(_focusedDay.year + 1, 12, 31);
    _selectedDay = _focusedDay;
    _loadWorkoutData();
  }

  Future<void> _loadWorkoutData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      print('운동 데이터 로드 시작 - 사용자: ${user.uid}');
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('Running_Data')
          .orderBy('date', descending: true)
          .get();

      print('가져온 운동 데이터 수: ${snapshot.docs.length}');

      setState(() {
        _workoutRecords = snapshot.docs.map((doc) {
          final data = doc.data();
          print('운동 데이터: ${data['date']} - 거리: ${data['distance']}km');

          final List<Map<String, double>> routePoints =
          (data['routePoints'] as List)
              .map((point) => Map<String, double>.from(point))
              .toList();

          // Convert pace string (e.g., "5'30"") to double
          String paceStr = data['pace'] as String;
          double pace = 0.0;
          if (paceStr.contains("'")) {
            final parts = paceStr.split("'");
            final minutes = int.parse(parts[0]);
            final seconds = int.parse(parts[1].replaceAll('"', ''));
            pace = minutes + (seconds / 60);
          }

          final record = WorkoutRecord(
            userId: user.uid,
            date: (data['date'] as Timestamp).toDate(),
            distance: (data['distance'] as num).toDouble(),
            duration: Duration(seconds: data['duration'] as int),
            pace: pace,
            cadence: 0, // Not stored in Firebase yet
            calories: data['calories'] as int,
            routePoints: routePoints,
          );

          print('변환된 운동 기록: ${record.date} - 거리: ${record.distance}km');
          return record;
        }).toList();
        _updateSelectedRecord();
      });
    } catch (e) {
      print('운동 데이터 로드 중 오류 발생: $e');
    }
  }

  void _updateSelectedRecord() {
    if (_selectedDay == null) return;

    print('선택된 날짜: $_selectedDay');
    print('현재 운동 기록 수: ${_workoutRecords.length}');

    for (var record in _workoutRecords) {
      print('비교 중: ${record.date} - 선택된 날짜: $_selectedDay');
      if (isSameDay(record.date, _selectedDay)) {
        print('일치하는 운동 기록 발견: ${record.date} - 거리: ${record.distance}km');
      }
    }

    _selectedRecord = _workoutRecords.firstWhere(
          (record) {
        final isSame = isSameDay(record.date, _selectedDay);
        print('날짜 비교: ${record.date} vs $_selectedDay = $isSame');
        return isSame;
      },
      orElse: () {
        print('일치하는 운동 기록 없음');
        return WorkoutRecord(
          userId: _currentUser,
          date: _selectedDay!,
          distance: 0,
          duration: Duration.zero,
          pace: 0,
          cadence: 0,
          calories: 0,
          routePoints: [],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('캘린더'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          SizedBox(height: 16),
          _buildUserSelector(),
          SizedBox(height: 24),
          Container(
            height: 80,
            margin: EdgeInsets.only(bottom: 24),
            child: _selectedRecord != null
                ? _buildWorkoutSummary()
                : _buildEmptyWorkoutSummary(),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: _buildCalendar(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserSelector() {
    return Container(
      height: 60,
      padding: EdgeInsets.symmetric(vertical: 8),
      margin: EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _friends.length,
        itemBuilder: (context, index) {
          final friend = _friends[index];
          final isSelected = friend == _currentUser;
          return Container(
            width: (MediaQuery.of(context).size.width - 32) / 4,
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _currentUser = friend;
                  _updateSelectedRecord();
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  color:
                  isSelected ? AppTheme.primaryColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.primaryColor
                        : AppTheme.lightTextColor.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    friend,
                    style: TextStyle(
                      color: isSelected
                          ? AppTheme.darkTextColor
                          : AppTheme.lightTextColor,
                      fontWeight:
                      isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyWorkoutSummary() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '날짜를 선택해 주세요',
                  style: TextStyle(
                    color: AppTheme.darkTextColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutSummary() {
    if (_selectedRecord == null) return SizedBox.shrink();

    return Container(
      padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: _selectedRecord!.distance > 0
          ? Row(
        children: [
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${_selectedRecord!.distance.toStringAsFixed(1)}km',
                  style: TextStyle(
                    color: AppTheme.darkTextColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('•', style: TextStyle(color: Colors.grey)),
                ),
                Text(
                  '${_selectedRecord!.duration.inMinutes}분',
                  style: TextStyle(
                    color: AppTheme.darkTextColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('•', style: TextStyle(color: Colors.grey)),
                ),
                Text(
                  '${_selectedRecord!.pace.toStringAsFixed(2)}분/km',
                  style: TextStyle(
                    color: AppTheme.darkTextColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      WorkoutDetailScreen(record: _selectedRecord!),
                ),
              );
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '상세보기',
                  style: TextStyle(
                    color: AppTheme.darkTextColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: AppTheme.darkTextColor,
                ),
              ],
            ),
          ),
        ],
      )
          : Row(
        children: [
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '날짜를 선택해 주세요',
                  style: TextStyle(
                    color: AppTheme.darkTextColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar() {
    print('캘린더 빌드 - 현재 운동 기록 수: ${_workoutRecords.length}');
    return TableCalendar(
      firstDay: _firstDay,
      lastDay: _lastDay,
      focusedDay: _focusedDay,
      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
      calendarFormat: CalendarFormat.month,
      startingDayOfWeek: StartingDayOfWeek.sunday,
      headerStyle: HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
        titleTextFormatter: (date, locale) {
          return '${date.year}년 ${date.month}월';
        },
        leftChevronIcon:
        Icon(Icons.chevron_left, color: AppTheme.darkTextColor),
        rightChevronIcon:
        Icon(Icons.chevron_right, color: AppTheme.darkTextColor),
      ),
      calendarStyle: CalendarStyle(
        outsideDaysVisible: false,
        weekendTextStyle: TextStyle(color: Colors.red),
        holidayTextStyle: TextStyle(color: Colors.red),
        todayDecoration: BoxDecoration(
          border: Border.all(color: AppTheme.primaryColor, width: 2),
          shape: BoxShape.circle,
        ),
        todayTextStyle: TextStyle(color: AppTheme.darkTextColor),
        selectedDecoration: BoxDecoration(
          color: AppTheme.primaryColor,
          shape: BoxShape.circle,
        ),
        selectedTextStyle: TextStyle(color: Colors.white),
        defaultTextStyle: TextStyle(color: AppTheme.darkTextColor),
        markerSize: 0,
        markersAlignment: AlignmentDirectional.center,
        cellMargin: EdgeInsets.all(4),
        rangeHighlightScale: 1.0,
      ),
      calendarBuilders: CalendarBuilders(
        defaultBuilder: (context, day, focusedDay) {
          final hasWorkout = _workoutRecords.any((record) {
            final isSame = isSameDay(record.date, day);
            if (isSame) {
              print('운동 기록 있는 날짜 발견: $day - 거리: ${record.distance}km');
            }
            return isSame;
          });

          if (hasWorkout) {
            return Container(
              margin: EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '${day.day}',
                  style: TextStyle(color: AppTheme.darkTextColor),
                ),
              ),
            );
          }
          return null;
        },
      ),
      onDaySelected: (selectedDay, focusedDay) {
        setState(() {
          _selectedDay = selectedDay;
          _focusedDay = focusedDay;
          _updateSelectedRecord();
        });
      },
      onPageChanged: (focusedDay) {
        setState(() {
          _focusedDay = focusedDay;
        });
      },
    );
  }
}