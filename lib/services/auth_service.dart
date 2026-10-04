import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<User?> get estadoUsuario => _auth.authStateChanges();

  Future<String?> registrar(String nombre, String correo, String clave) async {
    try {
      final credencial = await _auth.createUserWithEmailAndPassword(
        email: correo,
        password: clave,
      );

      final uid = credencial.user!.uid;

      await _db.collection('usuarios').doc(uid).set({
        'nombre': nombre,
        'correo': correo,
        'uid': uid,
      });

      return null;
    } on FirebaseAuthException catch (e) {
      return _traducirError(e.code);
    }
  }

  Future<String?> iniciarSesion(String correo, String clave) async {
    try {
      await _auth.signInWithEmailAndPassword(email: correo, password: clave);

      return null;
    } on FirebaseAuthException catch (e) {
      return _traducirError(e.code);
    }
  }

  Future<void> cerrarSesion() => _auth.signOut();

  String _traducirError(String codigo) {
    switch (codigo) {
      case 'email-already-in-use':
        return 'Ese correo ya tiene una cuenta.';
      case 'weak-password':
        return 'La contraseña necesita al menos 6 caracteres.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Correo o contraseña incorrectos.';
      default:
        return 'Ocurrió un error. Intenta de nuevo.';
    }
  }
}
