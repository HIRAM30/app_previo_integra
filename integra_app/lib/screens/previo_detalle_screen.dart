// ============================================================
// Integra Del Centro, S.C.
// Desarrollado por: HIRAM JAFET VELAZQUEZ SANTANDER
// screens/previo_detalle_screen.dart
// Descripción: Pantalla de detalle de un previo guardado.
//   Muestra toda la información capturada en campo y la galería
//   de fotos. Incluye el botón clave "Generar Reporte de
//   Discrepancia" que pre-llena automáticamente todos los datos
//   del previo en el formulario de reporte — el agente solo
//   necesita agregar la tabla de hallazgos.
// ============================================================

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/reporte.dart';
import '../services/pdf_service_previo.dart';
import 'nuevo_reporte_screen.dart';

class PrevioDetalleScreen extends StatelessWidget {
  final Map previo;
  final dynamic boxKey;

  const PrevioDetalleScreen({
    super.key,
    required this.previo,
    required this.boxKey,
  });

  Color _colorTipo(String tipo) {
    if (tipo == 'Averia') return Colors.red.shade700;
    if (tipo == 'Mercancia') return const Color(0xFF003087);
    return Colors.orange.shade700;
  }

  @override
  Widget build(BuildContext context) {
    final fotos = List<String>.from(previo['fotos'] ?? []);
    final fotosTipos = List<String>.from(
        previo['fotosTipos'] ?? List.filled(fotos.length, 'Foto'));

    final tieneAverias = fotosTipos.contains('Averia');

    // Ordenar: documentos → averías → mercancía
    final indexados = List.generate(fotos.length,
        (i) => {'path': fotos[i], 'tipo': fotosTipos[i]});
    final documentos = indexados
        .where((f) => f['tipo'] != 'Mercancia' && f['tipo'] != 'Averia')
        .toList();
    final averias =
        indexados.where((f) => f['tipo'] == 'Averia').toList();
    final mercancias =
        indexados.where((f) => f['tipo'] == 'Mercancia').toList();
    final ordenadas = [...documentos, ...averias, ...mercancias];

    return Scaffold(
      appBar: AppBar(
        title: Text(previo['referencia'] ?? 'Detalle del Previo'),
        actions: [
          // PDF rápido del previo
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'PDF del Previo',
            onPressed: () => _generarPdf(context),
          ),
          // Eliminar previo
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Eliminar',
            onPressed: () => _confirmarEliminar(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Botón principal: Generar Reporte de Discrepancia ──
          if (tieneAverias) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.fact_check, color: Colors.white, size: 22),
                label: const Text(
                  'Generar Reporte de Discrepancia',
                  style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => _generarReporteDesde(context),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 18, color: Colors.orange.shade800),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Este previo tiene ${averias.length} foto(s) de avería. '
                      'El reporte se pre-llena con los datos del previo. '
                      'Solo agrega la tabla de hallazgos.',
                      style: TextStyle(
                          fontSize: 12, color: Colors.orange.shade900),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Si no hay averías igual se puede generar reporte
            OutlinedButton.icon(
              icon: Icon(Icons.fact_check,
                  color: Colors.red.shade700, size: 20),
              label: Text(
                'Generar Reporte de Discrepancia',
                style: TextStyle(
                    fontSize: 14, color: Colors.red.shade700),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.red.shade300),
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => _generarReporteDesde(context),
            ),
            const SizedBox(height: 12),
          ],

          // ── Datos del previo ──
          _seccion('Datos del Embarque', Icons.local_shipping),
          _infoRow(Icons.tag, 'Referencia', previo['referencia']),
          _infoRow(Icons.business, 'Cliente', previo['cliente']),
          _infoRow(Icons.warehouse, 'Almacén', previo['almacen']),
          _infoRow(Icons.numbers, 'Terminación House', previo['house']),
          _infoRow(Icons.calendar_today, 'Fecha',
              previo['fecha']?.substring(0, 10)),
          if ((previo['observaciones'] ?? '').isNotEmpty)
            _infoRow(Icons.notes, 'Observaciones', previo['observaciones']),

          const SizedBox(height: 16),

          // ── Fotografías ──
          _seccion('Fotografías (${fotos.length})', Icons.photo_camera),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.82,
            ),
            itemCount: ordenadas.length,
            itemBuilder: (context, index) {
              final f = ordenadas[index];
              final path = f['path']!;
              final tipo = f['tipo']!;
              final color = _colorTipo(tipo);

              if (!File(path).existsSync()) {
                return const Center(
                    child: Icon(Icons.broken_image,
                        color: Colors.grey, size: 40));
              }

              return GestureDetector(
                onTap: () => _verFotoCompleta(context, path, tipo),
                child: Column(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(8)),
                        child: Image.file(
                          File(path),
                          fit: BoxFit.cover,
                          width: double.infinity,
                          cacheHeight: 300,
                          cacheWidth: 300,
                        ),
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        border:
                            Border(top: BorderSide(color: color, width: 2)),
                        borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(8)),
                      ),
                      child: Text(tipo,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: color)),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ── Pre-llenar el reporte con datos del previo ──────────────
  /// Construye un ReportePrevio con todos los datos del previo
  /// pre-cargados y navega al formulario de nuevo reporte.
  /// El agente solo necesita agregar la tabla de hallazgos.
  void _generarReporteDesde(BuildContext context) {
    // Extraer fotos de avería para pre-cargarlas en el reporte
    final fotos = List<String>.from(previo['fotos'] ?? []);
    final tipos = List<String>.from(previo['fotosTipos'] ?? []);

    final fotosAveria = <String>[];
    final tiposAveria = <String>[];
    for (int i = 0; i < fotos.length; i++) {
      if (i < tipos.length && tipos[i] == 'Averia') {
        fotosAveria.add(fotos[i]);
        tiposAveria.add('Averia');
      }
    }

    // Pre-llenar el reporte con los datos del previo
    final reporteInicial = ReportePrevio(
      id: ReportePrevio.generarId(),
      // Del previo
      importador: previo['cliente'] ?? '',
      recintoFiscal: previo['almacen'] ?? '',
      referencia: previo['referencia'] ?? '',
      guiaBLMaster: previo['house'] ?? '',
      realizaPrevio: '',
      proveedor: '',
      // Fotos de avería pre-cargadas
      fotos: fotosAveria,
      fotosTipos: tiposAveria,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NuevoReporteScreen(reporteInicial: reporteInicial),
      ),
    );
  }

  // ── PDF del previo ──────────────────────────────────────────
  Future<void> _generarPdf(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              CircularProgressIndicator(color: Color(0xFF003087)),
              SizedBox(height: 12),
              Text('Generando PDF del Previo...'),
            ]),
          ),
        ),
      ),
    );
    try {
      await PdfServicePrevio.generarYCompartir(previo, context);
    } finally {
      if (context.mounted) Navigator.pop(context);
    }
  }

  // ── Eliminar previo ─────────────────────────────────────────
  Future<void> _confirmarEliminar(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar Previo?'),
        content: Text(
            'Se eliminará el previo "${previo['referencia']}". '
            'Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await Hive.box('previos').delete(boxKey);
      Navigator.pop(context);
    }
  }

  // ── Ver foto a pantalla completa ────────────────────────────
  void _verFotoCompleta(BuildContext context, String path, String tipo) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            title: Text(tipo,
                style: TextStyle(color: _colorTipo(tipo))),
          ),
          body: InteractiveViewer(
            child: Center(child: Image.file(File(path))),
          ),
        ),
      ),
    );
  }

  // ── Helpers de UI ───────────────────────────────────────────
  Widget _seccion(String titulo, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF003087), size: 20),
          const SizedBox(width: 8),
          Text(titulo,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF003087))),
          const SizedBox(width: 8),
          Expanded(child: Divider(color: Colors.grey.shade300)),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF003087)),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                    fontSize: 14, color: Colors.black87),
                children: [
                  TextSpan(
                      text: '$label: ',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold)),
                  TextSpan(text: value),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
