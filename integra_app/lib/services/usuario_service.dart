// ============================================================
// Integra Del Centro, S.C.
// Desarrollado por: HIRAM JAFET VELAZQUEZ SANTANDER
// services/usuario_service.dart
// Descripcion: Maneja el nombre de la persona que usa la app en
// este dispositivo (se pide una sola vez, al primer inicio) y lo
// expone para usarse al guardar Previos y al exportar .integra.
// ============================================================

import 'package:hive_flutter/hive_flutter.dart';

class UsuarioService {
  static const String _boxName = 'config';
  static const String _key = 'nombreUsuario';

  static Box get _box => Hive.box(_boxName);

  /// Devuelve el nombre guardado, o null si aun no se ha capturado.
  static String? obtenerNombre() {
    final v = _box.get(_key);
    if (v == null) return null;
    final nombre = v.toString().trim();
    return nombre.isEmpty ? null : nombre;
  }

  static bool get tieneNombre => obtenerNombre() != null;

  static Future<void> guardarNombre(String nombre) async {
    await _box.put(_key, nombre.trim());
  }
}
