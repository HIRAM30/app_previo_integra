// ============================================================
// Integra Del Centro, S.C.
// Desarrollado por: HIRAM JAFET VELAZQUEZ SANTANDER
// screens/home_screen.dart v3.1
// Mejoras:
//   - PopScope: pregunta confirmación al presionar atrás
//   - Botón Editar (ícono naranja) en cada tarjeta de previo
//   - Botón Editar en cada tarjeta de reporte
// ============================================================

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/reporte.dart';
import '../services/pdf_service_reporte.dart';
import '../services/pdf_service_previo.dart';
import '../services/export_service.dart';
import '../services/export_service_previo.dart';
import 'nuevo_previo_screen.dart';
import 'previo_detalle_screen.dart';
import 'nuevo_reporte_screen.dart';
import 'detalle_reporte_screen.dart';
import '../main.dart' show kVersionApp;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Confirmación al salir ─────────────────────────────────
  Future<bool> _confirmarSalida() async {
    final salir = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Salir de la app?'),
        content: const Text(
            'Si sales perderás cualquier información no guardada.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF003087)),
            child: const Text('Salir',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    return salir ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final salir = await _confirmarSalida();
        if (salir && context.mounted) exit(0);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Integra Del Centro'),
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.info_outline),
              tooltip: 'Acerca de',
              onPressed: _mostrarAcercaDe,
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            tabs: const [
              Tab(icon: Icon(Icons.inventory_2_outlined),
                  text: 'Previos'),
              Tab(icon: Icon(Icons.fact_check_outlined),
                  text: 'Reportes'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _PreviosTab(
              searchQuery: _searchQuery,
              searchCtrl: _searchCtrl,
              onSearch: (v) =>
                  setState(() => _searchQuery = v.toUpperCase()),
              onClear: () {
                _searchCtrl.clear();
                setState(() => _searchQuery = '');
              },
            ),
            _ReportesTab(
              searchQuery: _searchQuery,
              searchCtrl: _searchCtrl,
              onSearch: (v) =>
                  setState(() => _searchQuery = v.toUpperCase()),
              onClear: () {
                _searchCtrl.clear();
                setState(() => _searchQuery = '');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarAcercaDe() {
    showAboutDialog(
      context: context,
      applicationName: 'Sistema Aduanal Integral',
      applicationVersion: 'v$kVersionApp',
      applicationIcon: Container(
        width: 50, height: 50,
        decoration: BoxDecoration(
          color: const Color(0xFF003087),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.business,
            color: Colors.white, size: 28),
      ),
      children: const [
        Text('Previos Aduanales + Reportes de Discrepancia'),
        SizedBox(height: 12),
        Text('Integra Del Centro, S.C.',
            style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        Text(
          'Desarrollado por:\nHIRAM JAFET VELAZQUEZ SANTANDER',
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// TAB 1 — PREVIOS
// ═══════════════════════════════════════════════════════════════
class _PreviosTab extends StatelessWidget {
  final String searchQuery;
  final TextEditingController searchCtrl;
  final Function(String) onSearch;
  final VoidCallback onClear;

  const _PreviosTab({
    required this.searchQuery,
    required this.searchCtrl,
    required this.onSearch,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Row(children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(
                      builder: (_) => const NuevoPrevioScreen())),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                backgroundColor: const Color(0xFF003087),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_circle_outline,
                      size: 24, color: Colors.white),
                  SizedBox(width: 10),
                  Text('Nuevo Previo',
                      style: TextStyle(
                          fontSize: 18, color: Colors.white)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: Colors.green.shade700,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _importar(context),
              child: const SizedBox(
                width: 56, height: 56,
                child: Icon(Icons.file_download_outlined, color: Colors.white),
              ),
            ),
          ),
        ]),
      ),
      _Buscador(
        ctrl: searchCtrl,
        hint: 'Buscar por referencia o House...',
        query: searchQuery,
        onChanged: onSearch,
        onClear: onClear,
      ),
      const Divider(height: 1),
      Expanded(
        child: ValueListenableBuilder(
          valueListenable: Hive.box('previos').listenable(),
          builder: (context, Box box, _) {
            if (box.isEmpty) {
              return _EmptyState(
                icon: Icons.inbox_outlined,
                mensaje: 'No hay previos guardados',
                sub: 'Presiona "Nuevo Previo" para comenzar',
              );
            }
            final keys = box.keys.toList().reversed.toList();
            final filtrados = _filtrar(keys, box, searchQuery);
            if (filtrados.isEmpty) {
              return _SinResultados(query: searchQuery);
            }
            return ListView.builder(
              itemCount: filtrados.length,
              itemBuilder: (ctx, i) =>
                  _PrevioCard(boxKey: filtrados[i], box: box),
            );
          },
        ),
      ),
    ]);
  }

  List<dynamic> _filtrar(List keys, Box box, String q) {
    if (q.isEmpty) return keys;
    return keys.where((key) {
      final d = box.get(key) as Map;
      return (d['house']      ?? '').toString().toUpperCase().contains(q) ||
             (d['referencia'] ?? '').toString().toUpperCase().contains(q);
    }).toList();
  }

  Future<void> _importar(BuildContext context) async {
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
              Text('Importando Previo...'),
            ]),
          ),
        ),
      ),
    );
    String? nuevoId;
    try {
      nuevoId = await ExportServicePrevio.importarPrevio(context);
    } finally {
      if (context.mounted) Navigator.pop(context);
    }
    if (nuevoId != null && context.mounted) {
      final data = Hive.box('previos').get(nuevoId) as Map;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PrevioDetalleScreen(previo: data, boxKey: nuevoId),
        ),
      );
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// TAB 2 — REPORTES
// ═══════════════════════════════════════════════════════════════
class _ReportesTab extends StatelessWidget {
  final String searchQuery;
  final TextEditingController searchCtrl;
  final Function(String) onSearch;
  final VoidCallback onClear;

  const _ReportesTab({
    required this.searchQuery,
    required this.searchCtrl,
    required this.onSearch,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: ElevatedButton(
          onPressed: () => Navigator.push(context,
              MaterialPageRoute(
                  builder: (_) => const NuevoReporteScreen())),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 56),
            backgroundColor: Colors.red.shade700,
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_circle_outline,
                  size: 24, color: Colors.white),
              SizedBox(width: 10),
              Text('Nuevo Reporte de Discrepancia',
                  style: TextStyle(
                      fontSize: 16, color: Colors.white)),
            ],
          ),
        ),
      ),
      Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Row(children: [
          Icon(Icons.computer,
              size: 18, color: Colors.blue.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Exporta el reporte como .integra para editarlo '
              'en la Web App de oficina.',
              style: TextStyle(
                  fontSize: 12, color: Colors.blue.shade800),
            ),
          ),
        ]),
      ),
      _Buscador(
        ctrl: searchCtrl,
        hint: 'Buscar por referencia o BL...',
        query: searchQuery,
        onChanged: onSearch,
        onClear: onClear,
      ),
      const Divider(height: 1),
      Expanded(
        child: ValueListenableBuilder(
          valueListenable: Hive.box('reportes').listenable(),
          builder: (context, Box box, _) {
            if (box.isEmpty) {
              return _EmptyState(
                icon: Icons.description_outlined,
                mensaje: 'No hay reportes guardados',
                sub: 'Crea uno nuevo o genera desde un Previo',
              );
            }
            final keys = box.keys.toList().reversed.toList();
            final filtrados = _filtrar(keys, box, searchQuery);
            if (filtrados.isEmpty) {
              return _SinResultados(query: searchQuery);
            }
            return ListView.builder(
              itemCount: filtrados.length,
              itemBuilder: (ctx, i) =>
                  _ReporteCard(boxKey: filtrados[i], box: box),
            );
          },
        ),
      ),
    ]);
  }

  List<dynamic> _filtrar(List keys, Box box, String q) {
    if (q.isEmpty) return keys;
    return keys.where((key) {
      final d = box.get(key) as Map;
      return (d['referencia']   ?? '').toString().toUpperCase().contains(q) ||
             (d['guiaBLMaster'] ?? '').toString().toUpperCase().contains(q) ||
             (d['importador']   ?? '').toString().toUpperCase().contains(q);
    }).toList();
  }
}

// ─────────────────────────────────────────────────────────────
// TARJETA DE PREVIO — con botón Editar
// ─────────────────────────────────────────────────────────────
class _PrevioCard extends StatelessWidget {
  final dynamic boxKey;
  final Box box;
  const _PrevioCard({required this.boxKey, required this.box});

  @override
  Widget build(BuildContext context) {
    final data  = box.get(boxKey) as Map;
    final fotos = List<String>.from(data['fotos'] ?? []);
    final tipos = List<String>.from(data['fotosTipos'] ?? []);
    final tieneAverias = tipos.contains('Averia');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: tieneAverias
            ? BorderSide(color: Colors.red.shade300, width: 1.5)
            : BorderSide.none,
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: tieneAverias
              ? Colors.red.shade700
              : const Color(0xFF003087),
          child: Icon(
            tieneAverias
                ? Icons.warning_amber_rounded
                : Icons.inventory_2_outlined,
            color: Colors.white, size: 20,
          ),
        ),
        title: Text(
          data['referencia'] ?? 'Sin referencia',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          [
            if ((data['cliente'] ?? '').isNotEmpty) data['cliente'],
            if ((data['house']   ?? '').isNotEmpty)
              'House: ${data['house']}',
            '${fotos.length} foto(s)',
            data['fecha']?.substring(0, 10) ?? '',
          ].join(' · '),
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Editar previo
            IconButton(
              icon: const Icon(Icons.edit_outlined,
                  color: Colors.orange, size: 24),
              tooltip: 'Editar previo',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => NuevoPrevioScreen(
                    previoEditar:  data,
                    boxKeyEditar:  boxKey,
                  ),
                ),
              ),
            ),
            // PDF rápido
            IconButton(
              icon: const Icon(Icons.picture_as_pdf,
                  color: Colors.red, size: 24),
              tooltip: 'PDF del Previo',
              onPressed: () => _pdfPrevio(context, data),
            ),
            // Exportar .integra (compartir/continuar en otro telefono)
            IconButton(
              icon: const Icon(Icons.ios_share,
                  color: Colors.green, size: 24),
              tooltip: 'Exportar / Compartir Previo',
              onPressed: () => _exportar(context, data),
            ),
            // Ver detalle
            IconButton(
              icon: const Icon(Icons.remove_red_eye,
                  color: Color(0xFF003087), size: 24),
              tooltip: 'Ver detalle',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PrevioDetalleScreen(
                    previo:  data,
                    boxKey:  boxKey,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pdfPrevio(BuildContext context, Map data) async {
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
      await PdfServicePrevio.generarYCompartir(data, context);
    } finally {
      if (context.mounted) Navigator.pop(context);
    }
  }

  Future<void> _exportar(BuildContext context, Map data) async {
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
              Text('Preparando archivo .integra...'),
            ]),
          ),
        ),
      ),
    );
    try {
      await ExportServicePrevio.exportarPrevio(data, context);
    } finally {
      if (context.mounted) Navigator.pop(context);
    }
  }
}

// ─────────────────────────────────────────────────────────────
// TARJETA DE REPORTE — con botón Editar
// ─────────────────────────────────────────────────────────────
class _ReporteCard extends StatelessWidget {
  final dynamic boxKey;
  final Box box;
  const _ReporteCard({required this.boxKey, required this.box});

  @override
  Widget build(BuildContext context) {
    final data    = box.get(boxKey) as Map;
    final reporte = ReportePrevio.fromMap(data);
    final disc    = reporte.totalDiscrepancias;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: disc > 0
            ? BorderSide(color: Colors.orange.shade400, width: 1.5)
            : BorderSide.none,
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: disc > 0
              ? Colors.orange.shade700
              : Colors.red.shade700,
          child: Icon(
            disc > 0
                ? Icons.warning_amber
                : Icons.fact_check_outlined,
            color: Colors.white, size: 20,
          ),
        ),
        title: Text(
          reporte.referencia.isNotEmpty
              ? reporte.referencia
              : 'Sin referencia',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          [
            if (reporte.importador.isNotEmpty) reporte.importador,
            '${reporte.hallazgos.length} hallazgo(s)',
            '${reporte.fotos.length} foto(s)',
            ReportePrevio.formatFecha(reporte.fechaCreacion),
          ].join(' · '),
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Editar reporte
            IconButton(
              icon: const Icon(Icons.edit_outlined,
                  color: Colors.orange, size: 24),
              tooltip: 'Editar reporte',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => NuevoReporteScreen(
                    reporteInicial: reporte,
                  ),
                ),
              ),
            ),
            // PDF oficial
            IconButton(
              icon: const Icon(Icons.picture_as_pdf,
                  color: Colors.red, size: 24),
              tooltip: 'PDF Oficial',
              onPressed: () => _pdfReporte(context, reporte),
            ),
            // Exportar .integra
            IconButton(
              icon: const Icon(Icons.upload_file,
                  color: Colors.green, size: 24),
              tooltip: 'Exportar a Web App',
              onPressed: () => _exportar(context, reporte),
            ),
            // Ver detalle
            IconButton(
              icon: const Icon(Icons.remove_red_eye,
                  color: Color(0xFF003087), size: 24),
              tooltip: 'Ver detalle',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DetalleReporteScreen(
                    reporteData: data,
                    boxKey:      boxKey,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pdfReporte(
      BuildContext context, ReportePrevio reporte) async {
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
      if (context.mounted) Navigator.pop(context);
    }
  }

  Future<void> _exportar(
      BuildContext context, ReportePrevio reporte) async {
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
      if (context.mounted) Navigator.pop(context);
    }
  }
}

// ─────────────────────────────────────────────────────────────
// WIDGETS AUXILIARES
// ─────────────────────────────────────────────────────────────

class _Buscador extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final String query;
  final Function(String) onChanged;
  final VoidCallback onClear;

  const _Buscador({
    required this.ctrl,
    required this.hint,
    required this.query,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: TextField(
        controller: ctrl,
        textCapitalization: TextCapitalization.characters,
        onChanged: (v) => onChanged(v.trim().toUpperCase()),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon:
              const Icon(Icons.search, color: Color(0xFF003087)),
          suffixIcon: query.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: onClear,
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(
              vertical: 10, horizontal: 12),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String mensaje;
  final String sub;
  const _EmptyState(
      {required this.icon,
      required this.mensaje,
      required this.sub});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(mensaje,
              style: TextStyle(
                  fontSize: 16, color: Colors.grey.shade600)),
          const SizedBox(height: 4),
          Text(sub,
              style: TextStyle(
                  fontSize: 13, color: Colors.grey.shade500)),
        ],
      ),
    );
  }
}

class _SinResultados extends StatelessWidget {
  final String query;
  const _SinResultados({required this.query});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off,
              size: 56, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text('Sin resultados para "$query"',
              style: TextStyle(
                  fontSize: 15, color: Colors.grey.shade500)),
        ],
      ),
    );
  }
}