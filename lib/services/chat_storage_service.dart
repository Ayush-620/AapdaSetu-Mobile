import 'package:hive/hive.dart';

class ChatStorageService {
  static Box get _box => Hive.box('chat');

  static List<Map<String, dynamic>> getMessages(String userId) {
    final data = _box.get('chat_$userId', defaultValue: []);

    if (data is! List) {
      return [];
    }

    return data
        .map<Map<String, dynamic>>((message) {
          if (message is Map) {
            return Map<String, dynamic>.from(
              message.map((key, value) => MapEntry(key.toString(), value)),
            );
          }

          return <String, dynamic>{};
        })
        .where((message) => message.isNotEmpty)
        .toList();
  }

  static Future<void> saveMessage({
    required String userId,
    required String role,
    required String text,
  }) async {
    final messages = getMessages(userId);

    messages.add({
      "role": role,
      "text": text,
      "timestamp": DateTime.now().toIso8601String(),
    });

    if (messages.length > 10) {
      messages.removeAt(0);
    }

    await _box.put('chat_$userId', messages);
  }

  static Future<void> clear(String userId) async {
    await _box.delete('chat_$userId');
  }
}
