import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../app_theme.dart';

enum MessageStatus { sending, sent, received, read }

MessageStatus messageStatus({
  required Timestamp? sentAt,
  required String recipientUid,
  required Map<String, dynamic> chat,
  bool pending = false,
}) {
  if (pending || sentAt == null) return MessageStatus.sending;
  final read =
      (chat['leidoHasta'] as Map<String, dynamic>?)?[recipientUid]
          as Timestamp?;
  final received =
      (chat['recibidoHasta'] as Map<String, dynamic>?)?[recipientUid]
          as Timestamp?;
  if (read != null && read.compareTo(sentAt) >= 0) return MessageStatus.read;
  if (received != null && received.compareTo(sentAt) >= 0) {
    return MessageStatus.received;
  }
  return MessageStatus.sent;
}

class MessageReceipt extends StatelessWidget {
  final MessageStatus status;
  const MessageReceipt({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      MessageStatus.sending => 'Enviando',
      MessageStatus.sent => 'Enviado',
      MessageStatus.received => 'Recibido',
      MessageStatus.read => 'Leído',
    };
    return Tooltip(
      message: label,
      child: Icon(
        switch (status) {
          MessageStatus.sending => Icons.schedule_rounded,
          MessageStatus.sent => Icons.check_rounded,
          MessageStatus.received ||
          MessageStatus.read => Icons.done_all_rounded,
        },
        size: 17,
        color: status == MessageStatus.read
            ? AppTheme.pink
            : const Color(0xFFBDA4B2),
        semanticLabel: label,
      ),
    );
  }
}
