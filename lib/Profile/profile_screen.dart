import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
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
  File? _imageFile;
  List<String> postUids = [];
  int _selectedIndex = 1;
  bool showPosts = false;
  List<Map<String, dynamic>> myPosts = [];

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadMyPosts();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    try {
      // users 컬렉션에서 기본 데이터 로드
      final userData = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userData.exists) {
        final data = userData.data()!;
        setState(() {
          nickname = data['nickname'] ?? '';
          name = data['name'] ?? '';
          email = data['email'] ?? '';
          _nameController.text = name;
        });
        print('기본 사용자 데이터 로드 성공: $nickname, $name, $email');

        // MyProfile 서브컬렉션에서 추가 데이터 로드
        final myProfileDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('MyProfile')
            .doc(user.uid)
            .get();

        if (myProfileDoc.exists) {
          final profileData = myProfileDoc.data()!;
          setState(() {
            message = profileData['message'] ?? '';
            photoUrl = profileData['photoUrl'];
            postUids = List<String>.from(profileData['postUids'] ?? []);
            // MyProfile에 name, nickname, email이 있으면 불러오기
            name = profileData['name'] ?? name;
            nickname = profileData['nickname'] ?? nickname;
            email = profileData['email'] ?? email;
            _nameController.text = name;
            _messageController.text = message;
          });
          
          // UserProvider 업데이트
          Provider.of<UserProvider>(context, listen: false).setPhotoUrl(photoUrl);
          
          print('MyProfile 데이터 로드 성공');
        } else {
          // MyProfile이 없으면 생성
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('MyProfile')
              .doc(user.uid)
              .set({
            'name': _nameController.text,
            'nickname': nickname,
            'email': email,
            'message': '',
            'photoUrl': null,
            'postUids': [],
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          print('MyProfile 생성 완료');
        }
      } else {
        print('사용자 데이터가 존재하지 않음');
      }
    } catch (e) {
      print('사용자 데이터 로드 중 오류 발생: $e');
    }
  }

  Future<void> _loadMyPosts() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('Post_Data')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .listen((snapshot) {
        setState(() {
          myPosts = snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList();
        });
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

  Future<void> _saveProfile() async {
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
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // UserProvider 업데이트
      Provider.of<UserProvider>(context, listen: false).setPhotoUrl(uploadedUrl);

      setState(() {
        message = _messageController.text;
        photoUrl = uploadedUrl;
        isEditing = false;
        isEditingMessage = false;
        isEditingPhoto = false;
        _imageFile = null;
        isUploading = false;
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
        title: Text(
          '$nickname님의 프로필',
          style: TextStyle(color: Colors.black, fontSize: 18.sp),
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
                      SizedBox(height: 16.h),
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          CircleAvatar(
                            radius: 48.r,
                            backgroundColor: Colors.grey.shade300,
                            backgroundImage: _imageFile != null
                                ? FileImage(_imageFile!)
                                : (photoUrl != null ? NetworkImage(photoUrl!) : null) as ImageProvider?,
                            child: (photoUrl == null && _imageFile == null)
                                ? Icon(Icons.account_circle, size: 36.sp, color: Colors.grey)
                                : null,
                          ),
                          if (isEditing)
                            Positioned(
                              bottom: 2.h,
                              right: 2.w,
                              child: Container(
                                width: 24.w,
                                height: 24.h,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  icon: Icon(Icons.edit, size: 18.sp, color: Colors.black87),
                                  onPressed: _pickImage,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 24,
                                    minHeight: 24,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        nickname,
                        style: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 16.h),
                    ],
                  ),
                ),
                Container(
                  color: Colors.white,
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: EdgeInsets.all(16.w),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 8.h),
                          Text('Name', style: TextStyle(fontSize: 14.sp)),
                          TextField(
                            controller: _nameController,
                            enabled: false,
                            style: TextStyle(fontSize: 14.sp),
                            decoration: InputDecoration(
                              border: OutlineInputBorder(),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                          ),
                          SizedBox(height: 16.h),
                          Text('Email', style: TextStyle(fontSize: 14.sp)),
                          TextField(
                            controller: TextEditingController(text: email),
                            enabled: false,
                            style: TextStyle(fontSize: 14.sp),
                            decoration: InputDecoration(
                              border: OutlineInputBorder(),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                          ),
                          SizedBox(height: 16.h),
                          Row(
                            children: [
                              Text('Message', style: TextStyle(fontSize: 14.sp)),
                              if (isEditing)
                                IconButton(
                                  icon: Icon(Icons.edit, size: 17.sp),
                                  onPressed: () {
                                    setState(() {
                                      isEditingMessage = true;
                                    });
                                  },
                                ),
                            ],
                          ),
                          TextField(
                            controller: _messageController,
                            enabled: isEditing,
                            maxLines: 2,
                            style: TextStyle(fontSize: 14.sp),
                            decoration: InputDecoration(border: OutlineInputBorder()),
                          ),
                          SizedBox(height: 24.h),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isEditing ? Colors.black : const Color(0xFFD8F9FF),
                                foregroundColor: isEditing ? Colors.white : Colors.black,
                                padding: EdgeInsets.symmetric(vertical: 12.h),
                              ),
                              onPressed: isUploading ? null : () {
                                if (isEditing) {
                                  _saveProfile();
                                } else {
                                  setState(() {
                                    isEditing = true;
                                  });
                                }
                              },
                              child: Text(
                                isEditing ? '수정완료' : '수정하기',
                                style: TextStyle(fontSize: 16.sp),
                              ),
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
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              showPosts = !showPosts;
                            });
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: 8.h),
                            child: Row(
                              children: [
                                Icon(
                                  showPosts ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                                  color: Colors.black87,
                                  size: 28.sp,
                                ),
                                SizedBox(width: 4.w),
                                Text(
                                  '내 게시글',
                                  style: TextStyle(
                                    fontSize: 18.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(width: 6.w),
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
                        ),
                        if (showPosts)
                          Column(
                            children: myPosts.isEmpty
                                ? [
                                    Padding(
                                      padding: EdgeInsets.symmetric(vertical: 16.h),
                                      child: Text(
                                        '등록된 게시글이 없습니다.',
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 14.sp,
                                        ),
                                      ),
                                    ),
                                  ]
                                : myPosts.map((post) {
                                    return GestureDetector(
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
                                      child: Container(
                                        margin: EdgeInsets.symmetric(vertical: 4.h),
                                        padding: EdgeInsets.all(8.w),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(12.r),
                                          border: Border.all(color: Colors.purple.shade100),
                                        ),
                                        child: Stack(
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        post['title'] ?? '',
                                                        style: TextStyle(
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 15.sp,
                                                        ),
                                                      ),
                                                      SizedBox(height: 3.h),
                                                      Row(
                                                        children: [
                                                          Text(
                                                            '코스 ${post['distance']?.toStringAsFixed(1) ?? '-'}km',
                                                            style: TextStyle(fontSize: 13.sp),
                                                          ),
                                                          SizedBox(width: 6.w),
                                                          Icon(Icons.favorite, size: 14.sp, color: Colors.purple),
                                                          Text(
                                                            ' ${post['likes'] ?? 0}',
                                                            style: TextStyle(fontSize: 13.sp),
                                                          ),
                                                        ],
                                                      ),
                                                      SizedBox(height: 3.h),
                                                      if (post['tags'] != null && (post['tags'] as List).isNotEmpty)
                                                        Wrap(
                                                          spacing: 3.w,
                                                          children: (post['tags'] as List).map<Widget>((tag) =>
                                                            Container(
                                                              padding: EdgeInsets.symmetric(
                                                                horizontal: 6.w,
                                                                vertical: 2.h,
                                                              ),
                                                              decoration: BoxDecoration(
                                                                color: Colors.yellow.shade200,
                                                                borderRadius: BorderRadius.circular(8.r),
                                                              ),
                                                              child: Text(
                                                                tag.toString(),
                                                                style: TextStyle(fontSize: 12.sp),
                                                              ),
                                                            )
                                                          ).toList(),
                                                        ),
                                                      if (post['createdAt'] != null)
                                                        Padding(
                                                          padding: EdgeInsets.only(top: 3.h),
                                                          child: Text(
                                                            '작성일: ${(post['createdAt'] as Timestamp).toDate().toString().split('.')[0]}',
                                                            style: TextStyle(
                                                              fontSize: 12.sp,
                                                              color: Colors.grey,
                                                            ),
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                                if ((post['imageUrls'] ?? []).isNotEmpty)
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
                                            ),
                                            if (isEditing)
                                              Positioned(
                                                top: 0,
                                                right: 0,
                                                child: IconButton(
                                                  icon: Icon(Icons.delete, color: Colors.red, size: 17.sp),
                                                  onPressed: () {
                                                    showDialog(
                                                      context: context,
                                                      builder: (context) => AlertDialog(
                                                        title: Text('게시글 삭제', style: TextStyle(fontSize: 17.sp)),
                                                        content: Text('이 게시글을 삭제하시겠습니까?', style: TextStyle(fontSize: 14.sp)),
                                                        actions: [
                                                          TextButton(
                                                            onPressed: () => Navigator.pop(context),
                                                            child: Text('취소', style: TextStyle(fontSize: 14.sp)),
                                                          ),
                                                          TextButton(
                                                            onPressed: () {
                                                              Navigator.pop(context);
                                                              _deletePost(post['id']);
                                                            },
                                                            child: Text('삭제', style: TextStyle(fontSize: 14.sp, color: Colors.red)),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
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
              MaterialPageRoute(builder: (context) => const ProfileScreen()),
            );
          }
        },
      ),
    );
  }
} 