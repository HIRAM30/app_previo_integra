// ============================================================
// Integra Del Centro, S.C.
// Desarrollado por: HIRAM JAFET VELAZQUEZ SANTANDER
// utils/image_helper.dart v3.1
// Descripción:
//   - compressImage()    → comprime foto de mercancía/avería
//   - compressDocument() → comprime documento con alta calidad
//   - detectDocumentType() → detecta tipo de doc con Claude IA
//   - fixRotation()      → NUEVO: corrige rotación EXIF antes
//     de comprimir para que la foto se vea completa en el PDF
//     sin importar el ángulo con que se tomó (vertical/horizontal)
// ============================================================

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class ImageHelper {

  // ── CORRECCIÓN DE ROTACIÓN EXIF ──────────────────────────────
  /// Lee el tag de orientación EXIF de un JPEG y rota los
  /// bytes de la imagen para que quede derecha.
  /// Esto evita que en el PDF aparezca recortada o acostada.
  ///
  /// Flutter y jsPDF ignoran el tag EXIF de orientación,
  /// así que corregimos la imagen ANTES de comprimir.
  static Future<File> fixRotation(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final orientation = _readExifOrientation(bytes);

      // Si la orientación es 1 (normal) o no se pudo leer, no hacer nada
      if (orientation <= 1) return file;

      // Rotar usando flutter_image_compress según la orientación EXIF
      final dir = await getApplicationDocumentsDirectory();
      final outPath =
          '${dir.path}/rot_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Mapa de orientación EXIF → grados de rotación
      // 1 = normal, 3 = 180°, 6 = 90° CW, 8 = 90° CCW
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
          rotar = 0;
      }

      if (rotar == 0) return file;

      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        outPath,
        quality: 100,     // Sin pérdida de calidad en esta etapa
        rotate: rotar,    // Rotar al ángulo correcto
        format: CompressFormat.jpeg,
      );

      return result != null ? File(result.path) : file;
    } catch (e) {
      // Si falla la corrección de EXIF, devolver original sin romper
      print('[ImageHelper] fixRotation error: $e');
      return file;
    }
  }

  /// Lee el tag de orientación EXIF directamente de los bytes JPEG.
  /// Devuelve 1 (normal) si no se encuentra o hay error.
  static int _readExifOrientation(Uint8List bytes) {
    try {
      // Los archivos JPEG empiezan con FFD8
      if (bytes.length < 4 ||
          bytes[0] != 0xFF ||
          bytes[1] != 0xD8) return 1;

      int offset = 2;
      while (offset < bytes.length - 4) {
        // Cada segmento EXIF/APP empieza con FF
        if (bytes[offset] != 0xFF) break;

        final marker = bytes[offset + 1];
        final segmentLength =
            (bytes[offset + 2] << 8) | bytes[offset + 3];

        // APP1 (0xE1) contiene los datos EXIF
        if (marker == 0xE1) {
          return _parseExifOrientation(bytes, offset + 4);
        }

        // Saltar al siguiente segmento
        offset += 2 + segmentLength;
      }
      return 1;
    } catch (_) {
      return 1;
    }
  }

  /// Parsea el bloque EXIF buscando el tag de orientación (0x0112).
  static int _parseExifOrientation(Uint8List bytes, int start) {
    try {
      // Verificar cabecera EXIF: "Exif\0\0"
      if (start + 6 >= bytes.length) return 1;
      final header = String.fromCharCodes(bytes.sublist(start, start + 4));
      if (header != 'Exif') return 1;

      // El IFD empieza después de la cabecera "Exif\0\0" + cabecera TIFF
      final tiffStart = start + 6;
      if (tiffStart + 8 >= bytes.length) return 1;

      // Detectar endianness: "II" = little endian, "MM" = big endian
      final endian = String.fromCharCodes(
          bytes.sublist(tiffStart, tiffStart + 2));
      final littleEndian = endian == 'II';

      // Offset del primer IFD (desde tiffStart)
      final ifdOffset = _readUint32(bytes, tiffStart + 4, littleEndian);
      final ifdStart  = tiffStart + ifdOffset;

      if (ifdStart + 2 >= bytes.length) return 1;

      // Número de entries en el IFD
      final numEntries = _readUint16(bytes, ifdStart, littleEndian);

      // Recorrer entries buscando el tag 0x0112 (orientación)
      for (int i = 0; i < numEntries; i++) {
        final entryOffset = ifdStart + 2 + (i * 12);
        if (entryOffset + 12 >= bytes.length) break;

        final tag = _readUint16(bytes, entryOffset, littleEndian);
        if (tag == 0x0112) {
          // El valor de orientación está en bytes 8-9 del entry
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

  // ── COMPRESIÓN DE IMÁGENES ────────────────────────────────────

  /// Comprime imagen de mercancía o avería.
  /// Primero corrige la rotación EXIF para que se vea completa
  /// en el PDF sin importar el ángulo con que se tomó.
  static Future<File?> compressImage(File file) async {
    try {
      // Paso 1: corregir rotación EXIF
      final rotated = await fixRotation(file);

      // Paso 2: comprimir con calidad estándar
      final dir = await getApplicationDocumentsDirectory();
      final outPath =
          '${dir.path}/img_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final result = await FlutterImageCompress.compressAndGetFile(
        rotated.absolute.path,
        outPath,
        quality: 82,
        minWidth: 1280,
        minHeight: 1280,
        format: CompressFormat.jpeg,
        // rotate: 0 porque ya corregimos arriba
      );
      return result == null ? null : File(result.path);
    } catch (e) {
      print('[ImageHelper] compressImage error: $e');
      return null;
    }
  }

  /// Comprime documento con mayor calidad para que el texto sea legible.
  /// También corrige rotación EXIF.
  static Future<File?> compressDocument(File file) async {
    try {
      // Paso 1: corregir rotación
      final rotated = await fixRotation(file);

      // Paso 2: comprimir con alta calidad
      final dir = await getApplicationDocumentsDirectory();
      final outPath =
          '${dir.path}/doc_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final result = await FlutterImageCompress.compressAndGetFile(
        rotated.absolute.path,
        outPath,
        quality: 92,
        minWidth: 1600,
        minHeight: 1600,
        format: CompressFormat.jpeg,
      );
      return result == null ? null : File(result.path);
    } catch (e) {
      print('[ImageHelper] compressDocument error: $e');
      return null;
    }
  }

  // ── DETECCIÓN DE TIPO DE DOCUMENTO CON IA ───────────────────

  /// Usa Claude Haiku para identificar el tipo de documento aduanal.
  static Future<String?> detectDocumentType(File imageFile) async {
    try {
      final bytes  = await imageFile.readAsBytes();
      final b64    = base64Encode(bytes);

      final response = await http.post(
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
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['content'][0]['text'] as String).trim();
      }
      return 'Documento';
    } catch (e) {
      print('[ImageHelper] detectDocumentType error: $e');
      return 'Documento';
    }
  }
}