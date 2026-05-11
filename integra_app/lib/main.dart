// ============================================================
// Integra Del Centro, S.C.
// Sistema Aduanal Integral — Previos + Reportes de Discrepancia
// ============================================================
// Desarrollado por: HIRAM JAFET VELAZQUEZ SANTANDER
// Versión: 3.0 (fusión)
// Cambios v3.0:
//   - Módulo de Reportes de Discrepancia integrado
//   - Exportar reporte a archivo .integra (JSON+fotos base64)
//     para abrir en la Web App de oficina
//   - Botón "Generar Reporte" desde el Detalle del Previo
//     pre-llena automáticamente todos los datos
//   - SplashScreen abre ambos boxes de Hive (previos + reportes)
// ============================================================

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'screens/splash_screen.dart';
import 'screens/app_vencida_screen.dart';

/// Fecha de expiración de la licencia.
/// Cambia esta fecha para renovar sin tocar más código.
const String _fechaExpiracion = '2027-12-31';

/// Versión visible en la pantalla de Acerca de
const String kVersionApp = '3.0';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Verificación de licencia ──────────────────────────────
  final hoy = DateTime.now();
  final expira = DateTime.parse(_fechaExpiracion);
  if (hoy.isAfter(expira)) {
    runApp(const AppVencidaScreen());
    return;
  }

  // Hive se inicializa en el SplashScreen para no bloquear arranque
  runApp(const IntegraApp());
}

/// Widget raíz. Define el tema corporativo de Integra Del Centro
/// que aplica a toda la app: previos Y reportes de discrepancia.
class IntegraApp extends StatelessWidget {
  const IntegraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Integra Del Centro — Sistema Aduanal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: false,
        primaryColor: const Color(0xFF003087),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF003087),
          primary: const Color(0xFF003087),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF003087),
          foregroundColor: Colors.white,
          iconTheme: IconThemeData(color: Colors.white, size: 24),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          elevation: 2,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF003087),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 14),
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
