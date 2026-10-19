import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/api_client.dart';
import '../../services/google_sign_in_stub.dart'
    if (dart.library.js_interop) '../../services/google_sign_in_web.dart'
    as google;
import 'auth_social_button.dart';

class GoogleSignInButton extends StatefulWidget {
  final VoidCallback onSuccess;
  const GoogleSignInButton({super.key, required this.onSuccess});
  @override
  State<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<GoogleSignInButton> {
  bool _busy = false;
  Future<void> _signIn() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final token = await google.signInWithGoogle(
        clientId: AuthService.googleClientId,
      );
      if (!mounted) return;
      final result = await AuthService.loginWithIdToken(idToken: token);
      if (!mounted) return;
      if (result['success'] == true) {
        widget.onSuccess();
      } else {
        _show(result['message']?.toString() ?? 'Google sign-in failed.');
      }
    } catch (e) {
      if (mounted) {
        _show(
          e is ApiException
              ? e.message
              : 'Google sign-in failed. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _show(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));
  @override
  Widget build(BuildContext context) {
    if (!kIsWeb || AuthService.googleClientId.isEmpty) {
      return const SizedBox.shrink();
    }
    return AuthSocialButton(
      text: _busy ? 'Signing in...' : 'Continue with Google',
      onPressed: _busy ? () {} : _signIn,
    );
  }
}
