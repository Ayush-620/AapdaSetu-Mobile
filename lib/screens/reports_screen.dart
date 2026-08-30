import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../services/app_localizations.dart';
import '../services/supabase_client.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final AudioPlayer _player = AudioPlayer();

  String? _currentlyPlayingUrl;

  // FETCH REPORTS + USER INFO
  Future<List<dynamic>> getReports() async {
    final user = supabase.auth.currentUser;

    if (user == null) return [];

    return await supabase
        .from('citizen_reports')
        .select()
        .eq('created_by', user.id)
        .order('created_at', ascending: false);
  }

  // FETCH USER NAME FROM citizen_id
  Future<Map<int, Map<String, dynamic>>> getUsersMap() async {
    final users = await supabase.from('profiles').select();

    Map<int, Map<String, dynamic>> map = {};

    for (var u in users) {
      map[u['citizen_id']] = u;
    }

    return map;
  }

  Future<void> _playAudio(String url) async {
    final l10n = AppLocalizations.of(context);

    try {
      if (_currentlyPlayingUrl == url && _player.playing) {
        await _player.pause();
        setState(() {});
        return;
      }

      await _player.setUrl(url);
      _currentlyPlayingUrl = url;
      await _player.play();

      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("${l10n.audioError}: $e")));
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.reports)),
      body: FutureBuilder(
        future: Future.wait([getReports(), getUsersMap()]),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final reports = snapshot.data![0] as List;
          final usersMap = snapshot.data![1] as Map<int, Map<String, dynamic>>;

          if (reports.isEmpty) {
            return Center(child: Text(l10n.noReportsYet));
          }

          return ListView.builder(
            itemCount: reports.length,
            itemBuilder: (context, i) {
              final r = reports[i];

              final isPlaying =
                  _currentlyPlayingUrl == r['audio_url'] && _player.playing;

              final reportedFor = r['reported_for'];
              final user = usersMap[reportedFor];

              return Card(
                margin: const EdgeInsets.all(10),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // TITLE
                      Text(
                        r['category'] ?? '',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),

                      const SizedBox(height: 6),

                      // WHO THIS REPORT IS FOR
                      Text(
                        user != null
                            ? "${l10n.forLabel} "
                                  "${user['name'] ?? user['email']}"
                            : "${l10n.forLabel} ${l10n.unknown}",
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),

                      const SizedBox(height: 6),

                      // DESCRIPTION
                      Text(r['details'] ?? ''),

                      const SizedBox(height: 10),

                      // IMAGE
                      if (r['image_url'] != null)
                        GestureDetector(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (_) =>
                                  Dialog(child: Image.network(r['image_url'])),
                            );
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(r['image_url']),
                          ),
                        ),

                      const SizedBox(height: 10),

                      // AUDIO
                      if (r['audio_url'] != null)
                        ElevatedButton.icon(
                          icon: Icon(
                            isPlaying ? Icons.pause : Icons.play_arrow,
                          ),
                          label: Text(
                            isPlaying ? l10n.pauseAudio : l10n.playAudio,
                          ),
                          onPressed: () => _playAudio(r['audio_url']),
                        ),

                      const SizedBox(height: 10),

                      // STATUS
                      Text(
                        "${l10n.status}: ${r['status']}",
                        style: TextStyle(
                          color: r['status'] == 'Open'
                              ? Colors.red
                              : Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
