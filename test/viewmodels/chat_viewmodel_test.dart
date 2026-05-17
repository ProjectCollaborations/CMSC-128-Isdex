import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:isdex/models/chat_message.dart';
import 'package:isdex/viewmodels/chat_viewmodel.dart';

class FakeChatRepo {
  final StreamController<List<ChatMessage>> _controller =
      StreamController<List<ChatMessage>>.broadcast();

  bool addMessageCalled = false;
  bool addModelMessageCalled = false;
  bool clearHistoryCalled = false;
  String? lastRole;
  String? lastContent;

  void emitMessages(List<ChatMessage> messages) {
    _controller.add(messages);
  }

  Stream<List<ChatMessage>> watchMessages(String uid) => _controller.stream;

  Future<void> addMessage(String uid, {required String role, required String content}) async {
    addMessageCalled = true;
    lastRole = role;
    lastContent = content;
  }

  Future<void> addModelMessage(String uid, {required String content}) async {
    addModelMessageCalled = true;
    lastContent = content;
  }

  Future<void> clearHistory(String uid) async {
    clearHistoryCalled = true;
  }

  void dispose() => _controller.close();
}

void main() {
  group('ChatViewModel', () {
    late ChatViewModel vm;
    late FakeChatRepo fakeRepo;

    setUp(() {
      fakeRepo = FakeChatRepo();
      vm = ChatViewModel(
        watchMessages: (uid) => fakeRepo.watchMessages(uid),
        addMessage: (uid, {required role, required content}) =>
            fakeRepo.addMessage(uid, role: role, content: content),
        addModelMessage: (uid, {required content}) =>
            fakeRepo.addModelMessage(uid, content: content),
        clearHistory: (uid) => fakeRepo.clearHistory(uid),
        currentUserId: () => 'test-uid',
      );
    });

    tearDown(() {
      vm.dispose();
      fakeRepo.dispose();
    });

    test('initial state has empty messages and loading', () {
      expect(vm.messages, isEmpty);
      expect(vm.isLoading, isTrue);
    });

    test('receives messages from stream', () async {
      final messages = [
        ChatMessage(id: '1', role: 'user', content: 'Hello', timestamp: 1000),
        ChatMessage(id: '2', role: 'model', content: 'Hi', timestamp: 2000),
      ];
      fakeRepo.emitMessages(messages);
      await Future.delayed(const Duration(milliseconds: 50));
      expect(vm.messages.length, 2);
      expect(vm.isLoading, isFalse);
    });

    test('addUserMessage calls repository', () async {
      await vm.addUserMessage('Hello');
      expect(fakeRepo.addMessageCalled, isTrue);
      expect(fakeRepo.lastRole, 'user');
    });

    test('addModelMessage calls repository', () async {
      await vm.addModelMessage('Response');
      expect(fakeRepo.addModelMessageCalled, isTrue);
    });

    test('clearHistory calls repository', () async {
      await vm.clearHistory();
      expect(fakeRepo.clearHistoryCalled, isTrue);
    });

    test('currentUserId returns null when not logged in', () {
      final vmNoUser = ChatViewModel(
        watchMessages: (uid) => fakeRepo.watchMessages(uid),
        addMessage: (uid, {required role, required content}) =>
            fakeRepo.addMessage(uid, role: role, content: content),
        addModelMessage: (uid, {required content}) =>
            fakeRepo.addModelMessage(uid, content: content),
        clearHistory: (uid) => fakeRepo.clearHistory(uid),
        currentUserId: () => null,
      );
      expect(vmNoUser.currentUserId, isNull);
      vmNoUser.dispose();
    });

    test('addUserMessage throws when not logged in', () async {
      final vmNoUser = ChatViewModel(
        watchMessages: (uid) => fakeRepo.watchMessages(uid),
        addMessage: (uid, {required role, required content}) =>
            fakeRepo.addMessage(uid, role: role, content: content),
        addModelMessage: (uid, {required content}) =>
            fakeRepo.addModelMessage(uid, content: content),
        clearHistory: (uid) => fakeRepo.clearHistory(uid),
        currentUserId: () => null,
      );
      expect(
        () => vmNoUser.addUserMessage('test'),
        throwsA(isA<Exception>()),
      );
      vmNoUser.dispose();
    });
  });
}
