// ============================================================
// Integra Del Centro, S.C.
// services/export_service_previo.dart v2.1
// Formato .integra v2.0 = ZIP con data.json + carpeta fotos/
// Retrocompatible: sigue leyendo .integra v1.0 (JSON+base64)
//
// v2.1: se agregó importarPrevioDesdeRuta() para recibir
//       archivos entrantes desde WhatsApp / correo / etc.
// ============================================================

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'usuario_service.dart';

class ExportServicePrevio {
  static const String _formatVersion = '2.0';

  // ═══════════════════════════════════════════════════════════
  // EXPORTAR
  // ═══════════════════════════════════════════════════════════

  static Future<void> exportarPrevio(Map previo, BuildContext context) async {
    try {
      final fotos = List<String>.from(previo['fotos'] ?? []);
      final tipos = List<String>.from(previo['fotosTipos'] ?? []);
      final descripciones =
          List<String>.from(previo['fotosDescripciones'] ?? []);
      final bloques = List<String>.from(previo['fotosBloques'] ?? []);

      final fotosMeta = <Map<String, dynamic>>[];
      for (int i = 0; i < fotos.length; i++) {
        final file = File(fotos[i]);
        if (!file.existsSync()) continue;
        final ext = fotos[i].split('.').last.toLowerCase();
        fotosMeta.add({
          'archivo': 'foto_${(i + 1).toString().padLeft(3, '0')}.$ext',
          'tipo': i < tipos.length ? tipos[i] : 'Mercancia',
          'descripcion': i < descripciones.length ? descripciones[i] : '',
          'bloqueId': i < bloques.length ? bloques[i] : '',
          'mimeType': ext == 'png' ? 'image/png' : 'image/jpeg',
        });
      }

      final dataJson = {
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
          'iniciadoPor': previo['iniciadoPor'] ??
              UsuarioService.obtenerNombre() ??
              'Desconocido',
          'aduana': previo['aduana'],
          'patente': previo['patente'],
          'tipoOperacion': previo['tipoOperacion'],
          'contenedor': previo['contenedor'],
          'sello': previo['sello'],
          'verificador': previo['verificador'],
        },
        'fotos': fotosMeta,
      };

      final archive = Archive();
      final jsonBytes =
          utf8.encode(const JsonEncoder.withIndent('  ').convert(dataJson));
      archive.addFile(ArchiveFile('data.json', jsonBytes.length, jsonBytes));

      for (int i = 0; i < fotos.length; i++) {
        final file = File(fotos[i]);
        if (!file.existsSync()) continue;
        final ext = fotos[i].split('.').last.toLowerCase();
        final nombreInterno =
            'fotos/foto_${(i + 1).toString().padLeft(3, '0')}.$ext';
        final bytes = await file.readAsBytes();
        archive.addFile(ArchiveFile(nombreInterno, bytes.length, bytes));
      }

      final zipBytes = ZipEncoder().encode(archive);
      if (zipBytes == null) throw Exception('No se pudo crear el ZIP');

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
      final filename = 'Previo_${refLimpia}_$fechaStr.integra';
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(zipBytes);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/zip')],
        subject: 'Previo — ${previo['referencia'] ?? ''}',
        text: 'Previo para continuar en otro teléfono\n'
            'Referencia: ${previo['referencia'] ?? ''}\n'
            'Cliente: ${previo['cliente'] ?? ''}\n'
            'Iniciado por: ${previo['iniciadoPor'] ?? UsuarioService.obtenerNombre() ?? ''}\n'
            'Integra Del Centro S.C.',
      );

      if (context.mounted) {
        final mb = (zipBytes.length / (1024 * 1024)).toStringAsFixed(2);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Archivo "$filename" listo ($mb MB).'),
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

  // ═══════════════════════════════════════════════════════════
  // IMPORTAR (autodetecta v2.0 ZIP o v1.0 JSON+base64)
  // ═══════════════════════════════════════════════════════════

  /// Abre el selector de archivos y permite importar un .integra.
  static Future<String?> importarPrevio(BuildContext context) async {
    try {
      final resultado = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: false,
      );
      if (resultado == null || resultado.files.single.path == null) return null;

      return await importarPrevioDesdeRuta(
          resultado.files.single.path!, context);
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

  /// Importa un previo desde una ruta ya conocida.
  /// Se usa tanto al elegir un archivo con el picker como al recibir
  /// un archivo entrante desde WhatsApp, correo, Bluetooth, etc.
  static Future<String?> importarPrevioDesdeRuta(
      String path, BuildContext context) async {
    try {
      final archivo = File(path);
      if (!archivo.existsSync()) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('El archivo no existe o no es accesible.'),
            backgroundColor: Colors.red,
          ));
        }
        return null;
      }

      final bytes = await archivo.readAsBytes();
      final esZip =
          bytes.length >= 4 && bytes[0] == 0x50 && bytes[1] == 0x4B;

      if (esZip) {
        return await _importarV2(bytes, context);
      } else {
        return await _importarV1(utf8.decode(bytes), context);
      }
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

  // ── v2.0 (ZIP) ─────────────────────────────────────────────
  static Future<String?> _importarV2(
      Uint8List zipBytes, BuildContext context) async {
    final archive = ZipDecoder().decodeBytes(zipBytes);

    ArchiveFile? dataFile;
    for (final f in archive.files) {
      if (f.name == 'data.json') {
        dataFile = f;
        break;
      }
    }
    if (dataFile == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Archivo .integra inválido (falta data.json).'),
          backgroundColor: Colors.red,
        ));
      }
      return null;
    }

    final data = jsonDecode(utf8.decode(dataFile.content as List<int>));
    final previoData = Map<String, dynamic>.from(data['previo'] as Map);
    final fotosMeta = List.from(data['fotos'] ?? []);

    final dir = await getApplicationDocumentsDirectory();
    final fotosRutas = <String>[];
    final fotosTipos = <String>[];
    final fotosDescripciones = <String>[];
    final fotosBloques = <String>[];

    for (int i = 0; i < fotosMeta.length; i++) {
      final meta = Map<String, dynamic>.from(fotosMeta[i] as Map);
      final nombreInterno = 'fotos/${meta['archivo']}';
      ArchiveFile? entry;
      for (final f in archive.files) {
        if (f.name == nombreInterno) {
          entry = f;
          break;
        }
      }
      if (entry == null || entry.content == null) continue;

      final ext = (meta['archivo'] as String).split('.').last;
      final path =
          '${dir.path}/import_${DateTime.now().microsecondsSinceEpoch}_$i.$ext';
      await File(path).writeAsBytes(entry.content as List<int>);

      fotosRutas.add(path);
      fotosTipos.add((meta['tipo'] ?? 'Mercancia').toString());
      fotosDescripciones.add((meta['descripcion'] ?? '').toString());
      fotosBloques.add((meta['bloqueId'] ?? '').toString());
    }

    return _guardarPrevioImportado(
      previoData: previoData,
      fotosRutas: fotosRutas,
      fotosTipos: fotosTipos,
      fotosDescripciones: fotosDescripciones,
      fotosBloques: fotosBloques,
      context: context,
    );
  }

  // ── v1.0 (JSON + base64) ───────────────────────────────────
  static Future<String?> _importarV1(
      String contenido, BuildContext context) async {
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

    final dir = await getApplicationDocumentsDirectory();
    final fotosRutas = <String>[];
    final fotosTipos = <String>[];
    final fotosDescripciones = <String>[];
    final fotosBloques = <String>[];

    for (int i = 0; i < fotosData.length; i++) {
      final f = Map<String, dynamic>.from(fotosData[i] as Map);
      final b64 = f['base64'] as String?;
      if (b64 == null) continue;
      final bytes = base64Decode(b64);
      final ext = (f['ext'] ?? 'jpg').toString();
      final path =
          '${dir.path}/import_${DateTime.now().microsecondsSinceEpoch}_$i.$ext';
      await File(path).writeAsBytes(bytes);

      fotosRutas.add(path);
      fotosTipos.add((f['tipo'] ?? 'Mercancia').toString());
      fotosDescripciones.add((f['descripcion'] ?? '').toString());
      fotosBloques.add((f['bloqueId'] ?? '').toString());
    }

    return _guardarPrevioImportado(
      previoData: previoData,
      fotosRutas: fotosRutas,
      fotosTipos: fotosTipos,
      fotosDescripciones: fotosDescripciones,
      fotosBloques: fotosBloques,
      context: context,
    );
  }

  // ── Guardado común ─────────────────────────────────────────
  static Future<String?> _guardarPrevioImportado({
    required Map<String, dynamic> previoData,
    required List<String> fotosRutas,
    required List<String> fotosTipos,
    required List<String> fotosDescripciones,
    required List<String> fotosBloques,
    required BuildContext context,
  }) async {
    final secciones = List.from(previoData['secciones'] ?? []);
    final partidas =
        List.from(previoData['partidas'] ?? previoData['particiones'] ?? []);

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
      'fotosTipos': fotosTipos,
      'fotosDescripciones': fotosDescripciones,
      'fotosBloques': fotosBloques,
      'bloques': todosLosBloques,
      'secciones': secciones,
      'partidas': partidas,
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
  }
}