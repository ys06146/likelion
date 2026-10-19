import 'package:flutter/material.dart';
import 'screens/auth/sign_in_screen.dart';
import 'screens/home_screen.dart';
import 'services/auth_service.dart';

class OraQApp extends StatefulWidget {
  const OraQApp({super.key});
  @override
  State<OraQApp> createState() => _OraQAppState();
}

class _OraQAppState extends State<OraQApp> {
  final _navigator = GlobalKey<NavigatorState>();
  @override
  void initState() {
    super.initState();
    AuthService.sessionExpired.addListener(_signIn);
  }

  void _signIn() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _navigator.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SignInScreen()),
        (_) => false,
      );
    });
  }

  @override
  void dispose() {
    AuthService.sessionExpired.removeListener(_signIn);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorKey: _navigator,
    title: 'OraQ',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorSchemeSeed: const Color(0xFF0C8A8A),
      useMaterial3: true,
    ),
    home: const _SessionGate(),
  );
}

class _SessionGate extends StatefulWidget {
  const _SessionGate();
  @override
  State<_SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<_SessionGate> {
  late Future<SessionStatus> _session;
  @override
  void initState() {
    super.initState();
    _session = AuthService.restoreSession();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<SessionStatus>(
    future: _session,
    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (snapshot.data == SessionStatus.authenticated) {
        return const HomeScreen();
      }
      if (snapshot.data == SessionStatus.anonymous) return const SignInScreen();
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Cannot connect to the server. Your saved session is still available.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () =>
                      setState(() => _session = AuthService.restoreSession()),
                  child: const Text('Retry'),
                ),
                TextButton(
                  onPressed: () async {
                    await AuthService.logout();
                    if (mounted) {
                      setState(
                        () => _session = Future.value(SessionStatus.anonymous),
                      );
                    }
                  },
                  child: const Text('Use another account'),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
