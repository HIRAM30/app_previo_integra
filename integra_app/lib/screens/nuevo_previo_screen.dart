// ============================================================
// Integra Del Centro, S.C.
// Desarrollado por: HIRAM JAFET VELAZQUEZ SANTANDER
// screens/nuevo_previo_screen.dart v3.5
// Mejoras:
//   - Reordenar fotos con drag & drop
//   - Descripcion visible en el carrusel
//   - Editar descripcion tocando la foto
//   - Corrección de rotación EXIF automática
//   - Bloques del previo con edición y fotos por bloque
// ============================================================

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../utils/image_helper.dart';
import '../widgets/seccion_header.dart';

class NuevoPrevioScreen extends StatefulWidget {
  final Map? previoEditar;
  final dynamic boxKeyEditar;
  const NuevoPrevioScreen({super.key, this.previoEditar, this.boxKeyEditar});

  @override
  State<NuevoPrevioScreen> createState() => _NuevoPrevioScreenState();
}

class _NuevoPrevioScreenState extends State<NuevoPrevioScreen> {
  final _referenciaCtrl    = TextEditingController();
  final _clienteCtrl       = TextEditingController();
  final _almacenCtrl       = TextEditingController();
  final _houseCtrl         = TextEditingController();
  final _observacionesCtrl = TextEditingController();

  // Cada foto: {'file': File, 'tipo': String, 'descripcion': String, 'bloqueId': String}
  final List<Map<String, dynamic>> _fotos = [];
  // Cada bloque: {'id': String, 'nombre': String, 'informacion': String}
  final List<Map<String, String>> _bloques = [];
  String? _bloqueActivoId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.previoEditar;
    if (p != null) {
      _referenciaCtrl.text    = p['referencia']    ?? '';
      _clienteCtrl.text       = p['cliente']       ?? '';
      _almacenCtrl.text       = p['almacen']       ?? '';
      _houseCtrl.text         = p['house']         ?? '';
      _observacionesCtrl.text = p['observaciones'] ?? '';

      final rutas = List<String>.from(p['fotos']              ?? []);
      final tipos = List<String>.from(p['fotosTipos']         ?? []);
      final descs = List<String>.from(p['fotosDescripciones'] ?? []);

      // Cargar bloques existentes
      for (final raw in List.from(p['bloques'] ?? [])) {
        final bloque = Map.from(raw as Map);
        _bloques.add({
          'id': '${bloque['id'] ?? ''}',
          'nombre': '${bloque['nombre'] ?? ''}',
          'informacion': '${bloque['informacion'] ?? ''}',
        });
      }
      if (_bloques.isEmpty) _crearBloqueInicial();
      _bloqueActivoId = _bloques.first['id'];

      // Cargar fotos con bloqueId
      final fotosBloques = List<String>.from(p['fotosBloques'] ?? []);
      for (int i = 0; i < rutas.length; i++) {
        final file = File(rutas[i]);
        if (file.existsSync()) {
          _fotos.add({
            'file':        file,
            'tipo':        i < tipos.length ? tipos[i] : 'Mercancia',
            'descripcion': i < descs.length ? descs[i] : '',
            'bloqueId':    i < fotosBloques.length ? fotosBloques[i] : _bloqueActivoId,
          });
        }
      }
    } else {
      _crearBloqueInicial();
      _bloqueActivoId = _bloques.first['id'];
    }
  }

  void _crearBloqueInicial() {
    _bloques.add({
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'nombre': 'Bloque 1',
      'informacion': '',
    });
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
    if (tipo == 'Mercancia') return const Color(0xFF2596BE);
    return Colors.orange.shade700;
  }

  Future<void> _nuevoBloque() async {
    final nombre = TextEditingController(text: 'Bloque ${_bloques.length + 1}');
    final informacion = TextEditingController();
    final resultado = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nuevo bloque'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: nombre,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Nombre del bloque',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: informacion,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Información del bloque',
              hintText: 'Ej. Caja 1 a 10, partida, contenido...',
              border: OutlineInputBorder(),
            ),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, {
              'nombre': nombre.text.trim(),
              'informacion': informacion.text.trim(),
            }),
            child: const Text('Crear'),
          ),
        ],
      ),
    );
    if (resultado != null && (resultado['nombre'] ?? '').isNotEmpty) {
      final id = DateTime.now().microsecondsSinceEpoch.toString();
      setState(() {
        _bloques.add({'id': id, ...resultado});
        _bloqueActivoId = id;
      });
    }
  }

  Future<void> _editarBloque(Map<String, String> bloque) async {
    final nombre = TextEditingController(text: bloque['nombre']);
    final informacion = TextEditingController(text: bloque['informacion']);
    final resultado = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Editar ${bloque['nombre']}'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: nombre,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Nombre del bloque',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: informacion,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Información del bloque',
              hintText: 'Contenido, cajas, partida u observaciones...',
              border: OutlineInputBorder(),
            ),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, {
              'nombre': nombre.text.trim(),
              'informacion': informacion.text.trim(),
            }),
            child: const Text('Guardar cambios'),
          ),
        ],
      ),
    );
    if (resultado != null && (resultado['nombre'] ?? '').isNotEmpty) {
      setState(() {
        bloque['nombre'] = resultado['nombre']!;
        bloque['informacion'] = resultado['informacion']!;
      });
    }
  }

  Future<void> _agregarFotos() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FotoContinuaSheet(
        onFotoCapturada: (File file, String tipo, String desc) {
          setState(() => _fotos.add({
            'file': file,
            'tipo': tipo,
            'descripcion': desc,
            'bloqueId': _bloqueActivoId,
          }));
        },
      ),
    );
  }

  Future<void> _editarDescripcion(int index) async {
    final ctrl = TextEditingController(
        text: _fotos[index]['descripcion'] as String? ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Descripción de la foto'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Ej: Caja 1, partida 338, etiqueta dañada...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2596BE)),
            child: const Text('Guardar',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (result != null) {
      setState(() => _fotos[index]['descripcion'] = result);
    }
  }

  void _removePhoto(int i) => setState(() => _fotos.removeAt(i));

  Future<void> _savePrevio() async {
    final referencia = _referenciaCtrl.text.trim();
    final cliente    = _clienteCtrl.text.trim();
    if (referencia.isEmpty) { _snack('Ingresa el Master o Referencia'); return; }
    if (cliente.isEmpty)    { _snack('Ingresa el nombre del cliente');  return; }
    if (_fotos.isEmpty)     { _snack('Agrega al menos una foto');       return; }

    setState(() => _isSaving = true);
    try {
      final box = Hive.box('previos');
      final id  = widget.boxKeyEditar as String? ??
          DateTime.now().millisecondsSinceEpoch.toString();

      final data = {
        'id':                 id,
        'referencia':         referencia,
        'cliente':            cliente,
        'almacen':            _almacenCtrl.text.trim(),
        'house':              _houseCtrl.text.trim(),
        'fecha':              DateTime.now().toIso8601String(),
        'observaciones':      _observacionesCtrl.text.trim(),
        'fotos':              _fotos.map((f) => (f['file'] as File).path).toList(),
        'fotosTipos':         _fotos.map((f) => f['tipo'] as String).toList(),
        'fotosDescripciones': _fotos.map((f) => (f['descripcion'] as String?) ?? '').toList(),
        'fotosBloques':       _fotos.map((f) => (f['bloqueId'] as String?) ?? '').toList(),
        'bloques':            _bloques,
      };

      await box.put(id, data);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(widget.previoEditar != null
              ? '✓ Previo actualizado' : '✓ Previo guardado'),
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
    final esEdicion = widget.previoEditar != null;
    final docCount  = _fotos.where((f) => f['tipo'] != 'Mercancia' && f['tipo'] != 'Averia').length;
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
            const SeccionHeader(titulo: 'Datos del Embarque', icono: Icons.local_shipping),
            _campo(_referenciaCtrl, 'Master / Referencia / Pedimento *', Icons.tag,
                hint: 'Número de guía master o pedimento', mayusc: true),
            _campo(_clienteCtrl, 'Cliente *', Icons.business,
                hint: 'Nombre del dueño de la carga'),
            _campo(_almacenCtrl, 'Almacén', Icons.warehouse,
                hint: 'Nombre o número del almacén'),
            _campo(_houseCtrl, 'Número House Completo', Icons.numbers,
                hint: 'Ej: CDGO633069-8', mayusc: true),
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: TextField(
                controller: _observacionesCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Observaciones',
                  hintText: 'Notas adicionales...',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.notes),
                ),
              ),
            ),

            const SizedBox(height: 4),
            const Divider(),
            const SizedBox(height: 12),

            // ─── BLOQUES DEL PREVIO ───
            const SeccionHeader(titulo: 'Particiones del previo', icono: Icons.inventory_2_outlined),
            Row(children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _bloqueActivoId,
                  decoration: const InputDecoration(
                    labelText: 'Bloque para las siguientes fotos',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.view_module_outlined),
                  ),
                  items: _bloques.map((b) => DropdownMenuItem(
                    value: b['id'],
                    child: Text(b['nombre'] ?? 'Bloque'),
                  )).toList(),
                  onChanged: (id) => setState(() => _bloqueActivoId = id),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Agregar bloque',
                onPressed: _nuevoBloque,
                icon: const Icon(Icons.add_circle, color: Color(0xFF2596BE), size: 32),
              ),
            ]),
            const SizedBox(height: 8),
            ..._bloques.map((bloque) {
              final cantidad = _fotos.where((f) => f['bloqueId'] == bloque['id']).length;
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: bloque['id'] == _bloqueActivoId ? const Color(0xFFEAF0FA) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(
                        '${bloque['nombre']} · $cantidad foto${cantidad == 1 ? '' : 's'}',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2596BE)),
                      ),
                      if ((bloque['informacion'] ?? '').isNotEmpty)
                        Text(bloque['informacion']!, style: const TextStyle(fontSize: 12)),
                    ]),
                  ),
                  IconButton(
                    tooltip: 'Agregar fotos a este bloque',
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      setState(() => _bloqueActivoId = bloque['id']);
                      _agregarFotos();
                    },
                    icon: const Icon(Icons.add_a_photo_outlined, color: Color(0xFF2596BE)),
                  ),
                  IconButton(
                    tooltip: 'Editar bloque',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _editarBloque(bloque),
                    icon: const Icon(Icons.edit_outlined, color: Color(0xFF2596BE)),
                  ),
                ]),
              );
            }),
            const SizedBox(height: 8),

            const Divider(),
            const SizedBox(height: 12),

            const SeccionHeader(titulo: 'Fotografías', icono: Icons.photo_camera),

            ElevatedButton(
              onPressed: _agregarFotos,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2596BE),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
              'Total: ${_fotos.length}  •  Doc: $docCount  •  Avería: $avCount  •  Merc: $mercCount',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),

            if (_fotos.isNotEmpty) ...[
              const SizedBox(height: 8),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Row(children: [
                  Icon(Icons.swap_vert, size: 18, color: Colors.amber.shade800),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Mantén presionada una foto para reordenarla',
                            style: TextStyle(fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber.shade900)),
                        Text('Toca una foto para editar su descripción',
                            style: TextStyle(fontSize: 11,
                                color: Colors.amber.shade800)),
                      ],
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 10),

              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                scrollDirection: Axis.vertical,
                buildDefaultDragHandles: false,
                itemCount: _fotos.length,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex--;
                    final item = _fotos.removeAt(oldIndex);
                    _fotos.insert(newIndex, item);
                  });
                },
                itemBuilder: (context, index) {
                  final f     = _fotos[index];
                  final tipo  = f['tipo']        as String;
                  final desc  = f['descripcion'] as String? ?? '';
                  final color = _colorTipo(tipo);
                  final bloqueId = f['bloqueId'] as String? ?? '';
                  final bloqueNombre = _bloques.where((b) => b['id'] == bloqueId).map((b) => b['nombre']).firstOrNull ?? 'Sin bloque';

                  return Padding(
                    key: ValueKey('foto_$index${f['file'].toString()}'),
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: color, width: 2),
                      ),
                      child: Row(children: [
                        Container(
                          width: 36,
                          height: 100,
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.12),
                            borderRadius: const BorderRadius.horizontal(
                                left: Radius.circular(10)),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('${index + 1}',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: color)),
                              const SizedBox(height: 4),
                              ReorderableDragStartListener(
                                index: index,
                                child: Icon(Icons.drag_indicator,
                                    color: color.withOpacity(0.7), size: 20),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _editarDescripcion(index),
                          child: ClipRRect(
                            borderRadius: BorderRadius.zero,
                            child: Image.file(
                              f['file'] as File,
                              width: 90,
                              height: 100,
                              fit: BoxFit.cover,
                              cacheWidth: 180,
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _editarDescripcion(index),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color: color.withOpacity(0.5)),
                                    ),
                                    child: Text(tipo,
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: color)),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(bloqueNombre,
                                      style: TextStyle(fontSize: 9, color: Colors.grey.shade600)),
                                  const SizedBox(height: 2),
                                  if (desc.isNotEmpty)
                                    Text(desc,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.black87),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis)
                                  else
                                    Row(children: [
                                      Icon(Icons.edit,
                                          size: 12,
                                          color: Colors.grey.shade400),
                                      const SizedBox(width: 4),
                                      Text('Toca para agregar descripción',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade400,
                                              fontStyle: FontStyle.italic)),
                                    ]),
                                ],
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.red, size: 22),
                          tooltip: 'Eliminar foto',
                          onPressed: () => _removePhoto(index),
                        ),
                      ]),
                    ),
                  );
                },
              ),
            ],

            const SizedBox(height: 28),

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
                  const Icon(Icons.save_alt, color: Colors.white, size: 24),
                  const SizedBox(width: 10),
                  Text(
                    _isSaving ? 'Guardando...'
                        : esEdicion ? 'Actualizar Previo' : 'Guardar Previo',
                    style: const TextStyle(fontSize: 18, color: Colors.white),
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

  Widget _campo(TextEditingController ctrl, String label, IconData icon,
      {String? hint, bool mayusc = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: ctrl,
        textCapitalization:
            mayusc ? TextCapitalization.characters : TextCapitalization.words,
        decoration: InputDecoration(
          labelText: label, hintText: hint,
          border: const OutlineInputBorder(), prefixIcon: Icon(icon),
        ),
      ),
    );
  }
}

// ================================================================
// Sheet de captura continua con descripcion
// ================================================================
class _FotoContinuaSheet extends StatefulWidget {
  final Function(File file, String tipo, String descripcion) onFotoCapturada;
  const _FotoContinuaSheet({required this.onFotoCapturada});

  @override
  State<_FotoContinuaSheet> createState() => _FotoContinuaSheetState();
}

class _FotoContinuaSheetState extends State<_FotoContinuaSheet> {
  String _tipo     = 'Mercancia';
  bool   _cargando = false;
  int    _total    = 0;
  final  _descCtrl = TextEditingController();

  @override
  void dispose() { _descCtrl.dispose(); super.dispose(); }

  Color get _color {
    if (_tipo == 'Averia')    return Colors.red.shade700;
    if (_tipo == 'Mercancia') return const Color(0xFF2596BE);
    return Colors.orange.shade700;
  }

  Future<void> _tomar(ImageSource source) async {
    if (_cargando) return;
    setState(() => _cargando = true);
    try {
      final picker = ImagePicker();
      final XFile? picked = await picker.pickImage(
        source: source,
        imageQuality: _tipo == 'Documento' ? 92 : 82,
        maxWidth:  _tipo == 'Documento' ? 1800 : 1600,
        maxHeight: _tipo == 'Documento' ? 1800 : 1600,
      );
      if (picked == null) return;

      final original = File(picked.path);
      File?  processed;
      String tipoFinal = _tipo;

      if (_tipo == 'Documento') {
        processed = await ImageHelper.compressDocument(original);
        final detected = processed != null
            ? await ImageHelper.detectDocumentType(processed) : null;
        if (detected != null && detected.isNotEmpty) tipoFinal = detected;
      } else {
        processed = await ImageHelper.compressImage(original);
      }

      if (processed != null) {
        final desc = _descCtrl.text.trim();
        widget.onFotoCapturada(processed, tipoFinal, desc);
        setState(() { _total++; _descCtrl.clear(); });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 36 + bottom),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Agregar Fotos',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            if (_total > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: Text('$_total capturada${_total != 1 ? 's' : ''}',
                    style: TextStyle(fontSize: 12,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.bold)),
              ),
          ]),
          const SizedBox(height: 14),
          const Align(alignment: Alignment.centerLeft,
            child: Text('Tipo de foto:',
                style: TextStyle(fontSize: 13,
                    fontWeight: FontWeight.bold, color: Colors.grey))),
          const SizedBox(height: 8),
          Row(children: [
            _chip('Mercancia', Icons.inventory_2,           const Color(0xFF2596BE)),
            const SizedBox(width: 8),
            _chip('Documento', Icons.description,           Colors.orange),
            const SizedBox(width: 8),
            _chip('Averia',    Icons.warning_amber_rounded, Colors.red),
          ]),
          const SizedBox(height: 14),
          const Align(alignment: Alignment.centerLeft,
            child: Text('Descripción (opcional):',
                style: TextStyle(fontSize: 13,
                    fontWeight: FontWeight.bold, color: Colors.grey))),
          const SizedBox(height: 6),
          TextField(
            controller: _descCtrl,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'Ej: Caja 1, partida 338, etiqueta dañada...',
              hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              suffixIcon: _descCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                      onPressed: () { _descCtrl.clear(); setState(() {}); })
                  : null,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          if (_cargando)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                CircularProgressIndicator(color: _color),
                const SizedBox(width: 14),
                const Text('Procesando foto...', style: TextStyle(fontSize: 14)),
              ]),
            )
          else ...[
            ElevatedButton.icon(
              icon: const Icon(Icons.camera_alt, color: Colors.white),
              label: const Text('Tomar foto con cámara',
                  style: TextStyle(color: Colors.white, fontSize: 15)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _color,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => _tomar(ImageSource.gallery),
            ),
          ],
          const SizedBox(height: 12),
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
                  fontSize: 15, fontWeight: FontWeight.bold,
                  color: _total > 0 ? Colors.green.shade700 : Colors.grey,
                ),
              ),
            ),
          ),
        ]),
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
                width: sel ? 2 : 1),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: sel ? color : Colors.grey.shade500, size: 22),
            const SizedBox(height: 4),
            Text(tipo, style: TextStyle(fontSize: 11,
                fontWeight: FontWeight.bold,
                color: sel ? color : Colors.grey.shade500)),
          ]),
        ),
      ),
    );
  }
}