// ============================================================
// Integra Del Centro, S.C.
// Desarrollado por: HIRAM JAFET VELAZQUEZ SANTANDER
// screens/nuevo_previo_screen.dart v3.1
// Mejoras:
//   - "Terminación House" → "Número House Completo"
//   - "Referencia/Pedimento" → "Master / Referencia / Pedimento"
//   - Captura continua: sheet se queda abierto para seguir
//     tomando fotos sin volver a elegir tipo cada vez.
//   - Soporte para EDITAR previo existente (recibe previoEditar)
// ============================================================

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../utils/image_helper.dart';
import '../widgets/seccion_header.dart';

class NuevoPrevioScreen extends StatefulWidget {
  /// Datos del previo a editar. Si es null, crea uno nuevo.
  final Map? previoEditar;

  /// Key de Hive del previo a editar.
  final dynamic boxKeyEditar;

  const NuevoPrevioScreen({
    super.key,
    this.previoEditar,
    this.boxKeyEditar,
  });

  @override
  State<NuevoPrevioScreen> createState() => _NuevoPrevioScreenState();
}

class _NuevoPrevioScreenState extends State<NuevoPrevioScreen> {
  final _referenciaCtrl    = TextEditingController();
  final _clienteCtrl       = TextEditingController();
  final _almacenCtrl       = TextEditingController();
  final _houseCtrl         = TextEditingController();
  final _observacionesCtrl = TextEditingController();

  final List<Map<String, dynamic>> _fotos = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Pre-llenar si es edición
    final p = widget.previoEditar;
    if (p != null) {
      _referenciaCtrl.text    = p['referencia']    ?? '';
      _clienteCtrl.text       = p['cliente']       ?? '';
      _almacenCtrl.text       = p['almacen']       ?? '';
      _houseCtrl.text         = p['house']         ?? '';
      _observacionesCtrl.text = p['observaciones'] ?? '';

      // Cargar fotos existentes
      final rutas = List<String>.from(p['fotos']      ?? []);
      final tipos = List<String>.from(p['fotosTipos'] ?? []);
      for (int i = 0; i < rutas.length; i++) {
        final file = File(rutas[i]);
        if (file.existsSync()) {
          _fotos.add({
            'file': file,
            'tipo': i < tipos.length ? tipos[i] : 'Mercancia',
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _referenciaCtrl.dispose();
    _clienteCtrl.dispose();
    _almacenCtrl.dispose();
    _houseCtrl.dispose();
    _observacionesCtrl.dispose();
    super.dispose();
  }

  Color _colorTipo(String tipo) {
    if (tipo == 'Averia')    return Colors.red.shade700;
    if (tipo == 'Mercancia') return const Color(0xFF003087);
    return Colors.orange.shade700;
  }

  /// Abre el sheet de captura continua.
  /// El sheet se queda abierto hasta que el usuario presione "Listo".
  Future<void> _agregarFotos() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FotoContinuaSheet(
        onFotoCapturada: (File file, String tipo) {
          setState(() => _fotos.add({'file': file, 'tipo': tipo}));
        },
      ),
    );
  }

  void _removePhoto(int i) => setState(() => _fotos.removeAt(i));

  /// Guarda o actualiza el previo en Hive.
  Future<void> _savePrevio() async {
    final referencia = _referenciaCtrl.text.trim();
    final cliente    = _clienteCtrl.text.trim();

    if (referencia.isEmpty) {
      _snack('Ingresa el Master o Referencia');
      return;
    }
    if (cliente.isEmpty) {
      _snack('Ingresa el nombre del cliente');
      return;
    }
    if (_fotos.isEmpty) {
      _snack('Agrega al menos una foto');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final box = Hive.box('previos');
      // En edición usa la misma key, en nuevo crea una nueva
      final id = widget.boxKeyEditar as String? ??
          DateTime.now().millisecondsSinceEpoch.toString();

      final data = {
        'id':            id,
        'referencia':    referencia,
        'cliente':       cliente,
        'almacen':       _almacenCtrl.text.trim(),
        'house':         _houseCtrl.text.trim(),
        'fecha':         DateTime.now().toIso8601String(),
        'observaciones': _observacionesCtrl.text.trim(),
        'fotos':         _fotos.map((f) => (f['file'] as File).path).toList(),
        'fotosTipos':    _fotos.map((f) => f['tipo']  as String).toList(),
      };

      await box.put(id, data);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(widget.previoEditar != null
              ? '✓ Previo actualizado correctamente'
              : '✓ Previo guardado correctamente'),
          backgroundColor: Colors.green,
        ));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) _snack('Error al guardar: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final bool esEdicion = widget.previoEditar != null;
    final docCount  = _fotos.where((f) =>
        f['tipo'] != 'Mercancia' && f['tipo'] != 'Averia').length;
    final avCount   = _fotos.where((f) => f['tipo'] == 'Averia').length;
    final mercCount = _fotos.where((f) => f['tipo'] == 'Mercancia').length;

    return Scaffold(
      appBar: AppBar(
        title: Text(esEdicion ? 'Editar Previo' : 'Nuevo Previo'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _savePrevio,
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

            // ═══ DATOS DEL EMBARQUE ═══════════════════════════
            const SeccionHeader(
              titulo: 'Datos del Embarque',
              icono: Icons.local_shipping,
            ),

            _campo(
              _referenciaCtrl,
              'Master / Referencia / Pedimento *',
              Icons.tag,
              hint: 'Número de guía master o pedimento',
              mayusc: true,
            ),
            _campo(
              _clienteCtrl,
              'Cliente *',
              Icons.business,
              hint: 'Nombre del dueño de la carga',
            ),
            _campo(
              _almacenCtrl,
              'Almacén',
              Icons.warehouse,
              hint: 'Nombre o número del almacén',
            ),
            _campo(
              _houseCtrl,
              'Número House Completo',
              Icons.numbers,
              hint: 'Ej: CDGO633069-8',
              mayusc: true,
            ),

            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: TextField(
                controller: _observacionesCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Observaciones',
                  hintText: 'Notas adicionales del embarque...',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.notes),
                ),
              ),
            ),

            const SizedBox(height: 4),
            const Divider(),
            const SizedBox(height: 12),

            // ═══ FOTOGRAFÍAS ══════════════════════════════════
            const SeccionHeader(
              titulo: 'Fotografías',
              icono: Icons.photo_camera,
            ),

            ElevatedButton(
              onPressed: _agregarFotos,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF003087),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo, size: 26, color: Colors.white),
                  SizedBox(width: 10),
                  Text('Agregar Fotos',
                      style: TextStyle(fontSize: 18, color: Colors.white)),
                ],
              ),
            ),

            const SizedBox(height: 10),

            Text(
              'Total: ${_fotos.length}  •  Doc: $docCount  •  '
              'Avería: $avCount  •  Merc: $mercCount',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.bold),
            ),

            // Carrusel de fotos
            if (_fotos.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 145,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _fotos.length,
                  itemBuilder: (_, i) {
                    final f     = _fotos[i];
                    final tipo  = f['tipo'] as String;
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
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(6)),
                            child: Image.file(
                              f['file'] as File,
                              height: 105, width: 115,
                              fit: BoxFit.cover,
                              cacheHeight: 200, cacheWidth: 200,
                            ),
                          ),
                          Container(
                            width: double.infinity,
                            padding:
                                const EdgeInsets.symmetric(vertical: 3),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.15),
                              borderRadius: const BorderRadius.vertical(
                                  bottom: Radius.circular(6)),
                            ),
                            child: Text(tipo,
                                style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: color),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                        ]),
                      ),
                      Positioned(
                        top: 0, right: 2,
                        child: GestureDetector(
                          onTap: () => _removePhoto(i),
                          child: Container(
                            decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle),
                            child: const Icon(Icons.close,
                                color: Colors.white, size: 18),
                          ),
                        ),
                      ),
                    ]);
                  },
                ),
              ),
            ],

            const SizedBox(height: 28),

            // Botón guardar
            ElevatedButton(
              onPressed: _isSaving ? null : _savePrevio,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.save_alt,
                      color: Colors.white, size: 24),
                  const SizedBox(width: 10),
                  Text(
                    _isSaving
                        ? 'Guardando...'
                        : esEdicion
                            ? 'Actualizar Previo'
                            : 'Guardar Previo',
                    style: const TextStyle(
                        fontSize: 18, color: Colors.white),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _campo(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    String? hint,
    bool mayusc = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: ctrl,
        textCapitalization: mayusc
            ? TextCapitalization.characters
            : TextCapitalization.words,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
          prefixIcon: Icon(icon),
        ),
      ),
    );
  }
}

// ================================================================
// Sheet de captura CONTINUA de fotos
// Se queda abierto hasta que el usuario presione "Listo".
// El tipo seleccionado persiste entre capturas.
// ================================================================
class _FotoContinuaSheet extends StatefulWidget {
  final Function(File file, String tipo) onFotoCapturada;
  const _FotoContinuaSheet({required this.onFotoCapturada});

  @override
  State<_FotoContinuaSheet> createState() => _FotoContinuaSheetState();
}

class _FotoContinuaSheetState extends State<_FotoContinuaSheet> {
  String _tipo     = 'Mercancia';
  bool   _cargando = false;
  int    _total    = 0;

  Color get _color {
    if (_tipo == 'Averia')    return Colors.red.shade700;
    if (_tipo == 'Mercancia') return const Color(0xFF003087);
    return Colors.orange.shade700;
  }

  Future<void> _tomar(ImageSource source) async {
    if (_cargando) return;
    setState(() => _cargando = true);
    try {
      final picker = ImagePicker();
      final XFile? picked = await picker.pickImage(
        source:       source,
        imageQuality: _tipo == 'Documento' ? 92 : 82,
        maxWidth:     _tipo == 'Documento' ? 1800 : 1600,
        maxHeight:    _tipo == 'Documento' ? 1800 : 1600,
      );
      if (picked == null) return;

      final original = File(picked.path);
      File?  processed;
      String tipoFinal = _tipo;

      if (_tipo == 'Documento') {
        processed = await ImageHelper.compressDocument(original);
        final detected = processed != null
            ? await ImageHelper.detectDocumentType(processed)
            : null;
        if (detected != null && detected.isNotEmpty) tipoFinal = detected;
      } else {
        processed = await ImageHelper.compressImage(original);
      }

      if (processed != null) {
        widget.onFotoCapturada(processed, tipoFinal);
        setState(() => _total++);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Manija
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),

          // Título + contador
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Agregar Fotos',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              if (_total > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade300),
                  ),
                  child: Text(
                    '$_total capturada${_total != 1 ? 's' : ''}',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Selector de tipo
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Tipo de foto:',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey)),
          ),
          const SizedBox(height: 8),
          Row(children: [
            _chip('Mercancia', Icons.inventory_2,
                const Color(0xFF003087)),
            const SizedBox(width: 8),
            _chip('Documento', Icons.description, Colors.orange),
            const SizedBox(width: 8),
            _chip('Averia', Icons.warning_amber_rounded, Colors.red),
          ]),
          const SizedBox(height: 20),

          // Botones o indicador de carga
          if (_cargando)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: _color),
                  const SizedBox(width: 14),
                  const Text('Procesando foto...',
                      style: TextStyle(fontSize: 14)),
                ],
              ),
            )
          else ...[
            ElevatedButton.icon(
              icon: const Icon(Icons.camera_alt, color: Colors.white),
              label: const Text('Tomar foto con cámara',
                  style: TextStyle(color: Colors.white, fontSize: 15)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _color,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => _tomar(ImageSource.camera),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              icon: Icon(Icons.photo_library, color: _color),
              label: Text('Elegir de galería',
                  style: TextStyle(color: _color, fontSize: 15)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: _color, width: 2),
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => _tomar(ImageSource.gallery),
            ),
          ],

          const SizedBox(height: 14),

          // Listo / Cancelar
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12)),
              child: Text(
                _total > 0
                    ? 'Listo — $_total foto${_total != 1 ? 's' : ''} '
                      'agregada${_total != 1 ? 's' : ''}'
                    : 'Cancelar',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: _total > 0
                      ? Colors.green.shade700
                      : Colors.grey,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String tipo, IconData icon, Color color) {
    final sel = _tipo == tipo;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tipo = tipo),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: sel ? color.withOpacity(0.15) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: sel ? color : Colors.grey.shade300,
              width: sel ? 2 : 1,
            ),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon,
                color: sel ? color : Colors.grey.shade500,
                size: 22),
            const SizedBox(height: 4),
            Text(tipo,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: sel ? color : Colors.grey.shade500)),
          ]),
        ),
      ),
    );
  }
}