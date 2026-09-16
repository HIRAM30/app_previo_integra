// ============================================================
// Integra Del Centro, S.C.
// Desarrollado por: HIRAM JAFET VELAZQUEZ SANTANDER
// services/pdf_service_previo.dart v7.0
// Cambios v7.0:
//   - Toda la construccion del PDF corre en isolate (compute).
//   - La UI solo muestra spinner; el telefono no se congela.
//   - Ya NO requiere fotosBytes en Hive: lee del disco dentro
//     del isolate.
//   - Sin dependencias de BuildContext dentro del isolate.
// ============================================================

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

class PdfServicePrevio {
  static final PdfColor _azul = PdfColor.fromInt(0xFF003087);
  static final PdfColor _rojo = PdfColor.fromInt(0xFFB71C1C);
  static final PdfColor _naranja = PdfColor.fromInt(0xFFE65100);
  static final PdfColor _verde = PdfColor.fromInt(0xFF2E7D32);
  static final PdfColor _gris = PdfColor.fromInt(0xFFE0E0E0);
  static final PdfColor _naranjaClaro = PdfColor.fromInt(0xFFFFF3E0);
  static final PdfColor _azulClaro = PdfColor.fromInt(0xFFE3F2FD);

  static Future<void> generarYCompartir(
      Map previo, BuildContext context) async {
    try {
      final fotosPaths = List<String>.from(previo['fotos'] ?? []);
      final tipos = List<String>.from(previo['fotosTipos'] ?? []);
      final descs = List<String>.from(previo['fotosDescripciones'] ?? []);
      final fotoBloques = List<String>.from(previo['fotosBloques'] ?? []);
      final secciones = List<Map>.from(previo['secciones'] ?? []);
      final partidas =
          List<Map>.from(previo['partidas'] ?? previo['particiones'] ?? []);

      final tipoBulto = (previo['tiposBulto'] is List &&
              (previo['tiposBulto'] as List).isNotEmpty)
          ? (previo['tiposBulto'] as List).join(', ')
          : (previo['tipoBulto'] ?? '');

      final args = <String, dynamic>{
        'referencia': previo['referencia'] ?? '',
        'cliente': previo['cliente'] ?? '',
        'almacen': previo['almacen'] ?? '',
        'house': previo['house'] ?? '',
        'fecha': previo['fecha'] ?? '',
        'observaciones': previo['observaciones'] ?? '',
        'tipoBulto': tipoBulto,
        'vieneConFactura': previo['vieneConFactura'] ?? '',
        'aduana': previo['aduana']?.toString() ?? '',
        'patente': previo['patente']?.toString() ?? '',
        'tipoOperacion': previo['tipoOperacion']?.toString() ?? '',
        'contenedor': previo['contenedor']?.toString() ?? '',
        'sello': previo['sello']?.toString() ?? '',
        'verificador': previo['verificador']?.toString() ?? '',
        'fotosPaths': fotosPaths,
        'fotosTipos': tipos,
        'fotosDescripciones': descs,
        'fotosBloques': fotoBloques,
        'secciones':
            secciones.map((s) => Map<String, dynamic>.from(s)).toList(),
        'partidas':
            partidas.map((p) => Map<String, dynamic>.from(p)).toList(),
      };

      final Uint8List? pdfBytes =
          await compute(_construirPdfPrevioEnIsolate, args);

      if (pdfBytes == null || pdfBytes.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('No hay fotos para generar el PDF'),
            backgroundColor: Colors.red,
          ));
        }
        return;
      }

      Directory dir;
      try {
        dir = await getApplicationDocumentsDirectory();
      } catch (_) {
        dir = Directory.systemTemp;
      }
      final ref = '${previo['referencia'] ?? 'Previo'}'
          .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final file = File('${dir.path}/Previo_$ref.pdf');
      await file.writeAsBytes(pdfBytes);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'Previo Aduanal - ${previo['referencia']}\n'
              'Integra Del Centro S.C.',
        ),
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Previo generado correctamente'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  static Future<Uint8List?> _construirPdfPrevioEnIsolate(
      Map<String, dynamic> args) async {
    final fotosPaths = List<String>.from(args['fotosPaths'] ?? []);
    final tipos = List<String>.from(args['fotosTipos'] ?? []);
    final descs = List<String>.from(args['fotosDescripciones'] ?? []);
    final fotoBloques = List<String>.from(args['fotosBloques'] ?? []);
    final secciones = List<Map>.from(args['secciones'] ?? []);
    final partidas = List<Map>.from(args['partidas'] ?? []);

    final todosLosDestinos = <String, Map>{};
    final tipoDestino = <String, String>{};
    final ordenDestino = <String, int>{};
    int orden = 0;

    for (final s in secciones) {
      final id = (s['id'] ?? '').toString();
      todosLosDestinos[id] = {
        'id': id,
        'nombre': 'SECCION: ${s['nombre'] ?? ''}',
        'informacion': s['informacion'] ?? '',
      };
      tipoDestino[id] = 'seccion';
      ordenDestino[id] = orden++;
    }
    for (int i = 0; i < partidas.length; i++) {
      final p = partidas[i];
      final id = (p['id'] ?? '').toString();
      final nombrePartida = (p['nombre'] ?? '').toString();
      todosLosDestinos[id] = {
        'id': id,
        'nombre': nombrePartida.isNotEmpty
            ? 'PARTIDA ${i + 1}: $nombrePartida'
            : 'PARTIDA ${i + 1}',
        'informacion': p['informacion'] ?? '',
      };
      tipoDestino[id] = 'partida';
      ordenDestino[id] = orden++;
    }

    final validas = <Map<String, dynamic>>[];
    for (var i = 0; i < fotosPaths.length; i++) {
      final path = fotosPaths[i];
      final file = File(path);
      if (!file.existsSync()) continue;
      Uint8List bytes;
      try {
        bytes = await file.readAsBytes();
      } catch (_) {
        continue;
      }
      if (bytes.isEmpty) continue;

      final bloqueId = i < fotoBloques.length ? fotoBloques[i] : '';
      validas.add({
        'bytes': bytes,
        'tipo': i < tipos.length ? tipos[i] : 'Mercancia',
        'desc': i < descs.length ? descs[i] : '',
        'bloqueId': bloqueId,
        'destino': todosLosDestinos[bloqueId],
        'tipoDestino': tipoDestino[bloqueId] ?? 'partida',
        'ordenOriginal': i,
      });
    }

    if (validas.isEmpty) return null;

    validas.sort((a, b) {
      final ordenA = ordenDestino[a['bloqueId']] ?? 999999;
      final ordenB = ordenDestino[b['bloqueId']] ?? 999999;
      if (ordenA != ordenB) return ordenA.compareTo(ordenB);
      return (a['ordenOriginal'] as int).compareTo(b['ordenOriginal'] as int);
    });

    final pdf = pw.Document(
      title: 'Previo - ${args['referencia']}',
      author: 'Integra Del Centro S.C.',
    );

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      header: (_) => pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 8),
        decoration: pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: _azul, width: 2)),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('PREVIO ADUANAL',
                style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: _azul)),
            pw.Text('Integra Del Centro, S.C.',
                style: const pw.TextStyle(
                    fontSize: 9, color: PdfColors.grey)),
          ],
        ),
      ),
      footer: (context) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
            'Pagina ${context.pageNumber} de ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
      ),
      build: (_) => [
        pw.SizedBox(height: 14),
        pw.Table(
          border: pw.TableBorder.all(color: _gris, width: 0.5),
          children: [
            _row('Referencia / Master', args['referencia'] as String,
                bold: true),
            if ((args['cliente'] as String).isNotEmpty)
              _row('Cliente', args['cliente'] as String),
            if ((args['almacen'] as String).isNotEmpty)
              _row('Almacen', args['almacen'] as String),
            if ((args['house'] as String).isNotEmpty)
              _row('House', args['house'] as String),
            _row('Fecha', '${args['fecha']}'.split('T').first),
            if ((args['tipoBulto'] as String).isNotEmpty)
              _row('Tipo de Bulto', args['tipoBulto'] as String),
            if ((args['vieneConFactura'] as String).isNotEmpty)
              _row('Viene con Factura', args['vieneConFactura'] as String),
            if ((args['aduana'] as String).isNotEmpty)
              _row('Aduana', args['aduana'] as String),
            if ((args['patente'] as String).isNotEmpty)
              _row('Patente', args['patente'] as String),
            if ((args['tipoOperacion'] as String).isNotEmpty)
              _row('Tipo de Operacion', args['tipoOperacion'] as String),
            if ((args['contenedor'] as String).isNotEmpty)
              _row('Contenedor', args['contenedor'] as String),
            if ((args['sello'] as String).isNotEmpty)
              _row('Sello', args['sello'] as String),
            if ((args['verificador'] as String).isNotEmpty)
              _row('Verificador', args['verificador'] as String),
            if ((args['observaciones'] as String).isNotEmpty)
              _row('Observaciones', args['observaciones'] as String),
          ],
        ),
        pw.SizedBox(height: 18),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly, children: [
          _statBox('Total Fotos', '${validas.length}', _azul,
              PdfColor.fromInt(0xFFE8ECF3)),
          _statBox('Secciones', '${secciones.length}', _naranja, _naranjaClaro),
          _statBox('Partidas', '${partidas.length}', _verde,
              PdfColor.fromInt(0xFFE8F5E9)),
        ]),
        pw.SizedBox(height: 16),
        pw.Text('Indice de fotografias:',
            style: pw.TextStyle(
                fontSize: 13, fontWeight: pw.FontWeight.bold, color: _azul)),
        pw.SizedBox(height: 8),
        ..._indiceConSeccionesYPartidas(validas),
      ],
    ));

    for (var i = 0; i < validas.length; i += 2) {
      final foto1 = validas[i];
      final foto2 = (i + 1 < validas.length) ? validas[i + 1] : null;

      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (_) => pw.Column(
          children: [
            pw.Expanded(flex: 1, child: _buildFoto(foto1, i + 1, args)),
            pw.SizedBox(height: 10),
            if (foto2 != null)
              pw.Expanded(flex: 1, child: _buildFoto(foto2, i + 2, args))
            else
              pw.Expanded(flex: 1, child: pw.SizedBox()),
          ],
        ),
      ));
    }

    return pdf.save();
  }

  static pw.Widget _statBox(
      String label, String value, PdfColor textColor, PdfColor bgColor) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: pw.BoxDecoration(color: bgColor),
      child: pw.Column(children: [
        pw.Text(value,
            style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: textColor)),
        pw.Text(label, style: pw.TextStyle(fontSize: 7, color: textColor)),
      ]),
    );
  }

  static pw.Widget _buildFoto(
      Map<String, dynamic> foto, int numero, Map<String, dynamic> args) {
    final bytes = foto['bytes'] as Uint8List;
    final tipo = foto['tipo'] as String;
    final desc = foto['desc'] as String;
    final color = _colorTipo(tipo);
    final destino = foto['destino'] as Map?;
    final tipoDestino = foto['tipoDestino'] as String? ?? 'partida';

    return pw.Container(
      decoration:
          pw.BoxDecoration(border: pw.Border.all(color: color, width: 2)),
      child: pw.Column(children: [
        pw.Container(
          height: 28,
          color: color,
          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Row(children: [
                pw.Container(
                  width: 20,
                  height: 20,
                  decoration: pw.BoxDecoration(
                      shape: pw.BoxShape.circle, color: PdfColors.white),
                  child: pw.Center(
                      child: pw.Text('$numero',
                          style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                              color: color))),
                ),
                pw.SizedBox(width: 8),
                pw.Text(tipo.toUpperCase(),
                    style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold)),
              ]),
              pw.Text(args['referencia'] as String? ?? '',
                  style: const pw.TextStyle(
                      color: PdfColors.white, fontSize: 8)),
            ],
          ),
        ),
        if (destino != null)
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(6),
            color: tipoDestino == 'seccion' ? _naranjaClaro : _azulClaro,
            child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('${destino['nombre'] ?? ''}',
                      style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color:
                              tipoDestino == 'seccion' ? _naranja : _azul)),
                  if ((destino['informacion'] ?? '')
                      .toString()
                      .isNotEmpty)
                    pw.Text(destino['informacion'].toString(),
                        style: const pw.TextStyle(fontSize: 8)),
                ]),
          ),
        pw.Expanded(
          child: pw.Container(
            color: PdfColors.black,
            child: pw.Center(
                child: pw.Image(pw.MemoryImage(bytes),
                    fit: pw.BoxFit.contain)),
          ),
        ),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: PdfColor.fromInt(0xFF1A1A1A),
          child: desc.isNotEmpty
              ? pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                      pw.Container(width: 3, height: 20, color: color),
                      pw.SizedBox(width: 8),
                      pw.Expanded(
                          child: pw.Text(desc,
                              style: const pw.TextStyle(
                                  color: PdfColors.white, fontSize: 10))),
                    ])
              : pw.Text('Sin descripcion',
                  style: const pw.TextStyle(
                      color: PdfColors.grey500, fontSize: 9)),
        ),
      ]),
    );
  }

  static List<pw.Widget> _indiceConSeccionesYPartidas(
      List<Map<String, dynamic>> fotos) {
    final resultado = <pw.Widget>[];
    String? destinoActual;

    for (final entry in fotos.asMap().entries) {
      final id = entry.value['bloqueId'] as String? ?? '';
      final tipoDest = entry.value['tipoDestino'] as String? ?? 'partida';
      final destino = entry.value['destino'] as Map?;

      if (id != destinoActual) {
        destinoActual = id;
        final esSeccion = tipoDest == 'seccion';
        final colorFondo = esSeccion ? _naranjaClaro : _azulClaro;
        final colorTexto = esSeccion ? _naranja : _azul;

        resultado.add(pw.Container(
          width: double.infinity,
          margin: const pw.EdgeInsets.only(top: 8, bottom: 4),
          padding: const pw.EdgeInsets.all(7),
          color: colorFondo,
          child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(destino?['nombre'] ?? 'Sin nombre',
                    style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: colorTexto)),
                if ((destino?['informacion'] ?? '')
                    .toString()
                    .isNotEmpty)
                  pw.Text(destino!['informacion'].toString(),
                      style: const pw.TextStyle(fontSize: 8)),
              ]),
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
      margin: const pw.EdgeInsets.only(bottom: 5),
      padding: const pw.EdgeInsets.all(7),
      decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _gris, width: 0.5)),
      child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.SizedBox(
            width: 24,
            child: pw.Text('${entry.key + 1}.',
                style: pw.TextStyle(
                    fontSize: 9, fontWeight: pw.FontWeight.bold))),
        pw.Container(
            padding:
                const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            color: color,
            child: pw.Text(tipo,
                style: const pw.TextStyle(
                    fontSize: 8, color: PdfColors.white))),
        pw.SizedBox(width: 8),
        pw.Expanded(
            child: pw.Text(desc.isNotEmpty ? desc : '(sin descripcion)',
                style: const pw.TextStyle(fontSize: 9))),
      ]),
    );
  }

  static pw.TableRow _row(String label, String value, {bool bold = false}) {
    return pw.TableRow(children: [
      pw.Padding(
        padding: const pw.EdgeInsets.all(6),
        child: pw.Text(label,
            style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 9,
                color: _azul)),
      ),
      pw.Padding(
        padding: const pw.EdgeInsets.all(6),
        child: pw.Text(value.isNotEmpty ? value : '-',
            style: pw.TextStyle(
                fontSize: 9,
                fontWeight:
                    bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
      ),
    ]);
  }

  static PdfColor _colorTipo(String tipo) {
    if (tipo == 'Averia') return _rojo;
    if (tipo == 'Mercancia') return _azul;
    return _naranja;
  }
}