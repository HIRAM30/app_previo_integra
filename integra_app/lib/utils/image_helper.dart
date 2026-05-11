// ============================================================
// Integra Del Centro, S.C.
// Desarrollado por: HIRAM JAFET VELAZQUEZ SANTANDER
// utils/image_helper.dart
// Descripción: Compresión de imágenes y detección automática
//   de tipo de documento usando la API de Claude Haiku.
//   compressImage()   → fotos de mercancía y avería (82% calidad)
//   compressDocument()→ documentos aduanales (92% calidad, mayor res.)
//   detectDocumentType() → llama a Claude para identificar el tipo
//     de documento: Pedimento, Factura, BL, Packing List, etc.
// ============================================================

import 'dart:convert';
import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class ImageHelper {
  /// Comprime imagen de mercancía o avería con calidad estándar.
  static Future<File?> compressImage(File file) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final path =
          '${dir.path}/img_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path, path,
        quality: 82, minWidth: 1280, minHeight: 1280,
        format: CompressFormat.jpeg,
      );
      return result == null ? null : File(result.path);
    } catch (e) {
      print('[ImageHelper] compressImage error: $e');
      return null;
    }
  }

  /// Comprime documento con mayor calidad para que el texto sea legible.
  static Future<File?> compressDocument(File file) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final path =
          '${dir.path}/doc_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path, path,
        quality: 92, minWidth: 1600, minHeight: 1600,
        format: CompressFormat.jpeg,
      );
      return result == null ? null : File(result.path);
    } catch (e) {
      print('[ImageHelper] compressDocument error: $e');
      return null;
    }
  }

  /// Usa Claude Haiku para detectar el tipo de documento aduanal.
  /// Devuelve el nombre del tipo o "Documento" si la API falla.
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
