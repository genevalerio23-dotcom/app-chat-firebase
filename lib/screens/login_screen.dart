import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _authService = AuthService();
  final _nombreCtrl = TextEditingController();
  final _correoCtrl = TextEditingController();
  final _claveCtrl = TextEditingController();

  bool _modoRegistro = false;
  bool _cargando = false;
  String? _error;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _correoCtrl.dispose();
    _claveCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    final resultado = _modoRegistro
        ? await _authService.registrar(
            _nombreCtrl.text.trim(),
            _correoCtrl.text.trim(),
            _claveCtrl.text.trim(),
          )
        : await _authService.iniciarSesion(
            _correoCtrl.text.trim(),
            _claveCtrl.text.trim(),
          );

    setState(() {
      _cargando = false;
      _error = resultado;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 64,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: Image.asset(
                          'assets/icon/app_icon.png',
                          width: 104,
                          height: 104,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        _modoRegistro
                            ? 'Tu nueva\nconexión.'
                            : 'Qué bueno\nverte de nuevo.',
                        style: theme.textTheme.headlineLarge,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _modoRegistro
                            ? 'Crea tu cuenta y empieza a conversar.'
                            : 'Inicia sesión para conectar con tus contactos.',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: const Color(0xFF99939F),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: const Color(0xFF302832)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              _modoRegistro ? 'Crear cuenta' : 'Iniciar sesión',
                              style: theme.textTheme.titleLarge,
                            ),
                            const SizedBox(height: 24),
                            if (_modoRegistro) ...[
                              TextField(
                                controller: _nombreCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Nombre completo',
                                  prefixIcon: Icon(
                                    Icons.person_outline_rounded,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                            TextField(
                              controller: _correoCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Correo',
                                prefixIcon: Icon(Icons.mail_outline_rounded),
                              ),
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _claveCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Contraseña',
                                prefixIcon: Icon(Icons.lock_outline_rounded),
                              ),
                              obscureText: true,
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 16),
                              Text(
                                _error!,
                                style: TextStyle(
                                  color: theme.colorScheme.error,
                                ),
                              ),
                            ],
                            const SizedBox(height: 24),
                            if (_cargando)
                              const Center(child: CircularProgressIndicator())
                            else ...[
                              ElevatedButton(
                                onPressed: _enviar,
                                child: Text(
                                  _modoRegistro ? 'Registrarme' : 'Ingresar',
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _modoRegistro = !_modoRegistro;
                                  });
                                },
                                child: Text(
                                  _modoRegistro
                                      ? '¿Ya tienes cuenta? Inicia sesión'
                                      : '¿No tienes cuenta? Regístrate',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
