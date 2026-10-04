import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../app_theme.dart';
import '../services/chat_service.dart';
import '../widgets/message_receipt.dart';
import 'chat_screen.dart';

class AgendaScreen extends StatefulWidget {
  const AgendaScreen({super.key});
  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen>
    with WidgetsBindingObserver {
  final _service = ChatService();
  late final String _uid;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _users;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  QuerySnapshot<Map<String, dynamic>>? _chats;
  final _acknowledging = <String>{};
  String _search = '';
  bool _chatError = false;
  bool _receiptError = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _uid = FirebaseAuth.instance.currentUser!.uid;
    _users = FirebaseFirestore.instance.collection('usuarios').snapshots();
    _subscription = _service
        .obtenerChats(_uid)
        .listen(
          (snapshot) {
            if (!mounted) return;
            setState(() {
              _chats = snapshot;
              _chatError = false;
            });
            _confirmReceived();
          },
          onError: (Object error) {
            if (mounted) setState(() => _chatError = true);
          },
        );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _confirmReceived();
  }

  Future<void> _confirmReceived() async {
    if (_chats == null ||
        _chats!.metadata.isFromCache ||
        (WidgetsBinding.instance.lifecycleState != null &&
            WidgetsBinding.instance.lifecycleState !=
                AppLifecycleState.resumed)) {
      return;
    }
    for (final doc in _chats!.docs) {
      final data = doc.data();
      final time = data['ultimaActualizacion'] as Timestamp?;
      final previous =
          (data['recibidoHasta'] as Map<String, dynamic>?)?[_uid] as Timestamp?;
      if (doc.metadata.hasPendingWrites ||
          time == null ||
          data['ultimoEmisorUid'] == _uid ||
          (previous != null && previous.compareTo(time) >= 0) ||
          !_acknowledging.add(doc.id)) {
        continue;
      }
      try {
        await _service.confirmar(chatId: doc.id, uid: _uid, hasta: time);
      } catch (_) {
        if (mounted) setState(() => _receiptError = true);
      } finally {
        _acknowledging.remove(doc.id);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    super.dispose();
  }

  String _time(Timestamp? value) {
    if (value == null) return '';
    final date = value.toDate();
    final now = DateTime.now();
    if (DateUtils.isSameDay(date, now)) return DateFormat('HH:mm').format(date);
    if (DateUtils.isSameDay(date, now.subtract(const Duration(days: 1)))) {
      return 'Ayer';
    }
    return DateFormat('dd/MM').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final chats = {
      for (final doc
          in _chats?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[])
        doc.id: doc,
    };
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 76,
        title: const Padding(
          padding: EdgeInsets.only(left: 8),
          child: Text(
            'Message',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
              color: AppTheme.pink,
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout_rounded, size: 22),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: TextField(
              onChanged: (value) =>
                  setState(() => _search = value.trim().toLowerCase()),
              decoration: const InputDecoration(
                hintText: 'Buscar una conversación',
                prefixIcon: Icon(Icons.search_rounded, color: AppTheme.muted),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Conversaciones',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          if (_chatError || _receiptError)
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: Text(
                'No se pudieron sincronizar las conversaciones o sus estados. Intenta abrir la app de nuevo.',
                style: TextStyle(color: AppTheme.pink),
              ),
            ),
          const SizedBox(height: 18),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _users,
              builder: (context, snapshot) {
                if (!snapshot.hasData &&
                    snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(
                    child: Text('No se pudieron cargar los contactos.'),
                  );
                }
                final contacts = (snapshot.data?.docs ?? [])
                    .where(
                      (doc) =>
                          doc.id != _uid &&
                          '${doc.data()['nombre']} ${doc.data()['correo']}'
                              .toLowerCase()
                              .contains(_search),
                    )
                    .toList();
                contacts.sort((a, b) {
                  final aId = _service.generarChatId(
                    _uid,
                    a.data()['uid'] as String? ?? a.id,
                  );
                  final bId = _service.generarChatId(
                    _uid,
                    b.data()['uid'] as String? ?? b.id,
                  );
                  final aTime =
                      chats[aId]?.data()['ultimaActualizacion'] as Timestamp?;
                  final bTime =
                      chats[bId]?.data()['ultimaActualizacion'] as Timestamp?;
                  final order =
                      (bTime?.compareTo(aTime ?? Timestamp(0, 0))) ??
                      (aTime == null ? 0 : -1);
                  return order != 0
                      ? order
                      : '${a.data()['nombre']}'.compareTo(
                          '${b.data()['nombre']}',
                        );
                });
                if (contacts.isEmpty) {
                  return Center(
                    child: Text(
                      _search.isEmpty
                          ? 'Tu próxima conversación empieza aquí'
                          : 'No se encontraron contactos',
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                  itemCount: contacts.length,
                  separatorBuilder: (_, index) => const Padding(
                    padding: EdgeInsets.only(left: 84, right: 12),
                    child: Divider(),
                  ),
                  itemBuilder: (context, i) {
                    final data = contacts[i].data();
                    final name = data['nombre'] as String? ?? 'Contacto';
                    final contactUid = data['uid'] as String? ?? contacts[i].id;
                    final chatDoc =
                        chats[_service.generarChatId(_uid, contactUid)];
                    final chat = chatDoc?.data() ?? <String, dynamic>{};
                    final time = chat['ultimaActualizacion'] as Timestamp?;
                    final lastMessage = chat['ultimoMensaje'] as String?;
                    final own = chat['ultimoEmisorUid'] == _uid;
                    final read =
                        (chat['leidoHasta'] as Map<String, dynamic>?)?[_uid]
                            as Timestamp?;
                    final unread =
                        lastMessage != null &&
                        !own &&
                        time != null &&
                        (read == null || read.compareTo(time) < 0);
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      leading: CircleAvatar(
                        radius: 28,
                        backgroundColor: const Color(0xFF422536),
                        child: Text(
                          name.isEmpty
                              ? '?'
                              : name.characters.first.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 23,
                            color: Color(0xFFFFC8DF),
                          ),
                        ),
                      ),
                      title: Text(
                        name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Row(
                          children: [
                            if (own) ...[
                              MessageReceipt(
                                status: messageStatus(
                                  sentAt: time,
                                  recipientUid: contactUid,
                                  chat: chat,
                                  pending:
                                      chatDoc?.metadata.hasPendingWrites ??
                                      false,
                                ),
                              ),
                              const SizedBox(width: 4),
                            ],
                            Expanded(
                              child: Text(
                                lastMessage ?? 'Envía un mensaje para iniciar la conversación',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: unread ? AppTheme.ink : AppTheme.muted,
                                  fontWeight: unread
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      trailing: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _time(time),
                            style: TextStyle(
                              fontSize: 11,
                              color: unread ? AppTheme.pink : AppTheme.muted,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (unread)
                            const Tooltip(
                              message: 'Mensajes sin leer',
                              child: Icon(
                                Icons.circle,
                                size: 10,
                                color: AppTheme.pink,
                              ),
                            ),
                        ],
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            contactoUid: contactUid,
                            contactoNombre: name,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
