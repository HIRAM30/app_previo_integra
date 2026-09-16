// ============================================================
// Integra Del Centro, S.C.
// Desarrollado por: HIRAM JAFET VELAZQUEZ SANTANDER
// utils/image_helper.dart v4.0
// Cambios:
//   - compressImage/compressDocument usan compute() para
//     no bloquear el UI thread.
//   - detectDocumentType con timeout.
//   - detectarTipoEnBackground() no bloqueante.
//   - fixRotation corre en isolate.
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class ImageHelper {
  static Future<Directory> _getSafeDirectory() async {
    try {
      return await getApplicationDocumentsDirectory();
    } catch (_) {
      try {
        return await getTemporaryDirectory();
      } catch (__) {
        return Directory.systemTemp;
      }
    }
  }

  // ═══════════════════════════════════════════════════════════
  // COMPRESIÓN EN ISOLATE
  // ═══════════════════════════════════════════════════════════

  static Future<File?> compressImage(File file) async {
    try {
      final dir = await _getSafeDirectory();
      final outPath =
          '${dir.path}/img_${DateTime.now().microsecondsSinceEpoch}.jpg';

      final resultPath = await compute(_comprimirEnIsolate, {
        'inPath': file.absolute.path,
        'outPath': outPath,
        'quality': 82,
        'minSize': 1280,
      });

      return resultPath != null ? File(resultPath) : file;
    } catch (e) {
      debugPrint('[ImageHelper] compressImage error: $e');
      return file;
    }
  }

  static Future<File?> compressDocument(File file) async {
    try {
      final dir = await _getSafeDirectory();
      final outPath =
          '${dir.path}/doc_${DateTime.now().microsecondsSinceEpoch}.jpg';

      final resultPath = await compute(_comprimirEnIsolate, {
        'inPath': file.absolute.path,
        'outPath': outPath,
        'quality': 92,
        'minSize': 1600,
      });

      return resultPath != null ? File(resultPath) : file;
    } catch (e) {
      debugPrint('[ImageHelper] compressDocument error: $e');
      return file;
    }
  }

  static Future<String?> _comprimirEnIsolate(Map<String, dynamic> args) async {
    final inPath = args['inPath'] as String;
    final outPath = args['outPath'] as String;
    final quality = args['quality'] as int;
    final minSize = args['minSize'] as int;

    final rotated = await _fixRotationEnIsolate(inPath);

    final result = await FlutterImageCompress.compressAndGetFile(
      rotated,
      outPath,
      quality: quality,
      minWidth: minSize,
      minHeight: minSize,
      format: CompressFormat.jpeg,
    );
    return result?.path;
  }

  static Future<String> _fixRotationEnIsolate(String inPath) async {
    try {
      final bytes = await File(inPath).readAsBytes();
      final orientation = _readExifOrientation(bytes);
      if (orientation <= 1) return inPath;

      int rotar = 0;
      switch (orientation) {
        case 3:
          rotar = 180;
          break;
        case 6:
          rotar = 90;
          break;
        case 8:
          rotar = 270;
          break;
        default:
          return inPath;
      }
      if (rotar == 0) return inPath;

      final dir = Directory(inPath).parent.path;
      final outPath = '$dir/rot_${DateTime.now().microsecondsSinceEpoch}.jpg';

      final result = await FlutterImageCompress.compressAndGetFile(
        inPath,
        outPath,
        quality: 100,
        rotate: rotar,
        format: CompressFormat.jpeg,
      );
      return result?.path ?? inPath;
    } catch (_) {
      return inPath;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // DETECCIÓN DE TIPO DE DOCUMENTO
  // ═══════════════════════════════════════════════════════════

  static Future<String?> detectDocumentType(
    File imageFile, {
    Duration timeout = const Duration(seconds: 12),
  }) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final b64 = base64Encode(bytes);

      final client = http.Client();
      try {
        final response = await client
            .post(
              Uri.parse('https://api.anthropic.com/v1/messages'),
              headers: {
                'Content-Type': 'application/json',
                'anthropic-version': '2023-06-01',
              },
              body: jsonEncode({
                'model': 'claude-haiku-4-5-20251001',
                'max_tokens': 60,
                'messages': [
                  {
                    'role': 'user',
                    'content': [
                      {
                        'type': 'image',
                        'source': {
                          'type': 'base64',
                          'media_type': 'image/jpeg',
                          'data': b64,
                        },
                      },
                      {
                        'type': 'text',
                        'text':
                            'Eres experto en comercio exterior mexicano. '
                                'Identifica el tipo de documento aduanal. '
                                'Responde SOLO con el nombre, sin explicación. '
                                'Ejemplos: Pedimento, Factura Comercial, '
                                'BL / Conocimiento de Embarque, Air Way Bill, '
                                'Packing List, Certificado de Origen, DODA, '
                                'Declaración de Valor, Permiso de Importación, '
                                'Carta de Encomienda, Otro Documento. '
                                'Si no es documento aduanal: Mercancía',
                      },
                    ],
                  },
                ],
              }),
            )
            .timeout(timeout);

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          return (data['content'][0]['text'] as String).trim();
        }
        return 'Documento';
      } finally {
        client.close();
      }
    } catch (e) {
      debugPrint('[ImageHelper] detectDocumentType error: $e');
      return 'Documento';
    }
  }

  static void detectarTipoEnBackground(
    File imageFile, {
    required void Function(String tipo) onResultado,
    Duration timeout = const Duration(seconds: 12),
  }) {
    detectDocumentType(imageFile, timeout: timeout).then((tipo) {
      onResultado(tipo ?? 'Documento');
    }).catchError((_) {
      onResultado('Documento');
    });
  }

  // ═══════════════════════════════════════════════════════════
  // EXIF
  // ═══════════════════════════════════════════════════════════

  static int _readExifOrientation(Uint8List bytes) {
    try {
      if (bytes.length < 4 || bytes[0] != 0xFF || bytes[1] != 0xD8) return 1;
      int offset = 2;
      while (offset < bytes.length - 4) {
        if (bytes[offset] != 0xFF) break;
        final marker = bytes[offset + 1];
        final segmentLength = (bytes[offset + 2] << 8) | bytes[offset + 3];
        if (marker == 0xE1) return _parseExifOrientation(bytes, offset + 4);
        offset += 2 + segmentLength;
      }
      return 1;
    } catch (_) {
      return 1;
    }
  }

  static int _parseExifOrientation(Uint8List bytes, int start) {
    try {
      if (start + 6 >= bytes.length) return 1;
      final header = String.fromCharCodes(bytes.sublist(start, start + 4));
      if (header != 'Exif') return 1;

      final tiffStart = start + 6;
      if (tiffStart + 8 >= bytes.length) return 1;

      final endian =
          String.fromCharCodes(bytes.sublist(tiffStart, tiffStart + 2));
      final littleEndian = endian == 'II';

      final ifdOffset = _readUint32(bytes, tiffStart + 4, littleEndian);
      final ifdStart = tiffStart + ifdOffset;

      if (ifdStart + 2 >= bytes.length) return 1;
      final numEntries = _readUint16(bytes, ifdStart, littleEndian);

      for (int i = 0; i < numEntries; i++) {
        final entryOffset = ifdStart + 2 + (i * 12);
        if (entryOffset + 12 >= bytes.length) break;
        final tag = _readUint16(bytes, entryOffset, littleEndian);
        if (tag == 0x0112) {
          return _readUint16(bytes, entryOffset + 8, littleEndian);
        }
      }
      return 1;
    } catch (_) {
      return 1;
    }
  }

  static int _readUint16(Uint8List b, int offset, bool le) {
    if (offset + 1 >= b.length) return 0;
    return le
        ? b[offset] | (b[offset + 1] << 8)
        : (b[offset] << 8) | b[offset + 1];
  }

  static int _readUint32(Uint8List b, int offset, bool le) {
    if (offset + 3 >= b.length) return 0;
    return le
        ? b[offset] |
            (b[offset + 1] << 8) |
            (b[offset + 2] << 16) |
            (b[offset + 3] << 24)
        : (b[offset] << 24) |
            (b[offset + 1] << 16) |
            (b[offset + 2] << 8) |
            b[offset + 3];
  }
}