// ============================================================
// Integra Del Centro, S.C.
// Desarrollado por: HIRAM JAFET VELAZQUEZ SANTANDER
// services/pdf_service_previo.dart v6.2
// Incluye: Tipo de Bulto multiselección en PDF
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
  static final _verde = PdfColor.fromInt(0xFF2E7D32);
  static final _gris = PdfColor.fromInt(0xFFE0E0E0);
  static final _naranjaClaro = PdfColor.fromInt(0xFFFFF3E0);
  static final _azulClaro = PdfColor.fromInt(0xFFE3F2FD);

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
      final secciones = List<Map>.from(previo['secciones'] ?? []);
      final partidas = List<Map>.from(previo['partidas'] ?? previo['particiones'] ?? []);

      // Tipo de bulto - soporta formato antiguo y nuevo (multiselección)
      final tipoBulto = (previo['tiposBulto'] is List && (previo['tiposBulto'] as List).isNotEmpty)
          ? (previo['tiposBulto'] as List).join(', ')
          : previo['tipoBulto'] ?? '';
      
      final vieneConFactura = previo['vieneConFactura'] ?? '';

      final todosLosDestinos = <String, Map>{};
      final tipoDestino = <String, String>{};

      for (final s in secciones) {
        final id = (s['id'] ?? '').toString();
        todosLosDestinos[id] = {
          'id': id,
          'nombre': 'SECCION: ${s['nombre'] ?? ''}',
          'informacion': s['informacion'] ?? '',
        };
        tipoDestino[id] = 'seccion';
      }
      for (int i = 0; i < partidas.length; i++) {
        final p = partidas[i];
        final id = (p['id'] ?? '').toString();
        todosLosDestinos[id] = {
          'id': id,
          'nombre': 'PARTIDA ${i + 1}',
          'informacion': p['informacion'] ?? '',
        };
        tipoDestino[id] = 'partida';
      }

      final ordenDestino = <String, int>{};
      int orden = 0;
      for (final s in secciones) {
        ordenDestino[(s['id'] ?? '').toString()] = orden++;
      }
      for (final p in partidas) {
        ordenDestino[(p['id'] ?? '').toString()] = orden++;
      }

      final validas = <Map<String, dynamic>>[];
      for (var i = 0; i < fotosPaths.length; i++) {
        Uint8List? bytes;
        if (i < fotosBytesList.length && fotosBytesList[i].isNotEmpty) {
          try { bytes = Uint8List.fromList(fotosBytesList[i].codeUnits); } catch (_) {}
        }
        if (bytes == null && i < fotosPaths.length) {
          final file = File(fotosPaths[i]);
          if (file.existsSync()) {
            try { bytes = file.readAsBytesSync(); } catch (_) {}
          }
        }
        if (bytes != null && bytes.isNotEmpty) {
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
        final ordenA = ordenDestino[a['bloqueId']] ?? 999999;
        final ordenB = ordenDestino[b['bloqueId']] ?? 999999;
        if (ordenA != ordenB) return ordenA.compareTo(ordenB);
        return (a['ordenOriginal'] as int).compareTo(b['ordenOriginal'] as int);
      });

      // ═══════════ PORTADA + ÍNDICE ═══════════
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
              if ((previo['cliente'] ?? '').isNotEmpty) _row('Cliente', previo['cliente']),
              if ((previo['almacen'] ?? '').isNotEmpty) _row('Almacen', previo['almacen']),
              if ((previo['house'] ?? '').isNotEmpty) _row('House', previo['house']),
              _row('Fecha', '${previo['fecha'] ?? ''}'.split('T').first),
              if (tipoBulto.isNotEmpty) _row('Tipo de Bulto', tipoBulto),
              if (vieneConFactura.isNotEmpty) _row('Viene con Factura', vieneConFactura),
              if ((previo['aduana'] ?? '').toString().isNotEmpty) _row('Aduana', previo['aduana'].toString()),
              if ((previo['patente'] ?? '').toString().isNotEmpty) _row('Patente', previo['patente'].toString()),
              if ((previo['tipoOperacion'] ?? '').toString().isNotEmpty) _row('Tipo de Operacion', previo['tipoOperacion'].toString()),
              if ((previo['contenedor'] ?? '').toString().isNotEmpty) _row('Contenedor', previo['contenedor'].toString()),
              if ((previo['sello'] ?? '').toString().isNotEmpty) _row('Sello', previo['sello'].toString()),
              if ((previo['verificador'] ?? '').toString().isNotEmpty) _row('Verificador', previo['verificador'].toString()),
              if ((previo['observaciones'] ?? '').isNotEmpty) _row('Observaciones', previo['observaciones']),
            ],
          ),
          pw.SizedBox(height: 18),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly, children: [
            _statBox('Total Fotos', '${validas.length}', _azul, PdfColor.fromInt(0xFFE8ECF3)),
            _statBox('Secciones', '${secciones.length}', _naranja, _naranjaClaro),
            _statBox('Partidas', '${partidas.length}', _verde, PdfColor.fromInt(0xFFE8F5E9)),
          ]),
          pw.SizedBox(height: 16),
          pw.Text('Indice de fotografias:',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: _azul)),
          pw.SizedBox(height: 8),
          ..._indiceConSeccionesYPartidas(validas),
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

  static pw.Widget _statBox(String label, String value, PdfColor textColor, PdfColor bgColor) {
    return pw.Container(
      padding: pw.EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: pw.BoxDecoration(color: bgColor),
      child: pw.Column(children: [
        pw.Text(value, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: textColor)),
        pw.Text(label, style: pw.TextStyle(fontSize: 7, color: textColor)),
      ]),
    );
  }

  static pw.Widget _buildFoto(Map<String, dynamic> foto, int numero, Map previo) {
    final bytes = foto['bytes'] as Uint8List;
    final tipo = foto['tipo'] as String;
    final desc = foto['desc'] as String;
    final color = _colorTipo(tipo);
    final destino = foto['destino'] as Map?;
    final tipoDestino = foto['tipoDestino'] as String? ?? 'partida';

    return pw.Container(
      decoration: pw.BoxDecoration(border: pw.Border.all(color: color, width: 2)),
      child: pw.Column(children: [
        pw.Container(
          height: 28, color: color,
          padding: pw.EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Row(children: [
              pw.Container(
                width: 20, height: 20,
                decoration: pw.BoxDecoration(shape: pw.BoxShape.circle, color: PdfColors.white),
                child: pw.Center(child: pw.Text('$numero',
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: color))),
              ),
              pw.SizedBox(width: 8),
              pw.Text(tipo.toUpperCase(),
                  style: pw.TextStyle(color: PdfColors.white, fontSize: 11, fontWeight: pw.FontWeight.bold)),
            ]),
            pw.Text(previo['referencia'] ?? '',
                style: pw.TextStyle(color: PdfColors.white, fontSize: 8)),
          ]),
        ),
        if (destino != null)
          pw.Container(
            width: double.infinity, padding: pw.EdgeInsets.all(6),
            color: tipoDestino == 'seccion' ? _naranjaClaro : _azulClaro,
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('${destino['nombre'] ?? ''}',
                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold,
                      color: tipoDestino == 'seccion' ? _naranja : _azul)),
              if ((destino['informacion'] ?? '').toString().isNotEmpty)
                pw.Text(destino['informacion'].toString(), style: pw.TextStyle(fontSize: 8)),
            ]),
          ),
        pw.Expanded(
          child: pw.Container(
            color: PdfColors.black,
            child: pw.Center(child: pw.Image(pw.MemoryImage(bytes), fit: pw.BoxFit.contain)),
          ),
        ),
        pw.Container(
          width: double.infinity, padding: pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: PdfColor.fromInt(0xFF1A1A1A),
          child: desc.isNotEmpty
              ? pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
                  pw.Container(width: 3, height: 20, color: color),
                  pw.SizedBox(width: 8),
                  pw.Expanded(child: pw.Text(desc, style: pw.TextStyle(color: PdfColors.white, fontSize: 10))),
                ])
              : pw.Text('Sin descripcion', style: pw.TextStyle(color: PdfColors.grey500, fontSize: 9)),
        ),
      ]),
    );
  }

  static List<pw.Widget> _indiceConSeccionesYPartidas(List<Map<String, dynamic>> fotos) {
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
          margin: pw.EdgeInsets.only(top: 8, bottom: 4),
          padding: pw.EdgeInsets.all(7),
          color: colorFondo,
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(destino?['nombre'] ?? 'Sin nombre',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: colorTexto)),
            if ((destino?['informacion'] ?? '').toString().isNotEmpty)
              pw.Text(destino!['informacion'].toString(), style: pw.TextStyle(fontSize: 8)),
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
      margin: pw.EdgeInsets.only(bottom: 5), padding: pw.EdgeInsets.all(7),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: _gris, width: 0.5)),
      child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.SizedBox(width: 24, child: pw.Text('${entry.key + 1}.',
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
        pw.Container(padding: pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2), color: color,
            child: pw.Text(tipo, style: pw.TextStyle(fontSize: 8, color: PdfColors.white))),
        pw.SizedBox(width: 8),
        pw.Expanded(child: pw.Text(desc.isNotEmpty ? desc : '(sin descripcion)',
            style: pw.TextStyle(fontSize: 9))),
      ]),
    );
  }

  static pw.TableRow _row(String label, String value, {bool bold = false}) {
    return pw.TableRow(children: [
      pw.Padding(
        padding: pw.EdgeInsets.all(6),
        child: pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: _azul)),
      ),
      pw.Padding(
        padding: pw.EdgeInsets.all(6),
        child: pw.Text(value.isNotEmpty ? value : '-',
            style: pw.TextStyle(fontSize: 9, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
      ),
    ]);
  }

  static PdfColor _colorTipo(String tipo) {
    if (tipo == 'Averia') return _rojo;
    if (tipo == 'Mercancia') return _azul;
    return _naranja;
  }
}