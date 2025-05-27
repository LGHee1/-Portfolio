import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../home_screen.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isExpanded = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이메일을 입력해주세요.')),
      );
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('비밀번호 재설정 이메일을 발송했습니다.')),
      );
    } on FirebaseAuthException catch (e) {
      String message = '비밀번호 재설정 이메일 발송 중 오류가 발생했습니다.';

      if (e.code == 'user-not-found') {
        message = '등록되지 않은 이메일입니다.';
      } else if (e.code == 'invalid-email') {
        message = '유효하지 않은 이메일 형식입니다.';
      } else if (e.code == 'network-request-failed') {
        message = '네트워크 연결을 확인해주세요.';
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('비밀번호 재설정 중 오류가 발생했습니다: ${e.toString()}')),
      );
    }
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      debugPrint('로그인 시도: ${_emailController.text.trim()}');

      final UserCredential userCredential = // ← 이거 추가!
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      debugPrint('로그인 성공: ${userCredential.user?.uid ?? "UID 없음"}');

      final user = FirebaseAuth.instance.currentUser;
      await user?.reload();
      if (user != null && !user.emailVerified) {
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('이메일 인증 필요'),
            content: const Text('가입한 이메일로 전송된 인증 링크를 클릭해주세요.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('확인'),
              ),
            ],
          ),
        );
        return;
      }

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ScreenHome()),
      );

    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase Auth 오류 발생: ${e.code} - ${e.message}');
      String message = '로그인 중 오류가 발생했습니다.';

      if (e.code == 'user-not-found') {
        message = '등록되지 않은 이메일입니다.';
      } else if (e.code == 'wrong-password') {
        message = '잘못된 비밀번호입니다.';
      } else if (e.code == 'invalid-email') {
        message = '유효하지 않은 이메일 형식입니다.';
      } else if (e.code == 'user-disabled') {
        message = '비활성화된 계정입니다.';
      } else if (e.code == 'too-many-requests') {
        message = '너무 많은 로그인 시도가 있었습니다. 잠시 후 다시 시도해주세요.';
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
        SnackBar(content: Text('로그인 중 오류가 발생했습니다: ${e.toString()}')),
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

          // 하단 카드형 로그인 폼
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            bottom: _isExpanded ? 0 : -MediaQuery.of(context).size.height * 0.3,
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
                height: MediaQuery.of(context).size.height * 0.7,
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
                                  return null;
                                },
                              ),
                              SizedBox(height: 24.h),

                              // 로그인 버튼
                              SizedBox(
                                width: double.infinity,
                                height: 48.h,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _signIn,
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
                                          "Sign In",
                                          style: TextStyle(
                                            fontSize: 16.sp,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                ),
                              ),
                              SizedBox(height: 16.h),

                              // 비밀번호 찾기 버튼
                              TextButton(
                                onPressed: _resetPassword,
                                child: Text(
                                  "Forgot password?",
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    color: Colors.black54,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                              SizedBox(height: 16.h),

                              // 회원가입 화면으로 이동
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "Don't have an account? ",
                                    style: TextStyle(
                                      fontSize: 14.sp,
                                      color: Colors.black54,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                            builder: (context) =>
                                                const SignUpScreen()),
                                      );
                                    },
                                    child: Text(
                                      "Sign Up",
                                      style: TextStyle(
                                        fontSize: 14.sp,
                                        color: const Color(0xFFB6F5E8),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
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