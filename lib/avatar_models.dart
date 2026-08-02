import 'package:flutter/material.dart';

enum AiAvatarId { robot, compass, lightbulb, school }

class AiAvatarStyle {
  const AiAvatarStyle({
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;
}

AiAvatarStyle aiAvatarStyle(AiAvatarId avatar) => switch (avatar) {
  AiAvatarId.robot => const AiAvatarStyle(
    icon: Icons.smart_toy_rounded,
    backgroundColor: Color(0xFFDBEAFE),
    foregroundColor: Color(0xFF2563EB),
  ),
  AiAvatarId.compass => const AiAvatarStyle(
    icon: Icons.explore_rounded,
    backgroundColor: Color(0xFFEDE9FE),
    foregroundColor: Color(0xFF7C3AED),
  ),
  AiAvatarId.lightbulb => const AiAvatarStyle(
    icon: Icons.lightbulb_rounded,
    backgroundColor: Color(0xFFFEF3C7),
    foregroundColor: Color(0xFFD97706),
  ),
  AiAvatarId.school => const AiAvatarStyle(
    icon: Icons.school_rounded,
    backgroundColor: Color(0xFFD1FAE5),
    foregroundColor: Color(0xFF059669),
  ),
};

AiAvatarId aiAvatarFromStorage(String? value) {
  for (final avatar in AiAvatarId.values) {
    if (avatar.name == value) return avatar;
  }
  return AiAvatarId.robot;
}
