import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../Widgets/bottom_bar.dart';
import '../Post/post_create.dart';
import 'package:provider/provider.dart';
import '../user_provider.dart';

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
      // 실시간 업데이트를 위해 snapshots() 사용
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
        backgroundColor: const Color(0xFFD8F9FF),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('$nickname님의 프로필', style: const TextStyle(color: Colors.black)),
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
                      const SizedBox(height: 16),
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          CircleAvatar(
                            radius: 48,
                            backgroundColor: Colors.grey.shade300,
                            backgroundImage: _imageFile != null
                                ? FileImage(_imageFile!)
                                : (photoUrl != null ? NetworkImage(photoUrl!) : null) as ImageProvider?,
                            child: (photoUrl == null && _imageFile == null)
                                ? const Icon(Icons.account_circle, size: 36, color: Colors.grey)
                                : null,
                          ),
                        ],
                      ),
                      if (isEditing)
                        Positioned(
                          top: -4,
                          right: -4,
                          child: IconButton(
                            icon: const Icon(Icons.edit, size: 18),
                            onPressed: _pickImage,
                          ),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        nickname,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      const Text('Name'),
                      TextField(
                        controller: _nameController,
                        enabled: false,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text('Email'),
                      TextField(
                        controller: TextEditingController(text: email),
                        enabled: false,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Text('Message'),
                          if (isEditing)
                            IconButton(
                              icon: const Icon(Icons.edit, size: 18),
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
                        decoration: const InputDecoration(border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isEditing ? Colors.black : const Color(0xFFD8F9FF),
                            foregroundColor: isEditing ? Colors.white : Colors.black,
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
                          child: Text(isEditing ? '수정완료' : '수정하기'),
                        ),
                      ),
                    ],
                  ),
                ),
                // 내 게시글 영역
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            showPosts = !showPosts;
                          });
                        },
                        child: Row(
                          children: [
                            const Icon(Icons.arrow_drop_down),
                            const SizedBox(width: 4),
                            const Text('내 게시글', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      if (showPosts)
                        Column(
                          children: myPosts.map((post) {
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
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFCBF6FF),
                                  borderRadius: BorderRadius.circular(12),
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
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Text('코스 ${post['distance']?.toStringAsFixed(1) ?? '-'}km', style: const TextStyle(fontSize: 13)),
                                                  const SizedBox(width: 8),
                                                  const Icon(Icons.favorite, size: 16, color: Colors.purple),
                                                  Text(' ${post['likes'] ?? 0}', style: const TextStyle(fontSize: 13)),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              if (post['tags'] != null && (post['tags'] as List).isNotEmpty)
                                                Wrap(
                                                  spacing: 4,
                                                  children: (post['tags'] as List).map<Widget>((tag) =>
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: Colors.yellow.shade200,
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                      child: Text(tag.toString(), style: const TextStyle(fontSize: 12)),
                                                    )
                                                  ).toList(),
                                                ),
                                              if (post['createdAt'] != null)
                                                Padding(
                                                  padding: const EdgeInsets.only(top: 4),
                                                  child: Text(
                                                    '작성일: ${(post['createdAt'] as Timestamp).toDate().toString().split('.')[0]}',
                                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        if ((post['imageUrls'] ?? []).isNotEmpty)
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: Image.network(
                                              post['imageUrls'][0],
                                              width: 70,
                                              height: 70,
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
                                          icon: const Icon(Icons.delete, color: Colors.red),
                                          onPressed: () {
                                            showDialog(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                title: const Text('게시글 삭제'),
                                                content: const Text('이 게시글을 삭제하시겠습니까?'),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () => Navigator.pop(context),
                                                    child: const Text('취소'),
                                                  ),
                                                  TextButton(
                                                    onPressed: () {
                                                      Navigator.pop(context);
                                                      _deletePost(post['id']);
                                                    },
                                                    child: const Text('삭제', style: TextStyle(color: Colors.red)),
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
} 