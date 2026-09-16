// ============================================================
// Integra Del Centro, S.C.
// Desarrollado por: HIRAM JAFET VELAZQUEZ SANTANDER
// screens/splash_screen.dart v4.0
// Cambios:
//   - Barra de progreso lineal 0 → 100 % (reemplaza la rueda)
//   - Progreso REAL basado en los pasos de inicialización
//   - Se eliminó la línea de versión del splash
// ============================================================

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'home_screen.dart';
import 'nombre_usuario_screen.dart';
import '../services/usuario_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  double _progreso = 0.0;
  String _mensaje = 'Iniciando...';

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
    _fadeCtrl.forward();
    _initApp();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _avanzarA(double target, String mensaje) async {
    if (!mounted) return;
    setState(() => _mensaje = mensaje);
    const pasos = 12;
    final delta = (target - _progreso) / pasos;
    for (int i = 0; i < pasos; i++) {
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 22));
      setState(() => _progreso = (_progreso + delta).clamp(0.0, 1.0));
    }
    if (mounted) setState(() => _progreso = target);
  }

  Future<void> _initApp() async {
    try {
      await _avanzarA(0.10, 'Preparando almacenamiento...');
      await Hive.initFlutter();

      await _avanzarA(0.25, 'Abriendo previos...');
      await Hive.openBox('previos');

      await _avanzarA(0.45, 'Abriendo reportes...');
      await Hive.openBox('reportes');

      await _avanzarA(0.60, 'Abriendo borradores...');
      await Hive.openBox('previos_borrador');

      await _avanzarA(0.75, 'Cargando configuración...');
      await Hive.openBox('config');

      await _avanzarA(0.90, 'Verificando usuario...');
      final tieneNombre = UsuarioService.tieneNombre;

      await _avanzarA(1.00, 'Listo');
      await Future.delayed(const Duration(milliseconds: 250));

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => tieneNombre
              ? const HomeScreen()
              : const NombreUsuarioScreen(),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _mensaje = 'Error al iniciar: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 160,
                  height: 160,
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
                        child: const Icon(
                          Icons.business,
                          size: 80,
                          color: Colors.white,
                        ),
                      ),
                    ),
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
                const SizedBox(height: 50),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: _progreso),
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    builder: (context, value, _) => LinearProgressIndicator(
                      value: value,
                      minHeight: 8,
                      backgroundColor:
                          const Color(0xFF003087).withValues(alpha: 0.12),
                      valueColor: const AlwaysStoppedAnimation(
                        Color(0xFF003087),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _mensaje,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      '${(_progreso * 100).round()} %',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF003087),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}