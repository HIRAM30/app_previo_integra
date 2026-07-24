// ============================================================
// Integra Del Centro, S.C.
// Desarrollado por: HIRAM JAFET VELAZQUEZ SANTANDER
// services/pdf_service_previo.dart v4.1
// Diseño: 2 fotos por hoja, índice completo, PARTIDAS visibles
// ============================================================

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

class PdfServicePrevio {
  static final _azul = PdfColor.fromInt(0xFF003087);
  static final _rojo = PdfColor.fromInt(0xFFB71C1C);
  static final _naranja = PdfColor.fromInt(0xFFE65100);
  static final _gris = PdfColor.fromInt(0xFFE0E0E0);

  static Future<void> generarYCompartir(Map previo, BuildContext context) async {
    try {
      final pdf = pw.Document(
        title: 'Previo - ${previo['referencia'] ?? ''}',
        author: 'Integra Del Centro S.C.',
      );

      final fotosPaths = List<String>.from(previo['fotos'] ?? []);
      final fotosBytesList = List<String>.from(previo['fotosBytes'] ?? []);
      final tipos = List<String>.from(previo['fotosTipos'] ?? []);
      final descs = List<String>.from(previo['fotosDescripciones'] ?? []);
      final fotoBloques = List<String>.from(previo['fotosBloques'] ?? []);
      final bloques = List<Map>.from(previo['bloques'] ?? []);

      final bloquesPorId = <String, Map>{};
      for (final bloque in bloques) {
        bloquesPorId[(bloque['id'] ?? '').toString()] = bloque;
      }
      final ordenBloque = <String, int>{};
      for (var i = 0; i < bloques.length; i++) {
        ordenBloque[(bloques[i]['id'] ?? '').toString()] = i;
      }

      final validas = <Map<String, dynamic>>[];
      for (var i = 0; i < fotosPaths.length; i++) {
        Uint8List? bytes;

        if (i < fotosBytesList.length && fotosBytesList[i].isNotEmpty) {
          try {
            bytes = Uint8List.fromList(fotosBytesList[i].codeUnits);
          } catch (_) {}
        }

        if (bytes == null && i < fotosPaths.length) {
          final file = File(fotosPaths[i]);
          if (file.existsSync()) {
            try {
              bytes = file.readAsBytesSync();
            } catch (_) {}
          }
        }

        if (bytes != null && bytes.isNotEmpty) {
          final bloqueId = i < fotoBloques.length ? fotoBloques[i] : '';
          validas.add({
            'bytes': bytes,
            'tipo': i < tipos.length ? tipos[i] : 'Mercancia',
            'desc': i < descs.length ? descs[i] : '',
            'bloqueId': bloqueId,
            'bloque': bloquesPorId[bloqueId],
            'ordenOriginal': i,
          });
        }
      }

      if (validas.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No hay fotos para generar el PDF'), backgroundColor: Colors.red),
          );
        }
        return;
      }

      validas.sort((a, b) {
        final ordenA = ordenBloque[a['bloqueId']] ?? 999999;
        final ordenB = ordenBloque[b['bloqueId']] ?? 999999;
        if (ordenA != ordenB) return ordenA.compareTo(ordenB);
        return (a['ordenOriginal'] as int).compareTo(b['ordenOriginal'] as int);
      });

      // ═══════════ PÁGINA 1: PORTADA + ÍNDICE POR PARTIDAS ═══════════
      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(32),
        header: (_) => pw.Container(
          padding: pw.EdgeInsets.only(bottom: 8),
          decoration: pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: _azul, width: 2)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('PREVIO ADUANAL',
                  style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: _azul)),
              pw.Text('Integra Del Centro, S.C.',
                  style: pw.TextStyle(fontSize: 9, color: PdfColors.grey)),
            ],
          ),
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text('Pagina ${context.pageNumber} de ${context.pagesCount}',
              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
        ),
        build: (_) => [
          pw.SizedBox(height: 14),
          pw.Table(
            border: pw.TableBorder.all(color: _gris, width: 0.5),
            children: [
              _row('Referencia / Master', previo['referencia'] ?? '', bold: true),
              if ((previo['cliente'] ?? '').isNotEmpty)
                _row('Cliente', previo['cliente']),
              if ((previo['almacen'] ?? '').isNotEmpty)
                _row('Almacen', previo['almacen']),
              if ((previo['house'] ?? '').isNotEmpty)
                _row('House', previo['house']),
              _row('Fecha', '${previo['fecha'] ?? ''}'.split('T').first),
              if ((previo['aduana'] ?? '').toString().isNotEmpty)
                _row('Aduana', previo['aduana'].toString()),
              if ((previo['patente'] ?? '').toString().isNotEmpty)
                _row('Patente', previo['patente'].toString()),
              if ((previo['tipoOperacion'] ?? '').toString().isNotEmpty)
                _row('Tipo de Operacion', previo['tipoOperacion'].toString()),
              if ((previo['contenedor'] ?? '').toString().isNotEmpty)
                _row('Contenedor', previo['contenedor'].toString()),
              if ((previo['sello'] ?? '').toString().isNotEmpty)
                _row('Sello', previo['sello'].toString()),
              if ((previo['verificador'] ?? '').toString().isNotEmpty)
                _row('Verificador', previo['verificador'].toString()),
              if ((previo['observaciones'] ?? '').isNotEmpty)
                _row('Observaciones', previo['observaciones']),
            ],
          ),
          pw.SizedBox(height: 18),
          pw.Text('Indice de fotografias (${validas.length}):',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: _azul)),
          pw.SizedBox(height: 8),
          ..._indicePorPartidas(validas),
        ],
      ));

      // ═══════════ PÁGINAS DE FOTOS: 2 POR HOJA ═══════════
      for (var i = 0; i < validas.length; i += 2) {
        final foto1 = validas[i];
        final foto2 = (i + 1 < validas.length) ? validas[i + 1] : null;

        pdf.addPage(pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.all(20),
          build: (_) => pw.Column(
            children: [
              pw.Expanded(flex: 1, child: _buildFoto(foto1, i + 1, previo)),
              pw.SizedBox(height: 10),
              if (foto2 != null)
                pw.Expanded(flex: 1, child: _buildFoto(foto2, i + 2, previo))
              else
                pw.Expanded(flex: 1, child: pw.SizedBox()),
            ],
          ),
        ));
      }

      // Guardar y compartir
      Directory dir;
      try {
        dir = await getApplicationDocumentsDirectory();
      } catch (_) {
        dir = Directory.systemTemp;
      }
      final ref = '${previo['referencia'] ?? 'Previo'}'.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final file = File('${dir.path}/Previo_$ref.pdf');
      await file.writeAsBytes(await pdf.save());

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'Previo Aduanal - ${previo['referencia']}\nIntegra Del Centro S.C.',
        ),
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Previo generado correctamente'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ═══════════ WIDGET DE FOTO INDIVIDUAL ═══════════
  static pw.Widget _buildFoto(Map<String, dynamic> foto, int numero, Map previo) {
    final bytes = foto['bytes'] as Uint8List;
    final tipo = foto['tipo'] as String;
    final desc = foto['desc'] as String;
    final color = _colorTipo(tipo);
    final bloque = foto['bloque'] as Map?;

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: color, width: 2),
      ),
      child: pw.Column(
        children: [
          // Banda superior
          pw.Container(
            height: 28,
            color: color,
            padding: pw.EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Row(children: [
                  pw.Container(
                    width: 20,
                    height: 20,
                    decoration: pw.BoxDecoration(
                      shape: pw.BoxShape.circle,
                      color: PdfColors.white,
                    ),
                    child: pw.Center(
                      child: pw.Text('$numero',
                          style: pw.TextStyle(
                              fontSize: 9, fontWeight: pw.FontWeight.bold, color: color)),
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Text(tipo.toUpperCase(),
                      style: pw.TextStyle(
                          color: PdfColors.white, fontSize: 11, fontWeight: pw.FontWeight.bold)),
                ]),
                pw.Text(previo['referencia'] ?? '',
                    style: pw.TextStyle(color: PdfColors.white, fontSize: 8)),
              ],
            ),
          ),

          // PARTIDA (si existe)
          if (bloque != null)
            pw.Container(
              width: double.infinity,
              padding: pw.EdgeInsets.all(6),
              color: PdfColor.fromInt(0xFFEEF2F7),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('PARTIDA: ${bloque['nombre'] ?? ''}',
                      style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _azul)),
                  if ((bloque['informacion'] ?? '').toString().isNotEmpty)
                    pw.Text(bloque['informacion'].toString(),
                        style: pw.TextStyle(fontSize: 8)),
                ],
              ),
            ),

          // Imagen
          pw.Expanded(
            child: pw.Container(
              color: PdfColors.black,
              child: pw.Center(
                child: pw.Image(pw.MemoryImage(bytes), fit: pw.BoxFit.contain),
              ),
            ),
          ),

          // Banda inferior
          pw.Container(
            width: double.infinity,
            padding: pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: PdfColor.fromInt(0xFF1A1A1A),
            child: desc.isNotEmpty
                ? pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Container(width: 3, height: 20, color: color),
                      pw.SizedBox(width: 8),
                      pw.Expanded(
                        child: pw.Text(desc,
                            style: pw.TextStyle(color: PdfColors.white, fontSize: 10)),
                      ),
                    ],
                  )
                : pw.Text('Sin descripcion',
                    style: pw.TextStyle(color: PdfColors.grey500, fontSize: 9)),
          ),
        ],
      ),
    );
  }

  // ═══════════ ÍNDICE POR PARTIDAS ═══════════
  static List<pw.Widget> _indicePorPartidas(List<Map<String, dynamic>> fotos) {
    final resultado = <pw.Widget>[];
    String? partidaActual;

    for (final entry in fotos.asMap().entries) {
      final id = entry.value['bloqueId'] as String? ?? '';
      final bloque = entry.value['bloque'] as Map?;

      if (id != partidaActual) {
        partidaActual = id;
        resultado.add(pw.Container(
          width: double.infinity,
          margin: pw.EdgeInsets.only(top: 8, bottom: 4),
          padding: pw.EdgeInsets.all(7),
          color: PdfColor.fromInt(0xFFEEF2F7),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('PARTIDA: ${bloque?['nombre'] ?? 'Sin partida'}',
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _azul)),
              if ((bloque?['informacion'] ?? '').toString().isNotEmpty)
                pw.Text(bloque!['informacion'].toString(),
                    style: pw.TextStyle(fontSize: 8)),
            ],
          ),
        ));
      }

      resultado.add(_filaIndice(entry));
    }
    return resultado;
  }

  static pw.Widget _filaIndice(MapEntry<int, Map<String, dynamic>> entry) {
    final foto = entry.value;
    final tipo = foto['tipo'] as String;
    final desc = foto['desc'] as String;
    final color = _colorTipo(tipo);

    return pw.Container(
      margin: pw.EdgeInsets.only(bottom: 5),
      padding: pw.EdgeInsets.all(7),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _gris, width: 0.5),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
              width: 24,
              child: pw.Text('${entry.key + 1}.',
                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
          pw.Container(
            padding: pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            color: color,
            child: pw.Text(tipo,
                style: pw.TextStyle(fontSize: 8, color: PdfColors.white)),
          ),
          pw.SizedBox(width: 8),
          pw.Expanded(
            child: pw.Text(
              desc.isNotEmpty ? desc : '(sin descripcion)',
              style: pw.TextStyle(fontSize: 9),
            ),
          ),
        ],
      ),
    );
  }

  static pw.TableRow _row(String label, String value, {bool bold = false}) {
    return pw.TableRow(children: [
      pw.Padding(
        padding: pw.EdgeInsets.all(6),
        child: pw.Text(label,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: _azul)),
      ),
      pw.Padding(
        padding: pw.EdgeInsets.all(6),
        child: pw.Text(value.isNotEmpty ? value : '-',
            style: pw.TextStyle(
                fontSize: 9,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
      ),
    ]);
  }

  static PdfColor _colorTipo(String tipo) {
    if (tipo == 'Averia') return _rojo;
    if (tipo == 'Mercancia') return _azul;
    return _naranja;
  }
}