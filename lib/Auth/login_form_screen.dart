import 'package:flutter/material.dart';
import 'login_screen.dart';

class LoginFormScreen extends StatelessWidget {
  const LoginFormScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('로그인'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const LoginScreen()),
            );
          },
          child: const Text('로그인 화면으로 이동'),
        ),
      ),
    );
  }
} 