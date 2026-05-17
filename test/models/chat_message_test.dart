import 'package:flutter_test/flutter_test.dart';
import 'package:isdex/models/chat_message.dart';

void main() {
  group('ChatMessage', () {
    test('fromMap creates ChatMessage from RTDB data', () {
      final data = <String, dynamic>{
        'role': 'user',
        'content': 'What is Bangus?',
        'timestamp': 1700000000000,
      };

      final msg = ChatMessage.fromMap('msg1', data);

      expect(msg.id, 'msg1');
      expect(msg.role, 'user');
      expect(msg.content, 'What is Bangus?');
      expect(msg.timestamp, 1700000000000);
    });

    test('fromMap defaults missing fields', () {
      final data = <String, dynamic>{};
      final msg = ChatMessage.fromMap('m1', data);

      expect(msg.role, '');
      expect(msg.content, '');
      expect(msg.timestamp, 0);
    });

    test('toMap produces correct map', () {
      final msg = ChatMessage(
        id: 'msg1',
        role: 'model',
        content: 'Bangus is milkfish.',
        timestamp: 1700000000000,
      );

      final map = msg.toMap();
      expect(map['role'], 'model');
      expect(map['content'], 'Bangus is milkfish.');
    });
  });
}
