// ============================================================
// Integra Del Centro, S.C.
// Desarrollado por: HIRAM JAFET VELAZQUEZ SANTANDER
// screens/splash_screen.dart v3.1
// El logo se carga con AssetImage con errorBuilder robusto.
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

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(
        parent: _animCtrl, curve: Curves.easeIn);
    _animCtrl.forward();
    _initApp();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  /// Inicializa Hive con ambos boxes en paralelo mientras
  /// el logo ya es visible — nunca pantalla negra.
  Future<void> _initApp() async {
    await Hive.initFlutter();
    await Future.wait([
      Hive.openBox('previos'),
      Hive.openBox('reportes'),
    ]);
    await Future.delayed(const Duration(milliseconds: 1600));
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
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ── Logo con fallback ────────────────────────
              Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset(
                    'assets/images/integra_logo.png',
                    width: 160,
                    height: 160,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        color: const Color(0xFF003087),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.business,
                              size: 80, color: Colors.white),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // Nombre empresa
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
                'v$kVersionApp',
                style: const TextStyle(
                    fontSize: 11, color: Colors.grey),
              ),

              const SizedBox(height: 50),
              const CircularProgressIndicator(
                  color: Color(0xFF003087)),
            ],
          ),
        ),
      ),
    );
  }
}