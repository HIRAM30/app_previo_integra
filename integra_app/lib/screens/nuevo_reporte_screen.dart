// ============================================================
// Integra Del Centro, S.C.
// Desarrollado por: HIRAM JAFET VELAZQUEZ SANTANDER
// screens/nuevo_reporte_screen.dart
// Descripción: Formulario de captura de Reporte de Discrepancia.
//   Acepta un [reporteInicial] opcional para pre-llenar campos
//   cuando se genera desde un previo existente. Si no se pasa,
//   el formulario inicia vacío (nuevo reporte manual).
//   Al guardar, también ofrece exportar el .integra directamente.
// ============================================================

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../models/reporte.dart';
import '../services/export_service.dart';
import '../utils/image_helper.dart';
import '../widgets/hallazgo_form_row.dart';
import '../widgets/seccion_header.dart';

enum TipoFoto { mercancia, documento, averia }
enum FuenteFoto { camara, galeria }

class NuevoReporteScreen extends StatefulWidget {
  /// Si viene de un previo, este objeto trae los datos pre-llenados.
  /// Si es null, el formulario inicia completamente vacío.
  final ReportePrevio? reporteInicial;

  const NuevoReporteScreen({super.key, this.reporteInicial});

  @override
  State<NuevoReporteScreen> createState() => _NuevoReporteScreenState();
}

class _NuevoReporteScreenState extends State<NuevoReporteScreen> {
  bool _isSaving = false;
  bool _vieneDeUnPrevio = false;

  // ── Controllers encabezado ──
  late final TextEditingController _importadorCtrl;
  late final TextEditingController _proveedorCtrl;
  late final TextEditingController _recintoFiscalCtrl;
  late final TextEditingController _realizaPrevioCtrl;

  // ── Controllers embarque ──
  late final TextEditingController _referenciaCtrl;
  late final TextEditingController _guiaBLCtrl;
  late final TextEditingController _bultosCtrl;
  late final TextEditingController _pesoBrutoCtrl;
  DateTime? _fechaEntrada;

  // ── Detalle del previo ──
  DateTime? _fechaSolicitud;
  DateTime? _fechaHoraInicio;
  DateTime? _fechaHoraTermino;

  // ── Estado mercancía ──
  bool _mercanciaCompleta = false;
  bool _mercanciaFaltantes = false;
  bool _mercanciaSobrantes = false;
  bool _cargaCompleta = true;

  // ── Observaciones ──
  late final TextEditingController _observacionesCtrl;
  late final TextEditingController _obsCargaCtrl;

  // ── Carga suelta ──
  late final TextEditingController _cantBultosCtrl;
  late final TextEditingController _tipoBultoCtrl;
  late final TextEditingController _largoCtrl;
  late final TextEditingController _anchoCtrl;
  late final TextEditingController _altoCtrl;

  // ── Hallazgos ──
  late final List<HallazgoItem> _hallazgos;
  late final TextEditingController _totalMercanciasCtrl;

  // ── Fotos: vienen pre-cargadas si viene de un previo ──
  late final List<Map<String, dynamic>> _fotos;

  @override
  void initState() {
    super.initState();
    final r = widget.reporteInicial;
    _vieneDeUnPrevio = r != null;

    // Pre-llenar con datos del previo si existen
    _importadorCtrl   = TextEditingController(text: r?.importador ?? '');
    _proveedorCtrl    = TextEditingController(text: r?.proveedor ?? '');
    _recintoFiscalCtrl= TextEditingController(text: r?.recintoFiscal ?? '');
    _realizaPrevioCtrl= TextEditingController(text: r?.realizaPrevio ?? '');
    _referenciaCtrl   = TextEditingController(text: r?.referencia ?? '');
    _guiaBLCtrl       = TextEditingController(text: r?.guiaBLMaster ?? '');
    _bultosCtrl       = TextEditingController(text: r?.bultos ?? '');
    _pesoBrutoCtrl    = TextEditingController(text: r?.pesoBruto ?? '');
    _observacionesCtrl= TextEditingController(text: r?.observacionesIncidencias ?? '');
    _obsCargaCtrl     = TextEditingController(text: r?.observacionesCarga ?? '');
    _cantBultosCtrl   = TextEditingController(text: r?.cantidadBultosSueltos ?? '');
    _tipoBultoCtrl    = TextEditingController(text: r?.tipoBulto ?? '');
    _largoCtrl        = TextEditingController(text: r?.largoBulto ?? '');
    _anchoCtrl        = TextEditingController(text: r?.anchoBulto ?? '');
    _altoCtrl         = TextEditingController(text: r?.altoBulto ?? '');
    _totalMercanciasCtrl = TextEditingController(text: r?.totalMercancias ?? '');

    _fechaEntrada     = r?.fechaEntrada;
    _fechaSolicitud   = r?.fechaSolicitud;
    _fechaHoraInicio  = r?.fechaHoraInicio;
    _fechaHoraTermino = r?.fechaHoraTermino;

    _hallazgos = r?.hallazgos ?? [];

    // Fotos pre-cargadas desde el previo (averías)
    _fotos = r != null
        ? List.generate(r.fotos.length, (i) {
            final path = r.fotos[i];
            final tipo = i < r.fotosTipos.length ? r.fotosTipos[i] : 'Averia';
            return {'file': File(path), 'tipo': tipo};
          })
        : [];
  }

  @override
  void dispose() {
    _importadorCtrl.dispose();
    _proveedorCtrl.dispose();
    _recintoFiscalCtrl.dispose();
    _realizaPrevioCtrl.dispose();
    _referenciaCtrl.dispose();
    _guiaBLCtrl.dispose();
    _bultosCtrl.dispose();
    _pesoBrutoCtrl.dispose();
    _observacionesCtrl.dispose();
    _obsCargaCtrl.dispose();
    _cantBultosCtrl.dispose();
    _tipoBultoCtrl.dispose();
    _largoCtrl.dispose();
    _anchoCtrl.dispose();
    _altoCtrl.dispose();
    _totalMercanciasCtrl.dispose();
    super.dispose();
  }

  Color _colorTipo(String tipo) {
    if (tipo == 'Averia') return Colors.red.shade700;
    if (tipo == 'Mercancia') return const Color(0xFF003087);
    return Colors.orange.shade700;
  }

  // ── AGREGAR FOTO ─────────────────────────────────────────────
  Future<void> _agregarFoto() async {
    final TipoFoto? tipo = await showDialog<TipoFoto>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tipo de Fotografía'),
        content: const Text('¿Qué vas a fotografiar?'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.inventory_2, color: Color(0xFF003087)),
            label: const Text('Mercancía'),
            onPressed: () => Navigator.pop(ctx, TipoFoto.mercancia),
          ),
          TextButton.icon(
            icon: const Icon(Icons.description, color: Colors.orange),
            label: const Text('Documento'),
            onPressed: () => Navigator.pop(ctx, TipoFoto.documento),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.warning_amber_rounded, color: Colors.white),
            label: const Text('Avería', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(ctx, TipoFoto.averia),
          ),
        ],
      ),
    );
    if (tipo == null || !mounted) return;

    final FuenteFoto? fuente = await showDialog<FuenteFoto>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿De dónde viene la foto?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF003087), size: 32),
              title: const Text('Tomar foto ahora'),
              subtitle: const Text('Usa la cámara del teléfono'),
              onTap: () => Navigator.pop(ctx, FuenteFoto.camara),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.green, size: 32),
              title: const Text('Elegir de galería'),
              subtitle: const Text('Selecciona una foto ya tomada'),
              onTap: () => Navigator.pop(ctx, FuenteFoto.galeria),
            ),
          ],
        ),
      ),
    );
    if (fuente == null || !mounted) return;
    await _capturarFoto(tipo, fuente);
  }

  Future<void> _capturarFoto(TipoFoto tipo, FuenteFoto fuente) async {
    try {
      final picker = ImagePicker();
      final source = fuente == FuenteFoto.camara
          ? ImageSource.camera
          : ImageSource.gallery;

      final XFile? picked = await picker.pickImage(
        source: source,
        imageQuality: tipo == TipoFoto.documento ? 92 : 82,
        maxWidth: tipo == TipoFoto.documento ? 1800 : 1600,
        maxHeight: tipo == TipoFoto.documento ? 1800 : 1600,
      );
      if (picked == null) return;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            const SizedBox(width: 12),
            Text(tipo == TipoFoto.documento
                ? 'Analizando documento...'
                : 'Procesando foto...'),
          ]),
          duration: const Duration(seconds: 5),
        ));
      }

      final original = File(picked.path);
      File? processed;
      String tipoLabel;

      switch (tipo) {
        case TipoFoto.documento:
          processed = await ImageHelper.compressDocument(original);
          final detected = processed != null
              ? await ImageHelper.detectDocumentType(processed)
              : null;
          tipoLabel = (detected != null && detected.isNotEmpty)
              ? detected
              : 'Documento';
          break;
        case TipoFoto.averia:
          processed = await ImageHelper.compressImage(original);
          tipoLabel = 'Averia';
          break;
        case TipoFoto.mercancia:
        default:
          processed = await ImageHelper.compressImage(original);
          tipoLabel = 'Mercancia';
          break;
      }

      if (processed != null && mounted) {
        setState(() => _fotos.add({'file': processed!, 'tipo': tipoLabel}));
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✓ Foto guardada: $tipoLabel'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _eliminarFoto(int i) => setState(() => _fotos.removeAt(i));
  void _agregarHallazgo() => setState(() => _hallazgos.add(HallazgoItem()));
  void _eliminarHallazgo(int i) => setState(() => _hallazgos.removeAt(i));

  // ── GUARDAR ─────────────────────────────────────────────────
  Future<void> _guardarReporte({bool exportarDespues = false}) async {
    if (_referenciaCtrl.text.trim().isEmpty) {
      _error('Ingresa la referencia del pedimento.');
      return;
    }
    if (_importadorCtrl.text.trim().isEmpty) {
      _error('Ingresa el nombre del importador.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final reporte = _buildReporte();
      await Hive.box('reportes').put(reporte.id, reporte.toMap());

      if (exportarDespues && mounted) {
        // Guardar y luego exportar de inmediato
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
        await ExportService.exportarReporte(reporte, context);
        if (mounted) Navigator.pop(context); // Cerrar loading
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✓ Reporte guardado correctamente'),
          backgroundColor: Colors.green,
        ));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) _error('Error al guardar: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// Construye el objeto ReportePrevio con todos los valores del formulario.
  ReportePrevio _buildReporte() => ReportePrevio(
    id: widget.reporteInicial?.id ?? ReportePrevio.generarId(),
    importador:    _importadorCtrl.text.trim(),
    proveedor:     _proveedorCtrl.text.trim(),
    recintoFiscal: _recintoFiscalCtrl.text.trim(),
    realizaPrevio: _realizaPrevioCtrl.text.trim(),
    referencia:    _referenciaCtrl.text.trim(),
    guiaBLMaster:  _guiaBLCtrl.text.trim(),
    fechaEntrada:  _fechaEntrada,
    bultos:        _bultosCtrl.text.trim(),
    pesoBruto:     _pesoBrutoCtrl.text.trim(),
    fechaSolicitud:   _fechaSolicitud,
    fechaHoraInicio:  _fechaHoraInicio,
    fechaHoraTermino: _fechaHoraTermino,
    estadoMercancia: EstadoMercancia(
      completa:      _mercanciaCompleta,
      faltantes:     _mercanciaFaltantes,
      sobrantes:     _mercanciaSobrantes,
      cargaCompleta: _cargaCompleta,
    ),
    observacionesIncidencias: _observacionesCtrl.text.trim(),
    observacionesCarga:       _obsCargaCtrl.text.trim(),
    cantidadBultosSueltos:    _cantBultosCtrl.text.trim(),
    tipoBulto:  _tipoBultoCtrl.text.trim(),
    largoBulto: _largoCtrl.text.trim(),
    anchoBulto: _anchoCtrl.text.trim(),
    altoBulto:  _altoCtrl.text.trim(),
    hallazgos:  _hallazgos,
    totalMercancias: _totalMercanciasCtrl.text.trim(),
    fotos:      _fotos.map((f) => (f['file'] as File).path).toList(),
    fotosTipos: _fotos.map((f) => f['tipo'] as String).toList(),
  );

  void _error(String msg) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red));

  // ── SELECCIÓN FECHA/HORA ─────────────────────────────────────
  Future<void> _seleccionarFecha(Function(DateTime) cb) async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (d != null) setState(() => cb(d));
  }

  Future<void> _seleccionarFechaHora(Function(DateTime) cb) async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(
        context: context, initialTime: TimeOfDay.now());
    if (t == null) return;
    setState(() => cb(
        DateTime(d.year, d.month, d.day, t.hour, t.minute)));
  }

  String _fmtF(DateTime? d) =>
      d == null ? 'Seleccionar fecha' : DateFormat('dd/MM/yyyy').format(d);
  String _fmtFH(DateTime? d) => d == null
      ? 'Seleccionar fecha y hora'
      : DateFormat('dd/MM/yyyy HH:mm').format(d);

  // ── UI ───────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final docCount  = _fotos.where((f) => f['tipo'] != 'Mercancia' && f['tipo'] != 'Averia').length;
    final avCount   = _fotos.where((f) => f['tipo'] == 'Averia').length;
    final mercCount = _fotos.where((f) => f['tipo'] == 'Mercancia').length;

    return Scaffold(
      appBar: AppBar(
        title: Text(_vieneDeUnPrevio
            ? 'Reporte desde Previo'
            : 'Nuevo Reporte'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : () => _guardarReporte(),
            child: const Text('GUARDAR',
                style: TextStyle(color: Colors.white, fontSize: 16)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Banner si viene de un previo
            if (_vieneDeUnPrevio) ...[
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle,
                        size: 20, color: Colors.green.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Datos pre-llenados desde el previo. '
                        'Completa la tabla de hallazgos y guarda.',
                        style: TextStyle(
                            fontSize: 12, color: Colors.green.shade900),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ═══ SECCIÓN 1: IMPORTADOR ════════════════════════
            const SeccionHeader(titulo: 'Datos del Importador', icono: Icons.business),
            _campo(_importadorCtrl, 'Importador *', Icons.business_center),
            _campo(_proveedorCtrl, 'Proveedor', Icons.storefront),
            _campo(_recintoFiscalCtrl, 'Recinto Fiscal', Icons.warehouse),
            _campo(_realizaPrevioCtrl, 'Realiza Previo', Icons.person),

            const SizedBox(height: 20),

            // ═══ SECCIÓN 2: EMBARQUE ══════════════════════════
            const SeccionHeader(titulo: 'Datos del Embarque', icono: Icons.local_shipping),
            _campo(_referenciaCtrl, 'Referencia / Pedimento *', Icons.tag, mayusculas: true),
            _campo(_guiaBLCtrl, 'Guía BL Master / AWB', Icons.flight_takeoff, mayusculas: true),
            _campo(_bultosCtrl, 'Número de Bultos', Icons.inventory, teclado: TextInputType.number),
            _campo(_pesoBrutoCtrl, 'Peso Bruto (kg)', Icons.scale, teclado: TextInputType.number),
            _fechaBtn('Fecha de Entrada', _fmtF(_fechaEntrada),
                () => _seleccionarFecha((d) => _fechaEntrada = d)),

            const SizedBox(height: 20),

            // ═══ SECCIÓN 3: DETALLE PREVIO ════════════════════
            const SeccionHeader(titulo: 'Detalle del Previo', icono: Icons.calendar_today),
            _fechaBtn('Fecha Solicitud', _fmtF(_fechaSolicitud),
                () => _seleccionarFecha((d) => _fechaSolicitud = d)),
            _fechaBtn('Inicio', _fmtFH(_fechaHoraInicio),
                () => _seleccionarFechaHora((d) => _fechaHoraInicio = d)),
            _fechaBtn('Término', _fmtFH(_fechaHoraTermino),
                () => _seleccionarFechaHora((d) => _fechaHoraTermino = d)),

            const SizedBox(height: 12),
            _estadoMercanciaWidget(),
            const SizedBox(height: 12),
            TextField(
              controller: _observacionesCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Observaciones e Incidencias',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.notes),
              ),
            ),

            const SizedBox(height: 20),

            // ═══ SECCIÓN 4: CARGA SUELTA ══════════════════════
            const SeccionHeader(titulo: 'Carga Suelta (si aplica)', icono: Icons.all_inbox),
            Row(children: [
              Expanded(child: _campo(_cantBultosCtrl, 'Cant. Bultos', Icons.numbers, teclado: TextInputType.number)),
              const SizedBox(width: 8),
              Expanded(child: _campo(_tipoBultoCtrl, 'Tipo', Icons.category)),
            ]),
            Row(children: [
              Expanded(child: _campo(_largoCtrl, 'Largo cm', Icons.straighten, teclado: TextInputType.number)),
              const SizedBox(width: 8),
              Expanded(child: _campo(_anchoCtrl, 'Ancho cm', Icons.straighten, teclado: TextInputType.number)),
              const SizedBox(width: 8),
              Expanded(child: _campo(_altoCtrl, 'Alto cm', Icons.height, teclado: TextInputType.number)),
            ]),

            const SizedBox(height: 20),

            // ═══ SECCIÓN 5: HALLAZGOS ═════════════════════════
            const SeccionHeader(titulo: 'Observaciones y Hallazgos', icono: Icons.fact_check),
            _encabezadoTabla(),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _hallazgos.length,
              itemBuilder: (_, i) => HallazgoFormRow(
                hallazgo: _hallazgos[i],
                onDelete: () => _eliminarHallazgo(i),
                indice: i,
              ),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.add, color: Color(0xFF003087)),
              label: const Text('Agregar Hallazgo',
                  style: TextStyle(color: Color(0xFF003087))),
              onPressed: _agregarHallazgo,
              style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF003087))),
            ),
            const SizedBox(height: 10),
            _campo(_totalMercanciasCtrl, 'Total de Mercancías', Icons.calculate,
                teclado: TextInputType.number),

            const SizedBox(height: 20),

            // ═══ SECCIÓN 6: FOTOS ═════════════════════════════
            const SeccionHeader(titulo: 'Evidencia Fotográfica', icono: Icons.photo_camera),
            if (_vieneDeUnPrevio && _fotos.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${avCount} foto(s) de avería pre-cargadas desde el previo. '
                  'Puedes agregar más.',
                  style: TextStyle(fontSize: 12, color: Colors.blue.shade800),
                ),
              ),
            ElevatedButton(
              onPressed: _agregarFoto,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14)),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo, size: 24, color: Colors.white),
                  SizedBox(width: 10),
                  Text('Agregar Foto', style: TextStyle(fontSize: 18, color: Colors.white)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Total: ${_fotos.length}  •  Doc: $docCount  •  Avería: $avCount  •  Merc: $mercCount',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            if (_fotos.isNotEmpty) _carruselFotos(),

            const SizedBox(height: 28),

            // ═══ BOTONES DE ACCIÓN ════════════════════════════
            // Guardar normal
            ElevatedButton.icon(
              icon: const Icon(Icons.save_alt, color: Colors.white, size: 22),
              label: Text(_isSaving ? 'Guardando...' : 'Guardar Reporte',
                  style: const TextStyle(fontSize: 18, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: _isSaving ? null : () => _guardarReporte(),
            ),
            const SizedBox(height: 10),
            // Guardar y exportar (para oficina)
            OutlinedButton.icon(
              icon: const Icon(Icons.upload_file, color: Colors.green),
              label: const Text(
                'Guardar y Exportar a Web App',
                style: TextStyle(
                    fontSize: 16, color: Colors.green, fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: Colors.green, width: 2),
              ),
              onPressed: _isSaving
                  ? null
                  : () => _guardarReporte(exportarDespues: true),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _encabezadoTabla() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      color: const Color(0xFF003087),
      child: const Row(children: [
        Expanded(flex: 2, child: Text('No Factura', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
        Expanded(flex: 2, child: Text('No Partida', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
        Expanded(flex: 3, child: Text('No Parte',   style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
        Expanded(flex: 2, child: Text('Cant. Fact.',style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
        Expanded(flex: 2, child: Text('Conteo',     style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
        SizedBox(width: 32),
      ]),
    );
  }

  Widget _estadoMercanciaWidget() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Estado de la Mercancía',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        Wrap(spacing: 8, children: [
          FilterChip(label: const Text('Completa', style: TextStyle(fontSize: 12)),
            selected: _mercanciaCompleta,
            onSelected: (v) => setState(() => _mercanciaCompleta = v),
            selectedColor: Colors.green.shade100,
            checkmarkColor: Colors.green.shade700,
          ),
          FilterChip(label: const Text('Faltantes', style: TextStyle(fontSize: 12)),
            selected: _mercanciaFaltantes,
            onSelected: (v) => setState(() => _mercanciaFaltantes = v),
            selectedColor: Colors.orange.shade100,
            checkmarkColor: Colors.orange.shade700,
          ),
          FilterChip(label: const Text('Sobrantes', style: TextStyle(fontSize: 12)),
            selected: _mercanciaSobrantes,
            onSelected: (v) => setState(() => _mercanciaSobrantes = v),
            selectedColor: Colors.red.shade100,
            checkmarkColor: Colors.red.shade700,
          ),
        ]),
        const SizedBox(height: 4),
        const Text('Tipo de Carga', style: TextStyle(fontSize: 12, color: Colors.grey)),
        Wrap(spacing: 8, children: [
          FilterChip(label: const Text('Completa', style: TextStyle(fontSize: 12)),
            selected: _cargaCompleta,
            onSelected: (v) => setState(() => _cargaCompleta = v),
            selectedColor: const Color(0xFF003087).withOpacity(0.15),
          ),
          FilterChip(label: const Text('Parcial', style: TextStyle(fontSize: 12)),
            selected: !_cargaCompleta,
            onSelected: (v) => setState(() => _cargaCompleta = !v),
            selectedColor: Colors.blueGrey.shade100,
          ),
        ]),
      ]),
    );
  }

  Widget _carruselFotos() {
    return Column(children: [
      const SizedBox(height: 10),
      SizedBox(
        height: 145,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: _fotos.length,
          itemBuilder: (_, i) {
            final f = _fotos[i];
            final tipo = f['tipo'] as String;
            final color = _colorTipo(tipo);
            return Stack(children: [
              Container(
                margin: const EdgeInsets.only(right: 10, top: 8),
                width: 115,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color, width: 2),
                ),
                child: Column(children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                    child: Image.file(f['file'] as File,
                        height: 105, width: 115, fit: BoxFit.cover,
                        cacheHeight: 200, cacheWidth: 200),
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(6)),
                    ),
                    child: Text(tipo,
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color),
                        textAlign: TextAlign.center,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ]),
              ),
              Positioned(
                top: 0, right: 2,
                child: GestureDetector(
                  onTap: () => _eliminarFoto(i),
                  child: Container(
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    child: const Icon(Icons.close, color: Colors.white, size: 18),
                  ),
                ),
              ),
            ]);
          },
        ),
      ),
    ]);
  }

  Widget _campo(TextEditingController ctrl, String label, IconData icon,
      {bool mayusculas = false, TextInputType teclado = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        keyboardType: teclado,
        textCapitalization:
            mayusculas ? TextCapitalization.characters : TextCapitalization.words,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          prefixIcon: Icon(icon),
        ),
      ),
    );
  }

  Widget _fechaBtn(String label, String valor, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.calendar_today),
          ),
          child: Text(valor,
              style: TextStyle(
                  color: valor.contains('Seleccionar') ? Colors.grey : Colors.black87)),
        ),
      ),
    );
  }
}
