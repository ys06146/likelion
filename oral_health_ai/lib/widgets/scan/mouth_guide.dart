import 'package:flutter/material.dart';

class MouthGuide extends StatelessWidget {
  final bool glowing;

  const MouthGuide({super.key, this.glowing = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 176,
      height: 118,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(44),
        border: Border.all(
          color: glowing
              ? const Color(0xFF00D3E0)
              : Colors.white.withValues(alpha: 0.35),
          width: glowing ? 1.4 : 1.1,
        ),
        boxShadow: glowing
            ? [
                BoxShadow(
                  color: const Color(0xFF00D3E0).withValues(alpha: 0.28),
                  blurRadius: 28,
                  spreadRadius: 3,
                ),
                BoxShadow(
                  color: const Color(0xFF00D3E0).withValues(alpha: 0.18),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ]
            : [],
      ),
      child: glowing
          ? null
          : Stack(
              children: [
                _tick(top: 0, left: 80),
                _tick(bottom: 0, left: 80),
                _tick(left: 0, top: 50, vertical: true),
                _tick(right: 0, top: 50, vertical: true),
              ],
            ),
    );
  }

  static Widget _tick({
    double? top,
    double? bottom,
    double? left,
    double? right,
    bool vertical = false,
  }) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Container(
        width: vertical ? 1.2 : 18,
        height: vertical ? 18 : 1.2,
        color: Colors.white.withValues(alpha: 0.45),
      ),
    );
  }
}
