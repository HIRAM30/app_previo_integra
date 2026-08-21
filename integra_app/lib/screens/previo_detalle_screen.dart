// ============================================================
// Integra Del Centro, S.C.
// Desarrollado por: HIRAM JAFET VELAZQUEZ SANTANDER
// screens/previo_detalle_screen.dart v5.0
// Fotos agrupadas por Seccion/Partida + filtro de busqueda
// ============================================================

import 'dart:io';
import 'package:flutter/material.dart';

import '../models/reporte.dart';
import '../services/pdf_service_previo.dart';
import 'nuevo_previo_screen.dart';
import 'nuevo_reporte_screen.dart';

class PrevioDetalleScreen extends StatefulWidget {
  final Map previo;
  final dynamic boxKey;

  const PrevioDetalleScreen({
    super.key,
    required this.previo,
    required this.boxKey,
  });

  @override
  State<PrevioDetalleScreen> createState() => _PrevioDetalleScreenState();
}

/// Representa un grupo de fotos: una Seccion, una Partida, o el grupo
/// especial "Sin partida asignada" para fotos sin bloque asociado.
class _GrupoFotos {
  final String id;
  final String tipoEtiqueta; // 'Seccion', 'Partida N', o ''
  final String nombre;
  final int? numero; // numero de partida, para poder filtrar por numero
  final List<Map<String, String>> fotos;

  _GrupoFotos({
    required this.id,
    required this.tipoEtiqueta,
    required this.nombre,
    required this.fotos,
    this.numero,
  });
}

class _PrevioDetalleScreenState extends State<PrevioDetalleScreen> {
  final _buscarCtrl = TextEditingController();
  String _busqueda = '';

  @override
  void initState() {
    super.initState();
    _buscarCtrl.addListener(() {
      setState(() => _busqueda = _buscarCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _buscarCtrl.dispose();
    super.dispose();
  }

  Map get previo => widget.previo;
  dynamic get boxKey => widget.boxKey;

  Color _colorTipo(String tipo) {
    if (tipo == 'Averia') return Colors.red.shade700;
    if (tipo == 'Mercancia') return const Color(0xFF2596BE);
    return Colors.orange.shade700;
  }

  /// Construye los grupos de fotos: uno por cada Seccion, uno por cada
  /// Partida (con su numero), y un grupo final con las fotos que no
  /// quedaron asociadas a ningun bloque.
  List<_GrupoFotos> _construirGrupos() {
    final fotos = List<String>.from(previo['fotos'] ?? []);
    final tipos = List<String>.from(previo['fotosTipos'] ?? []);
    final fotosBytes = List<String>.from(previo['fotosBytes'] ?? []);
    final fotosBloques = List<String>.from(previo['fotosBloques'] ?? []);

    final indexados = List.generate(fotos.length, (i) {
      final path = fotos[i];
      final tipo = i < tipos.length ? tipos[i] : 'Foto';
      final bytes = i < fotosBytes.length ? fotosBytes[i] : '';
      final bloqueId = i < fotosBloques.length ? fotosBloques[i] : '';
      return {
        'path': path,
        'tipo': tipo,
        'bytes': bytes,
        'bloqueId': bloqueId,
      };
    });

    // Orden dentro de cada grupo: documentos, averias, mercancia.
    void ordenarGrupo(List<Map<String, String>> l) {
      final docs = l.where((f) => f['tipo'] != 'Mercancia' && f['tipo'] != 'Averia').toList();
      final avs = l.where((f) => f['tipo'] == 'Averia').toList();
      final mercs = l.where((f) => f['tipo'] == 'Mercancia').toList();
      l..clear()..addAll([...docs, ...avs, ...mercs]);
    }

    final secciones = List.from(previo['secciones'] ?? []);
    final partidas = List.from(previo['partidas'] ?? previo['particiones'] ?? []);

    final grupos = <_GrupoFotos>[];

    for (final raw in secciones) {
      final s = Map<String, dynamic>.from(raw as Map);
      final id = (s['id'] ?? '').toString();
      final fotosGrupo = indexados.where((f) => f['bloqueId'] == id).toList();
      ordenarGrupo(fotosGrupo);
      grupos.add(_GrupoFotos(
        id: id,
        tipoEtiqueta: 'Seccion',
        nombre: (s['nombre'] ?? 'Sin nombre').toString(),
        fotos: fotosGrupo,
      ));
    }

    for (int i = 0; i < partidas.length; i++) {
      final p = Map<String, dynamic>.from(partidas[i] as Map);
      final id = (p['id'] ?? '').toString();
      final fotosGrupo = indexados.where((f) => f['bloqueId'] == id).toList();
      ordenarGrupo(fotosGrupo);
      grupos.add(_GrupoFotos(
        id: id,
        tipoEtiqueta: 'Partida ${i + 1}',
        numero: i + 1,
        nombre: (p['nombre'] ?? 'Sin nombre').toString(),
        fotos: fotosGrupo,
      ));
    }

    // Fotos que no pertenecen a ninguna seccion/partida conocida.
    final idsConocidos = grupos.map((g) => g.id).toSet();
    final sinAsignar = indexados
        .where((f) => (f['bloqueId'] ?? '').isEmpty || !idsConocidos.contains(f['bloqueId']))
        .toList();
    ordenarGrupo(sinAsignar);
    if (sinAsignar.isNotEmpty) {
      grupos.add(_GrupoFotos(
        id: '__sin_asignar__',
        tipoEtiqueta: '',
        nombre: 'Sin partida asignada',
        fotos: sinAsignar,
      ));
    }

    return grupos;
  }

  List<_GrupoFotos> _filtrarGrupos(List<_GrupoFotos> grupos) {
    if (_busqueda.isEmpty) return grupos;
    return grupos.where((g) {
      final nombre = g.nombre.toLowerCase();
      final etiqueta = g.tipoEtiqueta.toLowerCase();
      final numeroStr = g.numero?.toString() ?? '';
      return nombre.contains(_busqueda) ||
          etiqueta.contains(_busqueda) ||
          numeroStr == _busqueda ||
          etiqueta.replaceAll(RegExp(r'[^0-9]'), '') == _busqueda;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final fotos = List<String>.from(previo['fotos'] ?? []);
    final tipos = List<String>.from(previo['fotosTipos'] ?? []);
    final numAverias = tipos.where((t) => t == 'Averia').length;

    final todosLosGrupos = _construirGrupos();
    final gruposVisibles = _filtrarGrupos(todosLosGrupos);

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

          // ═══════════ FOTOGRAFÍAS POR SECCIÓN / PARTIDA ═══════════
          _seccion('Fotografias (${fotos.length})', Icons.photo_camera),
          const SizedBox(height: 8),

          if (todosLosGrupos.isNotEmpty) ...[
            _buscadorPartidas(),
            const SizedBox(height: 12),
          ],

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
          else if (gruposVisibles.isEmpty)
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(children: [
                Icon(Icons.search_off, size: 48, color: Colors.grey.shade300),
                const SizedBox(height: 8),
                Text('No se encontraron secciones o partidas para "${_buscarCtrl.text}"',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade500)),
              ]),
            )
          else
            ...gruposVisibles.map((g) => _buildGrupoCard(context, g)),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ═══════════ WIDGETS AUXILIARES ═══════════

  Widget _buscadorPartidas() {
    return TextField(
      controller: _buscarCtrl,
      decoration: InputDecoration(
        hintText: 'Buscar por titulo o numero de partida...',
        prefixIcon: const Icon(Icons.search, size: 20),
        suffixIcon: _busqueda.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () => _buscarCtrl.clear(),
              )
            : null,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2596BE), width: 1.5),
        ),
      ),
    );
  }

  Widget _buildGrupoCard(BuildContext context, _GrupoFotos g) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2596BE).withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            if (g.tipoEtiqueta.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF2596BE).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(g.tipoEtiqueta,
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2596BE))),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('General',
                    style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
              ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(g.nombre,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            Text('${g.fotos.length} foto${g.fotos.length != 1 ? 's' : ''}',
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ]),
          const SizedBox(height: 10),
          if (g.fotos.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text('Sin fotos en esta seccion/partida',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.85,
              ),
              itemCount: g.fotos.length,
              itemBuilder: (context, i) {
                final f = g.fotos[i];
                final path = f['path']!;
                final tipo = f['tipo']!;
                final color = _colorTipo(tipo);

                return GestureDetector(
                  onTap: () => _verFoto(context, path, tipo),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (File(path).existsSync())
                            Image.file(
                              File(path),
                              fit: BoxFit.cover,
                              cacheHeight: 220,
                              cacheWidth: 220,
                            )
                          else
                            Container(
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.broken_image, color: Colors.grey, size: 30),
                            ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                tipo,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 4,
                            left: 4,
                            child: Text(
                              '${i + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                shadows: [Shadow(blurRadius: 3, color: Colors.black)],
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
        ],
      ),
    );
  }

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
