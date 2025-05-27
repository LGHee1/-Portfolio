import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'login_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  bool _isLoading = false;
  bool _isChecked = false;
  bool _isExpanded = false;
  bool _isPrivacyChecked = false; // 개인정보 수집 동의 체크 여부


  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _nicknameController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<bool> _isNicknameAvailable(String nickname) async {
    try {
      final QuerySnapshot result = await FirebaseFirestore.instance
          .collection('users')
          .where('nickname', isEqualTo: nickname)
          .get();

      return result.docs.isEmpty;
    } catch (e) {
      debugPrint('닉네임 중복 체크 오류: $e');
      return false;
    }
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_isChecked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('위치 정보 동의가 필요합니다.')),
      );
      return;
    }

    if (!_isPrivacyChecked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('개인정보 수집 동의가 필요합니다.')),
      );
      return;
    }


    setState(() {
      _isLoading = true;
    });

    try {
      debugPrint('회원가입 시도: ${_emailController.text.trim()}');

      // 닉네임 중복 체크
      final bool isNicknameAvailable =
          await _isNicknameAvailable(_nicknameController.text.trim());
      if (!isNicknameAvailable) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이미 사용 중인 닉네임입니다.')),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Firebase Authentication으로 사용자 생성
      final UserCredential userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      debugPrint('Firebase Auth 사용자 생성 성공: ${userCredential.user?.uid}');

      // Firestore에 사용자 정보 저장
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({
        'name': _nameController.text.trim(),
        'nickname': _nicknameController.text.trim(),
        'email': _emailController.text.trim(),
        'age': int.tryParse(_ageController.text.trim()) ?? 0,
        'height': double.tryParse(_heightController.text.trim()) ?? 0.0,
        'weight': double.tryParse(_weightController.text.trim()) ?? 0.0,
        'createdAt': FieldValue.serverTimestamp(),
        'totalDistance': 0.0,
        'totalWorkouts': 0,
        'locationAgreed': _isChecked,
        'privacyAgreed': _isPrivacyChecked,

      });

      debugPrint('Firestore 사용자 정보 저장 성공');

      // ✅ 이메일 인증 메일 발송
      await userCredential.user?.sendEmailVerification();
      debugPrint('이메일 인증 메일 전송됨');


      if (!mounted) return;

      // 회원가입 성공 메시지 표시
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('회원가입이 완료되었습니다. 이메일로 전송된 인증 링크를 클릭 후 로그인해주세요.')),
      );

      // 로그인 화면으로 이동
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase Auth 오류 발생: ${e.code} - ${e.message}');
      String message = '회원가입 중 오류가 발생했습니다.';

      if (e.code == 'weak-password') {
        message = '비밀번호가 너무 약합니다. (6자 이상)';
      } else if (e.code == 'email-already-in-use') {
        message = '이미 사용 중인 이메일입니다.';
      } else if (e.code == 'invalid-email') {
        message = '유효하지 않은 이메일 형식입니다.';
      } else if (e.code == 'operation-not-allowed') {
        message = '이메일/비밀번호 로그인이 비활성화되어 있습니다.';
      } else if (e.code == 'network-request-failed') {
        message = '네트워크 연결을 확인해주세요.';
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      debugPrint('일반 오류 발생: $e');
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('회원가입 중 오류가 발생했습니다: ${e.toString()}')),
      );
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
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // 배경 이미지
          Positioned.fill(
            child: Image.asset(
              'assets/img/runner_background.png',
              fit: BoxFit.cover,
            ),
          ),

          // 하단 카드형 회원가입 폼
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            bottom: _isExpanded ? 0 : -MediaQuery.of(context).size.height * 0.1,
            left: 0,
            right: 0,
            child: GestureDetector(
              onVerticalDragUpdate: (details) {
                if (details.delta.dy < -10) {
                  setState(() => _isExpanded = true);
                } else if (details.delta.dy > 10) {
                  setState(() => _isExpanded = false);
                }
              },
              onVerticalDragEnd: (details) {
                if (details.primaryVelocity != null) {
                  if (details.primaryVelocity! > 500) {
                    setState(() => _isExpanded = false);
                  } else if (details.primaryVelocity! < -500) {
                    setState(() => _isExpanded = true);
                  }
                }
              },
              child: Container(
                height: MediaQuery.of(context).size.height * 0.9,
                padding: EdgeInsets.all(24.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(40.r),
                    topRight: Radius.circular(40.r),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // 드래그 핸들
                    Container(
                      width: 40.w,
                      height: 4.h,
                      margin: EdgeInsets.only(bottom: 20.h),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2.r),
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Email
                              _buildTextField(
                                controller: _emailController,
                                label: 'Email',
                                keyboardType: TextInputType.emailAddress,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return '이메일을 입력해주세요';
                                  }
                                  if (!value.contains('@')) {
                                    return '유효한 이메일 주소를 입력해주세요';
                                  }
                                  return null;
                                },
                              ),
                              SizedBox(height: 16.h),

                              // Password
                              _buildTextField(
                                controller: _passwordController,
                                label: 'Password',
                                obscureText: true,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return '비밀번호를 입력해주세요';
                                  }
                                  if (value.length < 6) {
                                    return '비밀번호는 6자 이상이어야 합니다';
                                  }
                                  return null;
                                },
                              ),
                              SizedBox(height: 16.h),

                              // Name
                              _buildTextField(
                                controller: _nameController,
                                label: 'Name',
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return '이름을 입력해주세요';
                                  }
                                  return null;
                                },
                              ),
                              SizedBox(height: 16.h),

                              // Nickname
                              _buildTextField(
                                controller: _nicknameController,
                                label: 'Nickname',
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return '닉네임을 입력해주세요';
                                  }
                                  if (value.length < 2) {
                                    return '닉네임은 2자 이상이어야 합니다';
                                  }
                                  return null;
                                },
                              ),
                              SizedBox(height: 16.h),

                              // Age
                              _buildTextField(
                                controller: _ageController,
                                label: 'Age',
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return '나이를 입력해주세요';
                                  }
                                  final age = int.tryParse(value);
                                  if (age == null || age < 1 || age > 120) {
                                    return '유효한 나이를 입력해주세요';
                                  }
                                  return null;
                                },
                              ),
                              SizedBox(height: 16.h),

                              // Height
                              _buildTextField(
                                controller: _heightController,
                                label: 'Height (cm)',
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return '키를 입력해주세요';
                                  }
                                  final height = double.tryParse(value);
                                  if (height == null ||
                                      height < 50 ||
                                      height > 250) {
                                    return '유효한 키를 입력해주세요';
                                  }
                                  return null;
                                },
                              ),
                              SizedBox(height: 16.h),

                              // Weight
                              _buildTextField(
                                controller: _weightController,
                                label: 'Weight (kg)',
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return '몸무게를 입력해주세요';
                                  }
                                  final weight = double.tryParse(value);
                                  if (weight == null ||
                                      weight < 20 ||
                                      weight > 200) {
                                    return '유효한 몸무게를 입력해주세요';
                                  }
                                  return null;
                                },
                              ),
                              SizedBox(height: 24.h),

                              // 위치 정보 동의 체크박스
                              Row(
                                children: [
                                  Checkbox(
                                    value: _isChecked,
                                    onChanged: (value) {
                                      setState(() {
                                        _isChecked = value ?? false;
                                      });
                                    },
                                  ),
                                  Expanded(
                                    child: Text(
                                      '위치 정보 수집에 동의합니다.',
                                      style: TextStyle(fontSize: 14.sp),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 24.h),

                              // 개인정보 수집 동의 체크박스
                              Row(
                                children: [
                                  Checkbox(
                                    value: _isPrivacyChecked,
                                    onChanged: (value) {
                                      setState(() {
                                        _isPrivacyChecked = value ?? false;
                                      });
                                    },
                                  ),
                                  Expanded(
                                    child: Text(
                                      '개인정보 수집에 동의합니다.',
                                      style: TextStyle(fontSize: 14.sp),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 24.h),


                              // 회원가입 버튼
                              SizedBox(
                                width: double.infinity,
                                height: 48.h,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _signUp,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFB6F5E8),
                                    foregroundColor: Colors.black87,
                                    elevation: 2,
                                    shadowColor: Colors.black26,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12.r),
                                    ),
                                  ),
                                  child: _isLoading
                                      ? CircularProgressIndicator(
                                          color: Colors.black87,
                                          strokeWidth: 2.w)
                                      : Text(
                                          "Sign Up",
                                          style: TextStyle(
                                            fontSize: 16.sp,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                ),
                              ),
                              SizedBox(height: 16.h),

                              // 로그인 화면으로 이동
                              TextButton(
                                onPressed: () {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) =>
                                            const LoginScreen()),
                                  );
                                },
                                child: Text(
                                  "Already have an account? Sign In",
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    color: Colors.black54,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    bool obscureText = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: 14.sp, color: Colors.black54),
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
      style: TextStyle(fontSize: 14.sp),
      validator: validator,
    );
  }
}