import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../models/workout_record.dart';
import '../../utils/theme.dart';
import 'workout_detail_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../Widgets/bottom_bar.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class CalendarScreen extends StatefulWidget {
  @override
  _CalendarScreenState createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _focusedDay;
  late DateTime _firstDay;
  late DateTime _lastDay;
  DateTime? _selectedDay;
  List<WorkoutRecord> _selectedDayRecords = [];
  int _currentRecordIndex = 0;
  String _currentUserId = '';
  String _currentUserNickname = '나';
  List<Map<String, dynamic>> _friends = [];
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<WorkoutRecord> _workoutRecords = [];
  final PageController _pageController = PageController();
  int _selectedIndex = 1;

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    _firstDay = DateTime(_focusedDay.year - 1, 1, 1);
    _lastDay = DateTime(_focusedDay.year + 1, 12, 31);
    _selectedDay = _focusedDay;
    _loadFriends();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    final user = _auth.currentUser;
    if (user == null) {
      print('사용자가 로그인되어 있지 않습니다');
      return;
    }

    try {
      print('현재 사용자 ID: ${user.uid}');
      
      // 현재 사용자 ID 즉시 설정
      setState(() {
        _currentUserId = user.uid;
      });
      
      // 현재 사용자 정보 가져오기
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        print('현재 사용자 닉네임: ${userDoc.data()?['nickname']}');
        setState(() {
          _currentUserNickname = userDoc.data()?['nickname'] ?? '나';
        });
      }

      // 친구 목록 가져오기
      final friendsSnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('Friends_Data')
          .get();
      
      print('Friends_Data 컬렉션 문서 수: ${friendsSnapshot.docs.length}');
      
      List<Map<String, dynamic>> friendsList = [];
      
      // 현재 사용자 추가
      friendsList.add({
        'uid': user.uid,
        'nickname': _currentUserNickname,
      });

      // 친구들의 정보 가져오기
      for (var friendDoc in friendsSnapshot.docs) {
        final friendId = friendDoc.id;
        final friendData = friendDoc.data();
        
        print('친구 ID: $friendId');
        print('친구 데이터: $friendData');
        
        // 친구 상태 확인 -> 상태에 관계 없이 친구로 처리
        print('친구 발견: $friendId');
        final friendUserDoc = await _firestore.collection('users').doc(friendId).get();
        if (friendUserDoc.exists) {
          print('친구 사용자 정보: ${friendUserDoc.data()}');
          friendsList.add({
            'uid': friendId,
            'nickname': friendUserDoc.data()?['nickname'] ?? '알 수 없음',
          });
        } else {
          print('친구 사용자 정보가 존재하지 않음: $friendId');
        }
      }
      
      print('최종 친구 목록: ${friendsList.map((f) => '${f['nickname']}(${f['uid']})').join(', ')}');
      
      setState(() {
        _friends = friendsList;
      });

      // 초기 운동 데이터 로드
      _loadWorkoutData();
    } catch (e) {
      print('친구 목록 로드 중 오류 발생: $e');
      // 오류 발생 시 현재 사용자만 표시
      setState(() {
        _friends = [{
          'uid': user.uid,
          'nickname': _currentUserNickname,
        }];
      });
    }
  }

  Future<void> _loadWorkoutData() async {
    final userId = _currentUserId.isEmpty ? _auth.currentUser?.uid : _currentUserId;
    List<WorkoutRecord> records = [];

    if (userId != null) {
      try {
        print('운동 데이터 로드 시작 - 사용자 ID: $userId');
        final snapshot = await _firestore
            .collection('users')
            .doc(userId)
            .collection('Running_Data')
            .orderBy('date', descending: true)
            .get();

        print('운동 데이터 문서 수: ${snapshot.docs.length}');
        
        records.addAll(snapshot.docs.map((doc) {
          final data = doc.data();
          final List<Map<String, double>> routePoints =
          (data['routePoints'] as List)
              .map((point) => Map<String, double>.from(point))
              .toList();

          String paceStr = data['pace'] as String;
          double pace = 0.0;
          if (paceStr.contains("'")) {
            final parts = paceStr.split("'");
            final minutes = int.parse(parts[0]);
            final seconds = int.parse(parts[1].replaceAll('"', ''));
            pace = minutes + (seconds / 60);
          }

          return WorkoutRecord(
            userId: userId,
            date: (data['date'] as Timestamp).toDate(),
            distance: (data['distance'] as num).toDouble(),
            duration: Duration(seconds: data['duration'] as int),
            pace: pace,
            cadence: 0,
            calories: (data['calories'] as num).toInt(),
            routePoints: routePoints,
          );
        }).toList());
        
        print('로드된 운동 기록 수: ${records.length}');
      } catch (e) {
        print('운동 데이터 로드 중 오류 발생: $e');
      }
    }

    setState(() {
      _workoutRecords = records;
      _updateSelectedRecords();
    });
  }

  // Duration을 'mm:ss' 형식으로 포맷하는 헬퍼 함수
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes분 $seconds초';
  }

  void _updateSelectedRecords() {
    if (_selectedDay == null) return;

    setState(() {
      _selectedDayRecords = _workoutRecords
          .where((record) => isSameDay(record.date, _selectedDay))
          .toList();
      _currentRecordIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '캘린더',
          style: TextStyle(fontSize: 24.sp),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          SizedBox(height: 4.h),
          _buildUserSelector(),
          SizedBox(height: 12.h),
          Container(
            height: 80.h,
            margin: EdgeInsets.only(bottom: 2.h),
            child: Stack(
              children: [
                _selectedDayRecords.isNotEmpty
                    ? _buildWorkoutSummary()
                    : _buildEmptyWorkoutSummary(),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: _buildCalendar(),
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
        },
      ),
    );
  }

  Widget _buildUserSelector() {
    return Container(
      height: 40.h,
      padding: EdgeInsets.symmetric(vertical: 4.h),
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _friends.length,
        itemBuilder: (context, index) {
          final friend = _friends[index];
          final isSelected = friend['uid'] == _currentUserId;
          return Container(
            width: (MediaQuery.of(context).size.width - 32) / 4,
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _currentUserId = friend['uid'];
                  _loadWorkoutData();
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.primaryColor
                        : AppTheme.lightTextColor.withOpacity(0.3),
                    width: 1.w,
                  ),
                ),
                child: Center(
                  child: Text(
                    friend['nickname'],
                    style: TextStyle(
                      color: isSelected
                          ? AppTheme.darkTextColor
                          : AppTheme.lightTextColor,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 14.sp,
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
      height: 50.h,
      padding: EdgeInsets.symmetric(
        vertical: 6.h,
        horizontal: 20.w,
      ),
      margin: EdgeInsets.symmetric(
        horizontal: 16.w,
        vertical: 2.h,
      ),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Center(
        child: Text(
          '날짜를 선택해 주세요',
          style: TextStyle(
            color: AppTheme.darkTextColor,
            fontSize: 16.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildWorkoutSummary() {
    if (_selectedDayRecords.isEmpty) return _buildEmptyWorkoutSummary();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 50.h,
          child: PageView.builder(
            controller: _pageController,
            itemCount: _selectedDayRecords.length,
            onPageChanged: (index) {
              setState(() {
                _currentRecordIndex = index;
              });
            },
            itemBuilder: (context, index) {
              final record = _selectedDayRecords[index];
              return Container(
                padding: EdgeInsets.symmetric(
                  vertical: 6.h,
                  horizontal: 20.w,
                ),
                margin: EdgeInsets.symmetric(
                  horizontal: 16.w,
                  vertical: 2.h,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${record.distance.toStringAsFixed(1)}km',
                            style: TextStyle(
                              color: AppTheme.darkTextColor,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12.w),
                            child: Text('•', style: TextStyle(color: Colors.grey)),
                          ),
                          Text(
                            _formatDuration(record.duration),
                            style: TextStyle(
                              color: AppTheme.darkTextColor,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12.w),
                            child: Text('•', style: TextStyle(color: Colors.grey)),
                          ),
                          Text(
                            '${record.pace.toStringAsFixed(2)} /km',
                            style: TextStyle(
                              color: AppTheme.darkTextColor,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => WorkoutDetailScreen(record: record),
                            ),
                          );
                        },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '상세보기',
                              style: TextStyle(
                                color: AppTheme.darkTextColor,
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(width: 4.w),
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 16.sp,
                              color: AppTheme.darkTextColor,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        if (_selectedDayRecords.length > 1)
          Container(
            height: 24.h,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _selectedDayRecords.length,
                (index) => Container(
                  width: 6.w,
                  height: 6.w,
                  margin: EdgeInsets.symmetric(
                    horizontal: 3.w,
                  ),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentRecordIndex == index
                        ? AppTheme.primaryColor
                        : AppTheme.primaryColor.withOpacity(0.3),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCalendar() {
    return Padding(
      padding: EdgeInsets.only(top: 8.h),
      child: TableCalendar(
        firstDay: _firstDay,
        lastDay: _lastDay,
        focusedDay: _focusedDay,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        calendarFormat: CalendarFormat.month,
        startingDayOfWeek: StartingDayOfWeek.sunday,
        headerStyle: HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: TextStyle(
            fontSize: 17.6.sp,
            fontWeight: FontWeight.bold,
          ),
          titleTextFormatter: (date, locale) {
            return '${date.year}년 ${date.month}월';
          },
          leftChevronIcon: Icon(
            Icons.chevron_left,
            color: AppTheme.darkTextColor,
            size: 20.8.sp,
          ),
          rightChevronIcon: Icon(
            Icons.chevron_right,
            color: AppTheme.darkTextColor,
            size: 20.8.sp,
          ),
          headerPadding: EdgeInsets.symmetric(vertical: 1.h),
        ),
        calendarStyle: CalendarStyle(
          outsideDaysVisible: false,
          weekendTextStyle: TextStyle(
            color: Colors.red,
            fontSize: 14.4.sp,
          ),
          holidayTextStyle: TextStyle(
            color: Colors.red,
            fontSize: 14.4.sp,
          ),
          todayDecoration: BoxDecoration(
            border: Border.all(color: AppTheme.primaryColor, width: 1.5.w),
            shape: BoxShape.circle,
          ),
          todayTextStyle: TextStyle(
            color: AppTheme.darkTextColor,
            fontSize: 14.4.sp,
          ),
          selectedDecoration: BoxDecoration(
            color: AppTheme.primaryColor,
            shape: BoxShape.circle,
          ),
          selectedTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 14.4.sp,
          ),
          defaultTextStyle: TextStyle(
            color: AppTheme.darkTextColor,
            fontSize: 14.4.sp,
          ),
          markerSize: 0,
          markersAlignment: AlignmentDirectional.center,
          cellMargin: EdgeInsets.all(0.5.w),
          cellPadding: EdgeInsets.zero,
          rangeHighlightScale: 1.0,
        ),
        calendarBuilders: CalendarBuilders(
          defaultBuilder: (context, day, focusedDay) {
            final hasWorkout = _workoutRecords.any((record) => isSameDay(record.date, day));

            if (hasWorkout) {
              return Container(
                margin: EdgeInsets.all(0.5.w),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${day.day}',
                    style: TextStyle(
                      color: AppTheme.darkTextColor,
                      fontSize: 14.4.sp,
                    ),
                  ),
                ),
              );
            }
            return null;
          },
        ),
        onDaySelected: _onDaySelected,
        onPageChanged: (focusedDay) {
          setState(() {
            _focusedDay = focusedDay;
          });
        },
      ),
    );
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;
      _updateSelectedRecords();
    });
  }
}