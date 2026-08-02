import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_localizations.dart';
import 'avatar_models.dart';
import 'auth_gate.dart';
import 'chat_appearance.dart';
import 'gemini_service.dart';
import 'user_state_storage.dart';

/// Entry point for the Material 3 career-guidance application.
class CareerGuidanceApp extends StatefulWidget {
  const CareerGuidanceApp({super.key, this.requireAuthentication = true});

  static const Color primaryBlue = Color(0xFF2563EB);
  final bool requireAuthentication;

  @override
  State<CareerGuidanceApp> createState() => _CareerGuidanceAppState();
}

class _CareerGuidanceAppState extends State<CareerGuidanceApp> {
  final _languageController = AppLanguageController();

  @override
  void dispose() {
    _languageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _languageController,
      builder: (context, _) => AppLanguageScope(
        controller: _languageController,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          title: _languageController.language == AppLanguage.english
              ? 'Career Chatbot'
              : 'Chatbot Hướng nghiệp',
          locale: Locale(
            _languageController.language == AppLanguage.english ? 'en' : 'vi',
          ),
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: CareerGuidanceApp.primaryBlue,
              brightness: Brightness.light,
            ),
            scaffoldBackgroundColor: const Color(0xFFF8FAFC),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: CareerGuidanceApp.primaryBlue,
                  width: 1.5,
                ),
              ),
            ),
          ),
          home: widget.requireAuthentication
              ? const AuthGate(signedInChild: MainNavigationScreen())
              : const MainNavigationScreen(enablePersistence: false),
        ),
      ),
    );
  }
}

/// Owns bottom navigation and routes a question from the home page into chat.
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key, this.enablePersistence = true});

  final bool enablePersistence;

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedTab = 0;
  int _submissionId = 0;
  int _clearHistoryId = 0;
  int _restoreId = 0;
  String? _pendingQuestion;
  List<CareerMessage> _history = const [];
  final _storage = UserStateStorage();
  AppLanguageController? _languageController;
  String? _userId;
  ChatAppearance _chatAppearance = const ChatAppearance();
  String? _avatarBase64;
  AiAvatarId _aiAvatar = AiAvatarId.robot;

  @override
  void initState() {
    super.initState();
    if (widget.enablePersistence) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _restoreUserState());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = AppLanguageScope.controllerOf(context);
    if (identical(controller, _languageController)) return;
    _languageController?.removeListener(_saveLanguage);
    _languageController = controller;
    _languageController!.addListener(_saveLanguage);
  }

  @override
  void dispose() {
    _languageController?.removeListener(_saveLanguage);
    super.dispose();
  }

  Future<void> _restoreUserState() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    _userId = user.id;
    final savedState = await _storage.read(user.id);
    if (!mounted) return;
    if (savedState.language != null) {
      _languageController?.changeTo(savedState.language!);
    }
    setState(() {
      _history = savedState.messages
          .map(
            (message) => CareerMessage(
              text: message.text,
              isUser: message.isUser,
              isError: message.isError,
              includeInAiHistory: message.includeInAiHistory,
            ),
          )
          .toList(growable: false);
      _chatAppearance = savedState.chatAppearance;
      _avatarBase64 = savedState.avatarBase64;
      _aiAvatar = savedState.aiAvatar;
      _restoreId++;
    });
  }

  void _saveLanguage() {
    final userId = _userId;
    final controller = _languageController;
    if (!widget.enablePersistence || userId == null || controller == null) {
      return;
    }
    unawaited(_storage.saveLanguage(userId, controller.language));
  }

  void _saveHistory(List<CareerMessage> messages) {
    setState(() => _history = messages);
    final userId = _userId;
    if (!widget.enablePersistence || userId == null) return;
    unawaited(
      _storage.saveMessages(
        userId,
        messages
            .map(
              (message) => StoredCareerMessage(
                text: message.text,
                isUser: message.isUser,
                isError: message.isError,
                includeInAiHistory: message.includeInAiHistory,
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  void _changeChatAppearance(ChatAppearance appearance) {
    setState(() => _chatAppearance = appearance);
    final userId = _userId;
    if (widget.enablePersistence && userId != null) {
      unawaited(_storage.saveChatAppearance(userId, appearance));
    }
  }

  void _changeAvatar(String? avatarBase64) {
    setState(() => _avatarBase64 = avatarBase64);
    final userId = _userId;
    if (widget.enablePersistence && userId != null) {
      unawaited(_storage.saveAvatar(userId, avatarBase64));
    }
  }

  void _changeAiAvatar(AiAvatarId avatar) {
    setState(() => _aiAvatar = avatar);
    final userId = _userId;
    if (widget.enablePersistence && userId != null) {
      unawaited(_storage.saveAiAvatar(userId, avatar));
    }
  }

  void _startChat(String question) {
    final text = question.trim();
    if (text.isEmpty) return;
    setState(() {
      _pendingQuestion = text;
      _submissionId++;
      _selectedTab = 1;
    });
  }

  void _clearHistory() {
    setState(() {
      _history = const [];
      _pendingQuestion = null;
      _clearHistoryId++;
    });
    final userId = _userId;
    if (widget.enablePersistence && userId != null) {
      unawaited(_storage.saveMessages(userId, const []));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final pages = [
      HomeScreen(onStartChat: _startChat),
      CareerChatScreen(
        question: _pendingQuestion,
        submissionId: _submissionId,
        clearHistoryId: _clearHistoryId,
        restoreId: _restoreId,
        initialMessages: _history,
        appearance: _chatAppearance,
        aiAvatar: _aiAvatar,
        onMessagesChanged: _saveHistory,
      ),
      HistoryScreen(
        messages: _history,
        onClearHistory: _clearHistory,
        onContinueConversation: () => setState(() => _selectedTab = 1),
      ),
      ProfileScreen(
        appearance: _chatAppearance,
        onAppearanceChanged: _changeChatAppearance,
        avatarBase64: _avatarBase64,
        onAvatarChanged: _changeAvatar,
        aiAvatar: _aiAvatar,
        onAiAvatarChanged: _changeAiAvatar,
      ),
    ];

    return Scaffold(
      appBar: _CareerAppBar(
        showExit: _selectedTab == 1,
        onExit: () => setState(() => _selectedTab = 0),
        avatarBase64: _avatarBase64,
      ),
      body: IndexedStack(index: _selectedTab, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTab,
        onDestinationSelected: (index) => setState(() => _selectedTab = index),
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: s.t('Trang chủ', 'Home'),
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline_rounded),
            selectedIcon: Icon(Icons.chat_bubble_rounded),
            label: s.t('Chat', 'Chat'),
          ),
          NavigationDestination(
            icon: Icon(Icons.history_rounded),
            selectedIcon: Icon(Icons.history_rounded),
            label: s.t('Lịch sử', 'History'),
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: s.t('Cá nhân', 'Profile'),
          ),
        ],
      ),
    );
  }
}

/// App bar shared by every tab.
class _CareerAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _CareerAppBar({
    required this.showExit,
    required this.onExit,
    required this.avatarBase64,
  });

  final bool showExit;
  final VoidCallback onExit;
  final String? avatarBase64;

  @override
  Size get preferredSize => const Size.fromHeight(68);

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    return AppBar(
      surfaceTintColor: Colors.transparent,
      backgroundColor: const Color(0xFFF8FAFC),
      leading: showExit
          ? IconButton(
              tooltip: s.t('Thoát chat', 'Exit chat'),
              onPressed: onExit,
              icon: const Icon(Icons.close_rounded),
            )
          : null,
      titleSpacing: 20,
      title: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: CareerGuidanceApp.primaryBlue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.smart_toy_rounded, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Text(
            s.t('Chatbot Hướng nghiệp', 'Career Chatbot'),
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 20),
          child: CircleAvatar(
            radius: 19,
            backgroundColor: const Color(0xFFDBEAFE),
            backgroundImage: _avatarImage(avatarBase64),
            child: avatarBase64 == null
                ? const Icon(
                    Icons.person_rounded,
                    color: CareerGuidanceApp.primaryBlue,
                  )
                : null,
          ),
        ),
      ],
    );
  }
}

MemoryImage? _avatarImage(String? avatarBase64) {
  if (avatarBase64 == null || avatarBase64.isEmpty) return null;
  try {
    return MemoryImage(base64Decode(avatarBase64));
  } on FormatException {
    return null;
  }
}

/// Main dashboard for discovering majors, schools and career pathways.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.onStartChat});

  final ValueChanged<String> onStartChat;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _questionController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    _questionController.dispose();
    super.dispose();
  }

  void _useSuggestion(String question) {
    setState(() => _questionController.text = question);
  }

  void _startQuestion(String question) {
    FocusScope.of(context).unfocus();
    widget.onStartChat(question);
  }

  Future<void> _openFeature(_Feature feature) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) =>
            _GuidanceFeaturePage(feature: feature, onStartChat: _startQuestion),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          children: [
            const _WelcomeBanner(),
            const SizedBox(height: 20),
            _SearchField(
              controller: _searchController,
              onSubmitted: _startQuestion,
            ),
            const SizedBox(height: 28),
            _SectionTitle(s.t('Khám phá cùng AI', 'Explore with AI')),
            const SizedBox(height: 12),
            _FeatureGrid(onOpenFeature: _openFeature),
            const SizedBox(height: 28),
            _SectionTitle(s.t('Đặt câu hỏi', 'Ask a question')),
            const SizedBox(height: 12),
            _QuickQuestionBox(
              controller: _questionController,
              onSend: () => _startQuestion(_questionController.text),
            ),
            const SizedBox(height: 16),
            Text(
              s.t('Gợi ý cho bạn', 'Suggestions for you'),
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            _SuggestionChips(onSelected: _useSuggestion),
          ],
        ),
      ),
    );
  }
}

class _WelcomeBanner extends StatelessWidget {
  const _WelcomeBanner();

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 14, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF4F8DF7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.t('Xin chào 👋', 'Hello 👋'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  s.t(
                    'AI sẽ giúp bạn lựa chọn ngành học và trường phù hợp.',
                    'AI helps you choose a major and school that fit you.',
                  ),
                  style: const TextStyle(
                    color: Color(0xFFEFF6FF),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const _ChatbotIllustration(),
        ],
      ),
    );
  }
}

class _ChatbotIllustration extends StatelessWidget {
  const _ChatbotIllustration();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: const BoxDecoration(
            color: Color(0x33255FEA),
            shape: BoxShape.circle,
          ),
        ),
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(23),
          ),
          child: const Icon(
            Icons.smart_toy_rounded,
            color: CareerGuidanceApp.primaryBlue,
            size: 38,
          ),
        ),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onSubmitted});

  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        hintText: s.t(
          'Hỏi về ngành học hoặc trường...',
          'Ask about a major or school...',
        ),
        prefixIcon: const Icon(Icons.search_rounded),
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
    );
  }
}

class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid({required this.onOpenFeature});

  final ValueChanged<_Feature> onOpenFeature;

  static const List<_Feature> _features = [
    _Feature(
      'Tư vấn ngành học',
      Icons.school_rounded,
      Color(0xFF2563EB),
      'Mình chưa rõ hợp ngành nào. Hãy hỏi mình về sở thích, năng lực và tính cách.',
      'Khám phá nhóm ngành phù hợp từ sở thích, môn học thế mạnh và tính cách của bạn.',
      [
        'Sở thích và hoạt động yêu thích',
        'Môn học thế mạnh',
        'Điều bạn muốn ưu tiên',
      ],
    ),
    _Feature(
      'Tìm trường phù hợp',
      Icons.account_balance_rounded,
      Color(0xFF7C3AED),
      'Hãy giúp mình chọn trường đại học hoặc cao đẳng phù hợp.',
      'Tìm cơ sở đào tạo phù hợp với ngành quan tâm, năng lực và điều kiện của bạn.',
      [
        'Khu vực muốn học',
        'Ngành đang quan tâm',
        'Ngân sách và năng lực hiện tại',
      ],
    ),
    _Feature(
      'So sánh trường',
      Icons.compare_arrows_rounded,
      Color(0xFF0891B2),
      'Hãy hướng dẫn mình so sánh các trường phù hợp.',
      'So sánh các trường theo chương trình học, học phí, vị trí và phương thức xét tuyển.',
      [
        'Chọn 2–3 trường để so sánh',
        'Xác định tiêu chí quan trọng',
        'Xem điểm khác biệt',
      ],
    ),
    _Feature(
      'Thông tin tuyển sinh',
      Icons.menu_book_rounded,
      Color(0xFFEA580C),
      'Mình muốn tìm hiểu thông tin tuyển sinh. Bạn cần biết trường, ngành và năm nào?',
      'Tìm hiểu tổ hợp xét tuyển, phương thức và mốc tuyển sinh của trường/ngành bạn quan tâm.',
      [
        'Trường hoặc ngành muốn hỏi',
        'Năm tuyển sinh',
        'Phương thức xét tuyển quan tâm',
      ],
    ),
    _Feature(
      'Khám phá nghề nghiệp',
      Icons.work_outline_rounded,
      Color(0xFF16A34A),
      'Hãy giúp mình khám phá các nghề nghiệp phù hợp.',
      'Khám phá công việc, môi trường làm việc và kỹ năng cần có của các nhóm nghề.',
      [
        'Việc bạn thích làm',
        'Kỹ năng bạn muốn phát triển',
        'Môi trường làm việc mong muốn',
      ],
    ),
    _Feature(
      'Làm bài test hướng nghiệp',
      Icons.psychology_alt_rounded,
      Color(0xFFDB2777),
      'Mình muốn làm bài khám phá hướng nghiệp. Hãy bắt đầu câu hỏi đầu tiên.',
      'Trả lời một số câu hỏi ngắn để AI hiểu rõ hơn về bạn trước khi gợi ý hướng đi.',
      ['Sở thích', 'Năng lực', 'Tính cách'],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.22,
      ),
      itemCount: _features.length,
      itemBuilder: (context, index) => _FeatureCard(
        feature: _features[index],
        onTap: () => onOpenFeature(_features[index]),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.feature, required this.onTap});

  final _Feature feature;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    return Card(
      elevation: 1.5,
      shadowColor: const Color(0x1A0F172A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: feature.color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(feature.icon, color: feature.color, size: 27),
              ),
              const Spacer(),
              Text(
                feature.titleFor(s),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A dedicated page for every feature card on the home screen.
class _GuidanceFeaturePage extends StatefulWidget {
  const _GuidanceFeaturePage({
    required this.feature,
    required this.onStartChat,
  });

  final _Feature feature;
  final ValueChanged<String> onStartChat;

  @override
  State<_GuidanceFeaturePage> createState() => _GuidanceFeaturePageState();
}

class _GuidanceFeaturePageState extends State<_GuidanceFeaturePage> {
  final TextEditingController _detailsController = TextEditingController();

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  void _continueToChat() {
    final details = _detailsController.text.trim();
    final s = context.strings;
    final prompt = details.isEmpty
        ? widget.feature.promptFor(s)
        : '${widget.feature.promptFor(s)}\n${s.t('Thông tin thêm của mình:', 'Additional information:')} $details';
    widget.onStartChat(prompt);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final feature = widget.feature;
    final s = context.strings;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: s.t('Thoát', 'Exit'),
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded),
        ),
        title: Text(feature.titleFor(s)),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  width: 64,
                  height: 64,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: feature.color.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(feature.icon, color: feature.color, size: 34),
                ),
                const SizedBox(height: 20),
                Text(
                  feature.titleFor(s),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  feature.descriptionFor(s),
                  style: const TextStyle(color: Color(0xFF64748B), height: 1.5),
                ),
                const SizedBox(height: 28),
                Text(
                  s.t('AI sẽ cùng bạn làm rõ', 'AI will help you clarify'),
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                ...feature
                    .stepsFor(s)
                    .map(
                      (step) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              color: feature.color,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: Text(step)),
                          ],
                        ),
                      ),
                    ),
                const SizedBox(height: 20),
                TextField(
                  controller: _detailsController,
                  minLines: 3,
                  maxLines: 5,
                  decoration: InputDecoration(
                    labelText: s.t(
                      'Thông tin bạn muốn chia sẻ thêm',
                      'Additional information',
                    ),
                    hintText: s.t(
                      'Ví dụ: Em đang học lớp 12 và thích môn Toán.',
                      'Example: I am in grade 12 and enjoy Mathematics.',
                    ),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _continueToChat,
                  icon: const Icon(Icons.chat_rounded),
                  label: Text(s.t('Bắt đầu với AI', 'Start with AI')),
                  style: FilledButton.styleFrom(
                    backgroundColor: CareerGuidanceApp.primaryBlue,
                    minimumSize: const Size.fromHeight(52),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickQuestionBox extends StatelessWidget {
  const _QuickQuestionBox({required this.controller, required this.onSend});

  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          TextField(
            key: const ValueKey('quick-question-field'),
            controller: controller,
            minLines: 3,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: s.t(
                'Ví dụ: Em được 24 điểm nên học trường nào?',
                'Example: I scored 24 points. Which school should I choose?',
              ),
              alignLabelWithHint: true,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onSend,
              icon: const Icon(Icons.send_rounded),
              label: Text(s.t('Gửi', 'Send')),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: CareerGuidanceApp.primaryBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestionChips extends StatelessWidget {
  const _SuggestionChips({required this.onSelected});

  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final suggestions = s.isEnglish
        ? const [
            'What do you study in Computer Science?',
            'Which schools have low tuition?',
            'Is it easy to find work in AI?',
            'Which major suits me?',
          ]
        : const [
            'Ngành CNTT học gì?',
            'Trường nào có học phí thấp?',
            'Nghề AI có dễ xin việc?',
            'Em hợp ngành nào?',
          ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: suggestions
          .map(
            (suggestion) => ActionChip(
              onPressed: () => onSelected(suggestion),
              label: Text(suggestion),
              labelStyle: const TextStyle(fontWeight: FontWeight.w600),
              side: const BorderSide(color: Color(0xFFBFDBFE)),
              backgroundColor: const Color(0xFFEFF6FF),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          )
          .toList(),
    );
  }
}

/// Functional Gemini chat screen. It inherits the system prompt from GeminiService.
class CareerChatScreen extends StatefulWidget {
  const CareerChatScreen({
    super.key,
    required this.question,
    required this.submissionId,
    required this.clearHistoryId,
    required this.restoreId,
    required this.initialMessages,
    required this.appearance,
    required this.aiAvatar,
    required this.onMessagesChanged,
  });

  final String? question;
  final int submissionId;
  final int clearHistoryId;
  final int restoreId;
  final List<CareerMessage> initialMessages;
  final ChatAppearance appearance;
  final AiAvatarId aiAvatar;
  final ValueChanged<List<CareerMessage>> onMessagesChanged;

  @override
  State<CareerChatScreen> createState() => _CareerChatScreenState();
}

class _CareerChatScreenState extends State<CareerChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  GeminiClient? _geminiClient;
  String? _geminiLanguage;
  bool _isWaiting = false;
  int _requestId = 0;
  final List<CareerMessage> _messages = [
    const CareerMessage(
      text:
          'Chào bạn 👋 Mình là trợ lý hướng nghiệp. Bạn đang băn khoăn điều gì?',
      isUser: false,
      includeInAiHistory: false,
    ),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_messages.length != 1 || _messages.first.includeInAiHistory) return;
    _messages[0] = CareerMessage(
      text: context.strings.t(
        'Chào bạn 👋 Mình là trợ lý hướng nghiệp. Bạn đang băn khoăn điều gì?',
        'Hello 👋 I am your career guidance assistant. What are you wondering about?',
      ),
      isUser: false,
      includeInAiHistory: false,
    );
  }

  @override
  void didUpdateWidget(covariant CareerChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.clearHistoryId != oldWidget.clearHistoryId) {
      _clearConversation();
    }
    if (widget.restoreId != oldWidget.restoreId) {
      _restoreConversation(widget.initialMessages);
    }
    if (widget.submissionId != oldWidget.submissionId &&
        widget.question != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _sendMessage(widget.question!),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _sendFromInput() {
    final text = _controller.text.trim();
    _controller.clear();
    _sendMessage(text);
  }

  void _clearConversation() {
    _requestId++;
    _controller.clear();
    setState(() {
      _isWaiting = false;
      _messages
        ..clear()
        ..add(
          CareerMessage(
            text: context.strings.t(
              'Chào bạn 👋 Mình là trợ lý hướng nghiệp. Bạn đang băn khoăn điều gì?',
              'Hello 👋 I am your career guidance assistant. What are you wondering about?',
            ),
            isUser: false,
            includeInAiHistory: false,
          ),
        );
    });
    _notifyHistory();
    _scrollToLatest();
  }

  void _restoreConversation(List<CareerMessage> messages) {
    _requestId++;
    _controller.clear();
    setState(() {
      _isWaiting = false;
      _messages
        ..clear()
        ..addAll(messages.isEmpty ? [_welcomeMessage()] : messages);
    });
    _notifyHistory();
    _scrollToLatest();
  }

  CareerMessage _welcomeMessage() => CareerMessage(
    text: context.strings.t(
      'Chào bạn 👋 Mình là trợ lý hướng nghiệp. Bạn đang băn khoăn điều gì?',
      'Hello 👋 I am your career guidance assistant. What are you wondering about?',
    ),
    isUser: false,
    includeInAiHistory: false,
  );

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _isWaiting) return;
    final requestId = ++_requestId;
    setState(() {
      _messages.add(CareerMessage(text: text.trim(), isUser: true));
      _isWaiting = true;
    });
    _notifyHistory();
    _scrollToLatest();

    try {
      final languageCode = context.strings.languageCode;
      final client = _geminiClient != null && _geminiLanguage == languageCode
          ? _geminiClient!
          : GeminiService(languageCode: languageCode);
      _geminiClient = client;
      _geminiLanguage = languageCode;
      final reply = await client.generateReply(
        _messages
            .where((message) => message.includeInAiHistory)
            .map(
              (message) => GeminiChatTurn(
                role: message.isUser ? 'user' : 'model',
                text: message.text,
              ),
            )
            .toList(),
      );
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _messages.add(CareerMessage(text: reply, isUser: false));
        _isWaiting = false;
      });
    } on GeminiException catch (error) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _messages.add(
          CareerMessage(
            text:
                '${context.strings.t('Không thể hỏi AI:', 'Unable to ask AI:')} ${error.message}',
            isUser: false,
            isError: true,
            includeInAiHistory: false,
          ),
        );
        _isWaiting = false;
      });
    } catch (_) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _messages.add(
          CareerMessage(
            text: context.strings.t(
              'Không thể kết nối với AI lúc này. Bạn hãy thử lại sau nhé.',
              'Unable to connect to AI right now. Please try again later.',
            ),
            isUser: false,
            isError: true,
            includeInAiHistory: false,
          ),
        );
        _isWaiting = false;
      });
    }
    _notifyHistory();
    _scrollToLatest();
  }

  void _notifyHistory() =>
      widget.onMessagesChanged(List.unmodifiable(_messages));

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final appearance = widget.appearance;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              s.t('Trò chuyện cùng AI', 'Chat with AI'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: appearance.botText,
              ),
            ),
          ),
        ),
        Expanded(
          child: ColoredBox(
            color: appearance.background,
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              children: [
                ..._messages.map(
                  (message) => _ChatBubble(
                    message: message,
                    appearance: appearance,
                    aiAvatar: widget.aiAvatar,
                  ),
                ),
                if (_isWaiting) _TypingBubble(appearance: appearance),
              ],
            ),
          ),
        ),
        _ChatComposer(
          controller: _controller,
          isWaiting: _isWaiting,
          appearance: appearance,
          onSend: _sendFromInput,
        ),
      ],
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.message,
    required this.appearance,
    required this.aiAvatar,
  });

  final CareerMessage message;
  final ChatAppearance appearance;
  final AiAvatarId aiAvatar;

  @override
  Widget build(BuildContext context) {
    final color = message.isUser
        ? appearance.accent
        : message.isError
        ? const Color(0xFFFFF1F2)
        : appearance.botBubble;
    final textColor = message.isUser
        ? Colors.white
        : message.isError
        ? const Color(0xFFBE123C)
        : appearance.botText;
    final bubble = Container(
      constraints: const BoxConstraints(maxWidth: 520),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(message.isUser ? 18 : 4),
          bottomRight: Radius.circular(message.isUser ? 4 : 18),
        ),
        border: message.isUser ? null : Border.all(color: appearance.border),
      ),
      child: Text(
        message.text,
        style: TextStyle(
          color: textColor,
          height: 1.45,
          fontSize: appearance.messageFontSize,
        ),
      ),
    );
    if (message.isUser) {
      return Align(alignment: Alignment.centerRight, child: bubble);
    }
    final aiStyle = aiAvatarStyle(aiAvatar);
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: aiStyle.backgroundColor,
            child: Icon(aiStyle.icon, size: 18, color: aiStyle.foregroundColor),
          ),
          const SizedBox(width: 8),
          Flexible(child: bubble),
        ],
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble({required this.appearance});

  final ChatAppearance appearance;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: appearance.accent,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              context.strings.t('AI đang suy nghĩ…', 'AI is thinking…'),
              style: TextStyle(
                color: appearance.mutedText,
                fontSize: appearance.messageFontSize,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatComposer extends StatelessWidget {
  const _ChatComposer({
    required this.controller,
    required this.isWaiting,
    required this.appearance,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool isWaiting;
  final ChatAppearance appearance;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: appearance.composer,
        border: Border(top: BorderSide(color: appearance.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: !isWaiting,
              onSubmitted: isWaiting ? null : (_) => onSend(),
              textInputAction: TextInputAction.send,
              style: TextStyle(
                color: appearance.inputText,
                fontSize: appearance.messageFontSize,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: appearance.inputFill,
                hintText: s.t('Nhập câu hỏi của bạn…', 'Type your question…'),
                hintStyle: TextStyle(color: appearance.mutedText),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: isWaiting ? null : onSend,
            style: FilledButton.styleFrom(
              backgroundColor: appearance.accent,
              minimumSize: const Size(52, 50),
              padding: EdgeInsets.zero,
            ),
            child: isWaiting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send_rounded),
          ),
        ],
      ),
    );
  }
}

/// Shows the current conversation, so a student can review what they asked.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({
    super.key,
    required this.messages,
    required this.onClearHistory,
    required this.onContinueConversation,
  });

  final List<CareerMessage> messages;
  final VoidCallback onClearHistory;
  final VoidCallback onContinueConversation;

  Future<void> _confirmClear(BuildContext context) async {
    final s = context.strings;
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(s.t('Xóa lịch sử trò chuyện?', 'Clear chat history?')),
        content: Text(
          s.t(
            'Toàn bộ tin nhắn với AI trong phiên này sẽ bị xóa.',
            'All AI messages from this session will be removed.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(s.t('Hủy', 'Cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(s.t('Xóa', 'Clear')),
          ),
        ],
      ),
    );
    if (shouldClear != true) return;
    onClearHistory();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final userMessages = messages.where((message) => message.isUser).toList();
    if (userMessages.isEmpty) {
      return _EmptyState(
        icon: Icons.history_rounded,
        title: s.t('Chưa có lịch sử', 'No history yet'),
        subtitle: s.t(
          'Các câu hỏi bạn gửi cho AI sẽ xuất hiện ở đây.',
          'Questions you send to AI will appear here.',
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: userMessages.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: () => _confirmClear(context),
              icon: const Icon(Icons.delete_outline_rounded),
              label: Text(s.t('Xóa lịch sử', 'Clear history')),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFB42318),
              ),
            ),
          );
        }
        final message = userMessages[index - 1];
        return ListTile(
          onTap: onContinueConversation,
          tileColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          leading: const CircleAvatar(
            backgroundColor: Color(0xFFDBEAFE),
            child: Icon(Icons.chat_bubble_outline_rounded),
          ),
          title: Text(
            message.text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(s.t('Câu hỏi đã gửi', 'Sent question')),
        );
      },
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.appearance,
    required this.onAppearanceChanged,
    required this.avatarBase64,
    required this.onAvatarChanged,
    required this.aiAvatar,
    required this.onAiAvatarChanged,
  });

  final ChatAppearance appearance;
  final ValueChanged<ChatAppearance> onAppearanceChanged;
  final String? avatarBase64;
  final ValueChanged<String?> onAvatarChanged;
  final AiAvatarId aiAvatar;
  final ValueChanged<AiAvatarId> onAiAvatarChanged;

  Future<void> _pickAvatar(BuildContext context) async {
    final s = context.strings;
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 72,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (bytes.length > 700 * 1024) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              s.t(
                'Ảnh quá lớn. Hãy chọn ảnh nhỏ hơn 700 KB.',
                'Image is too large. Choose an image under 700 KB.',
              ),
            ),
          ),
        );
        return;
      }
      onAvatarChanged(base64Encode(bytes));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            s.t(
              'Không thể chọn ảnh. Hãy thử lại.',
              'Unable to select an image. Try again.',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _chooseAiAvatar(BuildContext context) async {
    final s = context.strings;
    final selected = await showModalBottomSheet<AiAvatarId>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Wrap(
            spacing: 14,
            runSpacing: 14,
            children: AiAvatarId.values
                .map(
                  (avatar) => _AiAvatarChoice(
                    avatar: avatar,
                    label: _aiAvatarLabel(s, avatar),
                    selected: avatar == aiAvatar,
                    onTap: () => Navigator.pop(sheetContext, avatar),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
    if (selected != null) onAiAvatarChanged(selected);
  }

  String _aiAvatarLabel(AppStrings s, AiAvatarId avatar) => switch (avatar) {
    AiAvatarId.robot => s.t('Robot', 'Robot'),
    AiAvatarId.compass => s.t('La bàn', 'Compass'),
    AiAvatarId.lightbulb => s.t('Bóng đèn', 'Light bulb'),
    AiAvatarId.school => s.t('Trường học', 'School'),
  };

  Future<void> _signOut(BuildContext context) async {
    final s = context.strings;
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(s.t('Đăng xuất?', 'Sign out?')),
        content: Text(
          s.t(
            'Bạn sẽ cần đăng nhập lại để tiếp tục sử dụng ứng dụng.',
            'You will need to sign in again to continue using the app.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(s.t('Hủy', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(s.t('Đăng xuất', 'Sign out')),
          ),
        ],
      ),
    );
    if (shouldSignOut != true) return;
    await Supabase.instance.client.auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final controller = AppLanguageScope.controllerOf(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Center(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 38,
                backgroundColor: const Color(0xFFDBEAFE),
                backgroundImage: _avatarImage(avatarBase64),
                child: avatarBase64 == null
                    ? const Icon(
                        Icons.person_rounded,
                        size: 42,
                        color: CareerGuidanceApp.primaryBlue,
                      )
                    : null,
              ),
              Positioned(
                right: -6,
                bottom: -6,
                child: IconButton.filled(
                  tooltip: s.t('Tải ảnh đại diện', 'Upload profile picture'),
                  onPressed: () => _pickAvatar(context),
                  icon: const Icon(Icons.edit_rounded, size: 18),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: Text(
            s.t('Hồ sơ của bạn', 'Your profile'),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 24),
        Card(
          child: ListTile(
            leading: const Icon(
              Icons.photo_camera_back_outlined,
              color: CareerGuidanceApp.primaryBlue,
            ),
            title: Text(s.t('Ảnh đại diện', 'Profile picture')),
            subtitle: Text(
              avatarBase64 == null
                  ? s.t(
                      'Chọn ảnh từ thiết bị',
                      'Choose an image from your device',
                    )
                  : s.t('Đã cập nhật', 'Updated'),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _pickAvatar(context),
          ),
        ),
        Card(
          child: ListTile(
            leading: _AiAvatarBadge(avatar: aiAvatar, radius: 20),
            title: Text(s.t('Avatar của AI', 'AI avatar')),
            subtitle: Text(
              s.t('Chọn nhân vật trợ lý', 'Choose your assistant character'),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _chooseAiAvatar(context),
          ),
        ),
        _ProfileItem(
          icon: Icons.school_outlined,
          title: s.t('Lớp học', 'Grade level'),
          value: s.t('Chưa cập nhật', 'Not updated'),
        ),
        _ProfileItem(
          icon: Icons.location_on_outlined,
          title: s.t('Khu vực mong muốn', 'Preferred location'),
          value: s.t('Chưa cập nhật', 'Not updated'),
        ),
        _ProfileItem(
          icon: Icons.flag_outlined,
          title: s.t('Mục tiêu ngành học', 'Major goal'),
          value: s.t('Chưa cập nhật', 'Not updated'),
        ),
        Card(
          child: ListTile(
            leading: Icon(Icons.tune_rounded, color: appearance.accent),
            title: Text(s.t('Giao diện nhắn tin', 'Chat appearance')),
            subtitle: Text(
              s.t(
                'Màu sắc, cỡ chữ và sáng/tối',
                'Color, text size and light/dark',
              ),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ChatAppearanceScreen(
                  appearance: appearance,
                  onChanged: onAppearanceChanged,
                ),
              ),
            ),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(
              Icons.language_rounded,
              color: CareerGuidanceApp.primaryBlue,
            ),
            title: Text(s.t('Ngôn ngữ', 'Language')),
            subtitle: Text(s.languageName),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => showModalBottomSheet<void>(
              context: context,
              builder: (sheetContext) => SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      title: const Text('Tiếng Việt'),
                      trailing: controller.language == AppLanguage.vietnamese
                          ? const Icon(
                              Icons.check_rounded,
                              color: CareerGuidanceApp.primaryBlue,
                            )
                          : null,
                      onTap: () {
                        controller.changeTo(AppLanguage.vietnamese);
                        Navigator.pop(sheetContext);
                      },
                    ),
                    ListTile(
                      title: const Text('English'),
                      trailing: controller.language == AppLanguage.english
                          ? const Icon(
                              Icons.check_rounded,
                              color: CareerGuidanceApp.primaryBlue,
                            )
                          : null,
                      onTap: () {
                        controller.changeTo(AppLanguage.english);
                        Navigator.pop(sheetContext);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.logout_rounded, color: Color(0xFFB42318)),
            title: Text(
              s.t('Đăng xuất', 'Sign out'),
              style: const TextStyle(color: Color(0xFFB42318)),
            ),
            onTap: () => _signOut(context),
          ),
        ),
      ],
    );
  }
}

class ChatAppearanceScreen extends StatefulWidget {
  const ChatAppearanceScreen({
    super.key,
    required this.appearance,
    required this.onChanged,
  });

  final ChatAppearance appearance;
  final ValueChanged<ChatAppearance> onChanged;

  @override
  State<ChatAppearanceScreen> createState() => _ChatAppearanceScreenState();
}

class _ChatAppearanceScreenState extends State<ChatAppearanceScreen> {
  late ChatAppearance _appearance;

  @override
  void initState() {
    super.initState();
    _appearance = widget.appearance;
  }

  void _updateAppearance(ChatAppearance appearance) {
    setState(() => _appearance = appearance);
    widget.onChanged(appearance);
  }

  String _brightnessLabel(BuildContext context, ChatBrightness value) =>
      switch (value) {
        ChatBrightness.light => context.strings.t('Sáng', 'Light'),
        ChatBrightness.dark => context.strings.t('Tối', 'Dark'),
      };

  String _themeLabel(BuildContext context, ChatColorTheme value) =>
      switch (value) {
        ChatColorTheme.blue => context.strings.t('Xanh dương', 'Blue'),
        ChatColorTheme.violet => context.strings.t('Tím', 'Violet'),
        ChatColorTheme.emerald => context.strings.t('Xanh lá', 'Green'),
      };

  String _fontLabel(BuildContext context, ChatFontSize value) =>
      switch (value) {
        ChatFontSize.compact => context.strings.t('Nhỏ', 'Small'),
        ChatFontSize.standard => context.strings.t('Vừa', 'Medium'),
        ChatFontSize.large => context.strings.t('Lớn', 'Large'),
      };

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final appearance = _appearance;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: s.t('Thoát', 'Close'),
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close_rounded),
        ),
        title: Text(s.t('Giao diện nhắn tin', 'Chat appearance')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _AppearancePreview(appearance: appearance),
          const SizedBox(height: 24),
          Text(
            s.t('Chế độ', 'Mode'),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          SegmentedButton<ChatBrightness>(
            segments: ChatBrightness.values
                .map(
                  (value) => ButtonSegment(
                    value: value,
                    label: Text(_brightnessLabel(context, value)),
                    icon: Icon(
                      value == ChatBrightness.light
                          ? Icons.light_mode_rounded
                          : Icons.dark_mode_rounded,
                    ),
                  ),
                )
                .toList(),
            selected: {appearance.brightness},
            onSelectionChanged: (values) => _updateAppearance(
              appearance.copyWith(brightness: values.first),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            s.t('Màu tin nhắn', 'Chat color'),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ChatColorTheme.values
                .map(
                  (value) => ChoiceChip(
                    label: Text(_themeLabel(context, value)),
                    selected: appearance.colorTheme == value,
                    selectedColor: ChatAppearance(
                      colorTheme: value,
                    ).accent.withValues(alpha: .18),
                    onSelected: (_) => _updateAppearance(
                      appearance.copyWith(colorTheme: value),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 24),
          Text(
            s.t('Cỡ chữ', 'Text size'),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          SegmentedButton<ChatFontSize>(
            segments: ChatFontSize.values
                .map(
                  (value) => ButtonSegment(
                    value: value,
                    label: Text(_fontLabel(context, value)),
                  ),
                )
                .toList(),
            selected: {appearance.fontSize},
            onSelectionChanged: (values) =>
                _updateAppearance(appearance.copyWith(fontSize: values.first)),
          ),
        ],
      ),
    );
  }
}

class _AppearancePreview extends StatelessWidget {
  const _AppearancePreview({required this.appearance});

  final ChatAppearance appearance;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: appearance.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: appearance.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: _PreviewBubble(
              text: context.strings.t(
                'Em hợp ngành nào?',
                'Which major fits me?',
              ),
              color: appearance.accent,
              textColor: Colors.white,
              appearance: appearance,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: _PreviewBubble(
              text: context.strings.t(
                'Mình sẽ hỏi vài điều nhé.',
                'I will ask a few questions.',
              ),
              color: appearance.botBubble,
              textColor: appearance.botText,
              appearance: appearance,
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewBubble extends StatelessWidget {
  const _PreviewBubble({
    required this.text,
    required this.color,
    required this.textColor,
    required this.appearance,
  });

  final String text;
  final Color color;
  final Color textColor;
  final ChatAppearance appearance;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Text(
      text,
      style: TextStyle(color: textColor, fontSize: appearance.messageFontSize),
    ),
  );
}

class _AiAvatarBadge extends StatelessWidget {
  const _AiAvatarBadge({required this.avatar, required this.radius});

  final AiAvatarId avatar;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final style = aiAvatarStyle(avatar);
    return CircleAvatar(
      radius: radius,
      backgroundColor: style.backgroundColor,
      child: Icon(style.icon, color: style.foregroundColor, size: radius),
    );
  }
}

class _AiAvatarChoice extends StatelessWidget {
  const _AiAvatarChoice({
    required this.avatar,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final AiAvatarId avatar;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = aiAvatarStyle(avatar);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: 112,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? style.foregroundColor : const Color(0xFFE2E8F0),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _AiAvatarBadge(avatar: avatar, radius: 24),
            const SizedBox(height: 8),
            Text(label, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _ProfileItem extends StatelessWidget {
  const _ProfileItem({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: CareerGuidanceApp.primaryBlue),
        title: Text(title),
        subtitle: Text(value),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: const Color(0xFF94A3B8)),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }
}

class CareerMessage {
  const CareerMessage({
    required this.text,
    required this.isUser,
    this.isError = false,
    this.includeInAiHistory = true,
  });

  final String text;
  final bool isUser;
  final bool isError;
  final bool includeInAiHistory;
}

class _Feature {
  const _Feature(
    this.title,
    this.icon,
    this.color,
    this.prompt,
    this.description,
    this.steps,
  );

  final String title;
  final IconData icon;
  final Color color;
  final String prompt;
  final String description;
  final List<String> steps;

  String titleFor(AppStrings strings) {
    if (!strings.isEnglish) return title;
    return switch (title) {
      'Tư vấn ngành học' => 'Major guidance',
      'Tìm trường phù hợp' => 'Find suitable schools',
      'So sánh trường' => 'Compare schools',
      'Thông tin tuyển sinh' => 'Admissions information',
      'Khám phá nghề nghiệp' => 'Explore careers',
      _ => 'Career discovery test',
    };
  }

  String promptFor(AppStrings strings) {
    if (!strings.isEnglish) return prompt;
    return switch (title) {
      'Tư vấn ngành học' =>
        'I am not sure which major fits me. Ask about my interests, strengths, and personality.',
      'Tìm trường phù hợp' =>
        'Help me choose a suitable university or college.',
      'So sánh trường' => 'Help me compare suitable schools.',
      'Thông tin tuyển sinh' =>
        'I want admissions information. Ask me for the school, major, and year.',
      'Khám phá nghề nghiệp' => 'Help me explore suitable careers.',
      _ => 'I want a career discovery test. Start with the first question.',
    };
  }

  String descriptionFor(AppStrings strings) {
    if (!strings.isEnglish) return description;
    return switch (title) {
      'Tư vấn ngành học' =>
        'Explore majors that fit your interests, strongest subjects, and personality.',
      'Tìm trường phù hợp' =>
        'Find schools that suit your preferred major, academic level, and circumstances.',
      'So sánh trường' =>
        'Compare schools by curriculum, fees, location, and admissions methods.',
      'Thông tin tuyển sinh' =>
        'Learn about subject combinations, admissions methods, and key dates for a school or major.',
      'Khám phá nghề nghiệp' =>
        'Explore jobs, work environments, and skills needed for career groups.',
      _ =>
        'Answer a few short questions so AI can understand you before suggesting directions.',
    };
  }

  List<String> stepsFor(AppStrings strings) {
    if (!strings.isEnglish) return steps;
    return switch (title) {
      'Tư vấn ngành học' => [
        'Interests and favourite activities',
        'Strongest subjects',
        'Your priorities',
      ],
      'Tìm trường phù hợp' => [
        'Preferred location',
        'Major of interest',
        'Budget and current academic level',
      ],
      'So sánh trường' => [
        'Choose 2–3 schools',
        'Set your key criteria',
        'Review the differences',
      ],
      'Thông tin tuyển sinh' => [
        'School or major',
        'Admission year',
        'Admissions method of interest',
      ],
      'Khám phá nghề nghiệp' => [
        'Work you enjoy',
        'Skills you want to develop',
        'Preferred work environment',
      ],
      _ => ['Interests', 'Strengths', 'Personality'],
    };
  }
}
