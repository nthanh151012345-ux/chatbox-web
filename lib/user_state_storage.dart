import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'app_localizations.dart';
import 'avatar_models.dart';
import 'chat_appearance.dart';

class StoredCareerMessage {
  const StoredCareerMessage({
    required this.text,
    required this.isUser,
    required this.isError,
    required this.includeInAiHistory,
  });

  final String text;
  final bool isUser;
  final bool isError;
  final bool includeInAiHistory;

  Map<String, dynamic> toJson() => {
    'text': text,
    'isUser': isUser,
    'isError': isError,
    'includeInAiHistory': includeInAiHistory,
  };

  static StoredCareerMessage? fromJson(Object? value) {
    if (value is! Map) return null;
    final text = value['text'];
    final isUser = value['isUser'];
    if (text is! String || isUser is! bool) return null;
    return StoredCareerMessage(
      text: text,
      isUser: isUser,
      isError: value['isError'] is bool ? value['isError'] as bool : false,
      includeInAiHistory: value['includeInAiHistory'] is bool
          ? value['includeInAiHistory'] as bool
          : true,
    );
  }
}

class StoredUserState {
  const StoredUserState({
    required this.language,
    required this.messages,
    required this.chatAppearance,
    required this.avatarBase64,
    required this.aiAvatar,
  });

  final AppLanguage? language;
  final List<StoredCareerMessage> messages;
  final ChatAppearance chatAppearance;
  final String? avatarBase64;
  final AiAvatarId aiAvatar;
}

/// Keeps non-sensitive UI state locally and scopes it to the signed-in user.
class UserStateStorage {
  static const _prefix = 'career_chatbot';

  Future<StoredUserState> read(String userId) async {
    final preferences = await SharedPreferences.getInstance();
    final language = switch (preferences.getString(_languageKey(userId))) {
      'en' => AppLanguage.english,
      'vi' => AppLanguage.vietnamese,
      _ => null,
    };
    final chatAppearance = ChatAppearance.fromStorageValue(
      preferences.getString(_appearanceKey(userId)),
    );
    final avatarBase64 = preferences.getString(_avatarKey(userId));
    final aiAvatar = aiAvatarFromStorage(
      preferences.getString(_aiAvatarKey(userId)),
    );
    final encodedMessages = preferences.getString(_messagesKey(userId));
    if (encodedMessages == null) {
      return StoredUserState(
        language: language,
        messages: const [],
        chatAppearance: chatAppearance,
        avatarBase64: avatarBase64,
        aiAvatar: aiAvatar,
      );
    }

    try {
      final decoded = jsonDecode(encodedMessages);
      if (decoded is! List) {
        return StoredUserState(
          language: language,
          messages: const [],
          chatAppearance: chatAppearance,
          avatarBase64: avatarBase64,
          aiAvatar: aiAvatar,
        );
      }
      return StoredUserState(
        language: language,
        messages: decoded
            .map(StoredCareerMessage.fromJson)
            .whereType<StoredCareerMessage>()
            .toList(growable: false),
        chatAppearance: chatAppearance,
        avatarBase64: avatarBase64,
        aiAvatar: aiAvatar,
      );
    } on FormatException {
      return StoredUserState(
        language: language,
        messages: const [],
        chatAppearance: chatAppearance,
        avatarBase64: avatarBase64,
        aiAvatar: aiAvatar,
      );
    }
  }

  Future<void> saveLanguage(String userId, AppLanguage language) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _languageKey(userId),
      language == AppLanguage.english ? 'en' : 'vi',
    );
  }

  Future<void> saveMessages(
    String userId,
    List<StoredCareerMessage> messages,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _messagesKey(userId),
      jsonEncode(messages.map((message) => message.toJson()).toList()),
    );
  }

  Future<void> saveChatAppearance(
    String userId,
    ChatAppearance appearance,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _appearanceKey(userId),
      appearance.toStorageValue(),
    );
  }

  Future<void> saveAvatar(String userId, String? avatarBase64) async {
    final preferences = await SharedPreferences.getInstance();
    if (avatarBase64 == null) {
      await preferences.remove(_avatarKey(userId));
      return;
    }
    await preferences.setString(_avatarKey(userId), avatarBase64);
  }

  Future<void> saveAiAvatar(String userId, AiAvatarId avatar) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_aiAvatarKey(userId), avatar.name);
  }

  String _languageKey(String userId) => '$_prefix.language.$userId';
  String _messagesKey(String userId) => '$_prefix.messages.$userId';
  String _appearanceKey(String userId) => '$_prefix.appearance.$userId';
  String _avatarKey(String userId) => '$_prefix.avatar.$userId';
  String _aiAvatarKey(String userId) => '$_prefix.ai-avatar.$userId';
}
