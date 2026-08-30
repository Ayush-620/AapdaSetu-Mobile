import 'package:flutter/material.dart';

import '../services/language_service.dart';
import '../services/language_scope.dart';
import '../services/app_localizations.dart';
import '../services/auth_service.dart';
import '../services/supabase_client.dart';

import 'login_screen.dart';
import 'requests_screen.dart';
import 'reports_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _middlemanEmailController =
      TextEditingController();

  // ============================================================
  // FETCH USER FROM SUPABASE
  // ============================================================

  Future<Map<String, dynamic>?> getUser() async {
    final user = AuthService.currentUser;

    if (user == null) return null;

    try {
      final res = await supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (res == null) {
        print("⚠️ No profile found for user");
        return null;
      }

      return res;
    } catch (e) {
      print("❌ PROFILE FETCH ERROR: $e");
      return null;
    }
  }

  // ============================================================
  // GET REPORT COUNT
  // ============================================================

  Future<int> getMyReportCount() async {
    final user = supabase.auth.currentUser;

    if (user == null) return 0;

    final res = await supabase
        .from('citizen_reports')
        .select('id')
        .eq('created_by', user.id);

    return res.length;
  }

  // ============================================================
  // LANGUAGE DIALOG
  // ============================================================

  void _showLanguageDialog(
    BuildContext context,
    LanguageService languageService,
    AppLocalizations l10n,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.selectLanguage),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                title: Text(l10n.english),
                value: 'en',
                groupValue: languageService.locale.languageCode,
                onChanged: (value) async {
                  if (value == null) return;

                  await languageService.changeLanguage(value);

                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                },
              ),
              RadioListTile<String>(
                title: Text(l10n.hindi),
                value: 'hi',
                groupValue: languageService.locale.languageCode,
                onChanged: (value) async {
                  if (value == null) return;

                  await languageService.changeLanguage(value);

                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // EDIT PROFILE
  // ============================================================

  void _showEditDialog(Map<String, dynamic> data) {
    final l10n = AppLocalizations.of(context);

    final nameController = TextEditingController(text: data['name']);

    final ageController = TextEditingController(text: data['age']?.toString());

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text(l10n.editProfile),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(labelText: l10n.name),
              ),
              TextField(
                controller: ageController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: l10n.age),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () async {
                await supabase
                    .from('profiles')
                    .update({
                      'name': nameController.text.trim(),
                      'age': int.tryParse(ageController.text.trim()),
                    })
                    .eq('id', AuthService.currentUser!.id);

                if (!mounted) return;

                Navigator.pop(context);

                setState(() {});

                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(l10n.profileUpdated)));
              },
              child: Text(l10n.save),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // SEND MIDDLEMAN REQUEST
  // ============================================================

  Future<void> sendRequest() async {
    final email = _middlemanEmailController.text.trim();

    if (email.isEmpty) return;

    try {
      final user = supabase.auth.currentUser;

      if (user == null) {
        throw "Not logged in";
      }

      // Find target middleman
      final target = await supabase
          .from('profiles')
          .select('id')
          .eq('email', email)
          .maybeSingle();

      if (target == null) {
        throw "User not found";
      }

      // Get my citizen ID
      final myProfile = await supabase
          .from('profiles')
          .select('citizen_id')
          .eq('id', user.id)
          .single();

      await supabase.from('middleman_links').insert({
        'citizen_id': myProfile['citizen_id'],
        'middleman_id': target['id'],
        'status': 'Pending',
      });

      final l10n = AppLocalizations.of(context);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.requestSent)));

      _middlemanEmailController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$e")));
    }
  }

  // ============================================================
  // FETCH LINKED USERS
  // ============================================================

  Future<Map<String, dynamic>> getLinkedUsers() async {
    final user = supabase.auth.currentUser;

    if (user == null) return {};

    final myProfile = await supabase
        .from('profiles')
        .select('citizen_id')
        .eq('id', user.id)
        .single();

    final myId = myProfile['citizen_id'];

    // MY MIDDLEMEN
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

    // PEOPLE I HELP
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

  @override
  void dispose() {
    _middlemanEmailController.dispose();
    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final languageService = LanguageScope.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Colors.grey[100],

      // ========================================================
      // APP BAR
      // ========================================================
      appBar: AppBar(
        title: Text(l10n.profile),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RequestsScreen()),
              );
            },
          ),
        ],
      ),

      // ========================================================
      // BODY
      // ========================================================
      body: SafeArea(
        child: FutureBuilder(
          future: getUser(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return Center(child: Text(l10n.loading));
            }

            final data = snapshot.data!;

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ==================================================
                  // PROFILE CARD
                  // ==================================================
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Text(
                          data["name"] ?? l10n.noName,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 4),

                        Text("${l10n.age}: ${data["age"] ?? "--"}"),

                        const SizedBox(height: 10),

                        ElevatedButton(
                          onPressed: () => _showEditDialog(data),
                          child: Text(l10n.editProfile),
                        ),

                        const SizedBox(height: 8),

                        // LANGUAGE
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.language),
                          title: Text(l10n.language),
                          subtitle: Text(
                            languageService.locale.languageCode == 'hi'
                                ? l10n.hindi
                                : l10n.english,
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            _showLanguageDialog(context, languageService, l10n);
                          },
                        ),
                      ],
                    ),
                  ),

                  // ==================================================
                  // MIDDLEMAN SECTION
                  // ==================================================
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.middleman,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),

                        const SizedBox(height: 10),

                        TextField(
                          controller: _middlemanEmailController,
                          decoration: InputDecoration(
                            hintText: l10n.enterEmail,
                            border: const OutlineInputBorder(),
                          ),
                        ),

                        const SizedBox(height: 10),

                        ElevatedButton(
                          onPressed: sendRequest,
                          child: Text(l10n.sendRequest),
                        ),

                        const SizedBox(height: 10),

                        ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const RequestsScreen(),
                              ),
                            );
                          },
                          child: Text(l10n.viewRequests),
                        ),

                        const SizedBox(height: 12),

                        // LINKED USERS
                        FutureBuilder(
                          future: getLinkedUsers(),
                          builder: (context, snap) {
                            if (!snap.hasData) {
                              return Text(l10n.loading);
                            }

                            final data = snap.data!;

                            final middlemen = data['middlemen'] as List;

                            final citizens = data['citizens'] as List;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (middlemen.isNotEmpty) ...[
                                  Text(l10n.yourMiddlemen),
                                  ...middlemen.map(
                                    (m) => Text("• ${m['name']}"),
                                  ),
                                ],

                                if (citizens.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  Text(l10n.peopleYouHelp),
                                  ...citizens.map(
                                    (c) => Text("• ${c['name']}"),
                                  ),
                                ],
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  // ==================================================
                  // MY REPORTS
                  // ==================================================
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.myReports,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),

                        const SizedBox(height: 8),

                        FutureBuilder<int>(
                          future: getMyReportCount(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return Text(l10n.loading);
                            }

                            final count = snapshot.data!;

                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("$count ${l10n.reportsSubmitted}"),

                                TextButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const ReportsScreen(),
                                      ),
                                    );
                                  },
                                  child: Text(l10n.viewAll),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  // ==================================================
                  // LOGOUT
                  // ==================================================
                  ElevatedButton(
                    onPressed: () async {
                      await AuthService.logout();

                      if (!mounted) return;

                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (route) => false,
                      );
                    },
                    child: Text(l10n.logout),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
