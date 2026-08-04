// ============================================================
// Integra Del Centro, S.C.
// Desarrollado por: HIRAM JAFET VELAZQUEZ SANTANDER
// screens/nuevo_previo_screen.dart v6.0
// Mejoras: Tipo de bulto, Partidas, Factura Sí/No
// ============================================================

import 'dart:io';
import 'dart:typed_data';
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
  final _referenciaCtrl = TextEditingController();
  final _clienteCtrl = TextEditingController();
  final _almacenCtrl = TextEditingController();
  final _houseCtrl = TextEditingController();
  final _observacionesCtrl = TextEditingController();

  // Tipo de bulto
  String? _tipoBulto;
  final List<String> _tiposBulto = [
    'Palets de madera',
    'Carton',
    'Madera',
    'Cuñete',
    'Plastico',
    'Tambos',
    'Cajas de plastico',
    'Sacos',
    'Bidones',
    'Pacas',
    'Tarimas',
    'Contenedor completo',
    'Carga suelta',
    'Otro',
  ];

  // ¿Viene con factura?
  String? _vieneConFactura;

  final List<Map<String, dynamic>> _fotos = [];
  final List<Map<String, String>> _secciones = [];
  final List<Map<String, String>> _partidas = [];

  String? _destinoActivoId;
  String? _destinoActivoNombre;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.previoEditar;
    if (p != null) {
      _referenciaCtrl.text = p['referencia'] ?? '';
      _clienteCtrl.text = p['cliente'] ?? '';
      _almacenCtrl.text = p['almacen'] ?? '';
      _houseCtrl.text = p['house'] ?? '';
      _observacionesCtrl.text = p['observaciones'] ?? '';
      _tipoBulto = p['tipoBulto'];
      _vieneConFactura = p['vieneConFactura'];

      final rutas = List<String>.from(p['fotos'] ?? []);
      final tipos = List<String>.from(p['fotosTipos'] ?? []);
      final descs = List<String>.from(p['fotosDescripciones'] ?? []);
      final fotosBytes = List<String>.from(p['fotosBytes'] ?? []);

      for (final raw in List.from(p['secciones'] ?? [])) {
        final s = Map<String, String>.from(raw as Map);
        _secciones.add({
          'id': s['id'] ?? DateTime.now().microsecondsSinceEpoch.toString(),
          'nombre': s['nombre'] ?? 'Seccion',
          'informacion': s['informacion'] ?? '',
        });
      }

      for (final raw in List.from(p['partidas'] ?? p['particiones'] ?? [])) {
        final part = Map<String, String>.from(raw as Map);
        _partidas.add({
          'id': part['id'] ?? DateTime.now().microsecondsSinceEpoch.toString(),
          'nombre': part['nombre'] ?? 'Partida',
          'informacion': part['informacion'] ?? '',
        });
      }

      final fotosBloques = List<String>.from(p['fotosBloques'] ?? []);
      for (int i = 0; i < rutas.length; i++) {
        Uint8List? bytes;
        if (i < fotosBytes.length && fotosBytes[i].isNotEmpty) {
          try { bytes = Uint8List.fromList(fotosBytes[i].codeUnits); } catch (_) {}
        }
        if (bytes == null) {
          final file = File(rutas[i]);
          if (file.existsSync()) bytes = file.readAsBytesSync();
        }
        if (bytes != null) {
          _fotos.add({
            'file': File(rutas[i]),
            'bytes': bytes,
            'tipo': i < tipos.length ? tipos[i] : 'Mercancia',
            'descripcion': i < descs.length ? descs[i] : '',
            'bloqueId': i < fotosBloques.length ? fotosBloques[i] : '',
          });
        }
      }

      if (_secciones.isNotEmpty) {
        _destinoActivoId = _secciones.first['id'];
        _destinoActivoNombre = '${_secciones.first['nombre']} (Seccion)';
      } else if (_partidas.isNotEmpty) {
        _destinoActivoId = _partidas.first['id'];
        _destinoActivoNombre = '${_partidas.first['nombre']} (Partida)';
      }
    }
  }

  String _getNombreDestino(String id) {
    for (final s in _secciones) {
      if (s['id'] == id) return '${s['nombre']} (Seccion)';
    }
    for (int i = 0; i < _partidas.length; i++) {
      if (_partidas[i]['id'] == id) return 'Partida ${i + 1}: ${_partidas[i]['nombre']}';
    }
    return 'Sin destino';
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
    if (tipo == 'Averia') return Colors.red.shade700;
    if (tipo == 'Mercancia') return const Color(0xFF2596BE);
    return Colors.orange.shade700;
  }

  Future<Map<String, String>?> _dialogoEntidad(
      String titulo, String labelNombre, String labelInfo,
      TextEditingController nombreCtrl, TextEditingController infoCtrl) async {
    return showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titulo),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nombreCtrl, autofocus: true,
              decoration: InputDecoration(labelText: labelNombre, border: const OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: infoCtrl, maxLines: 3,
              decoration: InputDecoration(labelText: labelInfo, border: const OutlineInputBorder())),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              if (nombreCtrl.text.trim().isNotEmpty) {
                Navigator.pop(ctx, {'nombre': nombreCtrl.text.trim(), 'informacion': infoCtrl.text.trim()});
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2596BE)),
            child: const Text('Guardar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _nuevaSeccion() async {
    final nombreCtrl = TextEditingController();
    final infoCtrl = TextEditingController();
    final result = await _dialogoEntidad('Nueva Seccion', 'Nombre de Seccion',
        'Informacion', nombreCtrl, infoCtrl);
    if (result != null) {
      final id = DateTime.now().microsecondsSinceEpoch.toString();
      setState(() {
        _secciones.add({'id': id, 'nombre': result['nombre']!, 'informacion': result['informacion']!});
        _destinoActivoId = id;
        _destinoActivoNombre = '${result['nombre']} (Seccion)';
      });
    }
  }

  Future<void> _editarSeccion(int index) async {
    final s = _secciones[index];
    final nombreCtrl = TextEditingController(text: s['nombre']);
    final infoCtrl = TextEditingController(text: s['informacion']);
    final result = await _dialogoEntidad('Editar Seccion', 'Nombre', 'Informacion', nombreCtrl, infoCtrl);
    if (result != null) {
      setState(() {
        _secciones[index]['nombre'] = result['nombre']!;
        _secciones[index]['informacion'] = result['informacion']!;
      });
    }
  }

  Future<void> _nuevaPartida() async {
    final nombreCtrl = TextEditingController();
    final infoCtrl = TextEditingController();
    final result = await _dialogoEntidad('Nueva Partida', 'Mercancia',
        'Descripcion', nombreCtrl, infoCtrl);
    if (result != null) {
      final id = DateTime.now().microsecondsSinceEpoch.toString();
      setState(() {
        _partidas.add({'id': id, 'nombre': result['nombre']!, 'informacion': result['informacion']!});
        _destinoActivoId = id;
        _destinoActivoNombre = 'Partida ${_partidas.length}: ${result['nombre']}';
      });
    }
  }

  Future<void> _editarPartida(int index) async {
    final p = _partidas[index];
    final nombreCtrl = TextEditingController(text: p['nombre']);
    final infoCtrl = TextEditingController(text: p['informacion']);
    final result = await _dialogoEntidad('Editar Partida', 'Mercancia', 'Descripcion', nombreCtrl, infoCtrl);
    if (result != null) {
      setState(() {
        _partidas[index]['nombre'] = result['nombre']!;
        _partidas[index]['informacion'] = result['informacion']!;
      });
    }
  }

  Future<void> _agregarFotos() async {
    if (_destinoActivoId == null) {
      _snack('Selecciona primero una Seccion o Partida');
      return;
    }
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FotoContinuaSheet(
        onFotoCapturada: (File file, String tipo, String desc) async {
          final bytes = await file.readAsBytes();
          setState(() => _fotos.add({
            'file': file,
            'bytes': bytes,
            'tipo': tipo,
            'descripcion': desc,
            'bloqueId': _destinoActivoId,
          }));
        },
      ),
    );
  }

  Future<void> _editarDescripcion(int index) async {
    final ctrl = TextEditingController(text: _fotos[index]['descripcion'] as String? ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Descripcion de la foto'),
        content: TextField(controller: ctrl, autofocus: true, maxLines: 3,
            decoration: const InputDecoration(hintText: 'Ej: Caja 1, partida 338...', border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2596BE)),
            child: const Text('Guardar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (result != null) setState(() => _fotos[index]['descripcion'] = result);
  }

  void _removePhoto(int i) => setState(() => _fotos.removeAt(i));

  Future<void> _savePrevio() async {
    final referencia = _referenciaCtrl.text.trim();
    final cliente = _clienteCtrl.text.trim();
    if (referencia.isEmpty) { _snack('Ingresa el Master o Referencia'); return; }
    if (cliente.isEmpty) { _snack('Ingresa el nombre del cliente'); return; }
    if (_fotos.isEmpty) { _snack('Agrega al menos una foto'); return; }

    setState(() => _isSaving = true);
    try {
      final box = Hive.box('previos');
      final id = widget.boxKeyEditar as String? ?? DateTime.now().millisecondsSinceEpoch.toString();

      final todosLosBloques = <Map<String, String>>[];
      for (final s in _secciones) {
        todosLosBloques.add({'id': s['id']!, 'nombre': s['nombre']!, 'informacion': s['informacion']!});
      }
      for (int i = 0; i < _partidas.length; i++) {
        final p = _partidas[i];
        todosLosBloques.add({
          'id': p['id']!,
          'nombre': 'Partida ${i + 1}: ${p['nombre']!}',
          'informacion': p['informacion']!,
        });
      }

      final data = {
        'id': id,
        'referencia': referencia,
        'cliente': cliente,
        'almacen': _almacenCtrl.text.trim(),
        'house': _houseCtrl.text.trim(),
        'fecha': DateTime.now().toIso8601String(),
        'observaciones': _observacionesCtrl.text.trim(),
        'tipoBulto': _tipoBulto,
        'vieneConFactura': _vieneConFactura,
        'fotos': _fotos.map((f) => (f['file'] as File).path).toList(),
        'fotosBytes': _fotos.map((f) => String.fromCharCodes(f['bytes'] as Uint8List)).toList(),
        'fotosTipos': _fotos.map((f) => f['tipo'] as String).toList(),
        'fotosDescripciones': _fotos.map((f) => (f['descripcion'] as String?) ?? '').toList(),
        'fotosBloques': _fotos.map((f) => (f['bloqueId'] as String?) ?? '').toList(),
        'bloques': todosLosBloques,
        'secciones': _secciones,
        'partidas': _partidas,
        'particiones': _partidas, // Compatibilidad
      };

      await box.put(id, data);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(widget.previoEditar != null ? 'Previo actualizado' : 'Previo guardado'),
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

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final esEdicion = widget.previoEditar != null;
    final docCount = _fotos.where((f) => f['tipo'] != 'Mercancia' && f['tipo'] != 'Averia').length;
    final avCount = _fotos.where((f) => f['tipo'] == 'Averia').length;
    final mercCount = _fotos.where((f) => f['tipo'] == 'Mercancia').length;

    return Scaffold(
      appBar: AppBar(
        title: Text(esEdicion ? 'Editar Previo' : 'Nuevo Previo'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _savePrevio,
            child: const Text('GUARDAR', style: TextStyle(color: Colors.white, fontSize: 16)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SeccionHeader(titulo: 'Datos del Embarque', icono: Icons.local_shipping),
          _campo(_referenciaCtrl, 'Master / Referencia / Pedimento *', Icons.tag,
              hint: 'Numero de guia master o pedimento', mayusc: true),
          _campo(_clienteCtrl, 'Cliente *', Icons.business, hint: 'Nombre del dueno de la carga'),
          _campo(_almacenCtrl, 'Almacen', Icons.warehouse, hint: 'Nombre o numero del almacen'),
          _campo(_houseCtrl, 'Numero House Completo', Icons.numbers, hint: 'Ej: CDGO633069-8', mayusc: true),

          // ═══════════ TIPO DE BULTO ═══════════
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: _tipoBulto,
            decoration: const InputDecoration(
              labelText: 'Tipo de Bulto',
              hintText: 'Selecciona el tipo de embalaje',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.inventory_2),
            ),
            items: _tiposBulto.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
            onChanged: (val) => setState(() => _tipoBulto = val),
          ),

          // ═══════════ ¿VIENE CON FACTURA? ═══════════
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('¿Viene con factura?',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text('Si'),
                    value: 'Si',
                    groupValue: _vieneConFactura,
                    onChanged: (val) => setState(() => _vieneConFactura = val),
                    activeColor: const Color(0xFF2596BE),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text('No'),
                    value: 'No',
                    groupValue: _vieneConFactura,
                    onChanged: (val) => setState(() => _vieneConFactura = val),
                    activeColor: const Color(0xFF2596BE),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ]),
            ]),
          ),

          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 14),
            child: TextField(
              controller: _observacionesCtrl, maxLines: 3,
              decoration: const InputDecoration(labelText: 'Observaciones', hintText: 'Notas adicionales...',
                  border: OutlineInputBorder(), prefixIcon: Icon(Icons.notes)),
            ),
          ),
          const Divider(),
          const SizedBox(height: 12),

          // ═══════════ SECCIONES ═══════════
          Row(children: [
            const Icon(Icons.folder_outlined, color: Colors.orange, size: 22),
            const SizedBox(width: 8),
            const Expanded(child: Text('Secciones',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.orange))),
            IconButton(onPressed: _nuevaSeccion, icon: const Icon(Icons.add_circle, color: Colors.orange, size: 28)),
          ]),
          const SizedBox(height: 6),
          if (_secciones.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
              child: const Text('Sin secciones', style: TextStyle(color: Colors.grey), textAlign: TextAlign.center),
            )
          else
            ..._secciones.asMap().entries.map((e) => _buildCard(
              icon: Icons.folder_outlined, color: Colors.orange,
              nombre: e.value['nombre']!, informacion: e.value['informacion']!,
              cantFotos: _fotos.where((f) => f['bloqueId'] == e.value['id']).length,
              tipo: 'SECCION', seleccionado: _destinoActivoId == e.value['id'],
              onSeleccionar: () => setState(() {
                _destinoActivoId = e.value['id'];
                _destinoActivoNombre = '${e.value['nombre']} (Seccion)';
              }),
              onFotos: () {
                _destinoActivoId = e.value['id'];
                _destinoActivoNombre = '${e.value['nombre']} (Seccion)';
                _agregarFotos();
              },
              onEditar: () => _editarSeccion(e.key),
            )),
          const SizedBox(height: 16),

          // ═══════════ PARTIDAS ═══════════
          Row(children: [
            const Icon(Icons.inventory_2_outlined, color: Colors.blue, size: 22),
            const SizedBox(width: 8),
            const Expanded(child: Text('Partidas',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue))),
            IconButton(onPressed: _nuevaPartida, icon: const Icon(Icons.add_circle, color: Colors.blue, size: 28)),
          ]),
          const SizedBox(height: 6),
          if (_partidas.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
              child: const Text('Sin partidas', style: TextStyle(color: Colors.grey), textAlign: TextAlign.center),
            )
          else
            ..._partidas.asMap().entries.map((e) => _buildCard(
              icon: Icons.inventory_2_outlined, color: Colors.blue,
              nombre: 'Partida ${e.key + 1}: ${e.value['nombre']!}',
              informacion: e.value['informacion']!,
              cantFotos: _fotos.where((f) => f['bloqueId'] == e.value['id']).length,
              tipo: 'PARTIDA ${e.key + 1}', seleccionado: _destinoActivoId == e.value['id'],
              onSeleccionar: () => setState(() {
                _destinoActivoId = e.value['id'];
                _destinoActivoNombre = 'Partida ${e.key + 1}: ${e.value['nombre']}';
              }),
              onFotos: () {
                _destinoActivoId = e.value['id'];
                _destinoActivoNombre = 'Partida ${e.key + 1}: ${e.value['nombre']}';
                _agregarFotos();
              },
              onEditar: () => _editarPartida(e.key),
            )),
          const Divider(),
          const SizedBox(height: 12),

          // ═══════════ FOTOGRAFÍAS ═══════════
          const SeccionHeader(titulo: 'Fotografias', icono: Icons.photo_camera),
          const SizedBox(height: 10),
          Text('Total: ${_fotos.length}  •  Doc: $docCount  •  Averia: $avCount  •  Merc: $mercCount',
              textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),

          if (_fotos.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade300)),
              child: Row(children: [
                Icon(Icons.swap_vert, size: 18, color: Colors.amber.shade800),
                const SizedBox(width: 8),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Manten presionada una foto para reordenarla',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amber.shade900)),
                  Text('Toca una foto para editar su descripcion',
                      style: TextStyle(fontSize: 11, color: Colors.amber.shade800)),
                ])),
              ]),
            ),
            const SizedBox(height: 10),
            ReorderableListView.builder(
              shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false, itemCount: _fotos.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex--;
                  final item = _fotos.removeAt(oldIndex);
                  _fotos.insert(newIndex, item);
                });
              },
              itemBuilder: (context, index) {
                final f = _fotos[index];
                final tipo = f['tipo'] as String;
                final desc = f['descripcion'] as String? ?? '';
                final color = _colorTipo(tipo);
                final destinoNombre = _getNombreDestino(f['bloqueId'] as String? ?? '');

                return Padding(
                  key: ValueKey('foto_$index'),
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: color, width: 2)),
                    child: Row(children: [
                      Container(width: 36, height: 100,
                        decoration: BoxDecoration(color: color.withValues(alpha: 0.12),
                            borderRadius: const BorderRadius.horizontal(left: Radius.circular(10))),
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Text('${index + 1}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
                          ReorderableDragStartListener(index: index,
                              child: Icon(Icons.drag_indicator, color: color.withValues(alpha: 0.7), size: 20)),
                        ])),
                      GestureDetector(
                        onTap: () => _editarDescripcion(index),
                        child: ClipRRect(
                          child: Image.memory(f['bytes'] as Uint8List, width: 90, height: 100,
                              fit: BoxFit.cover, cacheWidth: 180),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _editarDescripcion(index),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center, children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(color: color.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: color.withValues(alpha: 0.5))),
                                child: Text(tipo, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
                              ),
                              const SizedBox(height: 2),
                              Text(destinoNombre, style: TextStyle(fontSize: 8, color: Colors.grey.shade500)),
                              const SizedBox(height: 2),
                              if (desc.isNotEmpty)
                                Text(desc, style: const TextStyle(fontSize: 12, color: Colors.black87),
                                    maxLines: 2, overflow: TextOverflow.ellipsis)
                              else
                                Row(children: [
                                  Icon(Icons.edit, size: 12, color: Colors.grey.shade400),
                                  const SizedBox(width: 4),
                                  Text('Toca para agregar descripcion',
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade400, fontStyle: FontStyle.italic)),
                                ]),
                            ]),
                          ),
                        ),
                      ),
                      IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red, size: 22),
                          onPressed: () => _removePhoto(index)),
                    ]),
                  ),
                );
              },
            ),
          ],
          const SizedBox(height: 28),
          ElevatedButton(
            onPressed: _isSaving ? null : _savePrevio,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.save_alt, color: Colors.white, size: 24),
              const SizedBox(width: 10),
              Text(_isSaving ? 'Guardando...' : esEdicion ? 'Actualizar Previo' : 'Guardar Previo',
                  style: const TextStyle(fontSize: 18, color: Colors.white)),
            ]),
          ),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  Widget _buildCard({
    required IconData icon, required Color color,
    required String nombre, required String informacion,
    required int cantFotos, required String tipo,
    required bool seleccionado,
    required VoidCallback onSeleccionar,
    required VoidCallback onFotos,
    required VoidCallback onEditar,
  }) {
    return GestureDetector(
      onTap: onSeleccionar,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: seleccionado ? color.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: seleccionado ? color : Colors.grey.shade200, width: seleccionado ? 2 : 1),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 32, height: 32,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
            child: Icon(icon, color: color, size: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(nombre, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color))),
                Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                    child: Text(tipo, style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: color))),
              ]),
              if (informacion.isNotEmpty) Text(informacion, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              const SizedBox(height: 2),
              Text('$cantFotos fotos', style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ]),
          ),
          Column(children: [
            IconButton(tooltip: 'Fotos', visualDensity: VisualDensity.compact, onPressed: onFotos,
                icon: Icon(Icons.add_a_photo, size: 18, color: color)),
            IconButton(tooltip: 'Editar', visualDensity: VisualDensity.compact, onPressed: onEditar,
                icon: Icon(Icons.edit, size: 16, color: Colors.grey)),
          ]),
        ]),
      ),
    );
  }

  Widget _campo(TextEditingController ctrl, String label, IconData icon,
      {String? hint, bool mayusc = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: ctrl,
        textCapitalization: mayusc ? TextCapitalization.characters : TextCapitalization.words,
        decoration: InputDecoration(labelText: label, hintText: hint,
            border: const OutlineInputBorder(), prefixIcon: Icon(icon)),
      ),
    );
  }
}

// ═══════════════════════════════════════════
// Sheet de captura continua
// ═══════════════════════════════════════════
class _FotoContinuaSheet extends StatefulWidget {
  final Function(File file, String tipo, String descripcion) onFotoCapturada;
  const _FotoContinuaSheet({required this.onFotoCapturada});
  @override
  State<_FotoContinuaSheet> createState() => _FotoContinuaSheetState();
}

class _FotoContinuaSheetState extends State<_FotoContinuaSheet> {
  String _tipo = 'Mercancia';
  bool _cargando = false;
  int _total = 0;
  final _descCtrl = TextEditingController();

  @override
  void dispose() { _descCtrl.dispose(); super.dispose(); }

  Color get _color {
    if (_tipo == 'Averia') return Colors.red.shade700;
    if (_tipo == 'Mercancia') return const Color(0xFF2596BE);
    return Colors.orange.shade700;
  }

  Future<void> _tomar(ImageSource source) async {
    if (_cargando) return;
    setState(() => _cargando = true);
    try {
      final picker = ImagePicker();
      final XFile? picked = await picker.pickImage(
        source: source, imageQuality: _tipo == 'Documento' ? 92 : 82,
        maxWidth: _tipo == 'Documento' ? 1800 : 1600, maxHeight: _tipo == 'Documento' ? 1800 : 1600,
      );
      if (picked == null) return;
      final original = File(picked.path);
      File? processed;
      String tipoFinal = _tipo;
      if (_tipo == 'Documento') {
        processed = await ImageHelper.compressDocument(original);
        final detected = processed != null ? await ImageHelper.detectDocumentType(processed) : null;
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 36 + bottom),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Agregar Fotos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            if (_total > 0) Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green.shade300)),
              child: Text('$_total capturada${_total != 1 ? 's' : ''}', style: TextStyle(fontSize: 12, color: Colors.green.shade700, fontWeight: FontWeight.bold)),
            ),
          ]),
          const SizedBox(height: 14),
          const Align(alignment: Alignment.centerLeft, child: Text('Tipo de foto:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey))),
          const SizedBox(height: 8),
          Row(children: [
            _chip('Mercancia', Icons.inventory_2, const Color(0xFF2596BE)),
            const SizedBox(width: 8),
            _chip('Documento', Icons.description, Colors.orange),
            const SizedBox(width: 8),
            _chip('Averia', Icons.warning_amber_rounded, Colors.red),
          ]),
          const SizedBox(height: 14),
          const Align(alignment: Alignment.centerLeft, child: Text('Descripcion (opcional):', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey))),
          const SizedBox(height: 6),
          TextField(
            controller: _descCtrl, maxLines: 2, textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'Ej: Caja 1, partida 338...', hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              suffixIcon: _descCtrl.text.isNotEmpty ? IconButton(icon: const Icon(Icons.clear, size: 18, color: Colors.grey), onPressed: () { _descCtrl.clear(); setState(() {}); }) : null,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          if (_cargando)
            Padding(padding: const EdgeInsets.symmetric(vertical: 20), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              CircularProgressIndicator(color: _color), const SizedBox(width: 14), const Text('Procesando foto...', style: TextStyle(fontSize: 14)),
            ]))
          else ...[
            ElevatedButton.icon(
              icon: const Icon(Icons.camera_alt, color: Colors.white),
              label: const Text('Tomar foto con camara', style: TextStyle(color: Colors.white, fontSize: 15)),
              style: ElevatedButton.styleFrom(backgroundColor: _color, minimumSize: const Size(double.infinity, 52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: () => _tomar(ImageSource.camera),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              icon: Icon(Icons.photo_library, color: _color),
              label: Text('Elegir de galeria', style: TextStyle(color: _color, fontSize: 15)),
              style: OutlinedButton.styleFrom(side: BorderSide(color: _color, width: 2), minimumSize: const Size(double.infinity, 52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: () => _tomar(ImageSource.gallery),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_total > 0 ? 'Listo — $_total foto${_total != 1 ? 's' : ''} agregada${_total != 1 ? 's' : ''}' : 'Cancelar',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _total > 0 ? Colors.green.shade700 : Colors.grey)),
          )),
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
          duration: const Duration(milliseconds: 150), padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: sel ? color.withValues(alpha: 0.15) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: sel ? color : Colors.grey.shade300, width: sel ? 2 : 1),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: sel ? color : Colors.grey.shade500, size: 22),
            const SizedBox(height: 4),
            Text(tipo, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: sel ? color : Colors.grey.shade500)),
          ]),
        ),
      ),
    );
  }
}