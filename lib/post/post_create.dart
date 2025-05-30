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
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

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
  // UI Constants
  static const double _kDefaultPadding = 16.0;
  static const double _kDefaultBorderRadius = 12.0;
  static const double _kButtonHeight = 48.0;
  static const double _kCardElevation = 2.0;
  static const double _kInputBorderRadius = 8.0;
  static const double _kTagBorderRadius = 16.0;
  static const double _kImageSize = 120.0;
  static const double _kMapHeight = 240.0;
  static const double _kIconSize = 20.0;
  static const double _kSmallIconSize = 16.0;

  // Colors
  static const Color _kPrimaryColor = Color(0xFFE5FBFF);
  static const Color _kAccentColor = Color(0xFFB6F5E8);
  static const Color _kTagColor = Color(0xFFE7EFA2);
  static const Color _kErrorColor = Color(0xFFFF6B6B);
  static const Color _kSuccessColor = Color(0xFF4CAF50);
  static const Color _kTextPrimaryColor = Color(0xFF2C3E50);
  static const Color _kTextSecondaryColor = Color(0xFF7F8C8D);

  // Animation Durations
  static const Duration _kAnimationDuration = Duration(milliseconds: 200);

  // Text Styles
  static const TextStyle _kTitleStyle = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: _kTextPrimaryColor,
    letterSpacing: 0.2,
  );

  static const TextStyle _kSubtitleStyle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: _kTextPrimaryColor,
    letterSpacing: 0.1,
  );

  static const TextStyle _kInputLabelStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: _kTextPrimaryColor,
    letterSpacing: 0.1,
  );

  static const TextStyle _kInputTextStyle = TextStyle(
    fontSize: 16,
    color: _kTextPrimaryColor,
    letterSpacing: 0.1,
  );

  static const TextStyle _kHelperTextStyle = TextStyle(
    fontSize: 12,
    color: _kTextSecondaryColor,
    letterSpacing: 0.1,
  );

  static const TextStyle _kButtonTextStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Colors.white,
    letterSpacing: 0.2,
  );

  static const TextStyle _kTagTextStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: _kTextPrimaryColor,
    letterSpacing: 0.1,
  );

  static const TextStyle _kErrorTextStyle = TextStyle(
    fontSize: 12,
    color: _kErrorColor,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
  );

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
  List<String> _inappropriateWords = [];

  bool get isSmallScreen => MediaQuery.of(context).size.height < 600;

  @override
  void initState() {
    super.initState();
    _loadInappropriateWords();
    if (widget.postData != null) {
      isEditMode = true;
      _titleController.text = widget.postData!['title'] ?? '';
      _contentController.text = widget.postData!['content'] ?? '';

      // 기존 태그 데이터 로드
      if (widget.postData!['tags'] != null) {
        final List<dynamic> tagNames = widget.postData!['tags'];
        selectedTags = tagNames
            .map((tagName) => Tag(
                  name: tagName.toString(),
                  category: TagCategory.etc,
                ))
            .toList();
      }
    }

    if (widget.workoutData != null) {
      _loadWorkoutData();
    } else if (widget.postData != null &&
        widget.postData!['routePoints'] != null) {
      final List<dynamic> routePointsData =
          widget.postData!['routePoints'] ?? [];
      setState(() {
        _routePoints = routePointsData
            .map((point) => LatLng(
                  point['latitude'] as double,
                  point['longitude'] as double,
                ))
            .toList();
        _isMapLoading = false;
      });
      if (_routePoints.isNotEmpty) {
        _initializePolylines();
        _initializeMarkers();
      }
    }
  }

  Future<void> _loadInappropriateWords() async {
    try {
      // 영어 부적절한 단어 로드
      final englishWordsJson =
          await rootBundle.loadString('assets/data/english_word_list.json');
      final englishWords =
          List<String>.from(json.decode(englishWordsJson)['en_words']);

      // 한국어 부적절한 단어 로드
      final koreanWordsJson =
          await rootBundle.loadString('assets/data/korean_word_list.json');
      final koreanWords =
          List<String>.from(json.decode(koreanWordsJson)['kr_words']);

      setState(() {
        _inappropriateWords = [...englishWords, ...koreanWords];
      });
    } catch (e) {
      print('부적절한 단어 목록 로드 중 오류 발생: $e');
    }
  }

  bool _containsInappropriateWords(String text) {
    if (text.isEmpty) return false;
    return _inappropriateWords.any((word) =>
        text.toLowerCase().contains(word.toLowerCase()) ||
        text.replaceAll(' ', '').toLowerCase().contains(word.toLowerCase()));
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
          _routePoints = routePointsData
              .map((point) => LatLng(
                    point['latitude'] as double,
                    point['longitude'] as double,
                  ))
              .toList();
          _isMapLoading = false;
        });

        if (_routePoints.isNotEmpty) {
          _initializePolylines();
          _initializeMarkers();
        } else if (workoutData['routePoints'] != null &&
            workoutData['routePoints'].isNotEmpty) {
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
              icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueRed),
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

      final List<dynamic> routePointsData =
          widget.workoutData!['routePoints'] ?? [];

      setState(() {
        _routePoints = routePointsData
            .map((point) => LatLng(
                  point['latitude'] as double,
                  point['longitude'] as double,
                ))
            .toList();
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
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
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
      String fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${path.basename(image.path)}';
      Reference ref =
          FirebaseStorage.instance.ref().child('post_images/$fileName');
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

    if (_containsInappropriateWords(_titleController.text) ||
        _containsInappropriateWords(_contentController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('제목에 부적절한 단어가 포함되어 있습니다.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (_containsInappropriateWords(_contentController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('내용에 부적절한 단어가 포함되어 있습니다.'),
          duration: Duration(seconds: 2),
        ),
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
        final storageRef =
            FirebaseStorage.instance.ref().child('post_images/$fileName');
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
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('Post_Data')
          .add(postData);

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
    // 부적절한 단어 체크
    bool hasInappropriateWords =
        _containsInappropriateWords(_titleController.text) ||
            _containsInappropriateWords(_contentController.text);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
        backgroundColor: _kPrimaryColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back,
              color: _kTextPrimaryColor, size: _kIconSize),
          onPressed: () => Navigator.pop(context),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        title: Text(
          isEditMode ? '게시글 수정' : '게시글 작성',
          style: _kTitleStyle,
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: _kDefaultPadding),
            child: AnimatedContainer(
              duration: _kAnimationDuration,
              child: TextButton(
                onPressed: _isLoading ? null : _savePost,
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: _kDefaultPadding),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(_kDefaultBorderRadius),
                  ),
                  backgroundColor:
                      _isLoading ? _kTextSecondaryColor : _kAccentColor,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        isEditMode ? '수정' : '저장',
                        style: _kButtonTextStyle.copyWith(
                            color: _kTextPrimaryColor),
                      ),
              ),
            ),
          ),
        ],
      ),
      backgroundColor: _kPrimaryColor,
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSection(
                  title: '제목',
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(_kInputBorderRadius),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        hintText: '제목을 입력하세요',
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(_kDefaultPadding),
                        hintStyle: _kInputTextStyle.copyWith(
                            color: _kTextSecondaryColor),
                        helperText: '부적절한 단어는 사용할 수 없습니다.',
                        helperStyle: _kHelperTextStyle,
                      ),
                      style: _kInputTextStyle,
                      maxLines: 1,
                      onChanged: (value) {
                        if (_containsInappropriateWords(value)) {
                          _showErrorSnackBar('부적절한 단어가 포함되어 있습니다.');
                        }
                      },
                    ),
                  ),
                ),
                _buildSection(
                  title: '운동 코스',
                  child: Container(
                    height: _kMapHeight,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(_kInputBorderRadius),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: _isMapLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(_kAccentColor),
                            ),
                          )
                        : _routePoints.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.map,
                                        size: _kIconSize * 2,
                                        color: _kTextSecondaryColor),
                                    const SizedBox(height: 8),
                                    Text(
                                      '운동 기록이 없습니다',
                                      style: _kInputTextStyle.copyWith(
                                          color: _kTextSecondaryColor),
                                    ),
                                  ],
                                ),
                              )
                            : ClipRRect(
                                borderRadius:
                                    BorderRadius.circular(_kInputBorderRadius),
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
                ),
                _buildSection(
                  title: '태그',
                  child: SizedBox(
                    width: double.infinity,
                    child: Container(
                      padding: const EdgeInsets.all(_kDefaultPadding),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                            BorderRadius.circular(_kInputBorderRadius),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (selectedTags.isNotEmpty)
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: selectedTags.map((tag) {
                                return _buildTagChip(tag);
                              }).toList(),
                            ),
                          const SizedBox(height: 8),
                          _buildAddTagButton(),
                        ],
                      ),
                    ),
                  ),
                ),
                _buildSection(
                  title: '세부설명',
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(_kInputBorderRadius),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _contentController,
                      decoration: InputDecoration(
                        hintText: '세부설명을 입력하세요',
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(_kDefaultPadding),
                        hintStyle: _kInputTextStyle.copyWith(
                            color: _kTextSecondaryColor),
                        helperText: '부적절한 단어는 사용할 수 없습니다.',
                        helperStyle: _kHelperTextStyle,
                      ),
                      style: _kInputTextStyle,
                      maxLines: 5,
                      onChanged: (value) {
                        if (_containsInappropriateWords(value)) {
                          _showErrorSnackBar('부적절한 단어가 포함되어 있습니다.');
                        }
                      },
                    ),
                  ),
                ),
                _buildSection(
                  title: '이미지',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: _kButtonHeight,
                        child: ElevatedButton.icon(
                          onPressed: _pickImage,
                          icon: const Icon(Icons.add_photo_alternate,
                              color: Colors.white),
                          label: const Text('사진 업로드', style: _kButtonTextStyle),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kTextPrimaryColor,
                            foregroundColor: Colors.white,
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(_kDefaultBorderRadius),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: _kDefaultPadding),
                          ),
                        ),
                      ),
                      if (selectedImages.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children:
                              List.generate(selectedImages.length, (index) {
                            return _buildImagePreview(
                                selectedImages[index], index);
                          }),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(height: isSmallScreen ? 16 : 32),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(_kAccentColor),
                ),
              ),
            ),
        ],
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

  Widget _buildSection({
    required String title,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.all(_kDefaultPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: _kSubtitleStyle),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _buildTagChip(Tag tag) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _kTagColor,
        borderRadius: BorderRadius.circular(_kTagBorderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(tag.name, style: _kTagTextStyle),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () {
              setState(() {
                selectedTags.remove(tag);
              });
            },
            child: const Icon(
              Icons.close,
              size: _kSmallIconSize,
              color: _kTextSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddTagButton() {
    return GestureDetector(
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: _kTagColor,
          borderRadius: BorderRadius.circular(_kTagBorderRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add,
                size: _kSmallIconSize, color: _kTextPrimaryColor),
            const SizedBox(width: 4),
            Text(
              '태그 추가',
              style: _kTagTextStyle.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview(File image, int index) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(_kInputBorderRadius),
          child: Image.file(
            image,
            width: _kImageSize,
            height: _kImageSize,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: () {
              setState(() {
                selectedImages.removeAt(index);
              });
            },
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.close,
                color: Colors.white,
                size: _kSmallIconSize,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: _kErrorColor,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_kDefaultBorderRadius),
        ),
      ),
    );
  }
}