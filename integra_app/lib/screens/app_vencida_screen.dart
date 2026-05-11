// ============================================================
// Integra Del Centro, S.C.
// Desarrollado por: HIRAM JAFET VELAZQUEZ SANTANDER
// screens/app_vencida_screen.dart
// Descripción: Pantalla de bloqueo cuando la licencia expira.
//   Muestra un mensaje claro con instrucciones para renovar.
//   Corre como app independiente (tiene su propio MaterialApp)
//   porque se invoca antes de inicializar Hive.
// ============================================================

import 'dart:io';
import 'package:flutter/material.dart';

class AppVencidaScreen extends StatelessWidget {
  const AppVencidaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF003087),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline,
                    size: 90, color: Colors.white),
                const SizedBox(height: 30),
                const Text('Licencia Vencida',
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                const SizedBox(height: 16),
                const Text(
                  'El periodo de uso de esta aplicación\nha concluido.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.white70),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Contacta al desarrollador para renovar:\nHIRAM JAFET VELAZQUEZ SANTANDER',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.white60),
                ),
                const SizedBox(height: 50),
                ElevatedButton.icon(
                  onPressed: () => exit(0),
                  icon: const Icon(Icons.close, color: Color(0xFF003087)),
                  label: const Text('Cerrar',
                      style: TextStyle(
                          fontSize: 18,
                          color: Color(0xFF003087),
                          fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        vertical: 14, horizontal: 40),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
