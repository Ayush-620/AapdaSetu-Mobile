import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/supabase_client.dart';
import '../widgets/report_button.dart';
import '../services/location_service.dart';
import '../services/weather_service.dart';
import '../services/auth_service.dart';
import '../services/language_scope.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  bool get _isHindi => LanguageScope.of(context).locale.languageCode == 'hi';

  String _weatherCondition(String condition) {
    if (!_isHindi) return condition;

    switch (condition) {
      case 'Clear':
        return 'साफ़';
      case 'Cloudy':
        return 'बादल';
      case 'Fog':
        return 'कोहरा';
      case 'Rain':
        return 'बारिश';
      case 'Snow':
        return 'बर्फ़';
      case 'Thunderstorm':
        return 'गरज के साथ बारिश';
      default:
        return condition;
    }
  }

  // ============================================================
  // DATA FUTURES
  // ============================================================

  late Future<List<dynamic>> _alertsFuture;
  Future<List<dynamic>>? _weatherFuture;
  late Future<Map<String, dynamic>> _linkedUsersFuture;

  bool _loadingLocation = true;

  // Used only to rebuild the alerts FutureBuilder when manually refreshed.
  int _refreshKey = 0;

  // ============================================================
  // SOS
  // ============================================================

  Timer? _sosTimer;

  int _sosCountdown = 10;

  bool _sosDialogOpen = false;

  final ValueNotifier<int> _sosCountdownNotifier = ValueNotifier<int>(10);

  // ============================================================
  // SOS COOLDOWN
  // ============================================================

  static const String _sosCooldownKey = 'last_sos_time';

  DateTime? _lastSosTime;
  Duration _sosRemaining = Duration.zero;
  Timer? _sosCooldownTimer;
  bool _sosOnCooldown = false;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _loadSOSCooldown();

    // These futures are created ONCE.
    _alertsFuture = getAlerts();
    _linkedUsersFuture = getLinkedUsers();

    _initLocation();
  }

  @override
  void dispose() {
    _sosTimer?.cancel();
    _sosCooldownTimer?.cancel();

    _sosCountdownNotifier.dispose();

    WidgetsBinding.instance.removeObserver(this);

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _handleLocationOnResume();
    }
  }

  // ============================================================
  // SOS COOLDOWN
  // ============================================================

  Future<void> _loadSOSCooldown() async {
    final prefs = await SharedPreferences.getInstance();

    final timestamp = prefs.getInt(_sosCooldownKey);

    if (timestamp == null) {
      if (mounted) {
        setState(() {
          _sosOnCooldown = false;
          _sosRemaining = Duration.zero;
        });
      }

      return;
    }

    final lastSOS = DateTime.fromMillisecondsSinceEpoch(timestamp);

    const cooldown = Duration(hours: 1);

    final elapsed = DateTime.now().difference(lastSOS);

    if (elapsed >= cooldown) {
      await prefs.remove(_sosCooldownKey);

      if (mounted) {
        setState(() {
          _lastSosTime = null;
          _sosRemaining = Duration.zero;
          _sosOnCooldown = false;
        });
      }

      return;
    }

    final remaining = cooldown - elapsed;

    if (mounted) {
      setState(() {
        _lastSosTime = lastSOS;
        _sosRemaining = remaining;
        _sosOnCooldown = true;
      });
    }

    _startSOSCooldownTimer();
  }

  void _startSOSCooldownTimer() {
    _sosCooldownTimer?.cancel();

    _sosCooldownTimer = Timer.periodic(const Duration(seconds: 1), (
      timer,
    ) async {
      if (_lastSosTime == null) {
        timer.cancel();
        return;
      }

      const cooldown = Duration(hours: 1);

      final elapsed = DateTime.now().difference(_lastSosTime!);

      final remaining = cooldown - elapsed;

      if (remaining <= Duration.zero) {
        timer.cancel();

        final prefs = await SharedPreferences.getInstance();

        await prefs.remove(_sosCooldownKey);

        if (!mounted) return;

        setState(() {
          _lastSosTime = null;
          _sosRemaining = Duration.zero;
          _sosOnCooldown = false;
        });

        return;
      }

      if (mounted) {
        setState(() {
          _sosRemaining = remaining;
          _sosOnCooldown = true;
        });
      }
    });
  }

  String _formatSOSRemaining() {
    final totalSeconds = _sosRemaining.inSeconds;

    final hours = totalSeconds ~/ 3600;

    final minutes = (totalSeconds % 3600) ~/ 60;

    final seconds = totalSeconds % 60;

    if (hours > 0) {
      return '${hours}h '
          '${minutes.toString().padLeft(2, '0')}m';
    }

    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  // ============================================================
  // LOCATION
  // ============================================================

  Future<void> _handleLocationOnResume() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) return;

    final position = await LocationService.getCurrentLocation();

    if (position == null || !mounted) return;

    LocationService.latitude = position.latitude;
    LocationService.longitude = position.longitude;

    // Refresh weather because location may have changed.
    _loadWeather();

    await AuthService.updateUserLocation(
      lat: position.latitude,
      lng: position.longitude,
    );

    if (!mounted) return;

    setState(() {
      _loadingLocation = false;

      _refreshKey++;

      // Explicitly refresh data.
      _alertsFuture = getAlerts();
      _linkedUsersFuture = getLinkedUsers();
    });
  }

  // ============================================================
  // WEATHER
  // ============================================================

  void _loadWeather() {
    final lat = LocationService.latitude;
    final lng = LocationService.longitude;

    if (lat == null || lng == null) {
      _weatherFuture = null;
      return;
    }

    _weatherFuture = Future.wait([
      WeatherService.getWeather(lat, lng),
      WeatherService.getAQI(lat, lng),
    ]);
  }

  // ============================================================
  // LOCATION INITIALIZATION
  // ============================================================

  Future<void> _initLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      _showLocationDialog();

      if (mounted) {
        setState(() {
          _loadingLocation = false;
        });
      }

      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (mounted) {
        setState(() {
          _loadingLocation = false;
        });
      }

      return;
    }

    final pos = await LocationService.getCurrentLocation();

    if (pos != null) {
      LocationService.latitude = pos.latitude;
      LocationService.longitude = pos.longitude;

      // Load weather ONCE after location is available.
      _loadWeather();

      if (mounted) {
        setState(() {
          _loadingLocation = false;
        });
      }

      await AuthService.updateUserLocation(
        lat: pos.latitude,
        lng: pos.longitude,
      );
    } else {
      if (mounted) {
        setState(() {
          _loadingLocation = false;
        });
      }
    }
  }

  // ============================================================
  // LOCATION DIALOG
  // ============================================================

  void _showLocationDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(_isHindi ? "स्थान आवश्यक है" : "Location Required"),
        content: Text(
          _isHindi
              ? "मौसम और अलर्ट देखने के लिए कृपया स्थान सेवा चालू करें।"
              : "Please turn on location services to see weather and alerts.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_isHindi ? "रद्द करें" : "Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              await Geolocator.openLocationSettings();
            },
            child: Text(_isHindi ? "सेटिंग्स खोलें" : "Open Settings"),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SOS - CREATE REPORT
  // ============================================================

  Future<void> _triggerSOS() async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isHindi ? 'कृपया पहले लॉगिन करें।' : 'Please login first.',
          ),
        ),
      );

      return;
    }

    double? lat = LocationService.latitude;
    double? lng = LocationService.longitude;

    // Get latest location before creating SOS report.
    final position = await LocationService.getCurrentLocation();

    if (position != null) {
      lat = position.latitude;
      lng = position.longitude;

      LocationService.latitude = lat;
      LocationService.longitude = lng;
    }

    try {
      // Get citizen_id of current user.
      final profile = await supabase
          .from('profiles')
          .select('citizen_id')
          .eq('id', user.id)
          .maybeSingle();

      final citizenId = profile?['citizen_id'];

      // CREATE SOS REPORT
      await supabase.from('citizen_reports').insert({
        'category': 'SOS',
        'details': 'SOS: I need immediate assistance.',
        'status': 'Open',
        'image_url': null,
        'audio_url': null,
        'reported_for': citizenId,
        'created_by': user.id,
        'latitude': lat,
        'longitude': lng,

        // Web/admin side will handle state.
        'state': null,
      });

      // ========================================================
      // SUCCESS → START 1 HOUR COOLDOWN
      // ========================================================

      final prefs = await SharedPreferences.getInstance();

      final now = DateTime.now();

      await prefs.setInt(_sosCooldownKey, now.millisecondsSinceEpoch);

      if (!mounted) return;

      setState(() {
        _lastSosTime = now;
        _sosRemaining = const Duration(hours: 1);
        _sosOnCooldown = true;
      });

      _startSOSCooldownTimer();

      // SUCCESS MESSAGE
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isHindi
                ? 'SOS भेज दिया गया। आपातकालीन सहायता का अनुरोध भेजा गया है।'
                : 'SOS sent. Emergency assistance has been requested.',
          ),
        ),
      );
    } catch (e) {
      debugPrint('SOS ERROR: $e');

      // IMPORTANT:
      // Do NOT start cooldown if submission failed.

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isHindi
                ? 'SOS भेजने में समस्या हुई। कृपया दोबारा प्रयास करें।'
                : 'Unable to send SOS. Please try again.',
          ),
        ),
      );
    }
  }

  // ============================================================
  // SOS - CANCEL
  // ============================================================

  void _cancelSOS() {
    _sosTimer?.cancel();
    _sosTimer = null;

    _sosDialogOpen = false;

    _sosCountdown = 10;
    _sosCountdownNotifier.value = 10;

    if (!mounted) return;

    Navigator.of(context, rootNavigator: true).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isHindi ? 'SOS रद्द कर दिया गया।' : 'SOS cancelled.'),
      ),
    );
  }

  // ============================================================
  // SOS - START COUNTDOWN
  // ============================================================

  void _startSOSCountdown() {
    if (_sosDialogOpen || _sosOnCooldown) {
      return;
    }

    if (_sosRemaining > Duration.zero) {
      return;
    }

    _sosCountdown = 10;
    _sosCountdownNotifier.value = 10;
    _sosDialogOpen = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            _isHindi ? 'SOS सक्रिय' : 'SOS Activated',
            style: const TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_rounded, color: Colors.red, size: 60),

              const SizedBox(height: 16),

              ValueListenableBuilder<int>(
                valueListenable: _sosCountdownNotifier,
                builder: (context, countdown, child) {
                  return Text(
                    _isHindi
                        ? 'आपातकालीन SOS $countdown सेकंड में भेजा जाएगा।'
                        : 'Emergency SOS will be sent in $countdown seconds.',
                    textAlign: TextAlign.center,
                  );
                },
              ),

              const SizedBox(height: 20),

              ValueListenableBuilder<int>(
                valueListenable: _sosCountdownNotifier,
                builder: (context, countdown, child) {
                  return Text(
                    '$countdown',
                    style: const TextStyle(
                      fontSize: 52,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  );
                },
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _cancelSOS,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(_isHindi ? 'SOS रद्द करें' : 'CANCEL SOS'),
              ),
            ),
          ],
        );
      },
    ).then((_) {
      _sosTimer?.cancel();
      _sosTimer = null;
      _sosDialogOpen = false;
    });

    _sosTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_sosCountdown > 1) {
        _sosCountdown--;

        _sosCountdownNotifier.value = _sosCountdown;
      } else {
        timer.cancel();
        _sosTimer = null;

        _sosCountdown = 0;
        _sosCountdownNotifier.value = 0;

        _sosDialogOpen = false;

        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop();
        }

        await _triggerSOS();
      }
    });
  }

  // ============================================================
  // ALERTS
  // ============================================================

  Future<List<dynamic>> getAlerts() async {
    // Ensure location exists.
    if (LocationService.latitude == null || LocationService.longitude == null) {
      final position = await LocationService.getCurrentLocation();

      if (position != null) {
        LocationService.latitude = position.latitude;
        LocationService.longitude = position.longitude;
      }
    }

    final userLat = LocationService.latitude;
    final userLng = LocationService.longitude;

    if (userLat == null || userLng == null) {
      return [];
    }

    final alerts = await supabase
        .from('alerts')
        .select()
        .eq('status', 'Active');

    final nearbyAlerts = alerts.where((alert) {
      final alertLat = alert['latitude'];
      final alertLng = alert['longitude'];

      if (alertLat == null || alertLng == null) {
        return false;
      }

      final radius = (alert['radius_km'] ?? 50).toDouble();

      final distance =
          Geolocator.distanceBetween(userLat, userLng, alertLat, alertLng) /
          1000;

      return distance <= radius;
    }).toList();

    nearbyAlerts.sort((a, b) {
      return DateTime.parse(
        b['created_at'],
      ).compareTo(DateTime.parse(a['created_at']));
    });

    return nearbyAlerts;
  }

  // ============================================================
  // LINKED USERS
  // ============================================================

  Future<Map<String, dynamic>> getLinkedUsers() async {
    final user = supabase.auth.currentUser;

    if (user == null) {
      return {'middlemen': [], 'citizens': []};
    }

    final myProfile = await supabase
        .from('profiles')
        .select('citizen_id')
        .eq('id', user.id)
        .maybeSingle();

    if (myProfile == null) {
      return {'middlemen': [], 'citizens': []};
    }

    final myId = myProfile['citizen_id'];

    final myMiddlemenLinks = await supabase
        .from('middleman_links')
        .select('middleman_id')
        .eq('citizen_id', myId)
        .eq('status', 'Accepted');

    final middlemanIds = myMiddlemenLinks
        .map((e) => e['middleman_id'])
        .toList();

    final middlemen = middlemanIds.isEmpty
        ? []
        : await supabase
              .from('profiles')
              .select('name')
              .inFilter('id', middlemanIds);

    final helpingLinks = await supabase
        .from('middleman_links')
        .select('citizen_id')
        .eq('middleman_id', user.id)
        .eq('status', 'Accepted');

    final citizenIds = helpingLinks.map((e) => e['citizen_id']).toList();

    final citizens = citizenIds.isEmpty
        ? []
        : await supabase
              .from('profiles')
              .select('name')
              .inFilter('citizen_id', citizenIds);

    return {'middlemen': middlemen, 'citizens': citizens};
  }

  // ============================================================
  // ALERT SEVERITY
  // ============================================================

  int severityWeight(String? s) {
    if (s == null) return 0;

    s = s.toLowerCase();

    if (s.contains("critical") || s.contains("high")) {
      return 3;
    }

    if (s.contains("medium")) {
      return 2;
    }

    return 1;
  }

  Color getColor(String? severity) {
    if (severity == null) {
      return Colors.grey.shade200;
    }

    severity = severity.toLowerCase();

    if (severity.contains("critical")) {
      return const Color(0xFFD32F2F);
    }

    if (severity.contains("major")) {
      return const Color(0xFFFFE082);
    }

    if (severity.contains("minor")) {
      return const Color(0xFFC8E6C9);
    }

    return Colors.grey.shade200;
  }

  Color getSeverityBadgeColor(String? severity) {
    if (severity == null) return Colors.grey;

    severity = severity.toLowerCase();

    if (severity.contains("critical")) {
      return Colors.red;
    }

    if (severity.contains("major")) {
      return Colors.orange;
    }

    if (severity.contains("minor")) {
      return Colors.green;
    }

    return Colors.grey;
  }

  // ============================================================
  // REFRESH
  // ============================================================

  Future<void> _refreshHome() async {
    final position = await LocationService.getCurrentLocation();

    if (position != null) {
      LocationService.latitude = position.latitude;
      LocationService.longitude = position.longitude;

      await AuthService.updateUserLocation(
        lat: position.latitude,
        lng: position.longitude,
      );
    }

    // Reload weather using latest location.
    _loadWeather();

    if (!mounted) return;

    setState(() {
      _refreshKey++;

      // Explicitly create NEW futures.
      _alertsFuture = getAlerts();
      _linkedUsersFuture = getLinkedUsers();
    });

    try {
      await _alertsFuture;

      if (_weatherFuture != null) {
        await _weatherFuture!;
      }

      await _linkedUsersFuture;
    } catch (e) {
      debugPrint('Home refresh error: $e');
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    if (_loadingLocation) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshHome,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              children: [
                const SizedBox(height: 16),

                // ============================================================
                // ALERTS
                // ============================================================
                FutureBuilder(
                  key: ValueKey(_refreshKey),
                  future: _alertsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return const Center(child: Text("Unable to load alerts"));
                    }

                    if (!snapshot.hasData) {
                      return const Center(child: Text("No data"));
                    }

                    final alerts = snapshot.data as List;

                    alerts.sort((a, b) {
                      return severityWeight(
                        b['severity'],
                      ).compareTo(severityWeight(a['severity']));
                    });

                    if (alerts.isEmpty) {
                      return Container(
                        width: double.infinity,
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: const Text(
                          "No active alerts in your location right now.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                      );
                    }

                    return Column(
                      children: [
                        ...alerts.map((data) {
                          final isCritical =
                              (data['severity'] ?? "")
                                  .toString()
                                  .toLowerCase() ==
                              "critical";

                          final bgColor = getColor(data['severity']);

                          return GestureDetector(
                            onTap: () {
                              final steps = data['safety_steps'] ?? [];

                              showDialog(
                                context: context,
                                builder: (_) => AlertDialog(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  title: Text(
                                    data['title'] ?? "",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        data['summary'] ?? "",
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                      const SizedBox(height: 12),
                                      const Text(
                                        "Safety Precautions:",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      ...List.generate(steps.length, (i) {
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 4,
                                          ),
                                          child: Text("• ${steps[i]}"),
                                        );
                                      }),
                                    ],
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: bgColor,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    data['title'] ?? "Alert",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                      color: isCritical
                                          ? Colors.white
                                          : Colors.grey.shade900,
                                      height: 1.3,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    data['summary'] ?? "",
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isCritical
                                          ? Colors.white70
                                          : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: getSeverityBadgeColor(
                                          data['severity'],
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        data['severity'] ?? "Low",
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    );
                  },
                ),

                // ============================================================
                // SOS BUTTON
                // ============================================================
                const SizedBox(height: 20),

                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: ElevatedButton(
                    onPressed: _sosOnCooldown ? null : _startSOSCountdown,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey,
                      disabledForegroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 4,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'SOS',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_sosOnCooldown) ...[
                          const SizedBox(height: 4),
                          Text(
                            _isHindi
                                ? 'फिर से उपलब्ध: ${_formatSOSRemaining()}'
                                : 'Available again in ${_formatSOSRemaining()}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // ============================================================
                // REPORT BUTTON
                // ============================================================
                const SizedBox(height: 12),

                const ReportButton(),

                // ============================================================
                // SAFETY NETWORK
                // ============================================================
                const SizedBox(height: 20),

                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isHindi ? "सुरक्षा नेटवर्क" : "Safety Network",
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),

                      const SizedBox(height: 8),

                      FutureBuilder(
                        future: _linkedUsersFuture,
                        builder: (context, snap) {
                          if (snap.connectionState == ConnectionState.waiting) {
                            return Text(
                              _isHindi ? "लोड हो रहा है..." : "Loading...",
                            );
                          }

                          if (snap.hasError || !snap.hasData) {
                            return Text(
                              _isHindi
                                  ? "डेटा लोड नहीं हो सका"
                                  : "Unable to load data",
                            );
                          }

                          final data = snap.data!;

                          final middlemen = data['middlemen'] as List;

                          final citizens = data['citizens'] as List;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (middlemen.isNotEmpty) ...[
                                Text(
                                  _isHindi
                                      ? "आपके मध्यस्थ:"
                                      : "Your Middlemen:",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                ...middlemen.map((m) => Text("• ${m['name']}")),
                              ],

                              if (citizens.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Text(
                                  _isHindi
                                      ? "जिन लोगों की आप मदद करते हैं:"
                                      : "People You Help:",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                ...citizens.map((c) => Text("• ${c['name']}")),
                              ],

                              if (middlemen.isEmpty && citizens.isEmpty)
                                Text(
                                  _isHindi
                                      ? "अभी कोई कनेक्शन नहीं है"
                                      : "No connections yet",
                                ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // ============================================================
                // WEATHER + AQI
                // ============================================================
                const SizedBox(height: 20),

                if (_weatherFuture != null)
                  FutureBuilder(
                    future: _weatherFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return const Center(
                          child: Text("Unable to load weather"),
                        );
                      }

                      if (!snapshot.hasData) {
                        return const Center(child: Text("No data"));
                      }

                      final weather =
                          snapshot.data![0] as Map<String, dynamic>?;

                      final aqi = snapshot.data![1] as int? ?? 0;

                      final temp = weather?['temperature'] ?? 0;

                      final code = weather?['weathercode'] ?? 0;

                      String condition = "Clear";

                      String emoji = "☀️";

                      // DYNAMIC WEATHER
                      if (code == 0) {
                        condition = "Clear";
                        emoji = "☀️";
                      } else if (code >= 1 && code <= 3) {
                        condition = "Cloudy";
                        emoji = "☁️";
                      } else if (code >= 45 && code <= 48) {
                        condition = "Fog";
                        emoji = "🌫️";
                      } else if (code >= 51 && code <= 67) {
                        condition = "Rain";
                        emoji = "🌧️";
                      } else if (code >= 71 && code <= 77) {
                        condition = "Snow";
                        emoji = "❄️";
                      } else if (code >= 95) {
                        condition = "Thunderstorm";
                        emoji = "⛈️";
                      }

                      // AQI COLOR
                      Color aqiColor = Colors.green;

                      if (aqi > 150) {
                        aqiColor = Colors.red;
                      } else if (aqi > 100) {
                        aqiColor = Colors.orange;
                      } else if (aqi > 50) {
                        aqiColor = Colors.yellow.shade700;
                      }

                      return Container(
                        width: double.infinity,
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF42A5F5), Color(0xFF90CAF9)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // CONDITION
                            Row(
                              children: [
                                Text(
                                  emoji,
                                  style: const TextStyle(fontSize: 22),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _weatherCondition(condition),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),

                            // TEMP
                            Text(
                              "$temp°C",
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),

                            // AQI
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: aqiColor,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                "AQI $aqi",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
