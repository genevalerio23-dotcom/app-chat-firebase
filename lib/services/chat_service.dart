import 'package:cloud_firestore/cloud_firestore.dart';

class ChatService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String generarChatId(String uidA, String uidB) {
    final ids = [uidA, uidB]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  Future<void> enviarMensaje({
    required String chatId,
    required List<String> participantes,
    required String texto,
    required String emisorUid,
  }) async {
    final chatRef = _db.collection('chats').doc(chatId);

    await chatRef.set({
      'participantes': participantes,
      'ultimoMensaje': texto,
      'ultimaActualizacion': Timestamp.now(),
    }, SetOptions(merge: true));

    await chatRef.collection('mensajes').add({
      'texto': texto,
      'emisorUid': emisorUid,
      'enviadoEn': Timestamp.now(),
    });
  }

  Stream<QuerySnapshot> obtenerMensajes(String chatId) {
    return _db
        .collection('chats')
        .doc(chatId)
        .collection('mensajes')
        .orderBy('enviadoEn', descending: false)
        .snapshots();
  }
}
