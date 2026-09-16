// ============================================================
// Integra Del Centro, S.C.
// Desarrollado por: HIRAM JAFET VELAZQUEZ SANTANDER
// services/export_service.dart v2.1
// Descripción: Servicio de exportación de reportes al formato
//   .integra — un JSON que incluye todos los datos del reporte
//   más las fotos codificadas en base64. El archivo se puede
//   compartir por WhatsApp, correo, Bluetooth, etc. para
//   respaldarlo o transferirlo entre teléfonos.
//
// v2.1: se agregó importarReporteDesdeRuta() para recibir
//       archivos entrantes desde WhatsApp / correo / etc.
// ============================================================

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/reporte.dart';

class ExportService {
  static const String _formatVersion = '1.0';

  /// Exporta un ReportePrevio a un archivo .integra y lo comparte.
  static Future<void> exportarReporte(
      ReportePrevio reporte, BuildContext context) async {
    try {
      // ── 1. Codificar fotos en base64 ──────────────────────
      final fotosExport = <Map<String, String>>[];
      for (int i = 0; i < reporte.fotos.length; i++) {
        final path = reporte.fotos[i];
        final file = File(path);
        if (!file.existsSync()) continue;

        final bytes = await file.readAsBytes();
        final base64Data = base64Encode(bytes);
        final tipo = i < reporte.fotosTipos.length
            ? reporte.fotosTipos[i]
            : 'Mercancia';
        final ext = path.split('.').last.toLowerCase();

        fotosExport.add({
          'tipo': tipo,
          'base64': base64Data,
          'nombre': 'foto_${i}_$tipo.$ext',
          'mimeType': ext == 'png' ? 'image/png' : 'image/jpeg',
        });
      }

      // ── 2. Construir el JSON completo ─────────────────────
      final exportData = {
        'version': _formatVersion,
        'tipo': 'reporte',
        'exportado': DateTime.now().toIso8601String(),
        'exportadoPor': 'HIRAM JAFET VELAZQUEZ SANTANDER',
        'empresa': 'Integra Del Centro S.C.',
        'app': 'previo_aduanal v3.0',
        'reporte': reporte.toMap(),
        'fotos': fotosExport,
      };

      final jsonStr =
          const JsonEncoder.withIndent('  ').convert(exportData);

      // ── 3. Guardar como archivo .integra ──────────────────
      final dir = await getApplicationDocumentsDirectory();
      final refLimpia =
          reporte.referencia.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
      final fecha = DateTime.now();
      final fechaStr =
          '${fecha.year}${fecha.month.toString().padLeft(2, '0')}'
          '${fecha.day.toString().padLeft(2, '0')}';
      final filename = 'Reporte_${refLimpia}_$fechaStr.integra';
      final file = File('${dir.path}/$filename');
      await file.writeAsString(jsonStr, encoding: utf8);

      // ── 4. Compartir el archivo ───────────────────────────
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/json')],
        subject: 'Reporte Discrepancia — ${reporte.referencia}',
        text: 'Reporte de Discrepancia (.integra)\n'
            'Referencia: ${reporte.referencia}\n'
            'BL/AWB: ${reporte.guiaBLMaster}\n'
            'Importador: ${reporte.importador}\n'
            'Generado por: HIRAM JAFET VELAZQUEZ SANTANDER\n'
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
                  child: Text(
                    'Archivo "$filename" listo para compartir.',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green.shade700,
            duration: const Duration(seconds: 5),
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

  /// Importa un reporte desde una ruta ya conocida.
  /// Se usa al recibir un archivo entrante desde WhatsApp, correo, etc.
  /// Devuelve el id del reporte importado o null si hubo error.
  static Future<String?> importarReporteDesdeRuta(
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

      final contenido = await archivo.readAsString();
      final Map<String, dynamic> data = jsonDecode(contenido);

      // Acepta archivos con "tipo": "reporte" (nuevo) o sin "tipo"
      // pero con clave "reporte" (formato viejo).
      final esReporte = (data['tipo'] == 'reporte') ||
          (data['tipo'] == null && data['reporte'] != null);

      if (!esReporte || data['reporte'] == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('Este archivo .integra no corresponde a un Reporte.'),
            backgroundColor: Colors.red,
          ));
        }
        return null;
      }

      final reporteData = Map<String, dynamic>.from(data['reporte'] as Map);
      final fotosData = List.from(data['fotos'] ?? []);

      final dir = await getApplicationDocumentsDirectory();
      final fotosRutas = <String>[];
      final fotosTipos = <String>[];

      for (int i = 0; i < fotosData.length; i++) {
        final f = Map<String, dynamic>.from(fotosData[i] as Map);
        final b64 = f['base64'] as String?;
        if (b64 == null) continue;
        final bytes = base64Decode(b64);
        final ext = (f['nombre'] as String?)?.split('.').last ?? 'jpg';
        final path =
            '${dir.path}/import_rep_${DateTime.now().microsecondsSinceEpoch}_$i.$ext';
        await File(path).writeAsBytes(bytes);

        fotosRutas.add(path);
        fotosTipos.add((f['tipo'] ?? 'Mercancia').toString());
      }

      reporteData['fotos'] = fotosRutas;
      reporteData['fotosTipos'] = fotosTipos;
      reporteData['id'] = DateTime.now().millisecondsSinceEpoch.toString();
      reporteData['fechaCreacion'] = DateTime.now().toIso8601String();

      final box = Hive.box('reportes');
      await box.put(reporteData['id'] as String, reporteData);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Reporte "${reporteData['referencia'] ?? ''}" importado.'),
          backgroundColor: Colors.green.shade700,
          duration: const Duration(seconds: 4),
        ));
      }
      return reporteData['id'] as String;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error al importar reporte: $e'),
          backgroundColor: Colors.red,
        ));
      }
      return null;
    }
  }

  /// Calcula el tamaño estimado del archivo .integra antes de exportar.
  static Future<String> calcularTamanoEstimado(
      ReportePrevio reporte) async {
    int totalBytes = 0;
    for (final path in reporte.fotos) {
      final file = File(path);
      if (file.existsSync()) {
        totalBytes += (await file.length() * 1.33).round();
      }
    }
    totalBytes += 2048;

    if (totalBytes < 1024 * 1024) {
      return '${(totalBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}