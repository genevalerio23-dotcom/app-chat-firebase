import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../services/chat_service.dart';

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

class _ChatScreenState extends State<ChatScreen> {
  final _chatService = ChatService();
  final _mensajeCtrl = TextEditingController();

  late final String _miUid;
  late final String _chatId;

  @override
  void initState() {
    super.initState();

    _miUid = FirebaseAuth.instance.currentUser!.uid;
    _chatId = _chatService.generarChatId(_miUid, widget.contactoUid);
  }

  @override
  void dispose() {
    _mensajeCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final texto = _mensajeCtrl.text.trim();

    if (texto.isEmpty) return;

    _mensajeCtrl.clear();

    await _chatService.enviarMensaje(
      chatId: _chatId,
      participantes: [_miUid, widget.contactoUid],
      texto: texto,
      emisorUid: _miUid,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: const Icon(Icons.person_outline_rounded),
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
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _chatService.obtenerMensajes(_chatId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final mensajes = snapshot.data?.docs ?? [];

                if (mensajes.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chat_bubble_outline_rounded, size: 48),
                        SizedBox(height: 16),
                        Text('Aún no hay mensajes. ¡Saluda!'),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  itemCount: mensajes.length,
                  itemBuilder: (context, i) {
                    final datos =
                        mensajes[mensajes.length - 1 - i].data()
                            as Map<String, dynamic>;

                    final esMio = datos['emisorUid'] == _miUid;

                    final hora =
                        (datos['enviadoEn'] as Timestamp?)?.toDate() ??
                        DateTime.now();

                    return _BurbujaMensaje(
                      texto: datos['texto'],
                      esMio: esMio,
                      hora: DateFormat('HH:mm').format(hora),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
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

  const _BurbujaMensaje({
    required this.texto,
    required this.esMio,
    required this.hora,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: esMio ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        decoration: BoxDecoration(
          color: esMio
              ? const Color(0xFF593047)
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(esMio ? 24 : 8),
            bottomRight: Radius.circular(esMio ? 8 : 24),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(texto, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 5),
            Text(
              hora,
              style: const TextStyle(fontSize: 11, color: Color(0xFF705766)),
            ),
          ],
        ),
      ),
    );
  }
}
