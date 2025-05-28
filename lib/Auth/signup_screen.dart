import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'login_screen.dart';
import 'dart:async';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen>
    with SingleTickerProviderStateMixin {
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
  bool _isEmailVerified = false; // 이메일 인증 상태 추가
  bool _isEmailSent = false;
  String? _selectedGender; // 성별 선택을 위한 변수 추가
  Timer? _verificationTimer;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeFirebaseState();

    // 애니메이션 컨트롤러 초기화
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeIn,
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _nicknameController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _verificationTimer?.cancel();
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

  Future<void> _checkEmailVerification() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        _verificationTimer =
            Timer.periodic(const Duration(seconds: 3), (timer) async {
              try {
                await user.reload();
                final updatedUser = FirebaseAuth.instance.currentUser;
                if (updatedUser != null && updatedUser.emailVerified) {
                  setState(() {
                    _isEmailVerified = true;
                  });
                  timer.cancel();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('이메일 인증이 완료되었습니다!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                }
              } catch (e) {
                debugPrint('이메일 인증 확인 중 오류: $e');
                timer.cancel();
              }
            });
      }
    } catch (e) {
      debugPrint('이메일 인증 확인 초기화 중 오류: $e');
    }
  }

  Future<void> _resendVerificationEmail() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.sendEmailVerification();
        setState(() {
          _isEmailSent = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('인증 이메일이 재발송되었습니다. 이메일을 확인해주세요.'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('이메일 재발송 중 오류가 발생했습니다: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteIncompleteAccountIfNeeded() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && !user.emailVerified) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (!userDoc.exists) {
          await user.delete();
          debugPrint('🔥 인증 안 된 임시 계정 삭제됨: ${user.email}');
        }
      }
    } catch (e) {
      debugPrint('❌ 임시 계정 삭제 중 오류: $e');
    }
  }

  Future<void> _deleteVerifiedButIncompleteAccount() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        await user.reload(); // 🔹 최신 상태로 갱신

        final refreshedUser = FirebaseAuth.instance.currentUser;
        if (refreshedUser != null && refreshedUser.emailVerified) {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(refreshedUser.uid)
              .get();

          if (!userDoc.exists) {
            // 🔥 Firestore에 없으면 인증만 된 상태 → 삭제 + 로그아웃
            await refreshedUser.delete();
            await FirebaseAuth.instance.signOut();

            debugPrint("🔥 인증만 된 계정 삭제 완료: ${refreshedUser.email}");

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('이전 인증만 된 계정이 삭제되었습니다. 다시 가입해주세요.'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        }
      }
    } catch (e) {
      debugPrint("❌ 인증만 된 계정 삭제 오류: $e");
    }
  }

  Future<void> _initializeFirebaseState() async {
    try {
      // 1️⃣ 인증 상태 강제 리로드
      await FirebaseAuth.instance.currentUser?.reload();

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        debugPrint('✅ 유저 이메일: ${user.email}, 인증됨: ${user.emailVerified}');
      } else {
        debugPrint('⚠️ 로그인된 사용자 없음');
      }

      // 2️⃣ 기존 초기화 함수들 호출
      await _deleteVerifiedButIncompleteAccount();
      await _deleteIncompleteAccountIfNeeded();
      _checkEmailVerification();
    } catch (e) {
      debugPrint('❌ Firebase 초기화 오류: $e');
    }
  }

  Future<void> _sendVerificationEmail() async {
    if (_emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이메일을 먼저 입력해주세요.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 이메일 형식 검증
      if (!_emailController.text.contains('@')) {
        throw FirebaseAuthException(
          code: 'invalid-email',
          message: '유효하지 않은 이메일 형식입니다.',
        );
      }

      // 이메일 중복 체크
      final methods = await FirebaseAuth.instance
          .fetchSignInMethodsForEmail(_emailController.text.trim());
      if (methods.isNotEmpty) {
        throw FirebaseAuthException(
          code: 'email-already-in-use',
          message: '이미 사용 중인 이메일입니다.',
        );
      }

      // 임시 사용자 생성 및 인증 이메일 발송
      final userCredential =
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: 'temporaryPassword123!', // 임시 비밀번호
      );

      await userCredential.user?.sendEmailVerification();
      setState(() {
        _isEmailSent = true;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('인증 이메일이 발송되었습니다. 이메일을 확인해주세요.'),
          backgroundColor: Colors.blue,
        ),
      );

      // 이메일 인증 상태 확인 시작
      _checkEmailVerification();
    } on FirebaseAuthException catch (e) {
      String message = '이메일 확인 중 오류가 발생했습니다.';
      if (e.code == 'email-already-in-use') {
        message = '이미 사용 중인 이메일입니다.';
      } else if (e.code == 'invalid-email') {
        message = '유효하지 않은 이메일 형식입니다.';
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류가 발생했습니다: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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

    if (!_isEmailVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이메일 인증을 먼저 완료해주세요.')),
      );
      return;
    }

    if (_selectedGender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('성별을 선택해주세요.')),
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

      // 현재 로그인된 사용자 가져오기
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('사용자 인증 정보가 없습니다. 앱을 다시 실행해주세요.')),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      debugPrint('Firebase Auth 사용자 UID: ${user.uid}');

      // Firestore에 사용자 정보 저장
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'name': _nameController.text.trim(),
        'nickname': _nicknameController.text.trim(),
        'email': user.email,
        'age': int.tryParse(_ageController.text.trim()) ?? 0,
        'height': double.tryParse(_heightController.text.trim()) ?? 0.0,
        'weight': double.tryParse(_weightController.text.trim()) ?? 0.0,
        'createdAt': FieldValue.serverTimestamp(),
        'totalDistance': 0.0,
        'totalWorkouts': 0,
        'locationAgreed': _isChecked,
        'privacyAgreed': _isPrivacyChecked,
        'gender': _selectedGender,
      });

      debugPrint('Firestore 사용자 정보 저장 성공');

      // 완료 메시지
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('회원가입이 완료되었습니다. 로그인해주세요.')),
      );

      // 로그인 화면으로 이동
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
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
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: SlideTransition(
                            position: _slideAnimation,
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Title
                                  Text(
                                    '회원가입',
                                    style: TextStyle(
                                      fontSize: 28.sp,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  SizedBox(height: 8.h),
                                  Text(
                                    '호다닥과 함께해요',
                                    style: TextStyle(
                                      fontSize: 14.sp,
                                      color: Colors.black54,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  SizedBox(height: 32.h),

                                  // Email
                                  _buildTextField(
                                    controller: _emailController,
                                    label: '이메일',
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
                                    suffixIcon: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (_isEmailVerified)
                                          Icon(Icons.check_circle,
                                              color: Colors.green, size: 20.w)
                                        else
                                          IconButton(
                                            icon: Icon(Icons.send,
                                                color: Colors.blue, size: 20.w),
                                            onPressed: _sendVerificationEmail,
                                            tooltip: '인증 이메일 발송',
                                          ),
                                      ],
                                    ),
                                  ),
                                  if (_isEmailSent && !_isEmailVerified)
                                    Container(
                                      margin: EdgeInsets.only(top: 8.h),
                                      padding: EdgeInsets.all(8.w),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withOpacity(0.1),
                                        borderRadius:
                                        BorderRadius.circular(8.r),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.info_outline,
                                              color: Colors.blue, size: 16.w),
                                          SizedBox(width: 8.w),
                                          Expanded(
                                            child: Text(
                                              '인증 이메일이 발송되었습니다. 이메일을 확인하고 인증을 완료해주세요.',
                                              style: TextStyle(
                                                  color: Colors.blue,
                                                  fontSize: 12.sp),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  if (_isEmailVerified)
                                    Container(
                                      margin: EdgeInsets.only(top: 8.h),
                                      padding: EdgeInsets.all(8.w),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.1),
                                        borderRadius:
                                        BorderRadius.circular(8.r),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.check_circle,
                                              color: Colors.green, size: 16.w),
                                          SizedBox(width: 8.w),
                                          Text(
                                            '이메일 인증이 완료되었습니다!',
                                            style: TextStyle(
                                                color: Colors.green,
                                                fontSize: 12.sp),
                                          ),
                                        ],
                                      ),
                                    ),
                                  SizedBox(height: 16.h),

                                  // Password
                                  _buildTextField(
                                    controller: _passwordController,
                                    label: '비밀번호',
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

                                  // Name and Nickname Row
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildTextField(
                                          controller: _nameController,
                                          label: '이름',
                                          validator: (value) {
                                            if (value == null ||
                                                value.isEmpty) {
                                              return '이름을 입력해주세요';
                                            }
                                            return null;
                                          },
                                        ),
                                      ),
                                      SizedBox(width: 16.w),
                                      Expanded(
                                        child: _buildTextField(
                                          controller: _nicknameController,
                                          label: '닉네임',
                                          validator: (value) {
                                            if (value == null ||
                                                value.isEmpty) {
                                              return '닉네임을 입력해주세요';
                                            }
                                            if (value.length < 2) {
                                              return '닉네임은 2자 이상이어야 합니다';
                                            }
                                            return null;
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 16.h),

                                  // Gender Selection
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 16.w, vertical: 12.h),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(12.r),
                                      border: Border.all(
                                          color: Colors.grey.shade300),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '성별',
                                          style: TextStyle(
                                            fontSize: 14.sp,
                                            color: Colors.black54,
                                            fontWeight: FontWeight.w500,
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
                                  ),
                                  SizedBox(height: 16.h),

                                  // Physical Info Row (Age, Height, Weight)
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildTextField(
                                          controller: _ageController,
                                          label: '나이',
                                          keyboardType: TextInputType.number,
                                          validator: (value) {
                                            if (value == null ||
                                                value.isEmpty) {
                                              return '나이를 입력해주세요';
                                            }
                                            final age = int.tryParse(value);
                                            if (age == null ||
                                                age < 1 ||
                                                age > 120) {
                                              return '유효한 나이를 입력해주세요';
                                            }
                                            return null;
                                          },
                                        ),
                                      ),
                                      SizedBox(width: 12.w),
                                      Expanded(
                                        child: _buildTextField(
                                          controller: _heightController,
                                          label: '키 (cm)',
                                          keyboardType: TextInputType.number,
                                          validator: (value) {
                                            if (value == null ||
                                                value.isEmpty) {
                                              return '키를 입력해주세요';
                                            }
                                            final height =
                                            double.tryParse(value);
                                            if (height == null ||
                                                height < 50 ||
                                                height > 250) {
                                              return '유효한 키를 입력해주세요';
                                            }
                                            return null;
                                          },
                                        ),
                                      ),
                                      SizedBox(width: 12.w),
                                      Expanded(
                                        child: _buildTextField(
                                          controller: _weightController,
                                          label: '몸무게 (kg)',
                                          keyboardType: TextInputType.number,
                                          validator: (value) {
                                            if (value == null ||
                                                value.isEmpty) {
                                              return '몸무게를 입력해주세요';
                                            }
                                            final weight =
                                            double.tryParse(value);
                                            if (weight == null ||
                                                weight < 20 ||
                                                weight > 200) {
                                              return '유효한 몸무게를 입력해주세요';
                                            }
                                            return null;
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 24.h),

                                  // Agreement Checkboxes
                                  _buildAgreementCheckbox(
                                    value: _isChecked,
                                    onChanged: (value) {
                                      setState(() {
                                        _isChecked = value ?? false;
                                      });
                                    },
                                    label: '위치 정보 수집에 동의합니다.',
                                  ),
                                  SizedBox(height: 12.h),
                                  _buildAgreementCheckbox(
                                    value: _isPrivacyChecked,
                                    onChanged: (value) {
                                      setState(() {
                                        _isPrivacyChecked = value ?? false;
                                      });
                                    },
                                    label: '개인정보 수집에 동의합니다.',
                                  ),
                                  SizedBox(height: 32.h),

                                  // Sign Up Button
                                  SizedBox(
                                    width: double.infinity,
                                    height: 52.h,
                                    child: ElevatedButton(
                                      onPressed: _isLoading ? null : _signUp,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                        const Color(0xFFB6F5E8),
                                        foregroundColor: Colors.black87,
                                        elevation: 2,
                                        shadowColor: Colors.black26,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                          BorderRadius.circular(16.r),
                                        ),
                                      ),
                                      child: _isLoading
                                          ? SizedBox(
                                        width: 24.w,
                                        height: 24.w,
                                        child: CircularProgressIndicator(
                                          color: Colors.black87,
                                          strokeWidth: 2.w,
                                        ),
                                      )
                                          : Text(
                                        "회원가입",
                                        style: TextStyle(
                                          fontSize: 16.sp,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: -0.3,
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 16.h),

                                  // Login Link
                                  Center(
                                    child: TextButton(
                                      onPressed: () {
                                        Navigator.pushReplacement(
                                          context,
                                          MaterialPageRoute(
                                              builder: (context) =>
                                              const LoginScreen()),
                                        );
                                      },
                                      child: Text(
                                        "이미 계정이 있으신가요? 로그인",
                                        style: TextStyle(
                                          fontSize: 14.sp,
                                          color: Colors.black54,
                                          decoration: TextDecoration.underline,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 24.h),
                                ],
                              ),
                            ),
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
    Widget? suffixIcon,
    IconData? prefixIcon,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            fontSize: 14.sp,
            color: Colors.black54,
            letterSpacing: -0.2,
          ),
          prefixIcon: prefixIcon != null
              ? Icon(prefixIcon, color: Colors.grey.shade600, size: 20.w)
              : null,
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
          suffixIcon: suffixIcon,
        ),
        style: TextStyle(
          fontSize: 14.sp,
          letterSpacing: -0.2,
        ),
        validator: validator,
        onTap: () {
          // 입력 필드 탭 시 자동으로 확장
          if (!_isExpanded) {
            setState(() => _isExpanded = true);
          }
        },
      ),
    );
  }

  Widget _buildGenderButton({
    required String label,
    required String value,
    required IconData icon,
  }) {
    final isSelected = _selectedGender == value;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedGender = value;
          });
          // 성별 선택 시 자동으로 확장
          if (!_isExpanded) {
            setState(() => _isExpanded = true);
          }
        },
        borderRadius: BorderRadius.circular(12.r),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 12.h),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFB6F5E8) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color:
              isSelected ? const Color(0xFFB6F5E8) : Colors.grey.shade300,
            ),
            boxShadow: isSelected
                ? [
              BoxShadow(
                color: const Color(0xFFB6F5E8).withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ]
                : null,
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
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAgreementCheckbox({
    required bool value,
    required ValueChanged<bool?> onChanged,
    required String label,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: CheckboxListTile(
        value: value,
        onChanged: onChanged,
        title: Text(
          label,
          style: TextStyle(
            fontSize: 14.sp,
            color: Colors.black87,
            letterSpacing: -0.2,
          ),
        ),
        controlAffinity: ListTileControlAffinity.leading,
        contentPadding: EdgeInsets.symmetric(horizontal: 12.w),
        dense: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
      ),
    );
  }
}