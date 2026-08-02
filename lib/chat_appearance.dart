import 'dart:convert';

import 'package:flutter/material.dart';

enum ChatBrightness { light, dark }

enum ChatColorTheme { blue, violet, emerald }

enum ChatFontSize { compact, standard, large }

class ChatAppearance {
  const ChatAppearance({
    this.brightness = ChatBrightness.light,
    this.colorTheme = ChatColorTheme.blue,
    this.fontSize = ChatFontSize.standard,
  });

  final ChatBrightness brightness;
  final ChatColorTheme colorTheme;
  final ChatFontSize fontSize;

  Color get accent => switch (colorTheme) {
    ChatColorTheme.blue => const Color(0xFF2563EB),
    ChatColorTheme.violet => const Color(0xFF7C3AED),
    ChatColorTheme.emerald => const Color(0xFF059669),
  };

  Color get background => brightness == ChatBrightness.dark
      ? const Color(0xFF0F172A)
      : const Color(0xFFF8FAFC);
  Color get botBubble => brightness == ChatBrightness.dark
      ? const Color(0xFF1E293B)
      : Colors.white;
  Color get botText => brightness == ChatBrightness.dark
      ? const Color(0xFFF8FAFC)
      : const Color(0xFF1E293B);
  Color get border => brightness == ChatBrightness.dark
      ? const Color(0xFF334155)
      : const Color(0xFFE2E8F0);
  Color get composer => brightness == ChatBrightness.dark
      ? const Color(0xFF172033)
      : Colors.white;
  Color get mutedText => brightness == ChatBrightness.dark
      ? const Color(0xFFCBD5E1)
      : const Color(0xFF64748B);
  Color get inputFill => brightness == ChatBrightness.dark
      ? const Color(0xFF1E293B)
      : Colors.white;
  Color get inputText => brightness == ChatBrightness.dark
      ? const Color(0xFFF8FAFC)
      : const Color(0xFF1E293B);
  double get messageFontSize => switch (fontSize) {
    ChatFontSize.compact => 13,
    ChatFontSize.standard => 15,
    ChatFontSize.large => 17,
  };

  ChatAppearance copyWith({
    ChatBrightness? brightness,
    ChatColorTheme? colorTheme,
    ChatFontSize? fontSize,
  }) => ChatAppearance(
    brightness: brightness ?? this.brightness,
    colorTheme: colorTheme ?? this.colorTheme,
    fontSize: fontSize ?? this.fontSize,
  );

  String toStorageValue() => jsonEncode({
    'brightness': brightness.name,
    'colorTheme': colorTheme.name,
    'fontSize': fontSize.name,
  });

  static ChatAppearance fromStorageValue(String? value) {
    if (value == null) return const ChatAppearance();
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map) return const ChatAppearance();
      return ChatAppearance(
        brightness: ChatBrightness.values.byNameOrDefault(
          decoded['brightness'],
          ChatBrightness.light,
        ),
        colorTheme: ChatColorTheme.values.byNameOrDefault(
          decoded['colorTheme'],
          ChatColorTheme.blue,
        ),
        fontSize: ChatFontSize.values.byNameOrDefault(
          decoded['fontSize'],
          ChatFontSize.standard,
        ),
      );
    } on FormatException {
      return const ChatAppearance();
    }
  }
}

extension _EnumStorage<T extends Enum> on List<T> {
  T byNameOrDefault(Object? value, T fallback) {
    if (value is! String) return fallback;
    for (final item in this) {
      if (item.name == value) return item;
    }
    return fallback;
  }
}
