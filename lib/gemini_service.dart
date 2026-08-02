import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'gemini_config.dart';

abstract class GeminiClient {
  Future<String> generateReply(List<GeminiChatTurn> history);
}

class GeminiChatTurn {
  const GeminiChatTurn({required this.role, required this.text});

  final String role;
  final String text;

  Map<String, dynamic> toJson() => {'role': role, 'text': text};
}

/// Calls the protected Supabase Edge Function instead of Gemini directly.
/// The Gemini API key is stored only in the Function's environment secrets.
class GeminiService implements GeminiClient {
  GeminiService({this.languageCode = 'vi'});

  final String languageCode;

  @override
  Future<String> generateReply(List<GeminiChatTurn> history) async {
    final contents = _normalizeHistory(history);
    if (contents.isEmpty) {
      throw const GeminiException(
        'Hãy nhập điều bạn đang băn khoăn về ngành học hoặc nghề nghiệp trước nhé.',
      );
    }

    try {
      final response = await Supabase.instance.client.functions
          .invoke(
            geminiFunctionName,
            body: {
              'languageCode': languageCode,
              'contents': contents.map((turn) => turn.toJson()).toList(),
            },
          )
          .timeout(const Duration(seconds: 30));
      final data = response.data;
      if (data is Map) {
        final text = data['text'];
        if (text is String && text.trim().isNotEmpty) return text.trim();
        final error = data['error'];
        if (error is String && error.isNotEmpty) {
          throw GeminiException(error);
        }
      }
      throw const GeminiException(
        'AI chưa tạo được câu trả lời. Bạn hãy thử diễn đạt lại câu hỏi nhé.',
      );
    } on TimeoutException {
      throw const GeminiException(
        'AI phản hồi hơi lâu. Bạn hãy kiểm tra mạng và thử lại nhé.',
      );
    } on GeminiException {
      rethrow;
    } catch (_) {
      throw const GeminiException(
        'Không thể kết nối với trợ lý AI lúc này. Bạn hãy thử lại sau nhé.',
      );
    }
  }

  List<GeminiChatTurn> _normalizeHistory(List<GeminiChatTurn> history) {
    final normalized = <GeminiChatTurn>[];
    for (final turn in history) {
      final text = turn.text.trim();
      if (text.isEmpty || (turn.role != 'user' && turn.role != 'model')) {
        continue;
      }
      if (normalized.isEmpty && turn.role != 'user') continue;

      if (normalized.isNotEmpty && normalized.last.role == turn.role) {
        final previous = normalized.removeLast();
        normalized.add(
          GeminiChatTurn(role: turn.role, text: '${previous.text}\n$text'),
        );
      } else {
        normalized.add(GeminiChatTurn(role: turn.role, text: text));
      }
    }
    return normalized;
  }
}

class GeminiException implements Exception {
  const GeminiException(this.message);

  final String message;
}
