import 'package:flutter/material.dart';

class AuthLayout extends StatelessWidget {
  final List<Widget> children;
  const AuthLayout({super.key, required this.children});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: children,
          ),
        ),
      ),
    ),
  );
}
