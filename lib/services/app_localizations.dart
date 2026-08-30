import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations(const Locale('en'));
  }

  // ============================================================
  // ENGLISH
  // ============================================================

  static const Map<String, String> _english = {
    // Profile
    'profile': 'Profile',
    'editProfile': 'Edit Profile',
    'name': 'Name',
    'age': 'Age',
    'phoneNumber': 'Phone Number',
    'cancel': 'Cancel',
    'save': 'Save',
    'profileUpdated': 'Profile updated',

    // Language
    'language': 'Language',
    'selectLanguage': 'Select Language',
    'english': 'English',
    'hindi': 'Hindi',

    // Middleman
    'middleman': 'Middleman',
    'enterEmail': 'Enter email',
    'sendRequest': 'Send Request',
    'requestSent': 'Request sent',
    'viewRequests': 'View Requests',
    'yourMiddlemen': 'Your Middlemen:',
    'peopleYouHelp': 'People You Help:',

    // Reports
    'myReports': 'My Reports',
    'reportsSubmitted': 'reports submitted',
    'viewAll': 'View All',
    'reportIncident': 'Report Incident',
    'describeIncident': 'Describe incident',
    'myself': 'Myself',
    'selected': 'Selected',
    'photo': 'Photo',
    'stop': 'Stop',
    'record': 'Record',
    'recording': 'Recording',
    'seconds': 'sec',
    'playAudio': 'Play Audio',
    'submit': 'Submit',
    'medical': 'Medical',
    'fire': 'Fire',
    'flood': 'Flood',
    'others': 'Others',

    // Login
    'email': 'Email',
    'password': 'Password',
    'login': 'LOGIN',
    'createNewAccount': 'Create new account',

    // Signup
    'createAccount': 'Create Account',
    'fullName': 'Full Name',
    'signUp': 'SIGN UP',
    'alreadyHaveAccount': 'Already have an account? Login',
    'signupSuccessful': 'Signup successful! Check your email to verify.',
    'invalidPhoneNumber': 'Phone number must be exactly 10 digits',

    // Reports Screen
    'reports': 'Reports',
    'noReportsYet': 'No reports yet',
    'forLabel': 'For:',
    'unknown': 'Unknown',
    'pauseAudio': 'Pause Audio',
    'status': 'Status',
    'audioError': 'Audio error',

    // Requests
    'requests': 'Requests',
    'noRequests': 'No requests',
    'wantsYouAsMiddleman': 'Wants you as middleman',

    // Common
    'loading': 'Loading...',
    'logout': 'Logout',
    'noName': 'No Name',

    // Chatbot
    'aiDisasterAssistant': 'AI Disaster Assistant',
    'askSafetyAlerts': 'Ask me about safety & alerts',
    'askSomething': 'Ask something...',
  };

  // ============================================================
  // HINDI
  // ============================================================

  static const Map<String, String> _hindi = {
    // Profile
    'profile': 'प्रोफ़ाइल',
    'editProfile': 'प्रोफ़ाइल संपादित करें',
    'name': 'नाम',
    'age': 'उम्र',
    'phoneNumber': 'फ़ोन नंबर',
    'cancel': 'रद्द करें',
    'save': 'सहेजें',
    'profileUpdated': 'प्रोफ़ाइल अपडेट हो गई',

    // Language
    'language': 'भाषा',
    'selectLanguage': 'भाषा चुनें',
    'english': 'अंग्रेज़ी',
    'hindi': 'हिन्दी',

    // Middleman
    'middleman': 'मिडिलमैन',
    'enterEmail': 'ईमेल दर्ज करें',
    'sendRequest': 'अनुरोध भेजें',
    'requestSent': 'अनुरोध भेज दिया गया',
    'viewRequests': 'अनुरोध देखें',
    'yourMiddlemen': 'आपके मिडिलमैन:',
    'peopleYouHelp': 'जिन लोगों की आप मदद करते हैं:',

    // Reports
    'myReports': 'मेरी रिपोर्ट',
    'reportsSubmitted': 'रिपोर्ट जमा की गईं',
    'viewAll': 'सभी देखें',
    'reportIncident': 'घटना की रिपोर्ट करें',
    'describeIncident': 'घटना का विवरण दें',
    'myself': 'स्वयं',
    'selected': 'चयनित',
    'photo': 'फोटो',
    'stop': 'रोकें',
    'record': 'रिकॉर्ड करें',
    'recording': 'रिकॉर्डिंग',
    'seconds': 'सेकंड',
    'playAudio': 'ऑडियो चलाएँ',
    'submit': 'जमा करें',
    'medical': 'चिकित्सा',
    'fire': 'आग',
    'flood': 'बाढ़',
    'others': 'अन्य',

    // Login
    'email': 'ईमेल',
    'password': 'पासवर्ड',
    'login': 'लॉगिन',
    'createNewAccount': 'नया खाता बनाएं',

    // Signup
    'createAccount': 'खाता बनाएं',
    'fullName': 'पूरा नाम',
    'signUp': 'साइन अप',
    'alreadyHaveAccount': 'पहले से खाता है? लॉगिन करें',
    'signupSuccessful': 'साइन अप सफल रहा! सत्यापन के लिए अपना ईमेल जांचें।',
    'invalidPhoneNumber': 'फ़ोन नंबर ठीक 10 अंकों का होना चाहिए',

    // Reports Screen
    'reports': 'रिपोर्ट',
    'noReportsYet': 'अभी तक कोई रिपोर्ट नहीं',
    'forLabel': 'के लिए:',
    'unknown': 'अज्ञात',
    'pauseAudio': 'ऑडियो रोकें',
    'status': 'स्थिति',
    'audioError': 'ऑडियो त्रुटि',

    // Requests
    'requests': 'अनुरोध',
    'noRequests': 'कोई अनुरोध नहीं',
    'wantsYouAsMiddleman': 'आपको मिडिलमैन बनाना चाहते हैं',

    // Common
    'loading': 'लोड हो रहा है...',
    'logout': 'लॉगआउट',
    'noName': 'नाम उपलब्ध नहीं',

    // Chatbot
    'aiDisasterAssistant': 'AI आपदा सहायक',
    'askSafetyAlerts': 'सुरक्षा और अलर्ट के बारे में पूछें',
    'askSomething': 'कुछ पूछें...',
  };

  // ============================================================
  // TRANSLATION
  // ============================================================

  String get(String key) {
    final translations = locale.languageCode == 'hi' ? _hindi : _english;

    return translations[key] ?? key;
  }

  // Profile
  String get profile => get('profile');
  String get editProfile => get('editProfile');
  String get name => get('name');
  String get age => get('age');
  String get phoneNumber => get('phoneNumber');
  String get cancel => get('cancel');
  String get save => get('save');
  String get profileUpdated => get('profileUpdated');

  // Language
  String get language => get('language');
  String get selectLanguage => get('selectLanguage');
  String get english => get('english');
  String get hindi => get('hindi');

  // Middleman
  String get middleman => get('middleman');
  String get enterEmail => get('enterEmail');
  String get sendRequest => get('sendRequest');
  String get requestSent => get('requestSent');
  String get viewRequests => get('viewRequests');
  String get yourMiddlemen => get('yourMiddlemen');
  String get peopleYouHelp => get('peopleYouHelp');

  // Reports
  String get myReports => get('myReports');
  String get reportsSubmitted => get('reportsSubmitted');
  String get viewAll => get('viewAll');
  String get reportIncident => get('reportIncident');
  String get describeIncident => get('describeIncident');
  String get myself => get('myself');
  String get selected => get('selected');
  String get photo => get('photo');
  String get stop => get('stop');
  String get record => get('record');
  String get recording => get('recording');
  String get seconds => get('seconds');
  String get playAudio => get('playAudio');
  String get submit => get('submit');
  String get medical => get('medical');
  String get fire => get('fire');
  String get flood => get('flood');
  String get others => get('others');

  // Login
  String get email => get('email');
  String get password => get('password');
  String get login => get('login');
  String get createNewAccount => get('createNewAccount');

  // Signup
  String get createAccount => get('createAccount');
  String get fullName => get('fullName');
  String get signUp => get('signUp');
  String get alreadyHaveAccount => get('alreadyHaveAccount');
  String get signupSuccessful => get('signupSuccessful');
  String get invalidPhoneNumber => get('invalidPhoneNumber');

  // Reports Screen
  String get reports => get('reports');
  String get noReportsYet => get('noReportsYet');
  String get forLabel => get('forLabel');
  String get unknown => get('unknown');
  String get pauseAudio => get('pauseAudio');
  String get status => get('status');
  String get audioError => get('audioError');

  // Requests
  String get requests => get('requests');
  String get noRequests => get('noRequests');
  String get wantsYouAsMiddleman => get('wantsYouAsMiddleman');

  // Common
  String get loading => get('loading');
  String get logout => get('logout');
  String get noName => get('noName');

  // Chatbot
  String get aiDisasterAssistant => get('aiDisasterAssistant');
  String get askSafetyAlerts => get('askSafetyAlerts');
  String get askSomething => get('askSomething');
}

// ============================================================
// LOCALIZATION DELEGATE
// ============================================================

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'hi'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) {
    return false;
  }
}