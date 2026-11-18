import 'package:flutter/material.dart';

class ProfileToggleTile extends StatelessWidget {
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool isLast;

  const ProfileToggleTile({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black,
                  ),
                ),
              ),
              Switch(
                value: value,
                onChanged: onChanged,
                activeThumbColor: Colors.white,
                activeTrackColor: const Color(0xFF0C8A8A),
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: const Color(0xFFE0E0E5),
              ),
            ],
          ),
        ),
        if (!isLast)
          const Divider(height: 1, thickness: 1, color: Color(0xFFE8E8EC)),
      ],
    );
  }
}
