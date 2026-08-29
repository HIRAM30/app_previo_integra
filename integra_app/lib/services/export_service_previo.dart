// ============================================================
// Integra Del Centro, S.C.
// Desarrollado por: HIRAM JAFET VELAZQUEZ SANTANDER
// services/export_service_previo.dart
// Descripcion: Exporta un Previo (en progreso o terminado) a un
// archivo .integra (JSON con fotos en base64) que se puede enviar
// por WhatsApp, correo, Bluetooth, etc. a otro telefono para
// continuar el mismo Previo, o importarlo de vuelta en esta app.
// ============================================================

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'usuario_service.dart';

class ExportServicePrevio {
  static const String _formatVersion = '1.0';

  /// Exporta un Previo a un archivo .integra y lo comparte con otras apps
  /// (WhatsApp, correo, Bluetooth, etc.) para continuarlo en otro telefono.
  static Future<void> exportarPrevio(Map previo, BuildContext context) async {
    try {
      final fotos = List<String>.from(previo['fotos'] ?? []);
      final tipos = List<String>.from(previo['fotosTipos'] ?? []);
      final descripciones = List<String>.from(previo['fotosDescripciones'] ?? []);
      final bloques = List<String>.from(previo['fotosBloques'] ?? []);

      // ── 1. Codificar fotos en base64 ──────────────────────
      final fotosExport = <Map<String, String>>[];
      for (int i = 0; i < fotos.length; i++) {
        final file = File(fotos[i]);
        if (!file.existsSync()) continue;
        final bytes = await file.readAsBytes();
        final ext = fotos[i].split('.').last.toLowerCase();
        fotosExport.add({
          'base64': base64Encode(bytes),
          'tipo': i < tipos.length ? tipos[i] : 'Mercancia',
          'descripcion': i < descripciones.length ? descripciones[i] : '',
          'bloqueId': i < bloques.length ? bloques[i] : '',
          'mimeType': ext == 'png' ? 'image/png' : 'image/jpeg',
          'ext': ext.isEmpty ? 'jpg' : ext,
        });
      }

      // ── 2. Construir el JSON completo ─────────────────────
      final exportData = {
        'version': _formatVersion,
        'tipo': 'previo',
        'exportado': DateTime.now().toIso8601String(),
        'exportadoPor': UsuarioService.obtenerNombre() ?? 'Desconocido',
        'empresa': 'Integra Del Centro S.C.',
        'app': 'previo_aduanal',
        'previo': {
          'idOriginal': previo['id'],
          'referencia': previo['referencia'],
          'cliente': previo['cliente'],
          'almacen': previo['almacen'],
          'house': previo['house'],
          'fecha': previo['fecha'],
          'observaciones': previo['observaciones'],
          'tipoBulto': previo['tipoBulto'],
          'tiposBulto': previo['tiposBulto'],
          'vieneConFactura': previo['vieneConFactura'],
          'secciones': previo['secciones'],
          'partidas': previo['partidas'] ?? previo['particiones'],
          'iniciadoPor': previo['iniciadoPor'] ?? UsuarioService.obtenerNombre() ?? 'Desconocido',
          'aduana': previo['aduana'],
          'patente': previo['patente'],
          'tipoOperacion': previo['tipoOperacion'],
          'contenedor': previo['contenedor'],
          'sello': previo['sello'],
          'verificador': previo['verificador'],
        },
        'fotos': fotosExport,
      };

      final jsonStr = const JsonEncoder.withIndent('  ').convert(exportData);

      // ── 3. Guardar como archivo .integra ──────────────────
      final dir = await getApplicationDocumentsDirectory();
      final refLimpia = (previo['referencia'] ?? 'previo')
          .toString()
          .replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
      final fecha = DateTime.now();
      final fechaStr = '${fecha.year}${fecha.month.toString().padLeft(2, '0')}'
          '${fecha.day.toString().padLeft(2, '0')}_${fecha.hour.toString().padLeft(2, '0')}'
          '${fecha.minute.toString().padLeft(2, '0')}';
      final filename = 'Previo_${refLimpia}_$fechaStr.integra';
      final file = File('${dir.path}/$filename');
      await file.writeAsString(jsonStr, encoding: utf8);

      // ── 4. Compartir el archivo ───────────────────────────
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/json')],
        subject: 'Previo — ${previo['referencia'] ?? ''}',
        text: 'Previo para continuar en otro telefono\n'
            'Referencia: ${previo['referencia'] ?? ''}\n'
            'Cliente: ${previo['cliente'] ?? ''}\n'
            'Iniciado por: ${previo['iniciadoPor'] ?? UsuarioService.obtenerNombre() ?? ''}\n'
            'Integra Del Centro S.C.',
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Archivo "$filename" listo para compartir.'),
          backgroundColor: Colors.green.shade700,
          duration: const Duration(seconds: 4),
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error al exportar: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  /// Deja al usuario elegir un archivo .integra (recibido por WhatsApp,
  /// correo, etc.) y lo importa como un nuevo Previo local, listo para
  /// continuar la captura donde se quedo la otra persona/telefono.
  ///
  /// Devuelve el id (boxKey) del previo importado, o null si se cancelo
  /// o hubo un error (ya notificado al usuario via SnackBar).
  static Future<String?> importarPrevio(BuildContext context) async {
    try {
      final resultado = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: false,
      );
      if (resultado == null || resultado.files.single.path == null) return null;

      final archivo = File(resultado.files.single.path!);
      final contenido = await archivo.readAsString();
      final Map<String, dynamic> data = jsonDecode(contenido);

      if ((data['tipo'] ?? 'previo') != 'previo' || data['previo'] == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Este archivo .integra no corresponde a un Previo.'),
            backgroundColor: Colors.red,
          ));
        }
        return null;
      }

      final previoData = Map<String, dynamic>.from(data['previo'] as Map);
      final fotosData = List.from(data['fotos'] ?? []);

      // ── Reconstruir las fotos en disco a partir del base64 ─
      final dir = await getApplicationDocumentsDirectory();
      final fotosRutas = <String>[];
      final fotosBytesStr = <String>[];
      final fotosTipos = <String>[];
      final fotosDescripciones = <String>[];
      final fotosBloques = <String>[];

      for (int i = 0; i < fotosData.length; i++) {
        final f = Map<String, dynamic>.from(fotosData[i] as Map);
        final b64 = f['base64'] as String?;
        if (b64 == null) continue;
        final bytes = base64Decode(b64);
        final ext = (f['ext'] ?? 'jpg').toString();
        final path = '${dir.path}/import_${DateTime.now().microsecondsSinceEpoch}_$i.$ext';
        final nuevoArchivo = File(path);
        await nuevoArchivo.writeAsBytes(bytes);

        fotosRutas.add(path);
        fotosBytesStr.add(String.fromCharCodes(bytes));
        fotosTipos.add((f['tipo'] ?? 'Mercancia').toString());
        fotosDescripciones.add((f['descripcion'] ?? '').toString());
        fotosBloques.add((f['bloqueId'] ?? '').toString());
      }

      final secciones = List.from(previoData['secciones'] ?? []);
      final partidas = List.from(previoData['partidas'] ?? []);
      final todosLosBloques = <Map<String, String>>[];
      for (final raw in secciones) {
        final s = Map<String, dynamic>.from(raw as Map);
        todosLosBloques.add({
          'id': (s['id'] ?? '').toString(),
          'nombre': (s['nombre'] ?? '').toString(),
          'informacion': (s['informacion'] ?? '').toString(),
        });
      }
      for (int i = 0; i < partidas.length; i++) {
        final p = Map<String, dynamic>.from(partidas[i] as Map);
        todosLosBloques.add({
          'id': (p['id'] ?? '').toString(),
          'nombre': 'Partida ${i + 1}: ${(p['nombre'] ?? '').toString()}',
          'informacion': (p['informacion'] ?? '').toString(),
        });
      }

      final nuevoId = DateTime.now().millisecondsSinceEpoch.toString();
      final nuevoPrevio = {
        'id': nuevoId,
        'idImportadoDe': previoData['idOriginal'],
        'referencia': previoData['referencia'] ?? '',
        'cliente': previoData['cliente'] ?? '',
        'almacen': previoData['almacen'] ?? '',
        'house': previoData['house'] ?? '',
        'fecha': previoData['fecha'] ?? DateTime.now().toIso8601String(),
        'observaciones': previoData['observaciones'] ?? '',
        'tipoBulto': previoData['tipoBulto'] ?? '',
        'tiposBulto': previoData['tiposBulto'] ?? [],
        'vieneConFactura': previoData['vieneConFactura'],
        'aduana': previoData['aduana'] ?? '',
        'patente': previoData['patente'] ?? '',
        'tipoOperacion': previoData['tipoOperacion'] ?? '',
        'contenedor': previoData['contenedor'] ?? '',
        'sello': previoData['sello'] ?? '',
        'verificador': previoData['verificador'] ?? '',
        'iniciadoPor': previoData['iniciadoPor'] ?? 'Desconocido',
        'fotos': fotosRutas,
        'fotosBytes': fotosBytesStr,
        'fotosTipos': fotosTipos,
        'fotosDescripciones': fotosDescripciones,
        'fotosBloques': fotosBloques,
        'bloques': todosLosBloques,
        'secciones': secciones,
        'partidas': partidas,
        'particiones': partidas,
      };

      final box = Hive.box('previos');
      await box.put(nuevoId, nuevoPrevio);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Previo "${nuevoPrevio['referencia']}" importado '
              '(iniciado por ${nuevoPrevio['iniciadoPor']}).'),
          backgroundColor: Colors.green.shade700,
          duration: const Duration(seconds: 4),
        ));
      }
      return nuevoId;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error al importar: $e'),
          backgroundColor: Colors.red,
        ));
      }
      return null;
    }
  }
}
