// ============================================================
// Integra Del Centro, S.C.
// Desarrollado por: HIRAM JAFET VELAZQUEZ SANTANDER
// widgets/seccion_header.dart
// Descripción: Encabezado de sección con icono, título y
//   línea decorativa con degradado en el color corporativo.
//   Reutilizado en NuevoPrevioScreen y NuevoReporteScreen.
// ============================================================

import 'package:flutter/material.dart';

class SeccionHeader extends StatelessWidget {
  final String titulo;
  final IconData icono;

  const SeccionHeader({
    super.key,
    required this.titulo,
    required this.icono,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icono, color: const Color(0xFF2596BE), size: 20),
          const SizedBox(width: 8),
          Text(titulo,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2596BE))),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF2596BE).withOpacity(0.6),
                    const Color(0xFF2596BE).withOpacity(0.04),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
