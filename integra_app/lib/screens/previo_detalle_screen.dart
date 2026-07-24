// ============================================================
// Integra Del Centro, S.C.
// Desarrollado por: HIRAM JAFET VELAZQUEZ SANTANDER
// screens/previo_detalle_screen.dart v3.2
// Mejora: Al presionar "Generar Reporte de Discrepancia",
//   las fotos de avería del previo se jalan automáticamente
//   al formulario del reporte. El agente solo agrega la
//   tabla de hallazgos.
//   Nuevo: Botón para gestionar bloques
// ============================================================

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/reporte.dart';
import '../services/pdf_service_previo.dart';
import 'nuevo_previo_screen.dart';
import 'nuevo_reporte_screen.dart';
import 'gestion_bloques_screen.dart';

class PrevioDetalleScreen extends StatelessWidget {
  final Map previo;
  final dynamic boxKey;

  const PrevioDetalleScreen({
    super.key,
    required this.previo,
    required this.boxKey,
  });

  Color _colorTipo(String tipo) {
    if (tipo == 'Averia')    return Colors.red.shade700;
    if (tipo == 'Mercancia') return const Color(0xFF2596BE);
    return Colors.orange.shade700;
  }

  @override
  Widget build(BuildContext context) {
    final fotos  = List<String>.from(previo['fotos']      ?? []);
    final tipos  = List<String>.from(previo['fotosTipos'] ?? []);
    final averias = <Map<String, String>>[];

    // Ordenar fotos para mostrar
    final indexados = List.generate(fotos.length,
        (i) => {'path': fotos[i], 'tipo': i < tipos.length ? tipos[i] : 'Foto'});
    final docs  = indexados.where((f) =>
        f['tipo'] != 'Mercancia' && f['tipo'] != 'Averia').toList();
    final avs   = indexados.where((f) => f['tipo'] == 'Averia').toList();
    final mercs = indexados.where((f) => f['tipo'] == 'Mercancia').toList();
    final ordenadas = [...docs, ...avs, ...mercs];

    final numAverias = avs.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(previo['referencia'] ?? 'Detalle del Previo'),
        actions: [
          // Gestionar Bloques
          IconButton(
            icon: const Icon(Icons.widgets_outlined, color: Colors.white),
            tooltip: 'Gestionar Bloques',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => GestionBloquesScreen(
                  previo: previo,
                  boxKey: boxKey,
                ),
              ),
            ),
          ),
          // Editar previo
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Colors.white),
            tooltip: 'Editar previo',
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => NuevoPrevioScreen(
                  previoEditar: previo,
                  boxKeyEditar: boxKey,
                ),
              ),
            ),
          ),
          // PDF del previo
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'PDF del Previo',
            onPressed: () => _generarPdf(context),
          ),
          // Eliminar
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

          // ── Botón principal: Generar Reporte ───────────────
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.fact_check,
                  color: Colors.white, size: 22),
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
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => _generarReporte(context),
            ),
          ),

          // Banner informativo según si hay averías
          if (numAverias > 0)
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade300),
              ),
              child: Row(children: [
                Icon(Icons.check_circle_outline,
                    size: 18, color: Colors.green.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$numAverias foto${numAverias != 1 ? 's' : ''} de '
                    'avería se agregarán automáticamente al reporte. '
                    'Solo completa la tabla de hallazgos.',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade900),
                  ),
                ),
              ]),
            )
          else
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade300),
              ),
              child: Row(children: [
                Icon(Icons.info_outline,
                    size: 18, color: Colors.orange.shade800),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Este previo no tiene fotos de avería. '
                    'Puedes agregar fotos manualmente en el reporte.',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade900),
                  ),
                ),
              ]),
            ),

          // ── Datos del previo ────────────────────────────────
          _seccion('Datos del Embarque', Icons.local_shipping),
          _fila(Icons.tag, 'Referencia / Master', previo['referencia']),
          _fila(Icons.business, 'Cliente', previo['cliente']),
          _fila(Icons.warehouse, 'Almacén', previo['almacen']),
          _fila(Icons.numbers, 'House', previo['house']),
          _fila(Icons.calendar_today, 'Fecha',
              previo['fecha']?.substring(0, 10)),
          if ((previo['observaciones'] ?? '').isNotEmpty)
            _fila(Icons.notes, 'Observaciones',
                previo['observaciones']),

          // ── Datos complementarios ───────────────────────────
          if ((previo['aduana'] ?? '').isNotEmpty ||
              (previo['patente'] ?? '').isNotEmpty ||
              (previo['contenedor'] ?? '').isNotEmpty ||
              (previo['verificador'] ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            _seccion('Datos Complementarios', Icons.assignment),
            if ((previo['aduana'] ?? '').isNotEmpty)
              _fila(Icons.location_on, 'Aduana', previo['aduana']),
            if ((previo['patente'] ?? '').isNotEmpty)
              _fila(Icons.numbers, 'Patente', previo['patente']),
            if ((previo['tipoOperacion'] ?? '').isNotEmpty)
              _fila(Icons.swap_horiz, 'Tipo de Operación', previo['tipoOperacion']),
            if ((previo['contenedor'] ?? '').isNotEmpty)
              _fila(Icons.inventory_2, 'Contenedor', previo['contenedor']),
            if ((previo['sello'] ?? '').isNotEmpty)
              _fila(Icons.lock, 'Sello', previo['sello']),
            if ((previo['verificador'] ?? '').isNotEmpty)
              _fila(Icons.person, 'Verificador', previo['verificador']),
          ],

          const SizedBox(height: 16),

          // ── Fotografías ─────────────────────────────────────
          _seccion('Fotografías (${fotos.length})',
              Icons.photo_camera),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.82,
            ),
            itemCount: ordenadas.length,
            itemBuilder: (context, i) {
              final f    = ordenadas[i];
              final path = f['path']!;
              final tipo = f['tipo']!;
              final color = _colorTipo(tipo);

              if (!File(path).existsSync()) {
                return const Center(
                    child: Icon(Icons.broken_image,
                        color: Colors.grey, size: 40));
              }

              return GestureDetector(
                onTap: () => _verFoto(context, path, tipo),
                child: Column(children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(8)),
                      child: Image.file(File(path),
                          fit: BoxFit.cover,
                          width: double.infinity,
                          cacheHeight: 300,
                          cacheWidth: 300),
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      border: Border(
                          top: BorderSide(color: color, width: 2)),
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
                ]),
              );
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _generarReporte(BuildContext context) {
    final fotos = List<String>.from(previo['fotos']      ?? []);
    final tipos = List<String>.from(previo['fotosTipos'] ?? []);

    final fotosAveria  = <String>[];
    final tiposAveria  = <String>[];
    for (int i = 0; i < fotos.length; i++) {
      final tipo = i < tipos.length ? tipos[i] : '';
      if (tipo == 'Averia') {
        fotosAveria.add(fotos[i]);
        tiposAveria.add('Averia');
      }
    }

    final reporteInicial = ReportePrevio(
      id:             ReportePrevio.generarId(),
      importador:     previo['cliente']      ?? '',
      recintoFiscal:  previo['almacen']      ?? '',
      referencia:     previo['referencia']   ?? '',
      guiaBLMaster:   previo['house']        ?? '',
      realizaPrevio:  '',
      proveedor:      '',
      observacionesIncidencias: previo['observaciones'] ?? '',
      fotos:          fotosAveria,
      fotosTipos:     tiposAveria,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NuevoReporteScreen(
            reporteInicial: reporteInicial),
      ),
    );
  }

  Future<void> _generarPdf(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              CircularProgressIndicator(color: Color(0xFF2596BE)),
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

  Future<void> _confirmarEliminar(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar Previo?'),
        content: Text(
            'Se eliminará el previo '
            '"${previo['referencia']}". '
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

  void _verFoto(BuildContext context, String path, String tipo) {
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

  Widget _seccion(String titulo, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Icon(icon, color: const Color(0xFF2596BE), size: 20),
        const SizedBox(width: 8),
        Text(titulo,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2596BE))),
        const SizedBox(width: 8),
        Expanded(child: Divider(color: Colors.grey.shade300)),
      ]),
    );
  }

  Widget _fila(IconData icon, String label, String? val) {
    if (val == null || val.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 18, color: const Color(0xFF2596BE)),
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
                TextSpan(text: val),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}