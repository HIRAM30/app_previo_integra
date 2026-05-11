// ============================================================
// Integra Del Centro, S.C.
// Desarrollado por: HIRAM JAFET VELAZQUEZ SANTANDER
// widgets/hallazgo_form_row.dart
// Descripción: Fila editable de la tabla de Observaciones y
//   Hallazgos. Detecta automáticamente discrepancias entre
//   Cantidad Factura y Conteo — resalta la fila en rojo y
//   muestra un banner de advertencia. Sincroniza en tiempo
//   real el modelo HallazgoItem con cada keystroke.
// ============================================================

import 'package:flutter/material.dart';
import '../models/reporte.dart';

class HallazgoFormRow extends StatefulWidget {
  final HallazgoItem hallazgo;
  final VoidCallback onDelete;
  final int indice;

  const HallazgoFormRow({
    super.key,
    required this.hallazgo,
    required this.onDelete,
    required this.indice,
  });

  @override
  State<HallazgoFormRow> createState() => _HallazgoFormRowState();
}

class _HallazgoFormRowState extends State<HallazgoFormRow> {
  late final TextEditingController _factCtrl;
  late final TextEditingController _partCtrl;
  late final TextEditingController _parteCtrl;
  late final TextEditingController _cfCtrl;
  late final TextEditingController _ctCtrl;
  late final TextEditingController _marcaCtrl;
  late final TextEditingController _modeloCtrl;
  late final TextEditingController _obsCtrl;

  bool get _disc => _cfCtrl.text.trim().isNotEmpty &&
      _ctCtrl.text.trim().isNotEmpty &&
      _cfCtrl.text.trim() != _ctCtrl.text.trim();

  @override
  void initState() {
    super.initState();
    final h = widget.hallazgo;
    _factCtrl  = TextEditingController(text: h.noFactura);
    _partCtrl  = TextEditingController(text: h.noPartida);
    _parteCtrl = TextEditingController(text: h.noParte);
    _cfCtrl    = TextEditingController(text: h.cantidadFactura);
    _ctCtrl    = TextEditingController(text: h.conteo);
    _marcaCtrl = TextEditingController(text: h.marca);
    _modeloCtrl= TextEditingController(text: h.modelo);
    _obsCtrl   = TextEditingController(text: h.observaciones);

    for (final c in [_factCtrl, _partCtrl, _parteCtrl,
                     _cfCtrl, _ctCtrl, _marcaCtrl,
                     _modeloCtrl, _obsCtrl]) {
      c.addListener(_sync);
    }
  }

  /// Sincroniza los controllers con el modelo de datos en tiempo real.
  void _sync() {
    widget.hallazgo.noFactura       = _factCtrl.text;
    widget.hallazgo.noPartida       = _partCtrl.text;
    widget.hallazgo.noParte         = _parteCtrl.text;
    widget.hallazgo.cantidadFactura = _cfCtrl.text;
    widget.hallazgo.conteo          = _ctCtrl.text;
    widget.hallazgo.marca           = _marcaCtrl.text;
    widget.hallazgo.modelo          = _modeloCtrl.text;
    widget.hallazgo.observaciones   = _obsCtrl.text;
    setState(() {});
  }

  @override
  void dispose() {
    for (final c in [_factCtrl, _partCtrl, _parteCtrl,
                     _cfCtrl, _ctCtrl, _marcaCtrl,
                     _modeloCtrl, _obsCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disc = _disc;
    final bg = disc
        ? Colors.red.shade50
        : widget.indice % 2 == 0
            ? Colors.white
            : Colors.grey.shade50;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300),
          left: disc
              ? BorderSide(color: Colors.red.shade700, width: 3)
              : BorderSide.none,
        ),
      ),
      child: Column(children: [
        // ── Fila principal ────────────────────────────────
        Row(children: [
          Expanded(flex: 2, child: _mini(_factCtrl,  'S/F', mayusc: true)),
          Expanded(flex: 2, child: _mini(_partCtrl,  'S/P', mayusc: true)),
          Expanded(flex: 3, child: _mini(_parteCtrl, 'No. Parte', mayusc: true)),
          Expanded(
            flex: 2,
            child: _mini(_cfCtrl, '0',
                teclado: TextInputType.number,
                colorTexto: disc ? Colors.red.shade700 : null),
          ),
          Expanded(
            flex: 2,
            child: _mini(_ctCtrl, '0',
                teclado: TextInputType.number,
                colorTexto: disc ? Colors.red.shade700 : null,
                negrita: disc),
          ),
          SizedBox(
            width: 32,
            child: IconButton(
              icon: Icon(Icons.remove_circle,
                  color: Colors.red.shade400, size: 20),
              padding: EdgeInsets.zero,
              tooltip: 'Eliminar',
              onPressed: widget.onDelete,
            ),
          ),
        ]),
        // ── Fila secundaria: Marca / Modelo / Obs ─────────
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
          child: Row(children: [
            Expanded(child: _mini(_marcaCtrl,  'Marca',  label: 'Marca')),
            const SizedBox(width: 4),
            Expanded(child: _mini(_modeloCtrl, 'Modelo', label: 'Modelo')),
            const SizedBox(width: 4),
            Expanded(
                flex: 2,
                child: _mini(_obsCtrl, 'Observaciones...',
                    label: 'Obs.')),
          ]),
        ),
        // ── Alerta de discrepancia ─────────────────────────
        if (disc)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 2),
            color: Colors.red.shade100,
            child: Row(children: [
              Icon(Icons.warning_amber_rounded,
                  size: 13, color: Colors.red.shade700),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'DISCREPANCIA: Factura ${_cfCtrl.text} ≠ Conteo ${_ctCtrl.text}',
                  style: TextStyle(
                      fontSize: 10,
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ]),
          ),
      ]),
    );
  }

  Widget _mini(
    TextEditingController ctrl,
    String hint, {
    String? label,
    TextInputType teclado = TextInputType.text,
    bool mayusc = false,
    Color? colorTexto,
    bool negrita = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      child: TextField(
        controller: ctrl,
        keyboardType: teclado,
        textCapitalization:
            mayusc ? TextCapitalization.characters : TextCapitalization.none,
        style: TextStyle(
          fontSize: 11,
          color: colorTexto,
          fontWeight: negrita ? FontWeight.bold : FontWeight.normal,
        ),
        decoration: InputDecoration(
          hintText: hint,
          labelText: label,
          hintStyle: const TextStyle(fontSize: 10, color: Colors.grey),
          labelStyle: const TextStyle(fontSize: 9),
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          border: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(4))),
          enabledBorder: OutlineInputBorder(
            borderRadius: const BorderRadius.all(Radius.circular(4)),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
        ),
      ),
    );
  }
}
