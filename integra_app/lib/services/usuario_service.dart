// ============================================================
// Integra Del Centro, S.C.
// Desarrollado por: HIRAM JAFET VELAZQUEZ SANTANDER
// services/usuario_service.dart v2.0
// Cambios:
//   - Verifica que la box 'config' esté abierta antes de usarla
//   - Fallback seguro si algo falla
// ============================================================

import 'package:hive_flutter/hive_flutter.dart';

class UsuarioService {
  static const String _boxName = 'config';
  static const String _key = 'nombreUsuario';

  static Box? get _boxOrNull =>
      Hive.isBoxOpen(_boxName) ? Hive.box(_boxName) : null;

  static String? obtenerNombre() {
    final box = _boxOrNull;
    if (box == null) return null;
    final v = box.get(_key);
    if (v == null) return null;
    final nombre = v.toString().trim();
    return nombre.isEmpty ? null : nombre;
  }

  static bool get tieneNombre => obtenerNombre() != null;

  static Future<void> guardarNombre(String nombre) async {
    final box = _boxOrNull ?? await Hive.openBox(_boxName);
    await box.put(_key, nombre.trim());
  }
}