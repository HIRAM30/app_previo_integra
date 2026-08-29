// ============================================================
// Integra Del Centro, S.C.
// Desarrollado por: HIRAM JAFET VELAZQUEZ SANTANDER
// screens/nombre_usuario_screen.dart
// Descripcion: Pantalla que se muestra una sola vez, al primer
// inicio de la app en el dispositivo, para capturar el nombre de
// la persona que va a realizar los Previos. Ese nombre se guarda
// localmente y se usa despues para identificar quien inicio cada
// Previo (util al compartir/exportar un .integra a otro telefono).
// ============================================================

import 'package:flutter/material.dart';
import '../services/usuario_service.dart';
import 'home_screen.dart';

class NombreUsuarioScreen extends StatefulWidget {
  const NombreUsuarioScreen({super.key});

  @override
  State<NombreUsuarioScreen> createState() => _NombreUsuarioScreenState();
}

class _NombreUsuarioScreenState extends State<NombreUsuarioScreen> {
  final _nombreCtrl = TextEditingController();
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    super.dispose();
  }

  Future<void> _continuar() async {
    final nombre = _nombreCtrl.text.trim();
    if (nombre.length < 3) {
      setState(() => _error = 'Ingresa tu nombre completo');
      return;
    }
    setState(() { _guardando = true; _error = null; });
    await UsuarioService.guardarNombre(nombre);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: const Color(0xFF003087),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.badge_outlined, color: Colors.white, size: 44),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    '¿Cual es tu nombre?',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF003087)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Se usara para identificar quien inicio cada Previo en este '
                    'telefono. Solo se pide una vez.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _nombreCtrl,
                    textCapitalization: TextCapitalization.words,
                    autofocus: true,
                    onSubmitted: (_) => _continuar(),
                    decoration: InputDecoration(
                      labelText: 'Nombre completo',
                      hintText: 'Ej. Juan Perez',
                      errorText: _error,
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _guardando ? null : _continuar,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52),
                      backgroundColor: const Color(0xFF003087),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _guardando
                        ? const SizedBox(
                            width: 22, height: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                        : const Text('Continuar', style: TextStyle(fontSize: 16, color: Colors.white)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
