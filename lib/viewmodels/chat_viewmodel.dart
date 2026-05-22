import 'dart:async';
import 'package:flutter/material.dart';
import '../models/chat_message.dart';

typedef MessagesStreamFactory = Stream<List<ChatMessage>> Function(String uid);
typedef AddMessageFn = Future<void> Function(String uid, {required String role, required String content});
typedef AddModelMessageFn = Future<void> Function(String uid, {required String content});
typedef ClearHistoryFn = Future<void> Function(String uid);
typedef CurrentUserIdFn = String? Function();

class ChatViewModel extends ChangeNotifier {
  final MessagesStreamFactory _watchMessages;
  final AddMessageFn _addMessage;
  final AddModelMessageFn _addModelMessage;
  final ClearHistoryFn _clearHistory;
  final CurrentUserIdFn _currentUserId;

  List<ChatMessage> _messages = [];
  bool _isLoading = true;

  List<ChatMessage> get messages => _messages;
  bool get isLoading => _isLoading;
  String? get currentUserId => _currentUserId();

  StreamSubscription<List<ChatMessage>>? _messagesSub;

  ChatViewModel({
    required MessagesStreamFactory watchMessages,
    required AddMessageFn addMessage,
    required AddModelMessageFn addModelMessage,
    required ClearHistoryFn clearHistory,
    required CurrentUserIdFn currentUserId,
  })  : _watchMessages = watchMessages,
        _addMessage = addMessage,
        _addModelMessage = addModelMessage,
        _clearHistory = clearHistory,
        _currentUserId = currentUserId {
    _init();
  }

  void _init() {
    final uid = _currentUserId();
    if (uid == null) {
      _isLoading = false;
      notifyListeners();
      return;
    }
    _messagesSub = _watchMessages(uid).listen((messages) {
      _messages = messages.reversed.toList();
      _isLoading = false;
      notifyListeners();
    });
  }

  Future<void> addUserMessage(String content) async {
    final uid = _currentUserId();
    if (uid == null) throw Exception('Must be logged in to send messages');
    await _addMessage(uid, role: 'user', content: content);
  }

  Future<void> addModelMessage(String content) async {
    final uid = _currentUserId();
    if (uid == null) throw Exception('Must be logged in to send messages');
    await _addModelMessage(uid, content: content);
  }

  Future<void> clearHistory() async {
    final uid = _currentUserId();
    if (uid == null) return;
    await _clearHistory(uid);
  }

  @override
  void dispose() {
    _messagesSub?.cancel();
    super.dispose();
  }
}
