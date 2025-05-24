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
    print('PostListPage 초기화');
    _getCurrentLocation();
    _filteredPosts = _posts;
    _loadLikedPosts(); // 좋아요한 게시글 로드
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
        desiredAccuracy: LocationAccuracy.high
      );
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

      print('게시글 로딩 시작');
      
      // 현재 로그인한 사용자 확인
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('사용자가 로그인되어 있지 않습니다');
        return;
      }

      // 모든 사용자의 Post_Data를 가져오기 위한 쿼리
      Query query = FirebaseFirestore.instance
          .collectionGroup('Post_Data')
          .orderBy('createdAt', descending: true)
          .limit(isInitial ? _initialLimit : _loadMoreLimit);

      if (!isInitial && _lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      final postsSnapshot = await query.get();

      print('가져온 게시글 수: ${postsSnapshot.docs.length}');
      
      if (postsSnapshot.docs.isEmpty) {
        setState(() {
          _hasMore = false;
          _isLoading = false;
        });
        return;
      }

      _lastDocument = postsSnapshot.docs.last;
      
      List<Map<String, dynamic>> newPosts = [];
      for (var doc in postsSnapshot.docs) {
        final Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        data['userId'] = doc.reference.parent.parent?.id;
        
        // 작성자 정보 가져오기
        if (data['userId'] != null) {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(data['userId'] as String)
              .get();
          if (userDoc.exists) {
            data['nickname'] = userDoc.data()?['nickname'] ?? '알 수 없음';
          }
        }

        // 운동 시작점 좌표 계산
        if (data['routePoints'] != null && (data['routePoints'] as List).isNotEmpty) {
          final firstPoint = (data['routePoints'] as List).first;
          data['startLatitude'] = firstPoint['latitude'];
          data['startLongitude'] = firstPoint['longitude'];
        }
        
        newPosts.add(data);
        print('게시글 데이터: $data');
      }

      // 현재 위치가 있는 경우 거리순으로 정렬
      if (_currentPosition != null) {
        newPosts.sort((a, b) {
          double distanceA = _calculateDistance(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            a['startLatitude'] ?? 0,
            a['startLongitude'] ?? 0
          );
          double distanceB = _calculateDistance(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            b['startLatitude'] ?? 0,
            b['startLongitude'] ?? 0
          );
          return distanceA.compareTo(distanceB); // 거리가 가까운 순으로 정렬
        });
      }

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
        _hasMore = postsSnapshot.docs.length == (isInitial ? _initialLimit : _loadMoreLimit);
        _isLoading = false;
      });
      
      print('게시글 로딩 완료: ${_posts.length}개');
    } catch (e) {
      print('게시글을 불러오는데 실패했습니다: $e');
      setState(() {
        _isLoading = false;
        _hasMore = false;
      });
    }
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    // 두 지점 간의 거리를 미터 단위로 계산
    double distanceInMeters = Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
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
        return selectedTags.every((selectedTag) => postTags.contains(selectedTag.name));
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
          transaction.update(postRef, {
            'likes': currentLikes - 1
          });
          transaction.delete(likedPostRef);
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
            a['startLongitude'] ?? 0
          );
          double distanceB = _calculateDistance(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            b['startLatitude'] ?? 0,
            b['startLongitude'] ?? 0
          );
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
    // 화면 크기 정보 가져오기
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;
    
    // 동적 크기 계산
    final mapHeight = screenHeight * 0.35; // 화면 높이의 35%
    final searchBarHeight = screenHeight * 0.06; // 화면 높이의 6%
    final padding = screenWidth * 0.04; // 화면 너비의 4%
    final titleFontSize = screenWidth * 0.05; // 화면 너비의 5%
    final subtitleFontSize = screenWidth * 0.035; // 화면 너비의 3.5%
    final tagFontSize = screenWidth * 0.035; // 화면 너비의 3.5%
    final thumbnailSize = screenWidth * 0.2; // 화면 너비의 20%

    return Scaffold(
      backgroundColor: const Color(0xFFCBF6FF),
      appBar: AppBar(
        automaticallyImplyLeading: true,
        backgroundColor: const Color(0xFFCBF6FF),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, size: screenWidth * 0.06),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const ScreenHome()),
            );
          },
        ),
      ),
      body: Column(
        children: [
          Container(
            height: mapHeight,
            child: _currentPosition == null
                ? Container(
                    color: Colors.grey[300],
                    child: const Center(
                      child: Text('위치 정보를 가져오는 중...'),
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
          Padding(
            padding: EdgeInsets.all(padding),
            child: Column(
              children: [
                // 정렬 버튼 추가
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _sortBy = 'distance';
                        });
                        _sortPosts();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _sortBy == 'distance' ? const Color(0xFF764BA2) : Colors.grey[300],
                        foregroundColor: _sortBy == 'distance' ? Colors.white : Colors.black,
                      ),
                      child: const Text('거리순'),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _sortBy = 'likes';
                        });
                        _sortPosts();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _sortBy == 'likes' ? const Color(0xFF764BA2) : Colors.grey[300],
                        foregroundColor: _sortBy == 'likes' ? Colors.white : Colors.black,
                      ),
                      child: const Text('좋아요순'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: padding),
                  height: searchBarHeight,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(searchBarHeight / 2),
                    border: Border.all(color: Colors.grey[400]!),
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
                                  initialSelectedTags: selectedTags, // 기존 선택된 태그 전달
                                ),
                              ),
                            );
                            if (result != null) {
                              setState(() {
                                selectedTags = result;
                              });
                              _filterPostsByTags(); // 태그 선택 후 필터링 실행
                            }
                          },
                          child: selectedTags.isEmpty
                              ? Text(
                                  '원하는 태그를 추가하세요',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: subtitleFontSize,
                                  ),
                                )
                              : SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: selectedTags.map((tag) {
                                      return Padding(
                                        padding: EdgeInsets.only(right: screenWidth * 0.02),
                                        child: Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: screenWidth * 0.02,
                                            vertical: screenHeight * 0.005,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFE7EFA2),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                tag.name,
                                                style: TextStyle(fontSize: tagFontSize),
                                              ),
                                              SizedBox(width: screenWidth * 0.01),
                                              GestureDetector(
                                                onTap: () {
                                                  setState(() {
                                                    selectedTags.remove(tag);
                                                  });
                                                  _filterPostsByTags(); // 태그 제거 후 필터링 실행
                                                },
                                                child: Icon(
                                                  Icons.close,
                                                  size: tagFontSize,
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
                          padding: EdgeInsets.only(left: screenWidth * 0.02),
                          child: Icon(
                            Icons.search,
                            color: Colors.grey,
                            size: subtitleFontSize * 1.2,
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
                    padding: EdgeInsets.symmetric(horizontal: padding),
                    itemBuilder: (context, index) {
                      final post = _filteredPosts[index];
                      return Column(
                        children: [
                          const Divider(
                            thickness: 1,
                            color: Color(0xFFACE3FF),
                            height: 1,
                          ),
                          ListTile(
                            contentPadding: EdgeInsets.symmetric(vertical: screenHeight * 0.01),
                            title: Text(
                              post['title'] ?? '제목 없음',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: titleFontSize,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  post['nickname'] ?? '작성자',
                                  style: TextStyle(
                                    fontSize: subtitleFontSize,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                if (_currentPosition != null && post['startLatitude'] != null && post['startLongitude'] != null)
                                  Text(
                                    '시작점까지 거리: ${_calculateDistance(
                                      _currentPosition!.latitude,
                                      _currentPosition!.longitude,
                                      post['startLatitude'],
                                      post['startLongitude']
                                    ).toStringAsFixed(1)}km',
                                    style: TextStyle(
                                      fontSize: subtitleFontSize,
                                      color: Colors.blue[700],
                                    ),
                                  ),
                                SizedBox(height: screenHeight * 0.005),
                                Row(
                                  children: [
                                    Icon(Icons.route, size: subtitleFontSize),
                                    SizedBox(width: screenWidth * 0.01),
                                    Text(
                                      '운동 거리: ${(post['distance'] ?? 0).toStringAsFixed(1)}km',
                                      style: TextStyle(fontSize: subtitleFontSize),
                                    ),
                                    SizedBox(width: screenWidth * 0.04),
                                    Icon(
                                      Icons.favorite,
                                      size: subtitleFontSize,
                                      color: Colors.red,
                                    ),
                                    SizedBox(width: screenWidth * 0.01),
                                    Text(
                                      '${post['likes'] ?? 0}',
                                      style: TextStyle(fontSize: subtitleFontSize),
                                    ),
                                  ],
                                ),
                                SizedBox(height: screenHeight * 0.005),
                                if (post['tags'] != null && (post['tags'] as List).isNotEmpty)
                                  Wrap(
                                    spacing: screenWidth * 0.01,
                                    children: (post['tags'] as List).map<Widget>((tag) =>
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: screenWidth * 0.02,
                                          vertical: screenHeight * 0.005,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE7EFA2),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          tag.toString(),
                                          style: TextStyle(fontSize: tagFontSize),
                                        ),
                                      )
                                    ).toList(),
                                  ),
                              ],
                            ),
                            trailing: Container(
                              width: thumbnailSize,
                              height: thumbnailSize,
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: post['imageUrls'] != null && (post['imageUrls'] as List).isNotEmpty
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        post['imageUrls'][0],
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Icon(
                                            Icons.image,
                                            color: Colors.grey,
                                            size: thumbnailSize * 0.4,
                                          );
                                        },
                                      ),
                                    )
                                  : Icon(
                                      Icons.image,
                                      color: Colors.grey,
                                      size: thumbnailSize * 0.4,
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
                        ],
                      );
                    },
                  ),
                ),
                if (_hasMore)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : () => _loadPosts(isInitial: false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD8F9FF),
                        foregroundColor: Colors.black,
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator()
                          : const Text('더보기'),
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
} 