// ============================================================
// Integra Del Centro, S.C.
// Desarrollado por: HIRAM JAFET VELAZQUEZ SANTANDER
// services/migration_service.dart
// Descripción: Servicio de migración de un previo entre dos
//   dispositivos. Genera un archivo .previomig con TODOS los
//   datos del previo (incluyendo fotos, ya recomprimidas a un
//   tamaño más ligero) para que otra persona lo reciba (WhatsApp,
//   Correo, Bluetooth...) y lo importe en su propia app, y ambos
//   puedan seguir trabajando bajo el mismo proyecto/previo.
//
//   El previo ya guarda los bytes de cada foto embebidos en el
//   campo 'fotosBytes' (ver nuevo_previo_screen.dart), así que no
//   dependemos de que existan los archivos físicos en el teléfono
//   origen — el .previomig es 100% autocontenido.
// ============================================================

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class MigrationService {
  // ── VERSIÓN DEL FORMATO DE MIGRACIÓN ─────────────────────
  static const String _formatVersion = '1.0';
  static const String _tipoArchivo = 'previo_migracion';

  /// Exporta un previo completo (datos + fotos comprimidas) a un
  /// archivo .previomig y abre el menú de compartir del sistema.
  static Future<void> exportarPrevio(Map previo, BuildContext context) async {
    try {
      final fotosBytesRaw = List<String>.from(previo['fotosBytes'] ?? []);
      final tipos = List<String>.from(previo['fotosTipos'] ?? []);
      final descs = List<String>.from(previo['fotosDescripciones'] ?? []);
      final bloques = List<String>.from(previo['fotosBloques'] ?? []);

      // ── 1. Recomprimir cada foto a una miniatura ligera ────
      final fotosExport = <Map<String, String>>[];
      for (int i = 0; i < fotosBytesRaw.length; i++) {
        if (fotosBytesRaw[i].isEmpty) continue;

        Uint8List original;
        try {
          original = Uint8List.fromList(fotosBytesRaw[i].codeUnits);
        } catch (_) {
          continue;
        }

        Uint8List liviana = original;
        try {
          final resultado = await FlutterImageCompress.compressWithList(
            original,
            minWidth: 1000,
            minHeight: 1000,
            quality: 55,
            format: CompressFormat.jpeg,
          );
          if (resultado.isNotEmpty) liviana = resultado;
        } catch (_) {
          // Si falla la recompresión, se exporta la foto original.
        }

        fotosExport.add({
          'tipo': i < tipos.length ? tipos[i] : 'Mercancia',
          'descripcion': i < descs.length ? descs[i] : '',
          'bloqueId': i < bloques.length ? bloques[i] : '',
          'base64': base64Encode(liviana),
        });
      }

      // ── 2. Datos del previo, sin las fotos originales pesadas ──
      final previoData = Map<String, dynamic>.from(previo);
      previoData.remove('fotosBytes');
      previoData.remove('fotos');

      // ── 3. Construir el JSON completo ──────────────────────
      final exportData = {
        'version': _formatVersion,
        'tipo': _tipoArchivo,
        'exportado': DateTime.now().toIso8601String(),
        'app': 'previo_aduanal',
        'previo': previoData,
        'fotos': fotosExport,
      };

      final jsonStr = jsonEncode(exportData);

      // ── 4. Guardar como archivo .previomig ─────────────────
      final dir = await getApplicationDocumentsDirectory();
      final refLimpia = (previo['referencia'] ?? 'previo')
          .toString()
          .replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
      final fecha = DateTime.now();
      final fechaStr = '${fecha.year}'
          '${fecha.month.toString().padLeft(2, '0')}'
          '${fecha.day.toString().padLeft(2, '0')}_'
          '${fecha.hour.toString().padLeft(2, '0')}'
          '${fecha.minute.toString().padLeft(2, '0')}';
      final filename = 'Previo_${refLimpia}_$fechaStr.previomig';
      final file = File('${dir.path}/$filename');
      await file.writeAsString(jsonStr, encoding: utf8);

      // ── 5. Compartir el archivo ─────────────────────────────
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/json')],
        subject: 'Migración de Previo — ${previo['referencia'] ?? ''}',
        text: 'Archivo para continuar este previo en otro dispositivo.\n'
            'Ábrelo desde el botón "Importar previo" en la app.\n'
            'Referencia: ${previo['referencia'] ?? ''}\n'
            'Integra Del Centro S.C.',
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Archivo "$filename" listo para compartir.'),
                ),
              ],
            ),
            backgroundColor: Colors.green.shade700,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al exportar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Lee un archivo .previomig y devuelve el Map listo para
  /// guardarse en el box 'previos' de Hive (ya reconstruido con
  /// fotosBytes, fotosTipos, fotosDescripciones y fotosBloques).
  static Future<Map<String, dynamic>> _leerArchivoMigracion(File file) async {
    final contenido = await file.readAsString(encoding: utf8);
    final data = jsonDecode(contenido) as Map<String, dynamic>;

    if (data['tipo'] != _tipoArchivo) {
      throw const FormatException(
          'Este archivo no es una migración de previo válida.');
    }

    final previoData = Map<String, dynamic>.from(data['previo'] as Map);
    final fotos = List<Map>.from(data['fotos'] ?? []);

    final rutas = <String>[];
    final fotosBytes = <String>[];
    final tipos = <String>[];
    final descs = <String>[];
    final bloques = <String>[];

    for (int i = 0; i < fotos.length; i++) {
      final f = fotos[i];
      final bytes = base64Decode(f['base64'] as String);
      rutas.add('migrado://foto_$i');
      fotosBytes.add(String.fromCharCodes(bytes));
      tipos.add((f['tipo'] as String?) ?? 'Mercancia');
      descs.add((f['descripcion'] as String?) ?? '');
      bloques.add((f['bloqueId'] as String?) ?? '');
    }

    previoData['fotos'] = rutas;
    previoData['fotosBytes'] = fotosBytes;
    previoData['fotosTipos'] = tipos;
    previoData['fotosDescripciones'] = descs;
    previoData['fotosBloques'] = bloques;

    return previoData;
  }

  /// Importa un archivo .previomig y lo guarda como un nuevo
  /// previo en el box local 'previos' de este dispositivo.
  /// Devuelve la referencia del previo importado (para mostrarla
  /// en un mensaje de confirmación).
  static Future<String> importarPrevio(File file) async {
    final previoData = await _leerArchivoMigracion(file);

    final box = Hive.box('previos');
    final nuevoId = DateTime.now().millisecondsSinceEpoch.toString();
    await box.put(nuevoId, previoData);

    return (previoData['referencia'] as String?) ?? 'Previo importado';
  }
}
