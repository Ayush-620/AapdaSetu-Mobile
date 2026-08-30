import 'package:flutter/material.dart';

import '../services/app_localizations.dart';
import '../services/supabase_client.dart';

class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key});

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> {
  // FETCH REQUESTS
  Future<List<dynamic>> getRequests() async {
    final user = supabase.auth.currentUser;

    if (user == null) return [];

    final res = await supabase
        .from('middleman_links')
        .select('id, citizen_id')
        .eq('middleman_id', user.id)
        .eq('status', 'Pending');

    return res;
  }

  // ACCEPT
  Future<void> acceptRequest(int id) async {
    await supabase
        .from('middleman_links')
        .update({'status': 'Accepted'})
        .eq('id', id);

    setState(() {});
  }

  // REJECT
  Future<void> rejectRequest(int id) async {
    await supabase
        .from('middleman_links')
        .update({'status': 'Rejected'})
        .eq('id', id);

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.requests)),
      body: FutureBuilder(
        future: getRequests(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: Text(l10n.loading));
          }

          final requests = snapshot.data as List;

          if (requests.isEmpty) {
            return Center(child: Text(l10n.noRequests));
          }

          return ListView(
            children: requests.map((req) {
              return FutureBuilder(
                future: supabase
                    .from('profiles')
                    .select('name')
                    .eq('citizen_id', req['citizen_id'])
                    .single(),
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return ListTile(title: Text(l10n.loading));
                  }

                  final citizen = snap.data as Map<String, dynamic>;

                  return ListTile(
                    title: Text(citizen['name']),
                    subtitle: Text(l10n.wantsYouAsMiddleman),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.check, color: Colors.green),
                          onPressed: () => acceptRequest(req['id']),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.red),
                          onPressed: () => rejectRequest(req['id']),
                        ),
                      ],
                    ),
                  );
                },
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
