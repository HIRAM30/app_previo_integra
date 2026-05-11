// ============================================================
// Integra Del Centro, S.C.
// Desarrollado por: HIRAM JAFET VELAZQUEZ SANTANDER
// screens/splash_screen.dart
// Descripción: Pantalla de presentación. Inicializa Hive con
//   DOS boxes en paralelo al mostrar el logo:
//   • 'previos'  — box de la app original de previos
//   • 'reportes' — box nuevo de reportes de discrepancia
//   El logo ya es visible mientras Hive trabaja en background.
// ============================================================

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'home_screen.dart';
import '../main.dart' show kVersionApp;

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initApp();
  }

  /// Inicializa Hive con ambos boxes y navega al Home.
  /// Se ejecuta mientras el logo ya está visible — nunca pantalla negra.
  Future<void> _initApp() async {
    await Hive.initFlutter();
    // Abrir los dos boxes en paralelo para mayor velocidad
    await Future.wait([
      Hive.openBox('previos'),
      Hive.openBox('reportes'),
    ]);
    // Mínimo 1.5s para que el splash se vea bien
    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo corporativo
            Image.asset(
              'assets/images/integra_logo.png',
              width: 180,
              height: 180,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  color: const Color(0xFF003087),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.business,
                    size: 90, color: Colors.white),
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'Integra Del Centro, S.C.',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF003087),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Sistema Aduanal Integral',
              style: TextStyle(fontSize: 15, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(
              'v$kVersionApp  •  Dev: HIRAM JAFET VELAZQUEZ SANTANDER',
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
            const SizedBox(height: 50),
            const CircularProgressIndicator(color: Color(0xFF003087)),
          ],
        ),
      ),
    );
  }
}
