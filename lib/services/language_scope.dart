import 'package:flutter/material.dart';

import 'language_service.dart';

class LanguageScope extends InheritedNotifier<LanguageService> {
  const LanguageScope({
    super.key,
    required LanguageService languageService,
    required Widget child,
  }) : super(notifier: languageService, child: child);

  static LanguageService of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<LanguageScope>();

    if (scope == null || scope.notifier == null) {
      throw Exception('LanguageScope not found in widget tree.');
    }

    return scope.notifier!;
  }
}
