// ============================================================
// Integra Del Centro, S.C.
// Desarrollado por: HIRAM JAFET VELAZQUEZ SANTANDER
// services/pdf_service_previo.dart v3.6
// ============================================================

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

class PdfServicePrevio {
  static const _azul = PdfColor.fromInt(0xFF003087);
  static const _rojo = PdfColor.fromInt(0xFFB71C1C);
  static const _naranja = PdfColor.fromInt(0xFFE65100);
  static const _gris = PdfColor.fromInt(0xFFE0E0E0);

  static Future<void> generarYCompartir(Map previo, BuildContext context) async {
    try {
      final pdf = pw.Document(
        title: 'Previo - ${previo['referencia'] ?? ''}',
        author: 'Integra Del Centro S.C.',
      );
      final fotos = List<String>.from(previo['fotos'] ?? []);
      final tipos = List<String>.from(previo['fotosTipos'] ?? []);
      final descs = List<String>.from(previo['fotosDescripciones'] ?? []);
      final fotoBloques = List<String>.from(previo['fotosBloques'] ?? []);
      final bloques = List<Map>.from(previo['bloques'] ?? []);

      final bloquesPorId = <String, Map>{
        for (final bloque in bloques) (bloque['id'] ?? '').toString(): bloque,
      };
      final ordenBloque = <String, int>{
        for (var i = 0; i < bloques.length; i++)
          (bloques[i]['id'] ?? '').toString(): i,
      };

      final validas = <Map<String, dynamic>>[];
      for (var i = 0; i < fotos.length; i++) {
        if (!File(fotos[i]).existsSync()) continue;
        final bloqueId = i < fotoBloques.length ? fotoBloques[i] : '';
        validas.add({
          'path': fotos[i],
          'tipo': i < tipos.length ? tipos[i] : 'Mercancia',
          'desc': i < descs.length ? descs[i] : '',
          'bloqueId': bloqueId,
          'bloque': bloquesPorId[bloqueId],
          'ordenOriginal': i,
        });
      }

      // Ordenar por bloque y luego por orden original
      validas.sort((a, b) {
        final ordenA = ordenBloque[a['bloqueId']] ?? 999999;
        final ordenB = ordenBloque[b['bloqueId']] ?? 999999;
        if (ordenA != ordenB) return ordenA.compareTo(ordenB);
        return (a['ordenOriginal'] as int).compareTo(b['ordenOriginal'] as int);
      });

      // Página de índice
      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (_) => _encabezado(previo),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text('Página ${context.pageNumber} de ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
        ),
        build: (_) => [
          pw.SizedBox(height: 14),
          pw.Table(
            border: pw.TableBorder.all(color: _gris, width: .5),
            children: [
              _row('Referencia / Master', '${previo['referencia'] ?? ''}', bold: true),
              _row('Cliente', '${previo['cliente'] ?? ''}'),
              _row('Almacén', '${previo['almacen'] ?? ''}'),
              _row('House', '${previo['house'] ?? ''}'),
              _row('Fecha', '${previo['fecha'] ?? ''}'.split('T').first),
              if ((previo['aduana'] ?? '').toString().isNotEmpty)
                _row('Aduana', '${previo['aduana']}'),
              if ((previo['patente'] ?? '').toString().isNotEmpty)
                _row('Patente', '${previo['patente']}'),
              if ((previo['tipoOperacion'] ?? '').toString().isNotEmpty)
                _row('Tipo de Operación', '${previo['tipoOperacion']}'),
              if ((previo['contenedor'] ?? '').toString().isNotEmpty)
                _row('Contenedor', '${previo['contenedor']}'),
              if ((previo['sello'] ?? '').toString().isNotEmpty)
                _row('Sello', '${previo['sello']}'),
              if ((previo['verificador'] ?? '').toString().isNotEmpty)
                _row('Verificador', '${previo['verificador']}'),
              if ('${previo['observaciones'] ?? ''}'.isNotEmpty)
                _row('Observaciones', '${previo['observaciones']}'),
            ],
          ),
          pw.SizedBox(height: 18),
          pw.Text('Índice de fotografías (${validas.length})',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: _azul)),
          pw.SizedBox(height: 8),
          ..._indicePorBloques(validas),
        ],
      ));

      // Una página por foto
      for (var i = 0; i < validas.length; i++) {
        final foto = validas[i];
        final bloque = foto['bloque'] as Map?;
        final tipo = foto['tipo'] as String;
        final color = _colorTipo(tipo);
        final bytes = File(foto['path'] as String).readAsBytesSync();
        pdf.addPage(pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(26),
          build: (_) => pw.Column(children: [
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(10),
              color: color,
              child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('FOTO ${i + 1} · ${tipo.toUpperCase()}',
                    style: pw.TextStyle(color: PdfColors.white, fontSize: 12, fontWeight: pw.FontWeight.bold)),
                pw.Text('${previo['referencia'] ?? ''}',
                    style: const pw.TextStyle(color: PdfColors.white, fontSize: 9)),
              ]),
            ),
            if (bloque != null) _fichaBloque(bloque),
            pw.SizedBox(height: 10),
            pw.Expanded(
              child: pw.Container(
                width: double.infinity,
                color: PdfColors.black,
                child: pw.Center(child: pw.Image(pw.MemoryImage(bytes), fit: pw.BoxFit.contain)),
              ),
            ),
            pw.SizedBox(height: 10),
            _dato('Descripción de la imagen', foto['desc'] as String),
          ]),
        ));
      }

      // Guardar PDF
      Directory dir;
      try {
        dir = await getApplicationDocumentsDirectory();
      } catch (_) {
        dir = Directory.systemTemp;
      }
      final referencia = '${previo['referencia'] ?? 'Previo'}'
          .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final file = File('${dir.path}/Previo_$referencia.pdf');
      await file.writeAsBytes(await pdf.save());
      await Share.shareXFiles([XFile(file.path)], text: 'Previo Aduanal - ${previo['referencia']}');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Previo generado correctamente'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  static pw.Widget _encabezado(Map previo) => pw.Container(
    padding: const pw.EdgeInsets.only(bottom: 8),
    decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _azul, width: 2))),
    child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
      pw.Text('PREVIO ADUANAL', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: _azul)),
      pw.Text('Integra Del Centro, S.C.', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey)),
    ]),
  );

  static List<pw.Widget> _indicePorBloques(List<Map<String, dynamic>> fotos) {
    final resultado = <pw.Widget>[];
    String? bloqueActual;
    for (final entry in fotos.asMap().entries) {
      final id = entry.value['bloqueId'] as String? ?? '';
      final bloque = entry.value['bloque'] as Map?;
      if (id != bloqueActual) {
        bloqueActual = id;
        resultado.add(pw.Container(
          width: double.infinity,
          margin: const pw.EdgeInsets.only(top: 8, bottom: 4),
          padding: const pw.EdgeInsets.all(7),
          color: const PdfColor(.92, .95, 1),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('BLOQUE: ${bloque?['nombre'] ?? 'Sin bloque'}',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _azul)),
            if ('${bloque?['informacion'] ?? ''}'.isNotEmpty)
              pw.Text('${bloque?['informacion']}', style: const pw.TextStyle(fontSize: 8)),
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
    final descripcion = foto['desc'] as String;
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 5),
      padding: const pw.EdgeInsets.all(7),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: _gris, width: .5)),
      child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.SizedBox(width: 24, child: pw.Text('${entry.key + 1}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
        pw.Container(padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2), color: _colorTipo(tipo), child: pw.Text(tipo, style: const pw.TextStyle(fontSize: 8, color: PdfColors.white))),
        pw.SizedBox(width: 8),
        pw.Expanded(child: pw.Text(descripcion.isNotEmpty ? descripcion : '(sin descripción)', style: const pw.TextStyle(fontSize: 8))),
      ]),
    );
  }

  static pw.Widget _fichaBloque(Map bloque) => pw.Container(
    width: double.infinity,
    margin: const pw.EdgeInsets.only(top: 10),
    padding: const pw.EdgeInsets.all(8),
    color: const PdfColor(.92, .95, 1),
    child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text('BLOQUE: ${bloque['nombre'] ?? ''}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _azul)),
      if ('${bloque['informacion'] ?? ''}'.isNotEmpty) pw.Text('${bloque['informacion']}', style: const pw.TextStyle(fontSize: 9)),
    ]),
  );

  static pw.Widget _dato(String etiqueta, String valor) => pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.all(8),
    decoration: pw.BoxDecoration(border: pw.Border.all(color: _gris, width: .5)),
    child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text(etiqueta, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _azul)),
      pw.Text(valor.isEmpty ? 'Sin descripción' : valor, style: const pw.TextStyle(fontSize: 10)),
    ]),
  );

  static pw.TableRow _row(String label, String value, {bool bold = false}) => pw.TableRow(children: [
    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(label, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _azul))),
    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(value.isEmpty ? '—' : value, style: pw.TextStyle(fontSize: 9, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal))),
  ]);

  static PdfColor _colorTipo(String tipo) => tipo == 'Averia' ? _rojo : tipo == 'Mercancia' ? _azul : _naranja;
}