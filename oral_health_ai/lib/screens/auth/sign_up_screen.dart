import 'dart:convert';
import 'package:flutter/material.dart';
import '../../widgets/auth/auth_layout.dart';
import '../../services/auth_service.dart';
import '../../widgets/auth/auth_divider_text.dart';
import '../../widgets/auth/auth_input_field.dart';
import '../../widgets/auth/auth_primary_button.dart';
import '../../widgets/auth/google_sign_in_button.dart';
import '../home_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _hidePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    final fullName = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (fullName.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('모든 항목을 입력하세요.')));
      return;
    }

    if (password.length < 8 || utf8.encode(password).length > 72) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Use at least 8 characters and at most 72 UTF-8 bytes for your password.',
          ),
        ),
      );
      return;
    }
    setState(() {
      _isLoading = true;
    });

    final result = await AuthService.signup(
      email: email,
      password: password,
      fullName: fullName,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (result['success'] == true) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('회원가입 성공')));
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message']?.toString() ?? '회원가입 실패')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Row(
                children: [
                  Icon(Icons.chevron_left, color: Color(0xFF0C8A8A)),
                  SizedBox(width: 2),
                  Text(
                    'Back',
                    style: TextStyle(
                      color: Color(0xFF0C8A8A),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Expanded(
              child: Center(
                child: Text(
                  'Create Account',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 60),
          ],
        ),
        const SizedBox(height: 34),
        RichText(
          text: const TextSpan(
            children: [
              TextSpan(
                text: 'Join Ora',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              TextSpan(
                text: 'Q',
                style: TextStyle(
                  color: Color(0xFF0C8A8A),
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        AuthInputField(
          controller: _nameController,
          label: 'Full Name',
          hintText: 'Alex Johnson',
        ),
        const SizedBox(height: 16),
        AuthInputField(
          controller: _emailController,
          label: 'Email',
          hintText: 'alex@example.com',
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),
        AuthInputField(
          controller: _passwordController,
          label: 'Password',
          hintText: 'At least 8 characters',
          obscureText: _hidePassword,
          suffixIcon: IconButton(
            onPressed: () {
              setState(() {
                _hidePassword = !_hidePassword;
              });
            },
            icon: Icon(
              _hidePassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: const Color(0xFFBEBEC2),
            ),
          ),
        ),
        const SizedBox(height: 14),
        const SizedBox(height: 10),
        AuthPrimaryButton(
          text: _isLoading ? 'Creating...' : 'Create Account',
          isEnabled: !_isLoading,
          onPressed: _isLoading
              ? () {}
              : () {
                  _handleSignUp();
                },
        ),
        const SizedBox(height: 28),
        if (AuthService.googleClientId.isNotEmpty)
          const AuthDividerText(text: 'or sign up with'),
        const SizedBox(height: 28),
        GoogleSignInButton(
          onSuccess: () {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Google 로그인 성공')));
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const HomeScreen()),
              (_) => false,
            );
          },
        ),
        const SizedBox(height: 32),
        Wrap(
          alignment: WrapAlignment.center,
          children: [
            const Text(
              'Already have an account?',
              style: TextStyle(color: Color(0xFF8F8F95), fontSize: 15),
            ),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Text(
                ' Sign In',
                style: TextStyle(
                  color: Color(0xFF0C8A8A),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
