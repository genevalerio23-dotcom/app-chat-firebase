import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../app_theme.dart';
import 'chat_screen.dart';

class AgendaScreen extends StatefulWidget {
  const AgendaScreen({super.key});
  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final miUid = FirebaseAuth.instance.currentUser!.uid;
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
                hintText: 'Buscar un contacto',
                prefixIcon: Icon(Icons.search_rounded, color: AppTheme.muted),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Text(
                  'Conversaciones',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF422536),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Contactos',
                    style: TextStyle(
                      color: AppTheme.pink,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('usuarios')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(
                    child: Text('No se pudieron cargar los contactos.'),
                  );
                }
                final contactos = (snapshot.data?.docs ?? []).where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return doc.id != miUid &&
                      '${data['nombre']} ${data['correo']}'
                          .toLowerCase()
                          .contains(_search);
                }).toList();
                if (contactos.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.forum_outlined,
                          size: 48,
                          color: AppTheme.pink,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _search.isEmpty
                              ? 'Tu próxima conversación empieza aquí'
                              : 'No se encontraron contactos',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                  itemCount: contactos.length,
                  separatorBuilder: (_, index) => const Padding(
                    padding: EdgeInsets.only(left: 84, right: 12),
                    child: Divider(),
                  ),
                  itemBuilder: (context, i) {
                    final datos = contactos[i].data() as Map<String, dynamic>;
                    final nombre = (datos['nombre'] as String?) ?? 'Contacto';
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      leading: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: i.isEven
                                ? [
                                    const Color(0xFF63394F),
                                    const Color(0xFF342632),
                                  ]
                                : [
                                    const Color(0xFF46405F),
                                    const Color(0xFF282635),
                                  ],
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          nombre.isEmpty
                              ? '?'
                              : nombre.characters.first.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFFFC8DF),
                          ),
                        ),
                      ),
                      title: Text(
                        nombre,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Text(
                          datos['correo'] as String? ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 20,
                        color: AppTheme.muted,
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            contactoUid:
                                datos['uid'] as String? ?? contactos[i].id,
                            contactoNombre: nombre,
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
