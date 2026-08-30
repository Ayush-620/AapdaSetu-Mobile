import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageService extends ChangeNotifier {
  static const String _languageKey = 'app_language';

  Locale _locale = const Locale('en');

  Locale get locale => _locale;

  /// Load the previously selected language.
  Future<void> loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();

    final languageCode = prefs.getString(_languageKey) ?? 'en';

    _locale = Locale(languageCode);

    notifyListeners();
  }

  /// Change and save the application language.
  Future<void> changeLanguage(String languageCode) async {
    if (languageCode != 'en' && languageCode != 'hi') {
      return;
    }

    _locale = Locale(languageCode);

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_languageKey, languageCode);

    notifyListeners();
  }
}
