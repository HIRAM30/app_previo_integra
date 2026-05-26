// ============================================================
// Integra Del Centro, S.C.
// Desarrollado por: HIRAM JAFET VELAZQUEZ SANTANDER
// services/pdf_service_previo.dart v3.4
// Correcciones:
//   - Fotos con BoxFit.contain: se ven COMPLETAS sin recortar
//   - Descripcion en banda separada DEBAJO de la foto,
//     fuera de la imagen, siempre legible
// ============================================================

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

class PdfServicePrevio {
  static const _azul   = PdfColor.fromInt(0xFF003087);
  static const _rojo   = PdfColor.fromInt(0xFFB71C1C);
  static const _naranja= PdfColor.fromInt(0xFFE65100);
  static const _negro  = PdfColor.fromInt(0xFF000000);
  static const _gris   = PdfColor.fromInt(0xFFE0E0E0);

  static Future<void> generarYCompartir(
      Map previo, BuildContext context) async {
    try {
      final pdf = pw.Document(
        title:  'Previo — ${previo['referencia'] ?? ''}',
        author: 'Integra Del Centro S.C.',
      );

      final fotos = List<String>.from(previo['fotos']              ?? []);
      final tipos = List<String>.from(previo['fotosTipos']         ?? []);
      final descs = List<String>.from(previo['fotosDescripciones'] ?? []);

      final validas = <Map<String, String>>[];
      for (int i = 0; i < fotos.length; i++) {
        if (!File(fotos[i]).existsSync()) continue;
        validas.add({
          'path': fotos[i],
          'tipo': i < tipos.length ? tipos[i] : 'Mercancia',
          'desc': i < descs.length ? descs[i] : '',
        });
      }

      // Pagina 1: resumen
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (_) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.only(bottom: 10),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                      bottom: pw.BorderSide(color: _azul, width: 2)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('PREVIO ADUANAL',
                        style: pw.TextStyle(fontSize: 20,
                            fontWeight: pw.FontWeight.bold,
                            color: _azul)),
                    pw.Text('Integra Del Centro, S.C.',
                        style: const pw.TextStyle(
                            fontSize: 10, color: PdfColors.grey)),
                  ],
                ),
              ),
              pw.SizedBox(height: 18),
              pw.Table(
                border: pw.TableBorder.all(color: _gris, width: 0.5),
                children: [
                  _row('Referencia / Master',
                      previo['referencia'] ?? '', bold: true),
                  if ((previo['cliente'] ?? '').isNotEmpty)
                    _row('Cliente', previo['cliente']),
                  if ((previo['almacen'] ?? '').isNotEmpty)
                    _row('Almacen', previo['almacen']),
                  if ((previo['house'] ?? '').isNotEmpty)
                    _row('House', previo['house']),
                  _row('Fecha', previo['fecha']?.substring(0, 10) ?? ''),
                  if ((previo['observaciones'] ?? '').isNotEmpty)
                    _row('Observaciones', previo['observaciones']),
                ],
              ),
              pw.SizedBox(height: 18),
              pw.Text('Fotografias (${validas.length}):',
                  style: pw.TextStyle(fontSize: 12,
                      fontWeight: pw.FontWeight.bold, color: _azul)),
              pw.SizedBox(height: 8),
              ...validas.asMap().entries.map((e) {
                final i    = e.key;
                final f    = e.value;
                final tipo = f['tipo']!;
                final desc = f['desc']!;
                final col  = _colorTipo(tipo);
                return pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 5),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.SizedBox(width: 22,
                          child: pw.Text('${i + 1}.',
                              style: const pw.TextStyle(
                                  fontSize: 9,
                                  color: PdfColors.grey700))),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: pw.BoxDecoration(
                          color: col.shade(0.8),
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: pw.Text(tipo,
                            style: pw.TextStyle(fontSize: 8,
                                fontWeight: pw.FontWeight.bold,
                                color: col)),
                      ),
                      pw.SizedBox(width: 8),
                      pw.Expanded(
                        child: pw.Text(
                          desc.isNotEmpty ? desc : '(sin descripcion)',
                          style: pw.TextStyle(fontSize: 9,
                              color: desc.isNotEmpty
                                  ? PdfColors.black
                                  : PdfColors.grey500),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              pw.Spacer(),
              pw.Container(
                padding: const pw.EdgeInsets.only(top: 6),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                      top: pw.BorderSide(color: _azul, width: 0.8)),
                ),
                child: pw.Text(
                  'Integra Del Centro S.C.  |  Despachos Aduanales',
                  style: const pw.TextStyle(
                      fontSize: 7, color: PdfColors.grey600),
                ),
              ),
            ],
          ),
        ),
      );

      // Paginas de fotos - layout en 3 bandas verticales:
      //
      //  BANDA 1: Banner tipo (color) — altura fija 28pt
      //  BANDA 2: Foto COMPLETA (contain + fondo negro)
      //  BANDA 3: Descripcion — FUERA de la foto, siempre visible
      //
      for (final f in validas) {
        final bytes      = File(f['path']!).readAsBytesSync();
        final tipo       = f['tipo']!;
        final desc       = f['desc']!;
        final color      = _colorTipo(tipo);
        final descHeight = desc.isNotEmpty ? 50.0 : 16.0;

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: pw.EdgeInsets.zero,
            build: (_) => pw.Column(
              children: [

                // BANDA 1: tipo + referencia
                pw.Container(
                  height: 28,
                  color: color,
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 16, vertical: 6),
                  child: pw.Row(
                    mainAxisAlignment:
                        pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(tipo.toUpperCase(),
                          style: pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold)),
                      pw.Text(previo['referencia'] ?? '',
                          style: const pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 9)),
                    ],
                  ),
                ),

                // BANDA 2: foto completa sin recortar
                // BoxFit.contain muestra la imagen entera.
                // El fondo negro cubre las areas vacias (letterbox).
                pw.Expanded(
                  child: pw.Container(
                    color: _negro,
                    child: pw.Center(
                      child: pw.Image(
                        pw.MemoryImage(bytes),
                        fit: pw.BoxFit.contain,
                      ),
                    ),
                  ),
                ),

                // BANDA 3: descripcion debajo de la foto
                // Siempre visible porque esta FUERA de la imagen.
                pw.Container(
                  height: descHeight,
                  width: double.infinity,
                  color: const PdfColor(0.08, 0.08, 0.08),
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  child: desc.isNotEmpty
                      ? pw.Row(
                          crossAxisAlignment:
                              pw.CrossAxisAlignment.center,
                          children: [
                            pw.Container(
                              width: 4,
                              height: 30,
                              decoration: pw.BoxDecoration(
                                color: color,
                                borderRadius:
                                    pw.BorderRadius.circular(2),
                              ),
                            ),
                            pw.SizedBox(width: 12),
                            pw.Expanded(
                              child: pw.Text(desc,
                                  style: const pw.TextStyle(
                                      color: PdfColors.white,
                                      fontSize: 12)),
                            ),
                          ],
                        )
                      : pw.SizedBox(),
                ),
              ],
            ),
          ),
        );
      }

      final dir  = await getApplicationDocumentsDirectory();
      final ref  = (previo['referencia'] ?? 'Previo')
          .replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
      final file = File('${dir.path}/Previo_$ref.pdf');
      await file.writeAsBytes(await pdf.save());

      await Share.shareXFiles([XFile(file.path)],
          text: 'Previo Aduanal — ${previo['referencia']}\n'
              'Integra Del Centro S.C.');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Previo generado correctamente'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
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
                fontSize: 10, color: _azul)),
      ),
      pw.Padding(
        padding: const pw.EdgeInsets.all(7),
        child: pw.Text(value.isNotEmpty ? value : '—',
            style: pw.TextStyle(fontSize: 10,
                fontWeight: bold
                    ? pw.FontWeight.bold
                    : pw.FontWeight.normal)),
      ),
    ]);
  }

  static PdfColor _colorTipo(String tipo) {
    if (tipo == 'Averia')    return _rojo;
    if (tipo == 'Mercancia') return _azul;
    return _naranja;
  }
}