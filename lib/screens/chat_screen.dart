import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../services/chat_storage_service.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';
import '../services/language_scope.dart';
import '../services/app_localizations.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, String>> messages = [];
  bool loading = false;

  // Voice
  late stt.SpeechToText _speech;
  bool _isListening = false;

  String get userId => AuthService.currentUser?.id ?? "guest";

  @override
  void initState() {
    super.initState();

    _speech = stt.SpeechToText();

    _loadMessages();
  }

  // ============================================================
  // LOAD CHAT HISTORY
  // ============================================================

  void _loadMessages() {
    try {
      final history = ChatStorageService.getMessages(userId);

      debugPrint("LOADED HISTORY: $history");

      setState(() {
        messages = history
            .where((e) => e["role"] != null && e["text"] != null)
            .map<Map<String, String>>(
              (e) => {
                "role": e["role"].toString(),
                "text": e["text"].toString(),
              },
            )
            .toList();
      });
    } catch (e) {
      debugPrint("CHAT LOAD ERROR: $e");

      setState(() {
        messages = [];
      });
    }
  }

  // ============================================================
  // START LISTENING
  // ============================================================

  Future<void> _startListening() async {
    final available = await _speech.initialize();

    if (available) {
      setState(() => _isListening = true);

      _speech.listen(
        onResult: (result) {
          setState(() {
            _controller.text = result.recognizedWords;
            _controller.selection = TextSelection.fromPosition(
              TextPosition(offset: _controller.text.length),
            );
          });
        },
      );
    }
  }

  void _stopListening() {
    _speech.stop();

    setState(() => _isListening = false);
  }

  // ============================================================
  // SEND MESSAGE TO AI
  // ============================================================

  Future<String> sendMessage(String message, String language) async {
    try {
      debugPrint("CHATBOT: sendMessage started");
      debugPrint("CHATBOT: language = $language");

      final history = ChatStorageService.getMessages(userId);

      debugPrint("CHATBOT: history loaded");

      final position = await LocationService.getCurrentLocation();

      debugPrint(
        "CHATBOT: location = ${position?.latitude}, ${position?.longitude}",
      );

      debugPrint("CHATBOT: invoking Supabase function...");

      final res = await Supabase.instance.client.functions.invoke(
        'chatbot',
        body: {
          "message": message,
          "history": history,
          "lat": position?.latitude,
          "lng": position?.longitude,
          "userId": userId,
          "language": language,
        },
      );

      debugPrint("CHATBOT: function returned");
      debugPrint("CHATBOT: status = ${res.status}");
      debugPrint("CHATBOT: data = ${res.data}");

      final data = res.data;

      return data?["reply"]?.toString() ?? "No reply";
    } catch (e, stackTrace) {
      debugPrint("CHATBOT ERROR: $e");
      debugPrint("CHATBOT STACK: $stackTrace");

      return language == "hi"
          ? "AI सेवा अभी उपलब्ध नहीं है। कृपया पुनः प्रयास करें।"
          : "AI unavailable. Try again.";
    }
  }

  // ============================================================
  // HANDLE SEND
  // ============================================================

  Future<void> handleSend() async {
    debugPrint("🔥🔥🔥 HANDLE SEND CALLED 🔥🔥🔥");
    final text = _controller.text.trim();

    debugPrint("🔥 MESSAGE: $text");

    debugPrint("CHATBOT TEST: handleSend called");
    debugPrint("CHATBOT TEST: message = $text");

    if (text.isEmpty || loading) return;

    setState(() {
      messages.add({"role": "user", "text": text});

      loading = true;
    });

    _controller.clear();

    await ChatStorageService.saveMessage(
      userId: userId,
      role: "user",
      text: text,
    );

    final language = Localizations.localeOf(context).languageCode;

    debugPrint("CHATBOT TEST: calling sendMessage");

    final reply = await sendMessage(text, language);

    await ChatStorageService.saveMessage(
      userId: userId,
      role: "bot",
      text: reply,
    );

    if (!mounted) return;

    setState(() {
      messages.add({"role": "bot", "text": reply});

      loading = false;
    });

    _scrollToBottom();
  }

  // ============================================================
  // SCROLL TO BOTTOM
  // ============================================================

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!_scrollController.hasClients) return;

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  // ============================================================
  // MESSAGE UI
  // ============================================================

  Widget buildMessage(Map<String, String> msg) {
    final isUser = msg["role"] == "user";

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isUser ? Colors.blue : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
        ),
        child: Text(
          msg["text"]?.replaceAll("**", "") ?? "",
          style: TextStyle(color: isUser ? Colors.white : Colors.black87),
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Colors.grey[100],

      // ========================================================
      // APP BAR
      // ========================================================
      appBar: AppBar(title: Text(l10n.aiDisasterAssistant)),

      // ========================================================
      // BODY
      // ========================================================
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: messages.isEmpty ? 1 : messages.length,
              itemBuilder: (context, index) {
                // EMPTY STATE
                if (messages.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 100),
                    child: Center(
                      child: Column(
                        children: [
                          const Icon(
                            Icons.support_agent,
                            size: 60,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            l10n.askSafetyAlerts,
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // CHAT MESSAGE
                return buildMessage(messages[index]);
              },
            ),
          ),

          // ======================================================
          // LOADING
          // ======================================================
          if (loading)
            const Padding(
              padding: EdgeInsets.all(8),
              child: CircularProgressIndicator(),
            ),

          // ======================================================
          // INPUT BAR
          // ======================================================
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: l10n.askSomething,
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // MIC
                GestureDetector(
                  onTap: _isListening ? _stopListening : _startListening,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _isListening ? Colors.red : Colors.grey[300],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isListening ? Icons.mic : Icons.mic_none,
                      color: _isListening ? Colors.white : Colors.black,
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // SEND
                GestureDetector(
                  onTap: () {
                    debugPrint("🔥🔥🔥 SEND BUTTON PRESSED 🔥🔥🔥");
                    handleSend();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
