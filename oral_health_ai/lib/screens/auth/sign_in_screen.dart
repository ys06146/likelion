import 'package:flutter/material.dart';
import '../../widgets/auth/auth_layout.dart';
import '../../services/auth_service.dart';
import '../../widgets/auth/auth_divider_text.dart';
import '../../widgets/auth/auth_input_field.dart';
import '../../widgets/auth/google_sign_in_button.dart';
import '../../widgets/auth/auth_primary_button.dart';
import '../home_screen.dart';
import 'sign_up_screen.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _hidePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('이메일과 비밀번호를 입력하세요.')));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final result = await AuthService.login(email: email, password: password);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (result['success'] == true) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('로그인 성공')));

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message']?.toString() ?? '로그인 실패')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      children: [
        const SizedBox(height: 16),
        RichText(
          text: const TextSpan(
            children: [
              TextSpan(
                text: 'Welcome to Ora',
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
          controller: _emailController,
          label: 'Email',
          hintText: 'alex@example.com',
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),
        AuthInputField(
          controller: _passwordController,
          label: 'Password',
          hintText: 'Enter your password',
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
        const SizedBox(height: 20),
        AuthPrimaryButton(
          text: _isLoading ? 'Signing In...' : 'Sign In',
          isEnabled: !_isLoading,
          onPressed: _isLoading
              ? () {}
              : () {
                  _handleSignIn();
                },
        ),
        const SizedBox(height: 28),
        if (AuthService.googleClientId.isNotEmpty)
          const AuthDividerText(text: 'or sign in with'),
        const SizedBox(height: 28),
        GoogleSignInButton(
          onSuccess: () {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Google 로그인 성공')));
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const HomeScreen()),
            );
          },
        ),
        const SizedBox(height: 32),
        Wrap(
          alignment: WrapAlignment.center,
          children: [
            const Text(
              "Don't have an account?",
              style: TextStyle(color: Color(0xFF8F8F95), fontSize: 15),
            ),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SignUpScreen()),
                );
              },
              child: const Text(
                ' Create Account',
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
