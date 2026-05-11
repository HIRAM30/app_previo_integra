// ============================================================
// Integra Del Centro, S.C.
// Desarrollado por: HIRAM JAFET VELAZQUEZ SANTANDER
// services/export_service.dart
// Descripción: Servicio de exportación de reportes al formato
//   .integra — un JSON que incluye todos los datos del reporte
//   más las fotos codificadas en base64. Este archivo se abre
//   en la Web App de oficina para completar y generar el PDF
//   oficial. Diseño preparado para Fase 2 (servidor): solo se
//   cambia exportarReporte() para hacer un POST en vez de
//   generar el archivo local.
// ============================================================

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/reporte.dart';

class ExportService {
  // ── VERSIÓN DEL FORMATO DE EXPORTACIÓN ───────────────────
  // Si en el futuro cambia la estructura del JSON, incrementar
  // esta versión para que la web app pueda manejar compatibilidad.
  static const String _formatVersion = '1.0';

  /// Exporta un ReportePrevio a un archivo .integra y lo comparte.
  ///
  /// El archivo .integra es un JSON con estructura:
  /// {
  ///   "version": "1.0",
  ///   "exportado": "2025-...",
  ///   "exportadoPor": "HIRAM JAFET VELAZQUEZ SANTANDER",
  ///   "empresa": "Integra Del Centro S.C.",
  ///   "reporte": { ...todos los campos del reporte... },
  ///   "fotos": [
  ///     { "tipo": "Averia", "base64": "...", "nombre": "foto_0.jpg" },
  ///     ...
  ///   ]
  /// }
  ///
  /// FASE 2: Reemplazar el contenido de este método con:
  ///   await http.post(Uri.parse('$servidorUrl/api/reportes'), body: json)
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
        'exportado': DateTime.now().toIso8601String(),
        'exportadoPor': 'HIRAM JAFET VELAZQUEZ SANTANDER',
        'empresa': 'Integra Del Centro S.C.',
        'app': 'previo_aduanal v3.0',
        'reporte': reporte.toMap(),
        'fotos': fotosExport,
      };

      final jsonStr = const JsonEncoder.withIndent('  ')
          .convert(exportData);

      // ── 3. Guardar como archivo .integra ──────────────────
      final dir = await getApplicationDocumentsDirectory();
      final refLimpia = reporte.referencia
          .replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
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
        text: 'Reporte para Web App de oficina\n'
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
                    'Archivo "$filename" listo. '
                    'Ábrelo en la Web App de oficina.',
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

  /// Calcula el tamaño estimado del archivo .integra antes de exportar.
  /// Útil para mostrar al usuario cuánto espacio ocupará.
  static Future<String> calcularTamanoEstimado(
      ReportePrevio reporte) async {
    int totalBytes = 0;
    for (final path in reporte.fotos) {
      final file = File(path);
      if (file.existsSync()) {
        // Base64 aumenta el tamaño ~33%
        totalBytes += (await file.length() * 1.33).round();
      }
    }
    // JSON base ~2KB
    totalBytes += 2048;

    if (totalBytes < 1024 * 1024) {
      return '${(totalBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
