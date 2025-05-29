import 'package:flutter/material.dart';
import 'post_view.dart';
import 'tag_list.dart';
import '../models/tag.dart';
import '../Widgets/bottom_bar.dart';
import '../home_screen.dart';
import '../Running/workout_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class PostListPage extends StatefulWidget {
  const PostListPage({super.key});

  @override
  State<PostListPage> createState() => _PostListPageState();
}

class _PostListPageState extends State<PostListPage> {
  List<Tag> selectedTags = [];
  int _selectedIndex = 2;
  Position? _currentPosition;
  List<Map<String, dynamic>> _posts = [];
  bool _isLoading = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDocument;
  static const int _initialLimit = 5;
  static const int _loadMoreLimit = 10;
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  List<Map<String, dynamic>> _filteredPosts = [];
  bool _isFiltered = false;
  String _sortBy = 'distance'; // 'distance' 또는 'likes'
  Set<String> _likedPosts = {}; // 좋아요한 게시글 ID 저장

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _loadLikedPosts();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sortPosts(); // 화면이 다시 표시될 때 정렬 상태 유지
  }

  Future<void> _getCurrentLocation() async {
    try {
      print('위치 정보 요청 시작');
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('위치 서비스가 비활성화되어 있습니다');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('위치 권한이 거부되었습니다');
          return;
        }
      }

      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      print('현재 위치: ${position.latitude}, ${position.longitude}');

      setState(() {
        _currentPosition = position;
        _markers.clear(); // 기존 마커 제거
        _markers.add(
          Marker(
            markerId: const MarkerId('current_location'),
            position: LatLng(position.latitude, position.longitude),
            infoWindow: const InfoWindow(title: '현재 위치'),
          ),
        );
      });

      // 지도 컨트롤러가 있다면 카메라 이동
      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(position.latitude, position.longitude),
              zoom: 15,
            ),
          ),
        );
      }

      _loadPosts();
    } catch (e) {
      print('위치 정보를 가져오는데 실패했습니다: $e');
    }
  }

  Future<void> _loadPosts({bool isInitial = true}) async {
    if (_isLoading || (!isInitial && !_hasMore)) return;

    try {
      setState(() {
        _isLoading = true;
      });

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('사용자가 로그인되어 있지 않습니다');
        return;
      }
      print('현재 로그인된 사용자: ${user.uid}');

      // 모든 사용자의 Post_Data 컬렉션에서 게시글 가져오기
      Query query = FirebaseFirestore.instance
          .collectionGroup('Post_Data')
          .orderBy('createdAt', descending: true)
          .limit(isInitial ? _initialLimit : _loadMoreLimit);

      if (!isInitial && _lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      print('게시글 쿼리 실행 중...');
      try {
        final postsSnapshot = await query.get();
        print('쿼리 결과: ${postsSnapshot.docs.length}개의 게시글 발견');

        if (postsSnapshot.docs.isEmpty) {
          print('게시글이 없습니다');
          setState(() {
            _hasMore = false;
            _isLoading = false;
          });
          return;
        }

        _lastDocument = postsSnapshot.docs.last;

        List<Map<String, dynamic>> newPosts = [];
        for (var doc in postsSnapshot.docs) {
          try {
            final Map<String, dynamic> data =
                doc.data() as Map<String, dynamic>;
            data['id'] = doc.id;
            data['userId'] = doc.reference.parent.parent?.id;
            print('게시글 처리 중: ID=${doc.id}, 작성자=${data['userId']}');

            if (data['userId'] != null) {
              final userDoc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(data['userId'] as String)
                  .get();
              if (userDoc.exists) {
                data['nickname'] = userDoc.data()?['nickname'] ?? '알 수 없음';
                print('작성자 닉네임: ${data['nickname']}');
              }
            }

            if (data['routePoints'] != null &&
                (data['routePoints'] as List).isNotEmpty) {
              final firstPoint = (data['routePoints'] as List).first;
              data['startLatitude'] = firstPoint['latitude'];
              data['startLongitude'] = firstPoint['longitude'];
            }

            newPosts.add(data);
          } catch (e) {
            print('게시글 데이터 처리 중 오류 발생: $e');
          }
        }

        print('처리된 게시글 수: ${newPosts.length}');
        setState(() {
          if (isInitial) {
            _posts = newPosts;
            _filteredPosts = newPosts;
          } else {
            _posts.addAll(newPosts);
            if (!_isFiltered) {
              _filteredPosts.addAll(newPosts);
            }
          }
          _hasMore = postsSnapshot.docs.length ==
              (isInitial ? _initialLimit : _loadMoreLimit);
          _isLoading = false;
        });

        if (_currentPosition != null) {
          _sortPosts();
        }
      } catch (e) {
        print('게시글을 불러오는데 실패했습니다: $e');
        setState(() {
          _isLoading = false;
          _hasMore = false;
        });
      }
    } catch (e) {
      print('게시글을 불러오는데 실패했습니다: $e');
      setState(() {
        _isLoading = false;
        _hasMore = false;
      });
    }
  }

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    // 두 지점 간의 거리를 미터 단위로 계산
    double distanceInMeters =
        Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
    // 미터를 킬로미터로 변환하고 소수점 첫째 자리까지 반올림
    return (distanceInMeters / 1000).roundToDouble();
  }

  void _filterPostsByTags() async {
    if (selectedTags.isEmpty) {
      setState(() {
        _filteredPosts = _posts;
        _isFiltered = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      List<Map<String, dynamic>> filtered = _posts.where((post) {
        if (post['tags'] == null) return false;
        List<String> postTags = List<String>.from(post['tags']);

        // 선택된 모든 태그가 게시글의 태그에 포함되어 있는지 확인
        return selectedTags
            .every((selectedTag) => postTags.contains(selectedTag.name));
      }).toList();

      setState(() {
        _filteredPosts = filtered;
        _isFiltered = true;
        _isLoading = false;
      });
    } catch (e) {
      print('게시글 필터링 중 오류 발생: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadLikedPosts() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final likedPostsDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('LikedPosts')
          .get();

      setState(() {
        _likedPosts = likedPostsDoc.docs.map((doc) => doc.id).toSet();
      });
    } catch (e) {
      print('좋아요한 게시글 로드 중 오류: $e');
    }
  }

  Future<void> _toggleLike(String postId, String userId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final postRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('Post_Data')
          .doc(postId);

      final likedPostRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('LikedPosts')
          .doc(postId);

      // 트랜잭션을 사용하여 좋아요 처리
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final postDoc = await transaction.get(postRef);
        if (!postDoc.exists) {
          throw Exception('게시물을 찾을 수 없습니다.');
        }

        final currentLikes = postDoc.data()?['likes'] ?? 0;

        if (_likedPosts.contains(postId)) {
          // 좋아요 취소
          transaction.update(postRef, {'likes': currentLikes - 1});
          transaction.delete(likedPostRef);
        } else {
          // 좋아요 추가
          transaction.update(postRef, {'likes': currentLikes + 1});
          transaction
              .set(likedPostRef, {'timestamp': FieldValue.serverTimestamp()});
        }
      });

      // 상태 업데이트
      setState(() {
        if (_likedPosts.contains(postId)) {
          _likedPosts.remove(postId);
          // 게시물의 좋아요 수 업데이트
          final postIndex = _posts.indexWhere((post) => post['id'] == postId);
          if (postIndex != -1) {
            _posts[postIndex]['likes'] = (_posts[postIndex]['likes'] ?? 1) - 1;
            if (!_isFiltered) {
              _filteredPosts[postIndex]['likes'] = _posts[postIndex]['likes'];
            }
          }
        } else {
          _likedPosts.add(postId);
          // 게시물의 좋아요 수 업데이트
          final postIndex = _posts.indexWhere((post) => post['id'] == postId);
          if (postIndex != -1) {
            _posts[postIndex]['likes'] = (_posts[postIndex]['likes'] ?? 0) + 1;
            if (!_isFiltered) {
              _filteredPosts[postIndex]['likes'] = _posts[postIndex]['likes'];
            }
          }
        }
      });
    } catch (e) {
      print('좋아요 토글 중 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('좋아요 처리 중 오류가 발생했습니다. 다시 시도해주세요.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _sortPosts() {
    setState(() {
      if (_sortBy == 'distance') {
        _filteredPosts.sort((a, b) {
          if (_currentPosition == null) return 0;
          double distanceA = _calculateDistance(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
              a['startLatitude'] ?? 0,
              a['startLongitude'] ?? 0);
          double distanceB = _calculateDistance(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
              b['startLatitude'] ?? 0,
              b['startLongitude'] ?? 0);
          return distanceA.compareTo(distanceB);
        });
      } else {
        _filteredPosts.sort((a, b) {
          int likesA = a['likes'] ?? 0;
          int likesB = b['likes'] ?? 0;
          return likesB.compareTo(likesA); // 좋아요 많은 순
        });
      }
    });
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
          icon: Icon(Icons.arrow_back, size: 24.sp, color: Colors.black87),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const ScreenHome()),
            );
          },
        ),
        title: Text(
          '추천 코스',
          style: TextStyle(
            fontSize: 22.sp,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Container(
            height: 250.h,
            margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20.r),
              child: _currentPosition == null
                  ? Container(
                      color: Colors.grey[200],
                      child: Center(
                        child: Text(
                          '위치 정보를 가져오는 중...',
                          style: TextStyle(
                            fontSize: 16.sp,
                            color: Colors.black54,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    )
                  : GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: LatLng(
                          _currentPosition!.latitude,
                          _currentPosition!.longitude,
                        ),
                        zoom: 15,
                      ),
                      markers: _markers,
                      onMapCreated: (controller) {
                        _mapController = controller;
                      },
                      myLocationEnabled: true,
                      myLocationButtonEnabled: true,
                    ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildSortButton(
                      '거리순',
                      _sortBy == 'distance',
                      () {
                        setState(() {
                          _sortBy = 'distance';
                        });
                        _sortPosts();
                      },
                    ),
                    SizedBox(width: 12.w),
                    _buildSortButton(
                      '좋아요순',
                      _sortBy == 'likes',
                      () {
                        setState(() {
                          _sortBy = 'likes';
                        });
                        _sortPosts();
                      },
                    ),
                  ],
                ),
                SizedBox(height: 16.h),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  height: 48.h,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24.r),
                    border: Border.all(color: Colors.grey[300]!),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => TagListPage(
                                  onTagsSelected: (tags) {
                                    setState(() {
                                      selectedTags = tags;
                                    });
                                  },
                                  initialSelectedTags: selectedTags,
                                ),
                              ),
                            );
                            if (result != null) {
                              setState(() {
                                selectedTags = result;
                              });
                              _filterPostsByTags();
                            }
                          },
                          child: selectedTags.isEmpty
                              ? Text(
                                  '원하는 태그를 추가하세요',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 15.sp,
                                    fontWeight: FontWeight.w500,
                                  ),
                                )
                              : SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: selectedTags.map((tag) {
                                      return Padding(
                                        padding: EdgeInsets.only(right: 8.w),
                                        child: Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 12.w,
                                            vertical: 6.h,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Color(0xFFE7EFA2),
                                            borderRadius:
                                                BorderRadius.circular(16.r),
                                            border: Border.all(
                                              color: Color(0xFFE7EFA2)
                                                  .withOpacity(0.5),
                                              width: 1,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                tag.name,
                                                style: TextStyle(
                                                  fontSize: 14.sp,
                                                  fontWeight: FontWeight.w500,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                              SizedBox(width: 4.w),
                                              GestureDetector(
                                                onTap: () {
                                                  setState(() {
                                                    selectedTags.remove(tag);
                                                  });
                                                  _filterPostsByTags();
                                                },
                                                child: Icon(
                                                  Icons.close,
                                                  size: 16.sp,
                                                  color: Colors.black54,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                        ),
                      ),
                      GestureDetector(
                        onTap: _filterPostsByTags,
                        child: Padding(
                          padding: EdgeInsets.only(left: 8.w),
                          child: Icon(
                            Icons.search,
                            color: Colors.grey[600],
                            size: 22.sp,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: _filteredPosts.length,
                    padding:
                        EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                    itemBuilder: (context, index) {
                      final post = _filteredPosts[index];
                      return Container(
                        margin: EdgeInsets.only(bottom: 12.h),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16.r),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ListTile(
                          contentPadding: EdgeInsets.all(16.w),
                          title: Text(
                            post['title'] ?? '제목 없음',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 17.sp,
                              color: Colors.black87,
                              letterSpacing: -0.3,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(height: 8.h),
                              Text(
                                post['nickname'] ?? '작성자',
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  color: Colors.black54,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (_currentPosition != null &&
                                  post['startLatitude'] != null &&
                                  post['startLongitude'] != null)
                                Padding(
                                  padding: EdgeInsets.only(top: 4.h),
                                  child: Text(
                                    '시작점까지 거리: ${_calculateDistance(_currentPosition!.latitude, _currentPosition!.longitude, post['startLatitude'], post['startLongitude']).toStringAsFixed(1)}km',
                                    style: TextStyle(
                                      fontSize: 14.sp,
                                      color: Color(0xFF0066CC),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              SizedBox(height: 8.h),
                              Row(
                                children: [
                                  Icon(Icons.route,
                                      size: 16.sp, color: Colors.black54),
                                  SizedBox(width: 4.w),
                                  Text(
                                    '운동 거리: ${(post['distance'] ?? 0).toStringAsFixed(1)}km',
                                    style: TextStyle(
                                      fontSize: 14.sp,
                                      color: Colors.black54,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(width: 16.w),
                                  Icon(
                                    Icons.favorite,
                                    size: 16.sp,
                                    color: Colors.red[400],
                                  ),
                                  SizedBox(width: 4.w),
                                  Text(
                                    '${post['likes'] ?? 0}',
                                    style: TextStyle(
                                      fontSize: 14.sp,
                                      color: Colors.black54,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              if (post['tags'] != null &&
                                  (post['tags'] as List).isNotEmpty)
                                Padding(
                                  padding: EdgeInsets.only(top: 8.h),
                                  child: Wrap(
                                    spacing: 6.w,
                                    runSpacing: 6.h,
                                    children: (post['tags'] as List)
                                        .map<Widget>((tag) => Container(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 10.w,
                                                vertical: 4.h,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Color(0xFFE7EFA2),
                                                borderRadius:
                                                    BorderRadius.circular(12.r),
                                                border: Border.all(
                                                  color: Color(0xFFE7EFA2)
                                                      .withOpacity(0.5),
                                                  width: 1,
                                                ),
                                              ),
                                              child: Text(
                                                tag.toString(),
                                                style: TextStyle(
                                                  fontSize: 12.sp,
                                                  fontWeight: FontWeight.w500,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                            ))
                                        .toList(),
                                  ),
                                ),
                            ],
                          ),
                          trailing: Container(
                            width: 80.w,
                            height: 80.h,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12.r),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: post['imageUrls'] != null &&
                                    (post['imageUrls'] as List).isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(12.r),
                                    child: Image.network(
                                      post['imageUrls'][0],
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                        return Container(
                                          color: Colors.grey[200],
                                          child: Icon(
                                            Icons.image,
                                            color: Colors.grey[400],
                                            size: 32.sp,
                                          ),
                                        );
                                      },
                                    ),
                                  )
                                : Container(
                                    color: Colors.grey[200],
                                    child: Icon(
                                      Icons.image,
                                      color: Colors.grey[400],
                                      size: 32.sp,
                                    ),
                                  ),
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PostViewPage(
                                  postData: post,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
                if (_hasMore)
                  Padding(
                    padding: EdgeInsets.all(16.w),
                    child: ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : () => _loadPosts(isInitial: false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Color(0xFF0066CC),
                        elevation: 2,
                        shadowColor: Colors.black.withOpacity(0.1),
                        minimumSize: Size(double.infinity, 50.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.r),
                          side: BorderSide(
                            color: Color(0xFF0066CC).withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                      ),
                      child: _isLoading
                          ? SizedBox(
                              width: 24.w,
                              height: 24.w,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFF0066CC)),
                              ),
                            )
                          : Text(
                              '더보기',
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.3,
                              ),
                            ),
                    ),
                  ),
              ],
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

  Widget _buildSortButton(
      String text, bool isSelected, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? Color(0xFF0066CC) : Colors.white,
        foregroundColor: isSelected ? Colors.white : Colors.black87,
        elevation: isSelected ? 2 : 0,
        shadowColor: Colors.black.withOpacity(0.1),
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
          side: BorderSide(
            color: isSelected ? Color(0xFF0066CC) : Colors.grey[300]!,
            width: 1,
          ),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 15.sp,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
      ),
    );
  }
} 