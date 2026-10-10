import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../providers/core_providers.dart';

/// Pantalla de arranque.
///
/// Solo vive el tiempo que tarda en resolverse la sesión persistida, pero ese
/// tiempo es la primera impresión del producto, así que en vez de un logo
/// quieto con un «cargando» debajo, el nombre de la marca se *pinta* de
/// izquierda a derecha con un barrido de luz, la palmera entra escalando y una
/// línea de progreso recorre el ancho. Todo con el reloj de animación de
/// Flutter: no hay ni un timer de verdad aquí.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _barrido = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..forward();

  late final AnimationController _entrada = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  late final AnimationController _progreso = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat();

  @override
  void dispose() {
    _barrido.dispose();
    _entrada.dispose();
    _progreso.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDemo = ref.watch(demoModeProvider);
    final Animation<double> curva = CurvedAnimation(
      parent: _barrido,
      curve: Curves.easeInOutCubic,
    );
    final Animation<double> palmera = CurvedAnimation(
      parent: _entrada,
      curve: Curves.easeOutBack,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.2, -0.6),
            radius: 1.4,
            colors: <Color>[Color(0xFF12333C), AppColors.background],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              // La palmera-logotipo entra escalando con un ligero rebote.
              ScaleTransition(
                scale: palmera,
                child: Container(
                  width: 104,
                  height: 104,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.35),
                        blurRadius: 44,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Image.asset(
                      'assets/brand/logo.jpeg',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // El nombre se pinta de izquierda a derecha con un barrido.
              AnimatedBuilder(
                animation: curva,
                builder: (BuildContext context, Widget? child) => ShaderMask(
                  shaderCallback: (Rect bounds) => LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    stops: <double>[
                      0,
                      curva.value.clamp(0.0, 1.0),
                      (curva.value + 0.001).clamp(0.0, 1.0),
                      1,
                    ],
                    colors: const <Color>[
                      Colors.white,
                      Colors.white,
                      Colors.transparent,
                      Colors.transparent,
                    ],
                  ).createShader(bounds),
                  child: child,
                ),
                child: Text(
                  Strings.appName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.6,
                    height: 1.1,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              FadeTransition(
                opacity: curva,
                child: Text(
                  Strings.appTagline,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: context.pal.textSecondary,
                    fontSize: 13.5,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 46),

              // Línea de progreso indeterminada que recorre el ancho.
              SizedBox(
                width: 180,
                child: AnimatedBuilder(
                  animation: _progreso,
                  builder: (BuildContext context, Widget? child) {
                    final double t = _progreso.value;
                    return CustomPaint(
                      size: const Size(180, 3),
                      painter: _BarraProgreso(t: t),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
              Text(
                isDemo
                    ? 'Preparando catálogo local…'
                    : 'Comprobando tu sesión…',
                style: TextStyle(
                  color: context.pal.textDisabled,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// La línea de progreso: un trazo corto que barre de izquierda a derecha.
class _BarraProgreso extends CustomPainter {
  const _BarraProgreso({required this.t});

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint fondo = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.16)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset.zero, Offset(size.width, 0), fondo);

    final double ancho = size.width * 0.35;
    final double x = -ancho + (size.width + ancho) * t;
    final Paint trazo = Paint()
      ..shader = LinearGradient(
        colors: <Color>[
          AppColors.accent.withValues(alpha: 0.2),
          AppColors.accentLight,
        ],
      ).createShader(Rect.fromLTWH(x, 0, ancho, size.height))
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(x, 0), Offset(x + ancho, 0), trazo);
  }

  @override
  bool shouldRepaint(covariant _BarraProgreso old) => old.t != t;
}
