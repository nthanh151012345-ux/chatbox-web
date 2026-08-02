import 'package:flutter/material.dart';

enum AppLanguage { vietnamese, english }

class AppLanguageController extends ChangeNotifier {
  AppLanguage _language = AppLanguage.vietnamese;

  AppLanguage get language => _language;

  void changeTo(AppLanguage language) {
    if (_language == language) return;
    _language = language;
    notifyListeners();
  }
}

class AppLanguageScope extends InheritedNotifier<AppLanguageController> {
  const AppLanguageScope({
    super.key,
    required AppLanguageController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppLanguageController controllerOf(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<AppLanguageScope>();
    assert(scope != null, 'AppLanguageScope is required above this widget.');
    return scope!.notifier!;
  }

  static AppStrings stringsOf(BuildContext context) {
    return AppStrings(controllerOf(context).language);
  }
}

extension AppTranslations on BuildContext {
  AppStrings get strings => AppLanguageScope.stringsOf(this);
}

class AppStrings {
  const AppStrings(this.language);

  final AppLanguage language;

  bool get isEnglish => language == AppLanguage.english;
  String get languageCode => isEnglish ? 'en' : 'vi';
  String get languageName => isEnglish ? 'English' : 'Tiếng Việt';

  String t(String vietnamese, String english) =>
      isEnglish ? english : vietnamese;
}
