import 'package:flutter/material.dart';
import 'tag_list.dart';
import '../models/tag.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path/path.dart' as path;
import 'package:firebase_storage/firebase_storage.dart';

class PostCreatePage extends StatefulWidget {
  const PostCreatePage({super.key});

  @override
  State<PostCreatePage> createState() => _PostCreatePageState();
}

class _PostCreatePageState extends State<PostCreatePage> {
  List<Tag> selectedTags = [];
  List<File> selectedImages = [];
  final TextEditingController _contentController = TextEditingController();
  bool _isLoading = false;

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
      String fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(image.path)}';
      Reference ref = FirebaseStorage.instance.ref().child('post_images/$fileName');
      await ref.putFile(image);
      String downloadUrl = await ref.getDownloadURL();
      imageUrls.add(downloadUrl);
    }
    return imageUrls;
  }

  Future<void> _createPost() async {
    if (_contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('내용을 입력해주세요')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // 사용자 닉네임 가져오기
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final nickname = userDoc.data()?['nickname'];

      // 이미지 업로드
      List<String> imageUrls = await _uploadImages();

      // Firestore에 게시글 저장
      await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('Post_Data').add({
        'content': _contentController.text,
        'imageUrls': imageUrls,
        'createdAt': FieldValue.serverTimestamp(),
        'userId': user.uid,
        'nickname': nickname,
        'likes': 0,
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('게시글이 작성되었습니다')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류가 발생했습니다: $e')),
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
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
        backgroundColor: const Color(0xFFCBF6FF),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text('게시글 작성'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _createPost,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('게시'),
          ),
        ],
      ),
      backgroundColor: const Color(0xFFCBF6FF),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 제목 및 작성자 정보
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '게시글 작성',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextField(
                      controller: _contentController,
                      decoration: const InputDecoration(
                        hintText: '내용을 입력하세요',
                        border: InputBorder.none,
                      ),
                      maxLines: 5,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            // 태그 목록
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: selectedTags.map((tag) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE7EFA2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(tag.name, style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              selectedTags.remove(tag);
                            });
                          },
                          child: const Icon(Icons.close, size: 16),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TagListPage(
                        onTagsSelected: (tags) {
                          setState(() {
                            // 기존 태그와 새로 선택된 태그를 합치고 중복 제거
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE7EFA2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '태그 추가',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            // 세부 설명
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '세부 설명',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: '게시글의 세부 설명을 입력하세요',
                        border: InputBorder.none,
                      ),
                      maxLines: 5,
                    ),
                  ),
                ],
              ),
            ),
            // 이미지 등록
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        _pickImage();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('사진 업로드'),
                    ),
                  ),
                  if (selectedImages.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12.0),
                      child: Wrap(
                        spacing: 8.0,
                        runSpacing: 8.0,
                        children: List.generate(selectedImages.length, (index) {
                          return Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  selectedImages[index],
                                  width: 120,
                                  height: 120,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: 0,
                                right: 0,
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      selectedImages.removeAt(index);
                                    });
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.close, color: Colors.white, size: 18),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
} 