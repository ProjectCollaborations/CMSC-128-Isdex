import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'theme.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  final String _userId = FirebaseAuth.instance.currentUser?.uid ?? '';
  bool _isAITyping = false;

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _userId.isEmpty) return;

    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('API Key not found. Please check your .env file.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    _messageController.clear();
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    try {
      // 1. Add user's message to RTDB
      final newMessageRef = _db.child('chat_sessions/$_userId').push();
      await newMessageRef.set({
        'role': 'user',
        'content': text,
        'timestamp': timestamp,
      });

      setState(() {
        _isAITyping = true;
      });

      // 2. Fetch Fish List for RAG (Retrieval-Augmented Generation)
      final fishSnap = await _db.child('fish').get();
      final allFish = fishSnap.value as Map? ?? {};

      String relevantContext = "";
      allFish.forEach((id, fishData) {
        final fish = Map<String, dynamic>.from(fishData as Map);
        final commonName = fish['commonName']?.toString().toLowerCase() ?? "";
        final localName = fish['localName']?.toString().toLowerCase() ?? "";
        
        // Simple keyword matching for RAG
        if (text.toLowerCase().contains(commonName) || 
            text.toLowerCase().contains(localName)) {
          relevantContext += "${jsonEncode(fish)}\n";
        }
      });

      // 3. Fetch Chat History (Last 5 messages for context)
      final historySnap = await _db.child('chat_sessions/$_userId').limitToLast(6).get();
      final historyData = historySnap.value as Map? ?? {};
      final historyList = historyData.entries.toList()
        ..sort((a, b) => (a.value['timestamp'] as int).compareTo(b.value['timestamp'] as int));

      // Filter out the current message to avoid duplication in history
      final filteredHistory = historyList.where((e) => e.key != newMessageRef.key).toList();

      final contentHistory = filteredHistory.map((m) {
        final role = m.value['role'] == 'user' ? 'user' : 'model';
        return Content(role, [TextPart(m.value['content'])]);
      }).toList();

      // 4. Initialize Gemini Model
      final model = GenerativeModel(
        model: 'gemini-3.1-flash-lite-preview',
        apiKey: apiKey,
        systemInstruction: Content.system(
          "You are the Isdex AI Assistant, an expert marine biologist specializing in Philippine fish. "
          "Use the following database context if relevant to provide accurate local information: $relevantContext. "
          "If the user asks about a fish not in the context, use your general knowledge but emphasize that it's not in the official Isdex database. "
          "Keep responses helpful, educational, and concise."
        ),
      );

      // 5. Query Gemini
      final chat = model.startChat(history: contentHistory);
      final response = await chat.sendMessage(Content.text(text));
      final responseText = response.text ?? "I'm sorry, I couldn't generate a response.";

      // 6. Save AI's response to RTDB
      await _db.child('chat_sessions/$_userId').push().set({
        'role': 'model',
        'content': responseText,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAITyping = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        title: const Text(
          'Isdex AI Assistant',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: kDarkNavy,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder(
              stream: _db.child('chat_sessions/$_userId').onValue,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          size: 64,
                          color: Colors.blue.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Ask me anything about Philippine fish!',
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }

                final data = Map<dynamic, dynamic>.from(
                  snapshot.data!.snapshot.value as Map,
                );
                final messages = data.entries.toList()
                  ..sort(
                    (a, b) => b.value['timestamp'].compareTo(a.value['timestamp']),
                  );

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 20,
                  ),
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index].value;
                    final isUser = msg['role'] == 'user';
                    final content = msg['content'] as String;
                    final ts = msg['timestamp'] as int;
                    final timeStr = DateFormat('jm').format(
                      DateTime.fromMillisecondsSinceEpoch(ts),
                    );

                    return _buildMessageBubble(content, isUser, timeStr);
                  },
                );
              },
            ),
          ),
          if (_isAITyping)
            Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 8),
              child: Row(
                children: [
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'AI is thinking...',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(String content, bool isUser, String timeStr) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isUser ? kAccentBlue : Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isUser ? 16 : 0),
                bottomRight: Radius.circular(isUser ? 0 : 16),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              content,
              style: TextStyle(
                color: isUser ? Colors.white : kDarkNavy,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            timeStr,
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, -2),
            blurRadius: 10,
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: kBackground,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _sendMessage,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: kDarkNavy,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.send, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
