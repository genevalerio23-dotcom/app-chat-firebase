import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../app_theme.dart';
import '../services/chat_service.dart';
import '../widgets/message_receipt.dart';

class ChatScreen extends StatefulWidget {
  final String contactoUid;
  final String contactoNombre;
  const ChatScreen({
    super.key,
    required this.contactoUid,
    required this.contactoNombre,
  });
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final _service = ChatService();
  final _mensajeCtrl = TextEditingController();
  late final String _uid;
  late final String _chatId;
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _chat;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  QuerySnapshot<Map<String, dynamic>>? _messages;
  Timestamp? _readThrough;
  bool _reading = false;
  bool _loading = true;
  bool _messageError = false;
  bool _receiptError = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _uid = FirebaseAuth.instance.currentUser!.uid;
    _chatId = _service.generarChatId(_uid, widget.contactoUid);
    _chat = _service.obtenerChat(_chatId);
    _subscription = _service
        .obtenerMensajes(_chatId)
        .listen(
          (snapshot) {
            if (!mounted) return;
            setState(() {
              _messages = snapshot;
              _loading = false;
              _messageError = false;
            });
            WidgetsBinding.instance.addPostFrameCallback((_) => _confirmRead());
          },
          onError: (Object error) {
            if (mounted) {
              setState(() {
                _loading = false;
                _messageError = true;
              });
            }
          },
        );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _confirmRead();
  }

  Future<void> _confirmRead() async {
    if (!mounted ||
        _reading ||
        _messages == null ||
        _messages!.metadata.isFromCache ||
        ModalRoute.of(context)?.isCurrent != true ||
        (WidgetsBinding.instance.lifecycleState != null &&
            WidgetsBinding.instance.lifecycleState !=
                AppLifecycleState.resumed)) {
      return;
    }
    Timestamp? latest;
    for (final doc in _messages!.docs) {
      final time = doc.data()['enviadoEn'] as Timestamp?;
      if (doc.data()['emisorUid'] != _uid &&
          !doc.metadata.hasPendingWrites &&
          time != null &&
          (latest == null || time.compareTo(latest) > 0)) {
        latest = time;
      }
    }
    if (latest == null ||
        (_readThrough != null && _readThrough!.compareTo(latest) >= 0)) {
      return;
    }
    _reading = true;
    var succeeded = false;
    try {
      await _service.confirmar(
        chatId: _chatId,
        uid: _uid,
        hasta: latest,
        leido: true,
      );
      _readThrough = latest;
      succeeded = true;
      if (mounted && _receiptError) setState(() => _receiptError = false);
    } catch (_) {
      if (mounted) setState(() => _receiptError = true);
    } finally {
      _reading = false;
    }
    // Catch messages arriving while the previous acknowledgement was in flight.
    if (succeeded && mounted) unawaited(_confirmRead());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    _mensajeCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final text = _mensajeCtrl.text.trim();
    if (text.isEmpty) return;
    _mensajeCtrl.clear();
    try {
      await _service.enviarMensaje(
        chatId: _chatId,
        participantes: [_uid, widget.contactoUid],
        texto: text,
        emisorUid: _uid,
      );
    } catch (_) {
      if (!mounted) return;
      if (_mensajeCtrl.text.isEmpty) _mensajeCtrl.text = text;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo enviar el mensaje. Intenta de nuevo.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = _messages?.docs ?? [];
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text(
                widget.contactoNombre.isEmpty
                    ? '?'
                    : widget.contactoNombre.characters.first.toUpperCase(),
                style: const TextStyle(color: AppTheme.pink),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.contactoNombre,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
      ),
      backgroundColor: const Color(0xFF131116),
      body: Column(
        children: [
          if (_receiptError)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'No se pudo confirmar la lectura. Abre el chat de nuevo para reintentar.',
                style: TextStyle(color: AppTheme.pink),
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messageError
                ? const Center(
                    child: Text('No se pudieron cargar los mensajes.'),
                  )
                : messages.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 48,
                            color: AppTheme.pink,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Envía un mensaje para iniciar la conversación',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: AppTheme.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: _chat,
                    builder: (context, snapshot) {
                      final chat = snapshot.data?.data() ?? <String, dynamic>{};
                      return Column(
                        children: [
                          if (snapshot.hasError)
                            const Padding(
                              padding: EdgeInsets.all(8),
                              child: Text(
                                'No se pudieron actualizar los estados.',
                                style: TextStyle(color: AppTheme.pink),
                              ),
                            ),
                          Expanded(
                            child: ListView.builder(
                              reverse: true,
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              itemCount: messages.length,
                              itemBuilder: (context, i) {
                                final doc = messages[i];
                                final data = doc.data();
                                final mine = data['emisorUid'] == _uid;
                                final time = data['enviadoEn'] as Timestamp?;
                                return _BurbujaMensaje(
                                  texto: data['texto'] as String? ?? '',
                                  esMio: mine,
                                  hora: time == null
                                      ? ''
                                      : DateFormat('HH:mm')
                                            .format(time.toDate()),
                                  status: messageStatus(
                                    sentAt: time,
                                    recipientUid: widget.contactoUid,
                                    chat: chat,
                                    pending: doc.metadata.hasPendingWrites,
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _mensajeCtrl,
                      minLines: 1,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        hintText: 'Escribe un mensaje...',
                        prefixIcon: Icon(Icons.mode_comment_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filled(
                    tooltip: 'Enviar mensaje',
                    padding: const EdgeInsets.all(16),
                    icon: const Icon(Icons.send_rounded),
                    onPressed: _enviar,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BurbujaMensaje extends StatelessWidget {
  final String texto;
  final bool esMio;
  final String hora;
  final MessageStatus status;
  const _BurbujaMensaje({
    required this.texto,
    required this.esMio,
    required this.hora,
    required this.status,
  });
  @override
  Widget build(BuildContext context) => Align(
    alignment: esMio ? Alignment.centerRight : Alignment.centerLeft,
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * .78,
      ),
      decoration: BoxDecoration(
        color: esMio
            ? const Color(0xFF593047)
            : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(esMio ? 18 : 4),
          bottomRight: Radius.circular(esMio ? 4 : 18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(texto, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 5),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                hora,
                style: const TextStyle(fontSize: 11, color: Color(0xFFBDA4B2)),
              ),
              if (esMio) ...[
                const SizedBox(width: 5),
                MessageReceipt(status: status),
              ],
            ],
          ),
        ],
      ),
    ),
  );
}
