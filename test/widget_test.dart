import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_chat_firebase/app_theme.dart';
import 'package:app_chat_firebase/widgets/message_receipt.dart';

void main() {
  final sent = Timestamp(100, 50);
  MessageStatus status(
    Map<String, dynamic> chat, {
    bool pending = false,
    Timestamp? time,
  }) => messageStatus(
    sentAt: time ?? sent,
    recipientUid: 'recipient',
    chat: chat,
    pending: pending,
  );

  test('Server confirmation alone means sent, not received', () {
    expect(status({}), MessageStatus.sent);
    expect(
      status({
        'recibidoHasta': {'sender': sent},
      }),
      MessageStatus.sent,
    );
  });

  test('Pending writes remain sending even with receipt watermarks', () {
    expect(
      status({
        'leidoHasta': {'recipient': Timestamp(200, 0)},
      }, pending: true),
      MessageStatus.sending,
    );
    expect(
      messageStatus(sentAt: null, recipientUid: 'recipient', chat: {}),
      MessageStatus.sending,
    );
  });

  test('Delivery watermark includes the boundary but not newer messages', () {
    final chat = {
      'recibidoHasta': {'recipient': sent},
    };
    expect(status(chat), MessageStatus.received);
    expect(status(chat, time: Timestamp(100, 51)), MessageStatus.sent);
    expect(
      status(chat, time: Timestamp(99, 999999999)),
      MessageStatus.received,
    );
  });

  test('Read supersedes received and does not mark later messages read', () {
    final chat = {
      'recibidoHasta': {'recipient': Timestamp(101, 0)},
      'leidoHasta': {'recipient': sent},
    };
    expect(status(chat), MessageStatus.read);
    expect(status(chat, time: Timestamp(100, 51)), MessageStatus.received);
    expect(status(chat, time: Timestamp(102, 0)), MessageStatus.sent);
  });

  testWidgets('Receipt labels and icons distinguish all four states', (
    tester,
  ) async {
    for (final entry in {
      MessageStatus.sending: ('Enviando', Icons.schedule_rounded),
      MessageStatus.sent: ('Enviado', Icons.check_rounded),
      MessageStatus.received: ('Recibido', Icons.done_all_rounded),
      MessageStatus.read: ('Leído', Icons.done_all_rounded),
    }.entries) {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(body: MessageReceipt(status: entry.key)),
        ),
      );
      expect(find.byTooltip(entry.value.$1), findsOneWidget);
      expect(find.byIcon(entry.value.$2), findsOneWidget);
      final icon = tester.widget<Icon>(find.byIcon(entry.value.$2));
      expect(
        icon.color,
        entry.key == MessageStatus.read
            ? AppTheme.pink
            : const Color(0xFFBDA4B2),
      );
    }
  });
}
