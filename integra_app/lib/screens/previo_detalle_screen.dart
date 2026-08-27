// ============================================================
// Integra Del Centro, S.C.
// Desarrollado por: HIRAM JAFET VELAZQUEZ SANTANDER
// screens/previo_detalle_screen.dart v4.1
// Diseño mejorado: tarjetas, mejor organización visual
// ============================================================

import 'dart:io';
import 'package:flutter/material.dart';

import '../models/reporte.dart';
import '../services/pdf_service_previo.dart';
import '../services/migration_service.dart';
import 'nuevo_previo_screen.dart';
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
    if (tipo == 'Mercancia') return const Color(0xFF2596BE);
    return Colors.orange.shade700;
  }

  @override
  Widget build(BuildContext context) {
    final fotos = List<String>.from(previo['fotos'] ?? []);
    final tipos = List<String>.from(previo['fotosTipos'] ?? []);
    final fotosBytes = List<String>.from(previo['fotosBytes'] ?? []);
    final fotosBloques = List<String>.from(previo['fotosBloques'] ?? []);

    final indexados = List.generate(fotos.length,
        (i) => {
              'path': fotos[i],
              'tipo': i < tipos.length ? tipos[i] : 'Foto',
              'bytes': i < fotosBytes.length ? fotosBytes[i] : '',
            });
    final docs = indexados
        .where((f) => f['tipo'] != 'Mercancia' && f['tipo'] != 'Averia')
        .toList();
    final avs = indexados.where((f) => f['tipo'] == 'Averia').toList();
    final mercs = indexados.where((f) => f['tipo'] == 'Mercancia').toList();
    final ordenadas = [...docs, ...avs, ...mercs];
    final numAverias = avs.length;
    final bloques = List<Map>.from(previo['bloques'] ?? []);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        title: Text(previo['referencia'] ?? 'Detalle del Previo',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
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
          // PDF
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
            tooltip: 'Generar PDF',
            onPressed: () => _generarPdf(context),
          ),
          // Migrar a otro dispositivo
          IconButton(
            icon: const Icon(Icons.send_to_mobile, color: Colors.white),
            tooltip: 'Exportar para migrar',
            onPressed: () => MigrationService.exportarPrevio(previo, context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ═══════════ BOTÓN PRINCIPAL: GENERAR REPORTE ═══════════
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.fact_check, color: Colors.white, size: 24),
              label: const Text(
                'Generar Reporte de Discrepancia',
                style: TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                minimumSize: const Size(double.infinity, 56),
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _generarReporte(context),
            ),
          ),

          // ═══════════ BANNER DE AVERÍAS ═══════════
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: numAverias > 0 ? Colors.green.shade50 : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: numAverias > 0 ? Colors.green.shade300 : Colors.orange.shade300,
                width: 1.5,
              ),
            ),
            child: Row(children: [
              Icon(
                numAverias > 0 ? Icons.check_circle_outline : Icons.info_outline,
                size: 22,
                color: numAverias > 0 ? Colors.green.shade700 : Colors.orange.shade800,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  numAverias > 0
                      ? '$numAverias foto${numAverias != 1 ? 's' : ''} de averia se agregaran al reporte.'
                      : 'Sin fotos de averia. Puedes agregar fotos manualmente en el reporte.',
                  style: TextStyle(
                    fontSize: 13,
                    color: numAverias > 0 ? Colors.green.shade900 : Colors.orange.shade900,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ]),
          ),

          // ═══════════ RESUMEN RÁPIDO DE PARTIDAS ═══════════
          if (bloques.isNotEmpty) ...[
            _seccion('Resumen de Partidas', Icons.summarize),
            const SizedBox(height: 8),
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: bloques.length,
                itemBuilder: (_, i) {
                  final b = bloques[i];
                  final bloqueId = (b['id'] ?? '').toString();
                  final cantFotosBloque = fotosBloques.where((id) => id == bloqueId).length;
                  return Container(
                    width: 140,
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF2596BE).withValues(alpha: 0.3)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Partida ${i + 1}',
                            style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        const SizedBox(height: 2),
                        Text(b['nombre'] ?? 'Sin nombre',
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF2596BE)),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        const Spacer(),
                        Text('$cantFotosBloque foto${cantFotosBloque != 1 ? 's' : ''}',
                            style: const TextStyle(fontSize: 10, color: Colors.grey)),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ═══════════ DATOS DEL EMBARQUE ═══════════
          _seccion('Datos del Embarque', Icons.local_shipping),
          const SizedBox(height: 8),
          _buildInfoCard(context, [
            _infoItem(Icons.tag, 'Referencia / Master', previo['referencia']),
            _infoItem(Icons.business, 'Cliente', previo['cliente']),
            _infoItem(Icons.warehouse, 'Almacen', previo['almacen']),
            _infoItem(Icons.numbers, 'House', previo['house']),
            _infoItem(Icons.calendar_today, 'Fecha', previo['fecha']?.substring(0, 10)),
            if ((previo['observaciones'] ?? '').isNotEmpty)
              _infoItem(Icons.notes, 'Observaciones', previo['observaciones']),
          ]),

          const SizedBox(height: 16),

          // ═══════════ DATOS COMPLEMENTARIOS ═══════════
          if ((previo['aduana'] ?? '').isNotEmpty ||
              (previo['patente'] ?? '').isNotEmpty ||
              (previo['contenedor'] ?? '').isNotEmpty ||
              (previo['verificador'] ?? '').isNotEmpty) ...[
            _seccion('Datos Complementarios', Icons.assignment),
            const SizedBox(height: 8),
            _buildInfoCard(context, [
              if ((previo['aduana'] ?? '').isNotEmpty)
                _infoItem(Icons.location_on, 'Aduana', previo['aduana']),
              if ((previo['patente'] ?? '').isNotEmpty)
                _infoItem(Icons.numbers, 'Patente', previo['patente']),
              if ((previo['tipoOperacion'] ?? '').isNotEmpty)
                _infoItem(Icons.swap_horiz, 'Tipo de Operacion', previo['tipoOperacion']),
              if ((previo['contenedor'] ?? '').isNotEmpty)
                _infoItem(Icons.inventory_2, 'Contenedor', previo['contenedor']),
              if ((previo['sello'] ?? '').isNotEmpty)
                _infoItem(Icons.lock, 'Sello', previo['sello']),
              if ((previo['verificador'] ?? '').isNotEmpty)
                _infoItem(Icons.person, 'Verificador', previo['verificador']),
            ]),
            const SizedBox(height: 16),
          ],

          // ═══════════ FOTOGRAFÍAS ═══════════
          _seccion('Fotografias (${fotos.length})', Icons.photo_camera),
          const SizedBox(height: 8),
          if (fotos.isEmpty)
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(children: [
                Icon(Icons.photo_library_outlined, size: 48, color: Colors.grey.shade300),
                const SizedBox(height: 8),
                Text('No hay fotografias', style: TextStyle(color: Colors.grey.shade500)),
              ]),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.85,
              ),
              itemCount: ordenadas.length,
              itemBuilder: (context, i) {
                final f = ordenadas[i];
                final path = f['path']!;
                final tipo = f['tipo']!;
                final color = _colorTipo(tipo);

                return GestureDetector(
                  onTap: () => _verFoto(context, path, tipo),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (File(path).existsSync())
                            Image.file(
                              File(path),
                              fit: BoxFit.cover,
                              cacheHeight: 300,
                              cacheWidth: 300,
                            )
                          else
                            Container(
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.broken_image, color: Colors.grey, size: 40),
                            ),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            height: 50,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    Colors.black.withValues(alpha: 0.7),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                tipo,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 8,
                            left: 8,
                            child: Text(
                              '${i + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ═══════════ WIDGETS AUXILIARES ═══════════

  Widget _buildInfoCard(BuildContext context, List<Widget> items) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: items.asMap().entries.map((e) {
          final isLast = e.key == items.length - 1;
          return Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
            child: isLast
                ? e.value
                : Column(children: [
                    e.value,
                    Divider(color: Colors.grey.shade100, height: 10),
                  ]),
          );
        }).toList(),
      ),
    );
  }

  Widget _infoItem(IconData icon, String label, String? val) {
    if (val == null || val.isEmpty) return const SizedBox.shrink();
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: const Color(0xFF2596BE).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: const Color(0xFF2596BE)),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500)),
            const SizedBox(height: 2),
            Text(val,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87)),
          ],
        ),
      ),
    ]);
  }

  void _generarReporte(BuildContext context) {
    final fotos = List<String>.from(previo['fotos'] ?? []);
    final tipos = List<String>.from(previo['fotosTipos'] ?? []);

    final fotosAveria = <String>[];
    final tiposAveria = <String>[];
    for (int i = 0; i < fotos.length; i++) {
      final tipo = i < tipos.length ? tipos[i] : '';
      if (tipo == 'Averia') {
        fotosAveria.add(fotos[i]);
        tiposAveria.add('Averia');
      }
    }

    final reporteInicial = ReportePrevio(
      id: ReportePrevio.generarId(),
      importador: previo['cliente'] ?? '',
      recintoFiscal: previo['almacen'] ?? '',
      referencia: previo['referencia'] ?? '',
      guiaBLMaster: previo['house'] ?? '',
      realizaPrevio: '',
      proveedor: '',
      observacionesIncidencias: previo['observaciones'] ?? '',
      fotos: fotosAveria,
      fotosTipos: tiposAveria,
    );

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => NuevoReporteScreen(reporteInicial: reporteInicial)),
    );
  }

  Future<void> _generarPdf(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: const Padding(
            padding: EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              CircularProgressIndicator(color: Color(0xFF2596BE)),
              SizedBox(height: 16),
              Text('Generando PDF...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
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

  void _verFoto(BuildContext context, String path, String tipo) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            elevation: 0,
            title: Text(tipo, style: TextStyle(color: _colorTipo(tipo), fontWeight: FontWeight.bold)),
          ),
          body: InteractiveViewer(
            child: Center(
              child: File(path).existsSync()
                  ? Image.file(File(path))
                  : const Icon(Icons.broken_image, color: Colors.white, size: 60),
            ),
          ),
        ),
      ),
    );
  }

  Widget _seccion(String titulo, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFF2596BE).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: const Color(0xFF2596BE)),
        ),
        const SizedBox(width: 10),
        Text(titulo,
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF2596BE))),
        const SizedBox(width: 8),
        Expanded(child: Divider(color: Colors.grey.shade200)),
      ]),
    );
  }
}