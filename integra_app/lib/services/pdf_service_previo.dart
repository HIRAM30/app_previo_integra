// ============================================================
// Integra Del Centro, S.C.
// Desarrollado por: HIRAM JAFET VELAZQUEZ SANTANDER
// services/pdf_service_previo.dart
// Descripción: Genera el PDF rápido del Previo Aduanal.
//   Es el mismo PDF que generaba la app original de previos —
//   una página de resumen + una foto por página con banner
//   de color. Se mantiene separado del PDF de discrepancias
//   para que cada módulo genere su propio documento.
// ============================================================

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

class PdfServicePrevio {
  static const _azul    = PdfColor.fromInt(0xFF003087);
  static const _rojo    = PdfColor.fromInt(0xFFB71C1C);
  static const _naranja = PdfColor.fromInt(0xFFE65100);
  static const _gris    = PdfColor.fromInt(0xFFE0E0E0);

  /// Genera el PDF del previo (formato original) y lo comparte.
  static Future<void> generarYCompartir(
      Map previo, BuildContext context) async {
    try {
      final pdf = pw.Document(
        title: 'Previo — ${previo['referencia'] ?? ''}',
        author: 'HIRAM JAFET VELAZQUEZ SANTANDER',
        creator: 'Integra Del Centro S.C.',
      );

      final fotos    = List<String>.from(previo['fotos'] ?? []);
      final tipos    = List<String>.from(previo['fotosTipos'] ?? []);

      // Clasificar y ordenar fotos
      final docs   = <Map<String, String>>[];
      final avs    = <Map<String, String>>[];
      final mercs  = <Map<String, String>>[];

      for (int i = 0; i < fotos.length; i++) {
        if (!File(fotos[i]).existsSync()) continue;
        final tipo = i < tipos.length ? tipos[i] : 'Mercancia';
        final e = {'path': fotos[i], 'tipo': tipo};
        if (tipo == 'Averia') avs.add(e);
        else if (tipo == 'Mercancia') mercs.add(e);
        else docs.add(e);
      }
      final ordenadas = [...docs, ...avs, ...mercs];

      // ── Página 1: resumen del previo ──────────────────────
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Encabezado
              pw.Container(
                padding: const pw.EdgeInsets.only(bottom: 10),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                      bottom: pw.BorderSide(color: _azul, width: 2)),
                ),
                child: pw.Row(
                  mainAxisAlignment:
                      pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('PREVIO ADUANAL',
                        style: pw.TextStyle(
                            fontSize: 20,
                            fontWeight: pw.FontWeight.bold,
                            color: _azul)),
                    pw.Text('Integra Del Centro, S.C.',
                        style: const pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.grey)),
                  ],
                ),
              ),
              pw.SizedBox(height: 18),
              pw.Table(
                border: pw.TableBorder.all(
                    color: _gris, width: 0.5),
                children: [
                  _row('Referencia',
                      previo['referencia'] ?? '', bold: true),
                  if ((previo['cliente'] ?? '').isNotEmpty)
                    _row('Cliente', previo['cliente']),
                  if ((previo['almacen'] ?? '').isNotEmpty)
                    _row('Almacén', previo['almacen']),
                  if ((previo['house'] ?? '').isNotEmpty)
                    _row('Term. House', previo['house']),
                  _row('Fecha',
                      previo['fecha']?.substring(0, 10) ?? ''),
                  if ((previo['observaciones'] ?? '').isNotEmpty)
                    _row('Observaciones',
                        previo['observaciones']),
                ],
              ),
              pw.SizedBox(height: 18),
              pw.Text('Resumen:',
                  style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: _azul)),
              pw.SizedBox(height: 6),
              if (docs.isNotEmpty)
                pw.Text('  Documentos: ${docs.length}',
                    style: const pw.TextStyle(fontSize: 10)),
              if (avs.isNotEmpty)
                pw.Text('  Averías: ${avs.length}',
                    style: const pw.TextStyle(fontSize: 10)),
              if (mercs.isNotEmpty)
                pw.Text('  Mercancía: ${mercs.length}',
                    style: const pw.TextStyle(fontSize: 10)),
              pw.Spacer(),
              pw.Container(
                padding: const pw.EdgeInsets.only(top: 6),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                      top:
                          pw.BorderSide(color: _azul, width: 0.8)),
                ),
                child: pw.Text(
                  'Integra Del Centro S.C.  |  Dev: HIRAM JAFET VELAZQUEZ SANTANDER',
                  style: const pw.TextStyle(
                      fontSize: 7, color: PdfColors.grey600),
                ),
              ),
            ],
          ),
        ),
      );

      // ── Páginas de fotos ──────────────────────────────────
      for (final foto in ordenadas) {
        final bytes = File(foto['path']!).readAsBytesSync();
        final tipo  = foto['tipo']!;
        final color = _colTipo(tipo);

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: pw.EdgeInsets.zero,
            build: (_) => pw.Stack(children: [
              pw.Positioned.fill(
                child: pw.Image(pw.MemoryImage(bytes),
                    fit: pw.BoxFit.cover),
              ),
              pw.Positioned(
                top: 0, left: 0, right: 0,
                child: pw.Container(
                  color: color,
                  padding: const pw.EdgeInsets.symmetric(
                      vertical: 6, horizontal: 16),
                  child: pw.Row(
                    mainAxisAlignment:
                        pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(tipo.toUpperCase(),
                          style: pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold)),
                      pw.Text(previo['referencia'] ?? '',
                          style: const pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 9)),
                    ],
                  ),
                ),
              ),
            ]),
          ),
        );
      }

      // Guardar y compartir
      final dir = await getApplicationDocumentsDirectory();
      final ref = (previo['referencia'] ?? 'Previo')
          .replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
      final file = File('${dir.path}/Previo_$ref.pdf');
      await file.writeAsBytes(await pdf.save());

      await Share.shareXFiles([XFile(file.path)],
          text: 'Previo Aduanal — ${previo['referencia']}\n'
              'Integra Del Centro S.C.');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✓ PDF del previo generado'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')));
      }
    }
  }

  static pw.TableRow _row(String label, String value,
      {bool bold = false}) {
    return pw.TableRow(children: [
      pw.Padding(
        padding: const pw.EdgeInsets.all(7),
        child: pw.Text(label,
            style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 10,
                color: _azul)),
      ),
      pw.Padding(
        padding: const pw.EdgeInsets.all(7),
        child: pw.Text(
          value.isNotEmpty ? value : '—',
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: bold
                ? pw.FontWeight.bold
                : pw.FontWeight.normal,
          ),
        ),
      ),
    ]);
  }

  static PdfColor _colTipo(String tipo) {
    if (tipo == 'Averia') return _rojo;
    if (tipo == 'Mercancia') return _azul;
    return _naranja;
  }
}
