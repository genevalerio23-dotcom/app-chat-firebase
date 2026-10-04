import 'package:cloud_firestore/cloud_firestore.dart';

class ChatService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String generarChatId(String uidA, String uidB) {
    final ids = [uidA, uidB]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> obtenerChats(String uid) => _db
      .collection('chats')
      .where('participantes', arrayContains: uid)
      .snapshots(includeMetadataChanges: true);

  Stream<DocumentSnapshot<Map<String, dynamic>>> obtenerChat(String chatId) =>
      _db.collection('chats').doc(chatId).snapshots();

  Future<void> enviarMensaje({
    required String chatId,
    required List<String> participantes,
    required String texto,
    required String emisorUid,
  }) async {
    final chatRef = _db.collection('chats').doc(chatId);
    final mensajeRef = chatRef.collection('mensajes').doc();
    final batch = _db.batch();
    batch.set(chatRef, {
      'participantes': participantes,
      'ultimoMensaje': texto,
      'ultimoEmisorUid': emisorUid,
      'ultimoMensajeId': mensajeRef.id,
      'ultimaActualizacion': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    batch.set(mensajeRef, {
      'texto': texto,
      'emisorUid': emisorUid,
      'enviadoEn': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  // Watermarks acknowledge only messages actually observed by this device.
  // A transaction prevents delayed snapshots from moving receipts backwards.
  Future<void> confirmar({
    required String chatId,
    required String uid,
    required Timestamp hasta,
    bool leido = false,
  }) async {
    final ref = _db.collection('chats').doc(chatId);
    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists) return;
      final data = snapshot.data()!;
      final updates = <String, dynamic>{};
      for (final field in ['recibidoHasta', if (leido) 'leidoHasta']) {
        final previous =
            (data[field] as Map<String, dynamic>?)?[uid] as Timestamp?;
        if (previous == null || previous.compareTo(hasta) < 0) {
          updates['$field.$uid'] = hasta;
        }
      }
      if (updates.isNotEmpty) transaction.update(ref, updates);
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> obtenerMensajes(String chatId) =>
      _db
          .collection('chats')
          .doc(chatId)
          .collection('mensajes')
          .orderBy('enviadoEn', descending: true)
          .snapshots(includeMetadataChanges: true);
}
