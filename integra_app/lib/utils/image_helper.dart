// ============================================================
// Integra Del Centro, S.C.
// Desarrollado por: HIRAM JAFET VELAZQUEZ SANTANDER
// utils/image_helper.dart v3.3
// Descripción:
//   - compressImage()    → comprime foto de mercancía/avería
//   - compressDocument() → comprime documento con alta calidad
//   - detectDocumentType() → detecta tipo de doc con Claude IA
//   - fixRotation()      → corrige rotación EXIF antes de comprimir
//   - Tolerante a fallos: si falla la compresión, devuelve la original
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
  static Future<File> fixRotation(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final orientation = _readExifOrientation(bytes);

      if (orientation <= 1) return file;

      // Usar directorio temporal que funciona en todas las plataformas
      final dir = await _getSafeDirectory();
      final outPath = '${dir.path}/rot_${DateTime.now().millisecondsSinceEpoch}.jpg';

      int rotar = 0;
      switch (orientation) {
        case 3: rotar = 180; break;
        case 6: rotar = 90; break;
        case 8: rotar = 270; break;
        default: rotar = 0;
      }

      if (rotar == 0) return file;

      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        outPath,
        quality: 100,
        rotate: rotar,
        format: CompressFormat.jpeg,
      );
      return result != null ? File(result.path) : file;
    } catch (e) {
      print('[ImageHelper] fixRotation error: $e');
      return file;
    }
  }

  // ── OBTENER DIRECTORIO SEGURO ────────────────────────────────
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

      final endian = String.fromCharCodes(bytes.sublist(tiffStart, tiffStart + 2));
      final littleEndian = endian == 'II';

      final ifdOffset = _readUint32(bytes, tiffStart + 4, littleEndian);
      final ifdStart = tiffStart + ifdOffset;

      if (ifdStart + 2 >= bytes.length) return 1;
      final numEntries = _readUint16(bytes, ifdStart, littleEndian);

      for (int i = 0; i < numEntries; i++) {
        final entryOffset = ifdStart + 2 + (i * 12);
        if (entryOffset + 12 >= bytes.length) break;
        final tag = _readUint16(bytes, entryOffset, littleEndian);
        if (tag == 0x0112) return _readUint16(bytes, entryOffset + 8, littleEndian);
      }
      return 1;
    } catch (_) {
      return 1;
    }
  }

  static int _readUint16(Uint8List b, int offset, bool le) {
    if (offset + 1 >= b.length) return 0;
    return le ? b[offset] | (b[offset + 1] << 8) : (b[offset] << 8) | b[offset + 1];
  }

  static int _readUint32(Uint8List b, int offset, bool le) {
    if (offset + 3 >= b.length) return 0;
    return le
        ? b[offset] | (b[offset + 1] << 8) | (b[offset + 2] << 16) | (b[offset + 3] << 24)
        : (b[offset] << 24) | (b[offset + 1] << 16) | (b[offset + 2] << 8) | b[offset + 3];
  }

  // ── COMPRESIÓN DE IMÁGENES ────────────────────────────────────
  static Future<File?> compressImage(File file) async {
    try {
      final rotated = await fixRotation(file);
      final dir = await _getSafeDirectory();
      final outPath = '${dir.path}/img_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final result = await FlutterImageCompress.compressAndGetFile(
        rotated.absolute.path,
        outPath,
        quality: 82,
        minWidth: 1280,
        minHeight: 1280,
        format: CompressFormat.jpeg,
      );
      return result != null ? File(result.path) : file;
    } catch (e) {
      // Si falla la compresión, devolver la imagen original para no bloquear al usuario
      print('[ImageHelper] compressImage error, usando original: $e');
      return file;
    }
  }

  static Future<File?> compressDocument(File file) async {
    try {
      final rotated = await fixRotation(file);
      final dir = await _getSafeDirectory();
      final outPath = '${dir.path}/doc_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final result = await FlutterImageCompress.compressAndGetFile(
        rotated.absolute.path,
        outPath,
        quality: 92,
        minWidth: 1600,
        minHeight: 1600,
        format: CompressFormat.jpeg,
      );
      return result != null ? File(result.path) : file;
    } catch (e) {
      print('[ImageHelper] compressDocument error, usando original: $e');
      return file;
    }
  }

  // ── DETECCIÓN DE TIPO DE DOCUMENTO CON IA ───────────────────
  static Future<String?> detectDocumentType(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final b64 = base64Encode(bytes);

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