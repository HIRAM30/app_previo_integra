// ============================================================
// Integra Del Centro, S.C.
// Desarrollado por: HIRAM JAFET VELAZQUEZ SANTANDER
// screens/gestion_bloques_screen.dart
// Descripción: Pantalla para gestionar bloques y elementos
//   dentro de un previo aduanal.
// ============================================================

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../utils/image_helper.dart';

class GestionBloquesScreen extends StatefulWidget {
  final Map previo;
  final dynamic boxKey;

  const GestionBloquesScreen({
    super.key,
    required this.previo,
    required this.boxKey,
  });

  @override
  State<GestionBloquesScreen> createState() => _GestionBloquesScreenState();
}

class _GestionBloquesScreenState extends State<GestionBloquesScreen> {
  late List<Map<String, dynamic>> _bloques;

  @override
  void initState() {
    super.initState();
    _bloques = List<Map<String, dynamic>>.from(
      widget.previo['bloques'] ?? [],
    );
  }

  Future<void> _guardarCambios() async {
    final box = Hive.box('previos');
    final data = Map<String, dynamic>.from(widget.previo);
    data['bloques'] = _bloques;
    await box.put(widget.boxKey, data);
  }

  // ─── DIÁLOGO NUEVO/EDITAR BLOQUE ─────────────────────────
  Future<void> _dialogoBloque({int? index}) async {
    final esEdicion = index != null;
    final bloque = esEdicion ? _bloques[index] : <String, dynamic>{};

    final nombreCtrl = TextEditingController(text: bloque['nombre'] ?? '');
    final descCtrl = TextEditingController(text: bloque['descripcion'] ?? '');
    final cantCtrl = TextEditingController(text: bloque['cantidad']?.toString() ?? '');
    final pesoCtrl = TextEditingController(text: bloque['peso']?.toString() ?? '');
    final infoCtrl = TextEditingController(text: bloque['informacion'] ?? '');
    String estado = bloque['estado'] ?? 'Correcto';

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(esEdicion ? 'Editar Bloque' : 'Nuevo Bloque'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre del Bloque *',
                  hintText: 'Ej: Tarima 1-3, Mercancía dañada',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Descripción General',
                  hintText: 'Ej: Cajas de herramienta eléctrica',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: cantCtrl,
                decoration: const InputDecoration(
                  labelText: 'Cantidad de Elementos',
                  hintText: 'Ej: 24',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: pesoCtrl,
                decoration: const InputDecoration(
                  labelText: 'Peso (kg)',
                  hintText: 'Ej: 580.5',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Estado',
                  border: OutlineInputBorder(),
                ),
                value: estado,
                items: ['Correcto', 'Incompleto', 'Dañado', 'Con Discrepancia']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => estado = v ?? 'Correcto',
              ),
              const SizedBox(height: 10),
              TextField(
                controller: infoCtrl,
                decoration: const InputDecoration(
                  labelText: 'Información/Observaciones',
                  hintText: 'Detalles específicos del bloque',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nombreCtrl.text.isNotEmpty) {
                Navigator.pop(ctx, {
                  'id': bloque['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
                  'nombre': nombreCtrl.text,
                  'descripcion': descCtrl.text,
                  'cantidad': int.tryParse(cantCtrl.text) ?? 0,
                  'peso': double.tryParse(pesoCtrl.text) ?? 0,
                  'estado': estado,
                  'informacion': infoCtrl.text,
                  'elementos': bloque['elementos'] ?? [],
                  'fotos': bloque['fotos'] ?? [],
                });
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF003087),
            ),
            child: const Text('Guardar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result != null) {
      setState(() {
        if (esEdicion) {
          _bloques[index!] = result;
        } else {
          _bloques.add(result);
        }
      });
      await _guardarCambios();
    }
  }

  // ─── DIÁLOGO NUEVO/EDITAR ELEMENTO ────────────────────────
  Future<void> _dialogoElemento(int bloqueIndex, {int? elemIndex}) async {
    final esEdicion = elemIndex != null;
    final bloque = _bloques[bloqueIndex];
    final elementos = List<Map<String, dynamic>>.from(bloque['elementos'] ?? []);
    final elemento = esEdicion ? elementos[elemIndex] : <String, dynamic>{};

    final nombreCtrl = TextEditingController(text: elemento['nombre'] ?? '');
    final descCtrl = TextEditingController(text: elemento['descripcion'] ?? '');
    final marcaCtrl = TextEditingController(text: elemento['marca'] ?? '');
    final modeloCtrl = TextEditingController(text: elemento['modelo'] ?? '');
    final declCtrl = TextEditingController(text: elemento['cantidadDeclarada']?.toString() ?? '');
    final encCtrl = TextEditingController(text: elemento['cantidadEncontrada']?.toString() ?? '');
    final serieCtrl = TextEditingController(text: elemento['numeroSerie'] ?? '');
    final obsCtrl = TextEditingController(text: elemento['observaciones'] ?? '');
    String estado = elemento['estado'] ?? 'Correcto';

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(esEdicion ? 'Editar Elemento' : 'Nuevo Elemento'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre del Elemento *',
                  hintText: 'Ej: Caja de taladros',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Descripción Comercial',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: marcaCtrl,
                decoration: const InputDecoration(
                  labelText: 'Marca',
                  hintText: 'Ej: BOSCH',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: modeloCtrl,
                decoration: const InputDecoration(
                  labelText: 'Modelo',
                  hintText: 'Ej: GSB-550',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: declCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Cant. Declarada',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: encCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Cant. Encontrada',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              TextField(
                controller: serieCtrl,
                decoration: const InputDecoration(
                  labelText: 'Número de Serie',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Estado',
                  border: OutlineInputBorder(),
                ),
                value: estado,
                items: ['Correcto', 'Averiado', 'Incompleto', 'Faltante']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => estado = v ?? 'Correcto',
              ),
              const SizedBox(height: 10),
              TextField(
                controller: obsCtrl,
                decoration: const InputDecoration(
                  labelText: 'Observaciones',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nombreCtrl.text.isNotEmpty) {
                Navigator.pop(ctx, {
                  'id': elemento['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
                  'nombre': nombreCtrl.text,
                  'descripcion': descCtrl.text,
                  'marca': marcaCtrl.text,
                  'modelo': modeloCtrl.text,
                  'cantidadDeclarada': int.tryParse(declCtrl.text) ?? 0,
                  'cantidadEncontrada': int.tryParse(encCtrl.text) ?? 0,
                  'numeroSerie': serieCtrl.text,
                  'estado': estado,
                  'observaciones': obsCtrl.text,
                  'fotos': elemento['fotos'] ?? [],
                });
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF003087),
            ),
            child: const Text('Guardar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result != null) {
      setState(() {
        if (esEdicion) {
          elementos[elemIndex!] = result;
        } else {
          elementos.add(result);
        }
        _bloques[bloqueIndex]['elementos'] = elementos;
      });
      await _guardarCambios();
    }
  }

  // ─── AGREGAR FOTO A BLOQUE ────────────────────────────────
  Future<void> _agregarFotoBloque(int bloqueIndex) async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 82,
      maxWidth: 1600,
      maxHeight: 1600,
    );
    if (picked == null) return;

    final original = File(picked.path);
    final processed = await ImageHelper.compressImage(original);

    if (processed != null && mounted) {
      setState(() {
        final fotos = List<String>.from(_bloques[bloqueIndex]['fotos'] ?? []);
        fotos.add(processed.path);
        _bloques[bloqueIndex]['fotos'] = fotos;
      });
      await _guardarCambios();
    }
  }

  // ─── AGREGAR FOTO A ELEMENTO ──────────────────────────────
  Future<void> _agregarFotoElemento(int bloqueIndex, int elemIndex) async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 82,
      maxWidth: 1600,
      maxHeight: 1600,
    );
    if (picked == null) return;

    final original = File(picked.path);
    final processed = await ImageHelper.compressImage(original);

    if (processed != null && mounted) {
      setState(() {
        final elementos = List<Map<String, dynamic>>.from(
            _bloques[bloqueIndex]['elementos'] ?? []);
        final fotos = List<String>.from(elementos[elemIndex]['fotos'] ?? []);
        fotos.add(processed.path);
        elementos[elemIndex]['fotos'] = fotos;
        _bloques[bloqueIndex]['elementos'] = elementos;
      });
      await _guardarCambios();
    }
  }

  // ─── ELIMINAR BLOQUE ──────────────────────────────────────
  Future<void> _eliminarBloque(int index) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Bloque'),
        content: Text('¿Eliminar "${_bloques[index]['nombre']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true) {
      setState(() => _bloques.removeAt(index));
      await _guardarCambios();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bloques — ${widget.previo['referencia'] ?? 'Previo'}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save, color: Colors.white),
            tooltip: 'Guardar cambios',
            onPressed: () async {
              await _guardarCambios();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✓ Cambios guardados'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _bloques.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        const Text('No hay bloques'),
                        const SizedBox(height: 8),
                        const Text('Agrega el primer bloque para organizar la mercancía'),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _bloques.length,
                    itemBuilder: (context, i) {
                      final bloque = _bloques[i];
                      final elementos = List<Map<String, dynamic>>.from(
                          bloque['elementos'] ?? []);
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ExpansionTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFF003087),
                            child: Text('${i + 1}',
                                style: const TextStyle(color: Colors.white)),
                          ),
                          title: Text(bloque['nombre'] ?? 'Bloque ${i + 1}'),
                          subtitle: Text(
                            '${elementos.length} elementos • '
                            '${(bloque['fotos'] as List?)?.length ?? 0} fotos',
                            style: const TextStyle(fontSize: 12),
                          ),
                          children: [
                            // Botones del bloque
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  _btnAccion(Icons.edit, 'Editar', const Color(0xFF003087),
                                      () => _dialogoBloque(index: i)),
                                  _btnAccion(Icons.add_a_photo, 'Foto', Colors.green,
                                      () => _agregarFotoBloque(i)),
                                  _btnAccion(Icons.add_box, 'Elemento', Colors.orange,
                                      () => _dialogoElemento(i)),
                                  _btnAccion(Icons.delete, 'Eliminar', Colors.red,
                                      () => _eliminarBloque(i)),
                                ],
                              ),
                            ),
                            const Divider(),
                            // Lista de elementos
                            ...elementos.asMap().entries.map((entry) {
                              final j = entry.key;
                              final elem = entry.value;
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.grey.shade200,
                                  child: Text('${j + 1}',
                                      style: const TextStyle(color: Colors.black87)),
                                ),
                                title: Text(elem['nombre'] ?? 'Elemento ${j + 1}'),
                                subtitle: Text(
                                  '${elem['marca'] ?? ''} ${elem['modelo'] ?? ''}',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, size: 18),
                                      onPressed: () => _dialogoElemento(i, elemIndex: j),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add_a_photo, size: 18),
                                      onPressed: () => _agregarFotoElemento(i, j),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          // Botón para nuevo bloque
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Nuevo Bloque'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF003087),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => _dialogoBloque(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _btnAccion(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 10, color: color)),
          ],
        ),
      ),
    );
  }
}