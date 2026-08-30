import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'services/language_service.dart';
import 'services/language_scope.dart';
import 'services/app_localizations.dart';
import 'screens/login_screen.dart';
import 'widgets/bottom_nav.dart';
import 'services/supabase_client.dart';

// ============================================================
// SYNC OFFLINE REPORTS
// ============================================================

Future<void> syncOfflineReports() async {
  final box = Hive.box('reports');

  for (var key in box.keys) {
    final report = box.get(key);

    if (report['synced'] == false) {
      try {
        await supabase.from('citizen_reports').insert({
          'category': report['category'],
          'details': report['details'],
          'latitude': report['latitude'],
          'longitude': report['longitude'],
          'reported_for': report['reported_for'],
          'created_by': report['created_by'],
        });

        report['synced'] = true;
        await box.put(key, report);
      } catch (_) {}
    }
  }
}

// ============================================================
// MAIN
// ============================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://cphqdgqtrosaxosdwdrz.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNwaHFkZ3F0cm9zYXhvc2R3ZHJ6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM3MjU4NDQsImV4cCI6MjA3OTMwMTg0NH0.CGhmghdxQaPpD6uxDjaoAmnhZZsOKiiwacNw-ZrpDQc',
  );

  await Hive.initFlutter();

  await Hive.openBox('reports');
  await Hive.openBox('chat');
  await Hive.openBox('profile');

  // ==========================================================
  // AUTO SYNC
  // ==========================================================

  Connectivity().onConnectivityChanged.listen((event) {
    if (!event.contains(ConnectivityResult.none)) {
      syncOfflineReports();
    }
  });

  runApp(const AapdaApp());
}

// ============================================================
// APP
// ============================================================

class AapdaApp extends StatefulWidget {
  const AapdaApp({super.key});

  @override
  State<AapdaApp> createState() => _AapdaAppState();
}

class _AapdaAppState extends State<AapdaApp> {
  final LanguageService _languageService = LanguageService();

  @override
  void initState() {
    super.initState();

    _languageService.addListener(_onLanguageChanged);

    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    await _languageService.loadLanguage();

    if (mounted) {
      setState(() {});
    }
  }

  void _onLanguageChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _languageService.removeListener(_onLanguageChanged);
    _languageService.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

    return MaterialApp(
      debugShowCheckedModeBanner: false,

      // ========================================================
      // CURRENT LANGUAGE
      // ========================================================
      locale: _languageService.locale,

      // ========================================================
      // SUPPORTED LANGUAGES
      // ========================================================
      supportedLocales: const [Locale('en'), Locale('hi')],

      // ========================================================
      // LOCALIZATION
      // ========================================================
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      // ========================================================
      // IMPORTANT:
      // LanguageScope is placed INSIDE MaterialApp.
      // Therefore all screens/routes can access it.
      // ========================================================
      builder: (context, child) {
        return LanguageScope(
          languageService: _languageService,
          child: child ?? const SizedBox.shrink(),
        );
      },

      // ========================================================
      // HOME
      // ========================================================
      home: user != null ? const MainNavigation() : const LoginScreen(),
    );
  }
}
