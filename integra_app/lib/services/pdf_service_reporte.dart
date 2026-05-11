// ============================================================
// Integra Del Centro, S.C.
// Desarrollado por: HIRAM JAFET VELAZQUEZ SANTANDER
// services/pdf_service_reporte.dart
// Descripción: Genera el PDF oficial del Reporte de Previo
//   con Avería o Discrepancia siguiendo el formato de Integra
//   Del Centro S.C. Página 1: tabla de datos y hallazgos.
//   Páginas siguientes: una foto por página con banner de color
//   según tipo (Azul=Mercancía, Rojo=Avería, Naranja=Documento).
//   Las discrepancias (Cant.Factura ≠ Conteo) se resaltan en rojo.
// ============================================================

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/reporte.dart';

class PdfServiceReporte {
  // ── Colores corporativos ──────────────────────────────────
  static const _azul    = PdfColor.fromInt(0xFF003087);
  static const _rojo    = PdfColor.fromInt(0xFFB71C1C);
  static const _naranja = PdfColor.fromInt(0xFFE65100);
  static const _gris    = PdfColor.fromInt(0xFFE0E0E0);
  static const _rojoClaro = PdfColor.fromInt(0xFFFFEBEE);
  static const _azulClaro = PdfColor.fromInt(0xFFE8EDF5);

  /// Genera el PDF oficial y lanza el diálogo de compartir.
  static Future<void> generarYCompartir(
      ReportePrevio reporte, BuildContext context) async {
    try {
      final pdf = pw.Document(
        title: 'Reporte Previo — ${reporte.referencia}',
        author: 'HIRAM JAFET VELAZQUEZ SANTANDER',
        creator: 'Integra Del Centro S.C.',
      );

      // Clasificar fotos: documentos → averías → mercancía
      final docs = <Map<String, String>>[];
      final avs  = <Map<String, String>>[];
      final mercs = <Map<String, String>>[];

      for (int i = 0; i < reporte.fotos.length; i++) {
        if (!File(reporte.fotos[i]).existsSync()) continue;
        final tipo = i < reporte.fotosTipos.length
            ? reporte.fotosTipos[i]
            : 'Mercancia';
        final e = {'path': reporte.fotos[i], 'tipo': tipo};
        if (tipo == 'Averia') avs.add(e);
        else if (tipo == 'Mercancia') mercs.add(e);
        else docs.add(e);
      }
      final ordenadas = [...docs, ...avs, ...mercs];

      // ── Página 1: formato oficial ─────────────────────────
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.letter,
          margin: const pw.EdgeInsets.all(28),
          build: (ctx) => _buildPagina1(
              reporte, docs.length, avs.length, mercs.length),
        ),
      );

      // ── Páginas de fotos ──────────────────────────────────
      for (final foto in ordenadas) {
        final bytes = File(foto['path']!).readAsBytesSync();
        final tipo = foto['tipo']!;
        final color = _colorTipo(tipo);

        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.letter,
            margin: pw.EdgeInsets.zero,
            build: (_) => pw.Stack(children: [
              // Foto a página completa
              pw.Positioned.fill(
                child: pw.Image(
                  pw.MemoryImage(bytes),
                  fit: pw.BoxFit.cover,
                ),
              ),
              // Banner superior
              pw.Positioned(
                top: 0, left: 0, right: 0,
                child: pw.Container(
                  color: color,
                  padding: const pw.EdgeInsets.symmetric(
                      vertical: 8, horizontal: 18),
                  child: pw.Row(
                    mainAxisAlignment:
                        pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(tipo.toUpperCase(),
                          style: pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold)),
                      pw.Text(reporte.referencia,
                          style: const pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 10)),
                    ],
                  ),
                ),
              ),
              // Pie de página
              pw.Positioned(
                bottom: 0, left: 0, right: 0,
                child: pw.Container(
                  color: const PdfColor(0, 0, 0, 0.55),
                  padding: const pw.EdgeInsets.symmetric(
                      vertical: 4, horizontal: 18),
                  child: pw.Row(
                    mainAxisAlignment:
                        pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Integra Del Centro S.C.',
                          style: const pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 8)),
                      pw.Text(
                          'Dev: HIRAM JAFET VELAZQUEZ SANTANDER',
                          style: const pw.TextStyle(
                              color: const PdfColor(1, 1, 1, 0.7),
                              fontSize: 7)),
                    ],
                  ),
                ),
              ),
            ]),
          ),
        );
      }

      // ── Guardar y compartir ───────────────────────────────
      final dir = await getApplicationDocumentsDirectory();
      final ref = reporte.referencia
          .replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
      final file =
          File('${dir.path}/ReporteDisc_$ref.pdf');
      await file.writeAsBytes(await pdf.save());

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Reporte Previo/Discrepancia — ${reporte.referencia}\n'
            'Integra Del Centro S.C.\n'
            'Dev: HIRAM JAFET VELAZQUEZ SANTANDER',
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✓ PDF generado y listo para compartir'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al generar PDF: $e')));
      }
    }
  }

  // ── Página 1 — Formato oficial ────────────────────────────
  static pw.Widget _buildPagina1(ReportePrevio r,
      int numDocs, int numAvs, int numMercs) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Encabezado
        pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 8),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
                bottom: pw.BorderSide(color: _azul, width: 2)),
          ),
          child: pw.Row(
            mainAxisAlignment:
                pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('INTEGRA DEL CENTRO, S.C.',
                      style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: _azul)),
                  pw.Text('Despachos Aduanales',
                      style: const pw.TextStyle(
                          fontSize: 8,
                          color: PdfColors.grey700)),
                ],
              ),
              pw.Text(
                  'FECHA: ${ReportePrevio.formatFecha(r.fechaCreacion)}',
                  style: const pw.TextStyle(fontSize: 9)),
            ],
          ),
        ),

        pw.SizedBox(height: 6),

        pw.Center(
          child: pw.Text(
            'REPORTE PREVIO CON AVERÍA O DISCREPANCIA',
            style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                color: _azul),
          ),
        ),

        pw.SizedBox(height: 10),

        // Datos generales
        pw.Table(
          border: pw.TableBorder.all(color: _gris, width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(1.2),
            1: const pw.FlexColumnWidth(2),
            2: const pw.FlexColumnWidth(1.2),
            3: const pw.FlexColumnWidth(2),
          },
          children: [
            _fila4('Importador',    r.importador,
                   'Referencia',   r.referencia),
            _fila4('Proveedor',     r.proveedor,
                   'Guía BL/AWB',  r.guiaBLMaster),
            _fila4('Recinto Fiscal',r.recintoFiscal,
                   'Fecha Entrada',
                   ReportePrevio.formatFecha(r.fechaEntrada)),
            _fila4('Realiza Previo',r.realizaPrevio,
                   'Bultos / Peso',
                   '${r.bultos.isEmpty ? "—" : r.bultos}  /  '
                   '${r.pesoBruto.isEmpty ? "—" : "${r.pesoBruto} kg"}'),
          ],
        ),

        pw.SizedBox(height: 8),

        // Detalle del previo
        _subtitulo('Detalle del Previo'),
        pw.Table(
          border: pw.TableBorder.all(color: _gris, width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(1.1),
            1: const pw.FlexColumnWidth(1.4),
            2: const pw.FlexColumnWidth(1.1),
            3: const pw.FlexColumnWidth(1.4),
          },
          children: [
            _fila4('Solicitud',
                ReportePrevio.formatFecha(r.fechaSolicitud),
                'Inicio',
                ReportePrevio.formatFechaHora(r.fechaHoraInicio)),
            _fila4('Término',
                ReportePrevio.formatFechaHora(r.fechaHoraTermino),
                'Fotografías',
                '${r.fotos.length}  (Doc: $numDocs  Av: $numAvs  Merc: $numMercs)'),
          ],
        ),

        pw.SizedBox(height: 4),

        // Estado de la mercancía
        pw.Table(
          border: pw.TableBorder.all(color: _gris, width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(1.4),
            1: const pw.FlexColumnWidth(1),
            2: const pw.FlexColumnWidth(1),
            3: const pw.FlexColumnWidth(1),
            4: const pw.FlexColumnWidth(1),
          },
          children: [
            pw.TableRow(children: [
              _hdr('Estado Mercancía'),
              _hdr('¿Completa?'),
              _hdr('¿Faltantes?'),
              _hdr('¿Sobrantes?'),
              _hdr('Tipo Carga'),
            ]),
            pw.TableRow(children: [
              _cel(''),
              _celBool(r.estadoMercancia.completa),
              _celBool(r.estadoMercancia.faltantes),
              _celBool(r.estadoMercancia.sobrantes),
              _cel(r.estadoMercancia.cargaCompleta
                  ? 'Completa'
                  : 'Parcial'),
            ]),
          ],
        ),

        if (r.observacionesIncidencias.isNotEmpty) ...[
          pw.SizedBox(height: 4),
          pw.Container(
            padding: const pw.EdgeInsets.all(6),
            decoration:
                pw.BoxDecoration(border: pw.Border.all(color: _gris, width: 0.5)),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Observaciones: ',
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 8,
                        color: _azul)),
                pw.Expanded(
                  child: pw.Text(r.observacionesIncidencias,
                      style: const pw.TextStyle(fontSize: 8)),
                ),
              ],
            ),
          ),
        ],

        pw.SizedBox(height: 8),

        // Tabla de hallazgos
        _subtitulo('Observaciones y Hallazgos'),
        pw.Table(
          border: pw.TableBorder.all(color: _gris, width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(1.6), // No Factura
            1: const pw.FlexColumnWidth(1.2), // No Partida
            2: const pw.FlexColumnWidth(2.4), // No Parte
            3: const pw.FlexColumnWidth(1.2), // Cant Factura
            4: const pw.FlexColumnWidth(1.2), // Conteo
            5: const pw.FlexColumnWidth(1.4), // Marca
            6: const pw.FlexColumnWidth(1.4), // Modelo
          },
          children: [
            // Encabezado de tabla
            pw.TableRow(
              decoration:
                  const pw.BoxDecoration(color: _azul),
              children: [
                _thdr('No Factura'),
                _thdr('No Partida'),
                _thdr('No Parte'),
                _thdr('Cant. Factura'),
                _thdr('Conteo'),
                _thdr('Marca'),
                _thdr('Modelo'),
              ],
            ),
            // Filas de datos
            ...r.hallazgos.map((h) {
              final disc = h.tieneDiscrepancia;
              return pw.TableRow(
                decoration: disc
                    ? const pw.BoxDecoration(color: _rojoClaro)
                    : null,
                children: [
                  _cel(h.noFactura),
                  _cel(h.noPartida),
                  _cel(h.noParte),
                  _cel(h.cantidadFactura,
                      color: disc ? _rojo : null),
                  _cel(h.conteo,
                      bold: disc,
                      color: disc ? _rojo : null),
                  _cel(h.marca),
                  _cel(h.modelo),
                ],
              );
            }),
            // Fila de total
            pw.TableRow(
              decoration:
                  const pw.BoxDecoration(color: _azulClaro),
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text('Total Mercancías:',
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 8,
                          color: _azul)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text(r.totalMercancias,
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 8)),
                ),
                ...List.generate(
                    5,
                    (_) => pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(''))),
              ],
            ),
          ],
        ),

        pw.Spacer(),

        // Pie de página
        pw.Container(
          padding: const pw.EdgeInsets.only(top: 6),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
                top: pw.BorderSide(color: _azul, width: 0.8)),
          ),
          child: pw.Row(
            mainAxisAlignment:
                pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Integra Del Centro S.C.  |  Reportes Aduanales',
                style: const pw.TextStyle(
                    fontSize: 7, color: PdfColors.grey600),
              ),
              pw.Text(
                'Dev: HIRAM JAFET VELAZQUEZ SANTANDER',
                style: const pw.TextStyle(
                    fontSize: 6, color: PdfColors.grey500),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Helpers de construcción ───────────────────────────────

  static pw.TableRow _fila4(
      String l1, String v1, String l2, String v2) {
    return pw.TableRow(children: [
      _label(l1), _val(v1), _label(l2), _val(v2),
    ]);
  }

  static pw.Widget _label(String t) => pw.Padding(
        padding: const pw.EdgeInsets.all(4),
        child: pw.Text(t,
            style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 8,
                color: _azul)),
      );

  static pw.Widget _val(String t) => pw.Padding(
        padding: const pw.EdgeInsets.all(4),
        child: pw.Text(t.isNotEmpty ? t : '—',
            style: const pw.TextStyle(fontSize: 8)),
      );

  static pw.Widget _subtitulo(String t) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 3),
        child: pw.Text(t,
            style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 9,
                color: _azul)),
      );

  static pw.Widget _thdr(String t) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(
            vertical: 5, horizontal: 4),
        child: pw.Text(t,
            style: pw.TextStyle(
                color: PdfColors.white,
                fontSize: 7,
                fontWeight: pw.FontWeight.bold)),
      );

  static pw.Widget _hdr(String t) => pw.Padding(
        padding: const pw.EdgeInsets.all(4),
        child: pw.Text(t,
            style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 8,
                color: _azul)),
      );

  static pw.Widget _cel(String t,
      {bool bold = false, PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(3),
      child: pw.Text(
        t.isNotEmpty ? t : '—',
        style: pw.TextStyle(
          fontSize: 7,
          fontWeight:
              bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color,
        ),
      ),
    );
  }

  static pw.Widget _celBool(bool v) => pw.Padding(
        padding: const pw.EdgeInsets.all(4),
        child: pw.Text(
          v ? '✓ SÍ' : 'NO',
          style: pw.TextStyle(
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
            color: v ? PdfColors.green700 : PdfColors.grey600,
          ),
        ),
      );

  static PdfColor _colorTipo(String tipo) {
    if (tipo == 'Averia') return _rojo;
    if (tipo == 'Mercancia') return _azul;
    return _naranja;
  }
}
