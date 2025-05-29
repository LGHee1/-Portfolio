import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:profanity_filter/profanity_filter.dart';
import '../Widgets/bottom_bar.dart';
import '../Post/post_create.dart';
import 'package:provider/provider.dart';
import '../user_provider.dart';
import '../Running/workout_screen.dart';
import '../home_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool isEditing = false;
  bool isEditingMessage = false;
  bool isEditingPhoto = false;
  bool isUploading = false;
  String nickname = '';
  String name = '';
  String email = '';
  String message = '';
  String? photoUrl;
  int age = 0;
  double height = 0.0;
  double weight = 0.0;
  String? gender;
  File? _imageFile;
  List<String> postUids = [];
  int _selectedIndex = 1;
  bool showPosts = false;
  List<Map<String, dynamic>> myPosts = [];
  List<String> _inappropriateWords = []; // 부적절한 단어 목록

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();


  // 욕설 필터 인스턴스 생성
  final ProfanityFilter _profanityFilter = ProfanityFilter();

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadMyPosts();
    _loadInappropriateWords(); // 부적절한 단어 목록 로드
    _ageController.text = age.toString();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _messageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // users 컬렉션에서 데이터 로드
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      // MyProfile 서브컬렉션에서 데이터 로드
      final myProfileDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('MyProfile')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        setState(() {
          nickname = userDoc.data()?['nickname'] ?? '';
          name = userDoc.data()?['name'] ?? '';
          email = userDoc.data()?['email'] ?? '';
          photoUrl = userDoc.data()?['photoUrl'];
          age = userDoc.data()?['age'] ?? 0;
          height = (userDoc.data()?['height'] ?? 0.0).toDouble();
          weight = (userDoc.data()?['weight'] ?? 0.0).toDouble();
          gender = userDoc.data()?['gender'];
          // MyProfile 서브컬렉션에서 message를 가져오고, 없으면 users 컬렉션에서 가져옴
          message = myProfileDoc.exists && myProfileDoc.data()?['message'] != null
              ? myProfileDoc.data()!['message']
              : userDoc.data()?['message'] ?? '';
          _nameController.text = name;
          _heightController.text = height.toString();
          _weightController.text = weight.toString();
          _ageController.text = age.toString();
          _messageController.text = message;
        });
      }
    } catch (e) {
      print('사용자 데이터 로드 중 오류 발생: $e');
    }
  }

  Future<void> _loadMyPosts() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final postsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('Post_Data')
          .orderBy('createdAt', descending: true)
          .get();

      setState(() {
        myPosts = postsSnapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();
      });
    } catch (e) {
      print('내 게시글 불러오기 오류: $e');
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
        isEditingPhoto = true;
      });
      // 여기서 _saveProfile() 호출하지 않음!
    }
  }

  Future<String?> _uploadImage() async {
    if (_imageFile == null) return null;

    try {
      setState(() {
        isUploading = true;
      });

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      // Firebase Storage에 이미지 업로드
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child('${user.uid}.jpg');

      final uploadTask = await storageRef.putFile(_imageFile!);
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      print('이미지 업로드 중 오류 발생: $e');
      return null;
    } finally {
      setState(() {
        isUploading = false;
      });
    }
  }

  Future<void> _loadInappropriateWords() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('system')
          .doc('inappropriate_words')
          .get();

      if (snapshot.exists) {
        setState(() {
          _inappropriateWords =
              List<String>.from(snapshot.data()?['words'] ?? []);
        });
      }
    } catch (e) {
      print('부적절한 단어 목록 로드 중 오류 발생: $e');
    }
  }

  // 부적절한 단어 체크 함수
  bool _containsInappropriateWords(String text) {
    return _profanityFilter.hasProfanity(text);
  }

  Future<void> _saveProfile() async {
    // 부적절한 단어 체크
    if (_containsInappropriateWords(_messageController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('부적절한 단어가 포함되어 있습니다.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    String? uploadedUrl = photoUrl;

    // 이미지가 선택되었다면 업로드
    if (_imageFile != null) {
      try {
        setState(() {
          isUploading = true;
        });

        // Firebase Storage에 이미지 업로드
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('profile_images')
            .child('${user.uid}.jpg');

        final uploadTask = await storageRef.putFile(_imageFile!);
        uploadedUrl = await uploadTask.ref.getDownloadURL();

        if (uploadedUrl == null) {
          throw Exception('이미지 URL을 가져오는데 실패했습니다.');
        }
      } catch (e) {
        print('이미지 업로드 중 오류 발생: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이미지 업로드에 실패했습니다.')),
        );
        setState(() {
          isUploading = false;
        });
        return;
      }
    }

    try {
      // MyProfile 서브컬렉션에 데이터 저장
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('MyProfile')
          .doc(user.uid)
          .set({
        'name': _nameController.text,
        'nickname': nickname,
        'email': email,
        'message': _messageController.text,
        'photoUrl': uploadedUrl,
        'postUids': postUids,
        'gender': gender,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 사용자의 키와 몸무게 정보 업데이트
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'name': _nameController.text,
        'nickname': nickname,
        'photoUrl': uploadedUrl,
        'height': double.tryParse(_heightController.text) ?? height,
        'weight': double.tryParse(_weightController.text) ?? weight,
        'age': int.tryParse(_ageController.text) ?? age,
        'gender': gender,
        'message': _messageController.text,
      });

      // UserProvider 업데이트
      Provider.of<UserProvider>(context, listen: false)
          .setPhotoUrl(uploadedUrl);

      setState(() {
        message = _messageController.text;
        photoUrl = uploadedUrl;
        isEditing = false;
        isEditingMessage = false;
        isEditingPhoto = false;
        _imageFile = null;
        isUploading = false;
        height = double.tryParse(_heightController.text) ?? height;
        weight = double.tryParse(_weightController.text) ?? weight;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('프로필이 업데이트되었습니다.')),
      );
    } catch (e) {
      print('프로필 업데이트 중 오류 발생: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('프로필 업데이트에 실패했습니다.')),
      );
      setState(() {
        isUploading = false;
      });
    }
  }

  Future<void> _deletePost(String postId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Firebase에서 게시글 삭제
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('Post_Data')
          .doc(postId)
          .delete();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('게시글이 삭제되었습니다')),
      );
    } catch (e) {
      print('게시글 삭제 중 오류 발생: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('게시글 삭제에 실패했습니다')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFD8F9FF),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black, size: 24.sp),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          '$nickname님의 프로필',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                Container(
                  color: const Color(0xFFD8F9FF),
                  width: double.infinity,
                  child: Column(
                    children: [
                      SizedBox(height: 20.h),
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 48.r,
                              backgroundColor: Colors.grey.shade300,
                              backgroundImage: _imageFile != null
                                  ? FileImage(_imageFile!)
                                  : (photoUrl != null
                                      ? NetworkImage(photoUrl!)
                                      : null) as ImageProvider?,
                              child: (photoUrl == null && _imageFile == null)
                                  ? Icon(Icons.account_circle,
                                      size: 36.sp, color: Colors.grey)
                                  : null,
                            ),
                          ),
                          if (isEditing)
                            Positioned(
                              top: -4.h,
                              right: -4.w,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: IconButton(
                                  icon: Icon(Icons.edit,
                                      size: 18.sp, color: Colors.black87),
                                  onPressed: _pickImage,
                                  padding: EdgeInsets.all(8.r),
                                  constraints: const BoxConstraints(),
                                ),
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: 12.h),
                      Text(
                        nickname,
                        style: TextStyle(
                          fontSize: 24.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                          letterSpacing: -0.5,
                        ),
                      ),
                      SizedBox(height: 20.h),
                    ],
                  ),
                ),
                Container(
                  color: Colors.white,
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: EdgeInsets.all(20.w),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInfoField(
                            label: 'Name',
                            controller: _nameController,
                            enabled: false,
                          ),
                          SizedBox(height: 20.h),
                          _buildInfoField(
                            label: 'Email',
                            controller: TextEditingController(text: email),
                            enabled: false,
                          ),
                          SizedBox(height: 20.h),
                          // 성별 선택
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '성별',
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              SizedBox(height: 8.h),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildGenderButton(
                                      label: '남성',
                                      value: 'male',
                                      icon: Icons.male,
                                    ),
                                  ),
                                  SizedBox(width: 12.w),
                                  Expanded(
                                    child: _buildGenderButton(
                                      label: '여성',
                                      value: 'female',
                                      icon: Icons.female,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          SizedBox(height: 20.h),
                          // 신체 정보 표시
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '나이',
                                      style: TextStyle(
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    SizedBox(height: 8.h),
                                    TextField(
                                      controller: _ageController,
                                      enabled: isEditing,
                                      keyboardType: TextInputType.number,
                                      style: TextStyle(
                                        fontSize: 14.sp,
                                        color: Colors.black87,
                                      ),
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: Colors.grey.shade50,
                                        suffixText: '세',
                                        suffixStyle: TextStyle(
                                          fontSize: 14.sp,
                                          color: Colors.black54,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12.r),
                                          borderSide: BorderSide(color: Colors.grey.shade300),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12.r),
                                          borderSide: BorderSide(color: Colors.grey.shade300),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12.r),
                                          borderSide: BorderSide(color: const Color(0xFFB6F5E8), width: 2),
                                        ),
                                        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                                      ),
                                    ),

                                  ],
                                ),
                              ),
                              SizedBox(width: 16.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '키',
                                      style: TextStyle(
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    SizedBox(height: 8.h),
                                    TextField(
                                      controller: _heightController,
                                      enabled: isEditing,
                                      keyboardType: TextInputType.number,
                                      style: TextStyle(
                                        fontSize: 14.sp,
                                        color: Colors.black87,
                                      ),
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: Colors.grey.shade50,
                                        suffixText: 'cm',
                                        suffixStyle: TextStyle(
                                          fontSize: 14.sp,
                                          color: Colors.black54,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12.r),
                                          borderSide: BorderSide(
                                              color: Colors.grey.shade300),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12.r),
                                          borderSide: BorderSide(
                                              color: Colors.grey.shade300),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12.r),
                                          borderSide: BorderSide(
                                              color: const Color(0xFFB6F5E8),
                                              width: 2),
                                        ),
                                        contentPadding: EdgeInsets.symmetric(
                                            horizontal: 16.w, vertical: 12.h),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: 16.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '몸무게',
                                      style: TextStyle(
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    SizedBox(height: 8.h),
                                    TextField(
                                      controller: _weightController,
                                      enabled: isEditing,
                                      keyboardType: TextInputType.number,
                                      style: TextStyle(
                                        fontSize: 14.sp,
                                        color: Colors.black87,
                                      ),
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: Colors.grey.shade50,
                                        suffixText: 'kg',
                                        suffixStyle: TextStyle(
                                          fontSize: 14.sp,
                                          color: Colors.black54,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12.r),
                                          borderSide: BorderSide(
                                              color: Colors.grey.shade300),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12.r),
                                          borderSide: BorderSide(
                                              color: Colors.grey.shade300),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12.r),
                                          borderSide: BorderSide(
                                              color: const Color(0xFFB6F5E8),
                                              width: 2),
                                        ),
                                        contentPadding: EdgeInsets.symmetric(
                                            horizontal: 16.w, vertical: 12.h),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 20.h),
                          Row(
                            children: [
                              Text(
                                '세부설명',
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              if (isEditing)
                                IconButton(
                                  icon: Icon(Icons.edit,
                                      size: 17.sp, color: Colors.black54),
                                  onPressed: () {
                                    setState(() {
                                      isEditingMessage = true;
                                    });
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                            ],
                          ),
                          SizedBox(height: 8.h),
                          TextField(
                            controller: _messageController,
                            enabled: isEditing,
                            maxLines: 5,
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: Colors.black87,
                            ),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.r),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.r),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.r),
                                borderSide: BorderSide(color: const Color(0xFFB6F5E8), width: 2),
                              ),
                              contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Container(
                  color: Colors.white,
                  child: Padding(
                    padding: EdgeInsets.all(20.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildPostListHeader(),
                        if (showPosts) _buildPostList(),
                        SizedBox(height: 20.h),
                        if (!isEditing)
                          Center(
                            child: ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  isEditing = true;
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFD8F9FF),
                                foregroundColor: Colors.black87,
                                elevation: 2,
                                shadowColor: Colors.black12,
                                padding: EdgeInsets.symmetric(
                                    horizontal: 24.w, vertical: 12.h),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                              ),
                              child: Text(
                                '수정하기',
                                style: TextStyle(
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ),
                        if (isEditing)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton(
                                onPressed: () async {
                                  await _saveProfile();
                                  if (mounted) {
                                    setState(() {
                                      isEditing = false;
                                      isEditingMessage = false;
                                    });
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFD8F9FF),
                                  foregroundColor: Colors.black87,
                                  elevation: 2,
                                  shadowColor: Colors.black12,
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 24.w, vertical: 12.h),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12.r),
                                  ),
                                ),
                                child: Text(
                                  '저장',
                                  style: TextStyle(
                                    fontSize: 15.sp,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                              SizedBox(width: 16.w),
                              ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    isEditing = false;
                                    isEditingMessage = false;
                                    _nameController.text = name;
                                    _messageController.text = message;
                                    _imageFile = null;
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey.shade100,
                                  foregroundColor: Colors.black87,
                                  elevation: 1,
                                  shadowColor: Colors.black.withOpacity(0.08),
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 24.w, vertical: 12.h),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12.r),
                                  ),
                                ),
                                child: Text(
                                  '취소',
                                  style: TextStyle(
                                    fontSize: 15.sp,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isUploading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
      bottomNavigationBar: BottomBar(
        selectedIndex: _selectedIndex,
        onTabSelected: (index) {
          setState(() => _selectedIndex = index);
        },
      ),
    );
  }

  Widget _buildInfoField({
    required String label,
    required TextEditingController controller,
    required bool enabled,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: 8.h),
        TextField(
          controller: controller,
          enabled: enabled,
          style: TextStyle(
            fontSize: 14.sp,
            color: Colors.black87,
            height: 1.5,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(color: const Color(0xFFB6F5E8), width: 2),
            ),
            contentPadding:
                EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          ),
        ),
      ],
    );
  }

  Widget _buildPostListHeader() {
    return GestureDetector(
      onTap: () {
        setState(() {
          showPosts = !showPosts;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12.h),
        child: Row(
          children: [
            Icon(
              showPosts
                  ? Icons.keyboard_arrow_down
                  : Icons.keyboard_arrow_right,
              color: Colors.black87,
              size: 28.sp,
            ),
            SizedBox(width: 8.w),
            Text(
              '내 게시글',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
                letterSpacing: -0.3,
              ),
            ),
            SizedBox(width: 8.w),
            Text(
              '(${myPosts.length})',
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostList() {
    if (myPosts.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 20.h),
        child: Center(
          child: Text(
            '등록된 게시글이 없습니다.',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14.sp,
            ),
          ),
        ),
      );
    }

    return Column(
      children: myPosts.map((post) {
        return Container(
          margin: EdgeInsets.only(bottom: 12.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: Colors.purple.shade100),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PostCreatePage(
                      postData: post,
                      postId: post['id'],
                    ),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(12.r),
              child: Padding(
                padding: EdgeInsets.all(16.w),
                child: Stack(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                post['title'] ?? '',
                                style: TextStyle(
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                  height: 1.4,
                                ),
                              ),
                              SizedBox(height: 8.h),
                              Row(
                                children: [
                                  Text(
                                    '코스 ${post['distance']?.toStringAsFixed(1) ?? '-'}km',
                                    style: TextStyle(
                                      fontSize: 13.sp,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  SizedBox(width: 8.w),
                                  Icon(Icons.favorite,
                                      size: 14.sp, color: Colors.purple),
                                  Text(
                                    ' ${post['likes'] ?? 0}',
                                    style: TextStyle(
                                      fontSize: 13.sp,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                              if (post['tags'] != null &&
                                  (post['tags'] as List).isNotEmpty) ...[
                                SizedBox(height: 8.h),
                                Wrap(
                                  spacing: 6.w,
                                  runSpacing: 6.h,
                                  children: (post['tags'] as List)
                                      .map<Widget>((tag) => Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 8.w,
                                              vertical: 4.h,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.yellow.shade100,
                                              borderRadius:
                                                  BorderRadius.circular(6.r),
                                            ),
                                            child: Text(
                                              tag.toString(),
                                              style: TextStyle(
                                                fontSize: 12.sp,
                                                color: Colors.black87,
                                              ),
                                            ),
                                          ))
                                      .toList(),
                                ),
                              ],
                              if (post['createdAt'] != null) ...[
                                SizedBox(height: 8.h),
                                Text(
                                  '작성일: ${(post['createdAt'] as Timestamp).toDate().toString().split('.')[0]}',
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if ((post['imageUrls'] ?? []).isNotEmpty) ...[
                          SizedBox(width: 12.w),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8.r),
                            child: Image.network(
                              post['imageUrls'][0],
                              width: 80.w,
                              height: 80.h,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (isEditing)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: IconButton(
                          icon: Icon(Icons.delete,
                              color: Colors.red.shade400, size: 20.sp),
                          onPressed: () => _showDeleteDialog(post['id']),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  void _showDeleteDialog(String postId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          '게시글 삭제',
          style: TextStyle(
            fontSize: 17.sp,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        content: Text(
          '이 게시글을 삭제하시겠습니까?',
          style: TextStyle(
            fontSize: 14.sp,
            color: Colors.black87,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              '취소',
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.black87,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deletePost(postId);
            },
            child: Text(
              '삭제',
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.red.shade400,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (isUploading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGenderButton({
    required String label,
    required String value,
    required IconData icon,
  }) {
    final isSelected = gender == value;
    return InkWell(
      onTap: isEditing ? () {
        setState(() {
          gender = value;
        });
      } : null,
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12.h),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFB6F5E8) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: isSelected ? const Color(0xFFB6F5E8) : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18.w,
              color: isSelected ? Colors.black87 : Colors.grey.shade600,
            ),
            SizedBox(width: 8.w),
            Text(
              label,
              style: TextStyle(
                fontSize: 14.sp,
                color: isSelected ? Colors.black87 : Colors.grey.shade600,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}