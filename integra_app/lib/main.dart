// ============================================================
// Integra Del Centro, S.C.
// Sistema Aduanal Integral — Previos + Reportes de Discrepancia
// ============================================================
// Desarrollado por: HIRAM JAFET VELAZQUEZ SANTANDER
// Desarrollado por: ISMAEL MORALES BARRIOS
// Versión: 3.0 (fusión)
// Cambios v3.0:
//   - Módulo de Reportes de Discrepancia integrado
//   - Exportar reporte a archivo .integra (JSON+fotos base64)
//   - Botón "Generar Reporte" desde el Detalle del Previo
//     pre-llena automáticamente todos los datos
//   - SplashScreen abre ambos boxes de Hive (previos + reportes)
//
// [COMENTADO] Se removieron las referencias a la Web App de
// oficina. El .integra sigue exportándose para respaldo entre
// teléfonos. Cuando exista la Web App, se reactivan los textos.
//
// v3.1: Recibe archivos .integra entrantes desde WhatsApp,
//       correo, Bluetooth, etc. y los importa automáticamente.
// ============================================================

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'screens/splash_screen.dart';
import 'screens/app_vencida_screen.dart';
import 'services/export_service_previo.dart';
import 'services/export_service.dart';

/// Fecha de expiración de la licencia.
const String _fechaExpiracion = '2027-12-31';

/// Versión visible en la pantalla de Acerca de
const String kVersionApp = '3.0';

/// ═══ Variables globales para manejar archivos entrantes ═══
StreamSubscription? _intentSub;
final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();
String? _archivoEntrantePendiente;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Verificación de licencia ──────────────────────────────
  final hoy = DateTime.now();
  final expira = DateTime.parse(_fechaExpiracion);
  if (hoy.isAfter(expira)) {
    runApp(const AppVencidaScreen());
    return;
  }

  // ═══ Escuchar archivos que llegan con la app CERRADA ═══
  ReceiveSharingIntent.instance.getInitialMedia().then((value) {
    if (value.isNotEmpty) {
      _archivoEntrantePendiente = value.first.path;
    }
  });

  runApp(const IntegraApp());
}

/// Widget raíz.
class IntegraApp extends StatefulWidget {
  const IntegraApp({super.key});

  @override
  State<IntegraApp> createState() => _IntegraAppState();
}

class _IntegraAppState extends State<IntegraApp> {
  @override
  void initState() {
    super.initState();
    _inicializarEscuchaArchivos();
  }

  void _inicializarEscuchaArchivos() {
    // ═══ Escuchar archivos que llegan con la app ABIERTA o en background ═══
    _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen(
      (value) {
        if (value.isNotEmpty) {
          _procesarArchivoEntrante(value.first.path);
        }
      },
      onError: (err) {
        debugPrint('Error recibiendo archivo: $err');
      },
    );

    // ═══ Procesar el que llegó con la app cerrada ═══
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_archivoEntrantePendiente != null) {
        final path = _archivoEntrantePendiente!;
        _archivoEntrantePendiente = null;
        // Esperar a que el splash termine antes de abrir el diálogo
        Future.delayed(const Duration(milliseconds: 2500), () {
          _procesarArchivoEntrante(path);
        });
      }
    });
  }

  Future<void> _procesarArchivoEntrante(String path) async {
    final ctx = _navKey.currentContext;
    if (ctx == null) return;

    // Solo procesar .integra (o zip/json)
    final ext = path.split('.').last.toLowerCase();
    if (ext != 'integra' && ext != 'zip' && ext != 'json') return;

    // Confirmar con el usuario
    final confirmar = await showDialog<bool>(
      context: ctx,
      builder: (c) => AlertDialog(
        title: const Text('Archivo .integra recibido'),
        content: const Text(
          '¿Deseas importar este archivo?\n\n'
          'Se creará una copia local en la app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF003087),
            ),
            child: const Text('Importar',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      // Intentar primero como PREVIO (ZIP v2.0)
      final esZip = await _esZip(path);
      if (esZip) {
        final id = await ExportServicePrevio.importarPrevioDesdeRuta(path, ctx);
        if (id != null && ctx.mounted) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            const SnackBar(
              content: Text('Previo importado correctamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
        return;
      }

      // Si no es ZIP, intentar como REPORTE (JSON v1.0)
      final idRep =
          await ExportService.importarReporteDesdeRuta(path, ctx);
      if (idRep != null && ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(
            content: Text('Reporte importado correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text('Error al importar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Detecta si un archivo es un ZIP (PK\x03\x04)
  Future<bool> _esZip(String path) async {
    try {
      final file = File(path);
      if (!file.existsSync()) return false;
      final bytes = await file.openRead(0, 4).first;
      return bytes.length >= 4 &&
          bytes[0] == 0x50 &&
          bytes[1] == 0x4B;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _intentSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Integra Del Centro — Sistema Aduanal',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navKey,
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
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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