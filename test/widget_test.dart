import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatbox/app_localizations.dart';
import 'package:chatbox/career_counselor.dart';
import 'package:chatbox/home_screen.dart';

void main() {
  testWidgets('renders the career-guidance home screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const CareerGuidanceApp(requireAuthentication: false),
    );

    expect(find.text('Chatbot Hướng nghiệp'), findsOneWidget);
    expect(find.text('Xin chào 👋'), findsOneWidget);
    expect(find.text('Tư vấn ngành học'), findsOneWidget);
    expect(find.text('Làm bài test hướng nghiệp'), findsOneWidget);
    expect(find.text('Trang chủ'), findsOneWidget);
  });

  testWidgets('puts a suggested question into the quick-question field', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const CareerGuidanceApp(requireAuthentication: false),
    );

    final suggestion = find.text('Em hợp ngành nào?');
    await tester.scrollUntilVisible(
      suggestion,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(suggestion);
    await tester.pump();

    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('quick-question-field')),
    );
    expect(field.controller?.text, 'Em hợp ngành nào?');
  });

  testWidgets('shows feedback when a feature card is pressed', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const CareerGuidanceApp(requireAuthentication: false),
    );

    final card = find.text('Tư vấn ngành học');
    await tester.drag(find.byType(ListView), const Offset(0, -220));
    await tester.pumpAndSettle();
    await tester.tap(card);
    await tester.pumpAndSettle();

    expect(find.text('AI sẽ cùng bạn làm rõ'), findsOneWidget);
  });

  test('uses concise response rules for the Gemini system prompt', () {
    expect(careerCounselorSystemPrompt, contains('tối đa 120 từ'));
    expect(careerCounselorSystemPrompt, contains('MỘT câu quan trọng nhất'));
    expect(careerCounselorSystemPrompt, contains('tối đa 3 ngành'));
  });

  testWidgets('returns to home when exiting the AI chat tab', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const CareerGuidanceApp(requireAuthentication: false),
    );

    await tester.tap(find.text('Chat'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Thoát chat'), findsOneWidget);

    await tester.tap(find.byTooltip('Thoát chat'));
    await tester.pumpAndSettle();
    expect(find.text('Xin chào 👋'), findsOneWidget);
  });

  testWidgets('switches the app language to English from profile', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const CareerGuidanceApp(requireAuthentication: false),
    );

    await tester.tap(find.text('Cá nhân'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ngôn ngữ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    expect(find.text('Career Chatbot'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
  });

  testWidgets('clears AI chat history after confirmation', (
    WidgetTester tester,
  ) async {
    var didClearHistory = false;
    final languageController = AppLanguageController();
    await tester.pumpWidget(
      AppLanguageScope(
        controller: languageController,
        child: MaterialApp(
          home: Scaffold(
            body: HistoryScreen(
              messages: const [
                CareerMessage(text: 'Em hợp ngành nào?', isUser: true),
              ],
              onClearHistory: () => didClearHistory = true,
              onContinueConversation: () {},
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Xóa lịch sử'));
    await tester.pumpAndSettle();
    expect(find.text('Xóa lịch sử trò chuyện?'), findsOneWidget);

    await tester.tap(find.text('Xóa'));
    await tester.pumpAndSettle();
    expect(didClearHistory, isTrue);
  });

  testWidgets('opens the active chat when a history item is tapped', (
    WidgetTester tester,
  ) async {
    var didContinueConversation = false;
    final languageController = AppLanguageController();
    await tester.pumpWidget(
      AppLanguageScope(
        controller: languageController,
        child: MaterialApp(
          home: Scaffold(
            body: HistoryScreen(
              messages: const [
                CareerMessage(text: 'Em hợp ngành nào?', isUser: true),
              ],
              onClearHistory: () {},
              onContinueConversation: () => didContinueConversation = true,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Em hợp ngành nào?'));
    expect(didContinueConversation, isTrue);
  });
}
