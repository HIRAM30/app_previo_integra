// ============================================================
// Integra Del Centro, S.C.
// Desarrollado por: HIRAM JAFET VELAZQUEZ SANTANDER
// services/pdf_service_previo.dart v8.0
// Cambios v8.0 (capacidad de fotos):
//   - Ya no se cargan TODAS las fotos en RAM a la vez.
//   - Con muchas fotos (> _umbralReduccion) se reducen a ~1100 px
//     antes de armar el PDF (nativo, una por una).
//   - El isolate escribe el PDF directo a disco y devuelve solo la
//     ruta (antes devolvia todos los bytes = copia extra en RAM).
//   - Si hay mas de _maxFotosPorPdf fotos, se generan varias partes
//     (Previo_REF_parte1de3.pdf ...) y se comparten juntas. Nunca
//     se trunca el contenido.
//   - Una foto danada ya no aborta todo el PDF (placeholder).
//   - Se avisa cuantas fotos no se encontraron en el telefono.
//   - maxPages de MultiPage subido (indice largo).
// ============================================================

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

class PdfServicePrevio {
  // ── Capacidad (ajustables) ──────────────────────────────────
  /// Fotos maximas dentro de un mismo archivo PDF. Si el previo tiene
  /// mas, se divide automaticamente en partes.
  static const int _maxFotosPorPdf = 200;

  /// Desde esta cantidad de fotos se reducen (resolucion/calidad)
  /// antes de meterlas al PDF para ahorrar memoria.
  static const int _umbralReduccion = 60;
  static const int _ladoReducido = 1100;
  static const int _calidadReducida = 72;
  static const int _pesoMinimoParaReducir = 250 * 1024; // bytes

  static final PdfColor _azul = PdfColor.fromInt(0xFF003087);
  static final PdfColor _rojo = PdfColor.fromInt(0xFFB71C1C);
  static final PdfColor _naranja = PdfColor.fromInt(0xFFE65100);
  static final PdfColor _verde = PdfColor.fromInt(0xFF2E7D32);
  static final PdfColor _gris = PdfColor.fromInt(0xFFE0E0E0);
  static final PdfColor _naranjaClaro = PdfColor.fromInt(0xFFFFF3E0);
  static final PdfColor _azulClaro = PdfColor.fromInt(0xFFE3F2FD);

  static Future<void> generarYCompartir(
    Map previo,
    BuildContext context,
  ) async {
    Directory? tmpDir;
    try {
      final fotosPaths = List<String>.from(previo['fotos'] ?? []);
      final tipos = List<String>.from(previo['fotosTipos'] ?? []);
      final descs = List<String>.from(previo['fotosDescripciones'] ?? []);
      final fotoBloques = List<String>.from(previo['fotosBloques'] ?? []);
      final secciones = List<Map>.from(previo['secciones'] ?? []);
      final partidas = List<Map>.from(
        previo['partidas'] ?? previo['particiones'] ?? [],
      );

      final tipoBulto =
          (previo['tiposBulto'] is List &&
              (previo['tiposBulto'] as List).isNotEmpty)
          ? (previo['tiposBulto'] as List).join(', ')
          : (previo['tipoBulto'] ?? '');

      final cabecera = <String, dynamic>{
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
        'numSecciones': secciones.length,
        'numPartidas': partidas.length,
      };

      // 1) Metadatos de fotos (SIN cargar bytes)
      final prep = _prepararFotos(
        fotosPaths: fotosPaths,
        tipos: tipos,
        descs: descs,
        fotoBloques: fotoBloques,
        secciones: secciones,
        partidas: partidas,
      );
      final validas = prep.fotos;
      final omitidas = prep.omitidas;

      if (validas.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No hay fotos para generar el PDF'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      Directory dir;
      try {
        dir = await getApplicationDocumentsDirectory();
      } catch (_) {
        dir = Directory.systemTemp;
      }
      final ref = '${previo['referencia'] ?? 'Previo'}'.replaceAll(
        RegExp(r'[^a-zA-Z0-9_-]'),
        '_',
      );

      final totalFotos = validas.length;
      final totalPartes = (totalFotos / _maxFotosPorPdf).ceil();
      final reducir = totalFotos > _umbralReduccion;

      if (reducir) {
        Directory base;
        try {
          base = await getTemporaryDirectory();
        } catch (_) {
          base = Directory.systemTemp;
        }
        tmpDir = await base.createTemp('pdf_previo_');
      }

      // 2) Una parte a la vez (la memoria se libera entre partes)
      final archivos = <String>[];
      for (var p = 0; p < totalPartes; p++) {
        final ini = p * _maxFotosPorPdf;
        final fin = math.min(ini + _maxFotosPorPdf, totalFotos);

        final fotosParte = <Map<String, dynamic>>[];
        for (var i = ini; i < fin; i++) {
          final f = Map<String, dynamic>.from(validas[i]);
          if (reducir) {
            f['path'] = await _reducirFoto(
              f['path'] as String,
              tmpDir!.path,
              i,
            );
          }
          fotosParte.add(f);
        }

        final sufijo = totalPartes > 1 ? '_parte${p + 1}de$totalPartes' : '';
        final outPath = '${dir.path}/Previo_$ref$sufijo.pdf';

        final String? resultado = await compute(
          _construirPdfPrevioEnIsolate,
          <String, dynamic>{
            ...cabecera,
            'outPath': outPath,
            'fotos': fotosParte,
            // el indice completo solo va en la parte 1
            'fotosIndice': p == 0 ? validas : <Map<String, dynamic>>[],
            'offset': ini,
            'totalFotos': totalFotos,
            'parte': p + 1,
            'totalPartes': totalPartes,
          },
        );

        if (resultado == null || !File(resultado).existsSync()) {
          throw Exception('No se pudo generar la parte ${p + 1} del PDF');
        }
        archivos.add(resultado);

        // limpiar las fotos reducidas de esta parte
        if (reducir && tmpDir != null) {
          try {
            await tmpDir.delete(recursive: true);
            await tmpDir.create(recursive: true);
          } catch (_) {}
        }
      }

      await SharePlus.instance.share(
        ShareParams(
          files: archivos.map((a) => XFile(a)).toList(),
          text:
              'Previo Aduanal - ${previo['referencia']}\n'
              'Integra Del Centro S.C.',
        ),
      );

      if (context.mounted) {
        final String msg;
        if (omitidas > 0) {
          msg =
              'Previo generado con $totalFotos fotos '
              '($omitidas no se encontraron en el telefono y se omitieron)';
        } else if (totalPartes > 1) {
          msg = 'Previo generado en $totalPartes archivos PDF';
        } else {
          msg = 'Previo generado correctamente';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: omitidas > 0 ? Colors.orange : Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (tmpDir != null) {
        try {
          await tmpDir.delete(recursive: true);
        } catch (_) {}
      }
    }
  }

  // ───────────────────────────────────────────────────────────
  // Prepara metadatos y orden de fotos (sin leer bytes)
  // ───────────────────────────────────────────────────────────
  static _FotosPreparadas _prepararFotos({
    required List<String> fotosPaths,
    required List<String> tipos,
    required List<String> descs,
    required List<String> fotoBloques,
    required List<Map> secciones,
    required List<Map> partidas,
  }) {
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
    int omitidas = 0;
    for (var i = 0; i < fotosPaths.length; i++) {
      final path = fotosPaths[i];
      try {
        final file = File(path);
        if (!file.existsSync() || file.lengthSync() <= 0) {
          omitidas++;
          continue;
        }
      } catch (_) {
        omitidas++;
        continue;
      }

      final bloqueId = i < fotoBloques.length ? fotoBloques[i] : '';
      validas.add({
        'path': path,
        'tipo': i < tipos.length ? tipos[i] : 'Mercancia',
        'desc': i < descs.length ? descs[i] : '',
        'bloqueId': bloqueId,
        'destino': todosLosDestinos[bloqueId],
        'tipoDestino': tipoDestino[bloqueId] ?? 'partida',
        'ordenOriginal': i,
      });
    }

    validas.sort((a, b) {
      final ordenA = ordenDestino[a['bloqueId']] ?? 999999;
      final ordenB = ordenDestino[b['bloqueId']] ?? 999999;
      if (ordenA != ordenB) return ordenA.compareTo(ordenB);
      return (a['ordenOriginal'] as int).compareTo(b['ordenOriginal'] as int);
    });

    return _FotosPreparadas(validas, omitidas);
  }

  // ───────────────────────────────────────────────────────────
  // Reduce una foto (nativo, una por una). Si falla, usa la original.
  // ───────────────────────────────────────────────────────────
  static Future<String> _reducirFoto(
    String path,
    String outDir,
    int idx,
  ) async {
    try {
      if (File(path).lengthSync() < _pesoMinimoParaReducir) return path;
      final out = '$outDir/r_$idx.jpg';
      final r = await FlutterImageCompress.compressAndGetFile(
        path,
        out,
        quality: _calidadReducida,
        minWidth: _ladoReducido,
        minHeight: _ladoReducido,
        format: CompressFormat.jpeg,
      );
      if (r == null) return path;
      final f = File(r.path);
      if (f.existsSync() && f.lengthSync() > 0) return r.path;
    } catch (e) {
      debugPrint('[PdfServicePrevio] _reducirFoto error: $e');
    }
    return path;
  }

  // ───────────────────────────────────────────────────────────
  // Construye UNA parte del PDF en un isolate y la escribe a disco.
  // Devuelve la ruta del archivo (no los bytes).
  // ───────────────────────────────────────────────────────────
  static Future<String?> _construirPdfPrevioEnIsolate(
    Map<String, dynamic> args,
  ) async {
    final fotosMeta = List<Map>.from(args['fotos'] ?? []);
    final fotosIndice = (args['fotosIndice'] as List? ?? [])
        .map((m) => Map<String, dynamic>.from(m as Map))
        .toList();
    final offset = args['offset'] as int;
    final totalFotos = args['totalFotos'] as int;
    final parte = args['parte'] as int;
    final totalPartes = args['totalPartes'] as int;
    final outPath = args['outPath'] as String;
    final numSecciones = args['numSecciones'] as int;
    final numPartidas = args['numPartidas'] as int;

    // Leer bytes SOLO de las fotos de esta parte
    final validas = <Map<String, dynamic>>[];
    for (final f in fotosMeta) {
      Uint8List bytes;
      try {
        bytes = await File(f['path'] as String).readAsBytes();
      } catch (_) {
        bytes = Uint8List(0);
      }
      final m = Map<String, dynamic>.from(f);
      m['bytes'] = bytes;
      validas.add(m);
    }
    if (validas.isEmpty) return null;

    final pdf = pw.Document(
      title: 'Previo - ${args['referencia']}',
      author: 'Integra Del Centro S.C.',
    );

    if (parte == 1) {
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          maxPages: 10000,
          header: (_) => pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 8),
            decoration: pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: _azul, width: 2)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'PREVIO ADUANAL',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: _azul,
                  ),
                ),
                pw.Text(
                  'Integra Del Centro, S.C.',
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey),
                ),
              ],
            ),
          ),
          footer: (context) => pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Pagina ${context.pageNumber} de ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
            ),
          ),
          build: (_) => [
            pw.SizedBox(height: 14),
            pw.Table(
              border: pw.TableBorder.all(color: _gris, width: 0.5),
              children: [
                _row(
                  'Referencia / Master',
                  args['referencia'] as String,
                  bold: true,
                ),
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
                if (totalPartes > 1)
                  _row(
                    'Archivo',
                    'Parte 1 de $totalPartes (fotos 1 a ${validas.length} de $totalFotos)',
                  ),
              ],
            ),
            pw.SizedBox(height: 18),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
              children: [
                _statBox(
                  'Total Fotos',
                  '$totalFotos',
                  _azul,
                  PdfColor.fromInt(0xFFE8ECF3),
                ),
                _statBox('Secciones', '$numSecciones', _naranja, _naranjaClaro),
                _statBox(
                  'Partidas',
                  '$numPartidas',
                  _verde,
                  PdfColor.fromInt(0xFFE8F5E9),
                ),
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Text(
              'Indice de fotografias:',
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                color: _azul,
              ),
            ),
            pw.SizedBox(height: 8),
            ..._indiceConSeccionesYPartidas(fotosIndice),
          ],
        ),
      );
    } else {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (_) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'PREVIO ADUANAL',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                  color: _azul,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'Referencia / Master: ${args['referencia']}',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Parte $parte de $totalPartes - fotos ${offset + 1} a '
                '${offset + validas.length} de $totalFotos',
                style: const pw.TextStyle(fontSize: 11),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'El indice completo esta en la parte 1.',
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey700,
                ),
              ),
            ],
          ),
        ),
      );
    }

    for (var i = 0; i < validas.length; i += 2) {
      final foto1 = validas[i];
      final foto2 = (i + 1 < validas.length) ? validas[i + 1] : null;
      final n1 = offset + i + 1;
      final n2 = offset + i + 2;

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          build: (_) => pw.Column(
            children: [
              pw.Expanded(flex: 1, child: _buildFoto(foto1, n1, args)),
              pw.SizedBox(height: 10),
              if (foto2 != null)
                pw.Expanded(flex: 1, child: _buildFoto(foto2, n2, args))
              else
                pw.Expanded(flex: 1, child: pw.SizedBox()),
            ],
          ),
        ),
      );
    }

    final pdfBytes = await pdf.save();
    await File(outPath).writeAsBytes(pdfBytes, flush: true);
    return outPath;
  }

  static pw.Widget _statBox(
    String label,
    String value,
    PdfColor textColor,
    PdfColor bgColor,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: pw.BoxDecoration(color: bgColor),
      child: pw.Column(
        children: [
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: textColor,
            ),
          ),
          pw.Text(label, style: pw.TextStyle(fontSize: 7, color: textColor)),
        ],
      ),
    );
  }

  static pw.Widget _buildFoto(
    Map<String, dynamic> foto,
    int numero,
    Map<String, dynamic> args,
  ) {
    final bytes = foto['bytes'] as Uint8List;
    final tipo = foto['tipo'] as String;
    final desc = foto['desc'] as String;
    final color = _colorTipo(tipo);
    final destino = foto['destino'] as Map?;
    final tipoDestino = foto['tipoDestino'] as String? ?? 'partida';

    // Una foto danada/ilegible no debe abortar todo el PDF
    pw.ImageProvider? imagen;
    try {
      if (bytes.isNotEmpty) imagen = pw.MemoryImage(bytes);
    } catch (_) {
      imagen = null;
    }

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: color, width: 2),
      ),
      child: pw.Column(
        children: [
          pw.Container(
            height: 28,
            color: color,
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Row(
                  children: [
                    pw.Container(
                      width: 20,
                      height: 20,
                      decoration: pw.BoxDecoration(
                        shape: pw.BoxShape.circle,
                        color: PdfColors.white,
                      ),
                      child: pw.Center(
                        child: pw.Text(
                          '$numero',
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ),
                    ),
                    pw.SizedBox(width: 8),
                    pw.Text(
                      tipo.toUpperCase(),
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                pw.Text(
                  args['referencia'] as String? ?? '',
                  style: const pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 8,
                  ),
                ),
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
                  pw.Text(
                    '${destino['nombre'] ?? ''}',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: tipoDestino == 'seccion' ? _naranja : _azul,
                    ),
                  ),
                  if ((destino['informacion'] ?? '').toString().isNotEmpty)
                    pw.Text(
                      destino['informacion'].toString(),
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                ],
              ),
            ),
          pw.Expanded(
            child: pw.Container(
              color: PdfColors.black,
              child: pw.Center(
                child: imagen != null
                    ? pw.Image(imagen, fit: pw.BoxFit.contain)
                    : pw.Text(
                        'Imagen no disponible',
                        style: const pw.TextStyle(
                          color: PdfColors.grey500,
                          fontSize: 10,
                        ),
                      ),
              ),
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
                        child: pw.Text(
                          desc,
                          style: const pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  )
                : pw.Text(
                    'Sin descripcion',
                    style: const pw.TextStyle(
                      color: PdfColors.grey500,
                      fontSize: 9,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  static List<pw.Widget> _indiceConSeccionesYPartidas(
    List<Map<String, dynamic>> fotos,
  ) {
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

        resultado.add(
          pw.Container(
            width: double.infinity,
            margin: const pw.EdgeInsets.only(top: 8, bottom: 4),
            padding: const pw.EdgeInsets.all(7),
            color: colorFondo,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  destino?['nombre'] ?? 'Sin nombre',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: colorTexto,
                  ),
                ),
                if ((destino?['informacion'] ?? '').toString().isNotEmpty)
                  pw.Text(
                    destino!['informacion'].toString(),
                    style: const pw.TextStyle(fontSize: 8),
                  ),
              ],
            ),
          ),
        );
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
        border: pw.Border.all(color: _gris, width: 0.5),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 24,
            child: pw.Text(
              '${entry.key + 1}.',
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            color: color,
            child: pw.Text(
              tipo,
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.white),
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Expanded(
            child: pw.Text(
              desc.isNotEmpty ? desc : '(sin descripcion)',
              style: const pw.TextStyle(fontSize: 9),
            ),
          ),
        ],
      ),
    );
  }

  static pw.TableRow _row(String label, String value, {bool bold = false}) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(
            label,
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 9,
              color: _azul,
            ),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(
            value.isNotEmpty ? value : '-',
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }

  static PdfColor _colorTipo(String tipo) {
    if (tipo == 'Averia') return _rojo;
    if (tipo == 'Mercancia') return _azul;
    return _naranja;
  }
}

class _FotosPreparadas {
  final List<Map<String, dynamic>> fotos;
  final int omitidas;
  _FotosPreparadas(this.fotos, this.omitidas);
}
