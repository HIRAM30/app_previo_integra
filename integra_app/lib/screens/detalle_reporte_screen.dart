// ============================================================
// Integra Del Centro, S.C.
// Desarrollado por: HIRAM JAFET VELAZQUEZ SANTANDER
// screens/detalle_reporte_screen.dart
// Descripción: Vista de solo lectura de un reporte guardado.
//   Muestra todos los campos, tabla de hallazgos con resaltado
//   de discrepancias, galería de fotos y accesos a PDF y
//   exportar el archivo .integra para la Web App de oficina.
// ============================================================

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/reporte.dart';
import '../services/pdf_service_reporte.dart';
import '../services/export_service.dart';

class DetalleReporteScreen extends StatefulWidget {
  final Map reporteData;
  final dynamic boxKey;

  const DetalleReporteScreen({
    super.key,
    required this.reporteData,
    required this.boxKey,
  });

  @override
  State<DetalleReporteScreen> createState() => _DetalleReporteScreenState();
}

class _DetalleReporteScreenState extends State<DetalleReporteScreen> {
  late ReportePrevio reporte;

  @override
  void initState() {
    super.initState();
    reporte = ReportePrevio.fromMap(widget.reporteData);
  }

  @override
  Widget build(BuildContext context) {
    final discrepancias = reporte.totalDiscrepancias;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          reporte.referencia.isNotEmpty
              ? reporte.referencia
              : 'Detalle del Reporte',
        ),
        actions: [
          // Exportar para Web App
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: 'Exportar a Web App',
            onPressed: () => _exportar(),
          ),
          // PDF oficial
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Generar PDF oficial',
            onPressed: () => _generarPDF(),
          ),
          // Eliminar
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Eliminar reporte',
            onPressed: () => _confirmarEliminar(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Banner de discrepancias ──────────────────────────
          if (discrepancias > 0)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.shade300, width: 1.5),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Colors.red.shade700, size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '$discrepancias discrepancia${discrepancias > 1 ? 's' : ''} '
                      'detectada${discrepancias > 1 ? 's' : ''} '
                      'entre cantidad facturada y conteo físico.',
                      style: TextStyle(
                          color: Colors.red.shade800,
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),

          // ── Botón exportar ───────────────────────────────────
          OutlinedButton.icon(
            icon: const Icon(Icons.upload_file, color: Colors.green),
            label: const Text(
              'Exportar a Web App de oficina (.integra)',
              style: TextStyle(
                  color: Colors.green, fontWeight: FontWeight.bold),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.green, width: 2),
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _exportar,
          ),

          const SizedBox(height: 16),

          // ── Sección: Importador ──────────────────────────────
          _seccion('Datos del Importador', Icons.business),
          _fila(Icons.business_center, 'Importador', reporte.importador),
          _fila(Icons.storefront, 'Proveedor', reporte.proveedor),
          _fila(Icons.warehouse, 'Recinto Fiscal', reporte.recintoFiscal),
          _fila(Icons.person, 'Realiza Previo', reporte.realizaPrevio),

          const SizedBox(height: 14),

          // ── Sección: Embarque ────────────────────────────────
          _seccion('Datos del Embarque', Icons.local_shipping),
          _fila(Icons.tag, 'Referencia', reporte.referencia),
          _fila(Icons.flight_takeoff, 'Guía BL / AWB', reporte.guiaBLMaster),
          _fila(Icons.calendar_today, 'Fecha de Entrada',
              ReportePrevio.formatFecha(reporte.fechaEntrada)),
          _fila(Icons.inventory, 'Bultos', reporte.bultos),
          _fila(Icons.scale, 'Peso Bruto', reporte.pesoBruto),

          const SizedBox(height: 14),

          // ── Sección: Detalle del previo ──────────────────────
          _seccion('Detalle del Previo', Icons.calendar_today),
          _fila(Icons.event, 'Fecha Solicitud',
              ReportePrevio.formatFecha(reporte.fechaSolicitud)),
          _fila(Icons.play_circle_outline, 'Inicio',
              ReportePrevio.formatFechaHora(reporte.fechaHoraInicio)),
          _fila(Icons.timer_off, 'Término',
              ReportePrevio.formatFechaHora(reporte.fechaHoraTermino)),

          const SizedBox(height: 10),

          // Estado mercancía
          _cardEstado(),

          if (reporte.observacionesIncidencias.isNotEmpty) ...[
            const SizedBox(height: 10),
            _fila(Icons.notes, 'Observaciones e Incidencias',
                reporte.observacionesIncidencias),
          ],

          const SizedBox(height: 14),

          // ── Sección: Tabla de hallazgos ──────────────────────
          if (reporte.hallazgos.isNotEmpty) ...[
            _seccion(
              'Observaciones y Hallazgos (${reporte.hallazgos.length})',
              Icons.fact_check,
            ),
            _tablaHallazgos(),
            if (reporte.totalMercancias.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _fila(Icons.calculate, 'Total de Mercancías',
                    reporte.totalMercancias),
              ),
            const SizedBox(height: 14),
          ],

          // ── Sección: Fotos ───────────────────────────────────
          _seccion(
            'Evidencia Fotográfica (${reporte.fotos.length})',
            Icons.photo_camera,
          ),
          _galeriaFotos(),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ── Tabla de hallazgos ──────────────────────────────────────
  Widget _tablaHallazgos() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 36,
        dataRowMinHeight: 32,
        dataRowMaxHeight: 48,
        headingRowColor: MaterialStateProperty.all(
            const Color(0xFF003087).withOpacity(0.1)),
        columns: const [
          DataColumn(
              label: Text('No Factura',
                  style: TextStyle(fontSize: 11))),
          DataColumn(
              label: Text('No Partida',
                  style: TextStyle(fontSize: 11))),
          DataColumn(
              label:
                  Text('No Parte', style: TextStyle(fontSize: 11))),
          DataColumn(
              label: Text('Cant. Fact.',
                  style: TextStyle(fontSize: 11))),
          DataColumn(
              label: Text('Conteo',
                  style: TextStyle(fontSize: 11))),
          DataColumn(
              label:
                  Text('Marca', style: TextStyle(fontSize: 11))),
          DataColumn(
              label:
                  Text('Modelo', style: TextStyle(fontSize: 11))),
        ],
        rows: reporte.hallazgos.map((h) {
          final disc = h.tieneDiscrepancia;
          return DataRow(
            color: MaterialStateProperty.all(
                disc ? Colors.red.shade50 : null),
            cells: [
              DataCell(Text(h.noFactura,
                  style: const TextStyle(fontSize: 12))),
              DataCell(Text(h.noPartida,
                  style: const TextStyle(fontSize: 12))),
              DataCell(Text(h.noParte,
                  style: const TextStyle(fontSize: 11))),
              DataCell(Text(
                h.cantidadFactura,
                style: TextStyle(
                  fontSize: 12,
                  color: disc ? Colors.red.shade700 : null,
                  fontWeight:
                      disc ? FontWeight.bold : FontWeight.normal,
                ),
              )),
              DataCell(Text(
                h.conteo,
                style: TextStyle(
                  fontSize: 12,
                  color: disc ? Colors.red.shade700 : null,
                  fontWeight:
                      disc ? FontWeight.bold : FontWeight.normal,
                ),
              )),
              DataCell(Text(h.marca,
                  style: const TextStyle(fontSize: 12))),
              DataCell(Text(h.modelo,
                  style: const TextStyle(fontSize: 12))),
            ],
          );
        }).toList(),
      ),
    );
  }

  // ── Galería de fotos ────────────────────────────────────────
  Widget _galeriaFotos() {
    if (reporte.fotos.isEmpty) {
      return const Center(
          child: Text('Sin fotos',
              style: TextStyle(color: Colors.grey)));
    }

    final indexados = List.generate(
        reporte.fotos.length,
        (i) => {
              'path': reporte.fotos[i],
              'tipo': i < reporte.fotosTipos.length
                  ? reporte.fotosTipos[i]
                  : 'Foto',
            });

    final docs = indexados
        .where((f) =>
            f['tipo'] != 'Mercancia' && f['tipo'] != 'Averia')
        .toList();
    final avs =
        indexados.where((f) => f['tipo'] == 'Averia').toList();
    final mercs = indexados
        .where((f) => f['tipo'] == 'Mercancia')
        .toList();
    final ordenadas = [...docs, ...avs, ...mercs];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.82,
      ),
      itemCount: ordenadas.length,
      itemBuilder: (ctx, i) {
        final f = ordenadas[i];
        final path = f['path']!;
        final tipo = f['tipo']!;
        final color = _colorTipo(tipo);

        if (!File(path).existsSync()) {
          return const Center(
              child: Icon(Icons.broken_image,
                  color: Colors.grey, size: 40));
        }

        return GestureDetector(
          onTap: () => _verFoto(path, tipo),
          child: Column(
            children: [
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
    );
  }

  // ── Acciones ────────────────────────────────────────────────

  Future<void> _exportar() async {
    // Mostrar tamaño estimado antes de exportar
    final tam =
        await ExportService.calcularTamanoEstimado(reporte);
    if (!mounted) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.upload_file, color: Colors.green),
          SizedBox(width: 8),
          Text('Exportar a Web App'),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Se generará un archivo .integra con todos los datos '
              'del reporte y las fotos embebidas.',
            ),
            const SizedBox(height: 10),
            Text('Tamaño estimado: $tam',
                style: const TextStyle(
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text(
              'Envíalo por WhatsApp, correo o USB a la computadora '
              'y ábrelo en la Web App de oficina.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton.icon(
            icon: const Icon(Icons.upload_file, color: Colors.white),
            label: const Text('Exportar',
                style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              CircularProgressIndicator(color: Colors.green),
              SizedBox(height: 12),
              Text('Preparando archivo para Web App...'),
            ]),
          ),
        ),
      ),
    );

    try {
      await ExportService.exportarReporte(reporte, context);
    } finally {
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _generarPDF() async {
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
              Text('Generando PDF oficial...'),
            ]),
          ),
        ),
      ),
    );
    try {
      await PdfServiceReporte.generarYCompartir(reporte, context);
    } finally {
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _confirmarEliminar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar reporte?'),
        content: Text(
            'Se eliminará permanentemente el reporte '
            '"${reporte.referencia}". '
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
    if (ok == true && mounted) {
      await Hive.box('reportes').delete(widget.boxKey);
      Navigator.pop(context);
    }
  }

  void _verFoto(String path, String tipo) {
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

  Color _colorTipo(String tipo) {
    if (tipo == 'Averia') return Colors.red.shade700;
    if (tipo == 'Mercancia') return const Color(0xFF003087);
    return Colors.orange.shade700;
  }

  Widget _seccion(String titulo, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF003087), size: 20),
          const SizedBox(width: 8),
          Flexible(
            child: Text(titulo,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF003087))),
          ),
          const SizedBox(width: 8),
          Expanded(
              child: Divider(color: Colors.grey.shade300)),
        ],
      ),
    );
  }

  Widget _fila(IconData icon, String label, String? val) {
    if (val == null || val.isEmpty) return const SizedBox.shrink();
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
                  TextSpan(text: val),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardEstado() {
    final em = reporte.estadoMercancia;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Estado de la Mercancía',
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 6, children: [
            _chip('Completa', em.completa, Colors.green),
            _chip('Faltantes', em.faltantes, Colors.orange),
            _chip('Sobrantes', em.sobrantes, Colors.red),
            _chip(
                em.cargaCompleta
                    ? 'Carga Completa'
                    : 'Carga Parcial',
                true,
                const Color(0xFF003087)),
          ]),
        ],
      ),
    );
  }

  Widget _chip(String label, bool activo, Color color) {
    return Chip(
      label: Text(label,
          style: TextStyle(
              fontSize: 12,
              color: activo ? color : Colors.grey,
              fontWeight: activo
                  ? FontWeight.bold
                  : FontWeight.normal)),
      backgroundColor: activo
          ? color.withOpacity(0.12)
          : Colors.grey.shade100,
      side: BorderSide(
          color: activo ? color : Colors.grey.shade300),
      visualDensity: VisualDensity.compact,
    );
  }
}
