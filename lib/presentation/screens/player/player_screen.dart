import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';

/// Qué se va a reproducir y de dónde sale.
///
/// El reproductor es agnóstico a la fuente: acepta cualquier URL directa
/// (MP4, WebM o HLS) que el negocio tenga derecho a servir. Mientras el panel
/// de administración de la fase 2 no exista, se ofrece una pieza con licencia
/// Creative Commons para que el reproductor se pueda probar de verdad sin
/// servir contenido sin derechos: esa es la línea que protege al negocio,
/// cuya aplicación anterior cayó precisamente por licenciamiento.
class PlayerArgs {
  const PlayerArgs({
    required this.title,
    required this.url,
    this.subtitle,
    this.isSample = false,
  });

  /// Muestra con licencia CC (Big Buck Bunny) para pruebas del reproductor.
  factory PlayerArgs.sample(String title) => PlayerArgs(
    title: title,
    subtitle: 'Pieza de prueba con licencia Creative Commons',
    url:
        'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
    isSample: true,
  );

  final String title;
  final String? subtitle;
  final String url;
  final bool isSample;
}

/// Reproductor de vídeo a pantalla completa con controles propios.
///
/// Controles que se ocultan solos a los 3 s, búsqueda arrastrable, indicadores
/// de buffer y error con reintento, y bloqueo de orientación/perfil inmersivo
/// mientras dura la reproducción en móvil.
class PlayerScreen extends StatefulWidget {
  const PlayerScreen({required this.args, super.key});

  final PlayerArgs args;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  VideoPlayerController? _controller;
  bool _controles = true;
  bool _cargando = true;
  String? _error;
  Timer? _ocultar;
  bool _inmersivo = false;

  @override
  void initState() {
    super.initState();
    _abrir();
    _programarOcultado();
  }

  @override
  void dispose() {
    _ocultar?.cancel();
    _salirInmersivo();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _abrir() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    final VideoPlayerController c = VideoPlayerController.networkUrl(
      Uri.parse(widget.args.url),
    );
    try {
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() {
        _controller = c;
        _cargando = false;
      });
      c.addListener(_alCambiar);
      await c.play();
    } catch (_) {
      if (mounted) {
        setState(() {
          _cargando = false;
          _error = 'No se pudo cargar el vídeo. Comprueba la conexión.';
        });
      }
      await c.dispose();
    }
  }

  void _alCambiar() {
    if (mounted) setState(() {});
  }

  void _programarOcultado() {
    _ocultar?.cancel();
    _ocultar = Timer(const Duration(seconds: 3), () {
      if (mounted && (_controller?.value.isPlaying ?? false)) {
        setState(() => _controles = false);
      }
    });
  }

  void _toggleControles() {
    setState(() => _controles = !_controles);
    if (_controles) _programarOcultado();
  }

  Future<void> _toggleInmersivo() async {
    setState(() => _inmersivo = !_inmersivo);
    if (_inmersivo) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      await _salirInmersivo();
    }
  }

  Future<void> _salirInmersivo() async {
    if (!_inmersivo) return;
    _inmersivo = false;
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[]);
  }

  String _fmt(Duration d) {
    final String h = d.inHours > 0 ? '${d.inHours}:' : '';
    final String m = '${d.inMinutes % 60}'.padLeft(2, '0');
    final String s = '${d.inSeconds % 60}'.padLeft(2, '0');
    return '$h$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final VideoPlayerController? c = _controller;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (c != null && c.value.isInitialized)
            GestureDetector(
              onTap: _toggleControles,
              onDoubleTap: () => c.value.isPlaying ? c.pause() : c.play(),
              child: Center(
                child: AspectRatio(
                  aspectRatio: c.value.aspectRatio,
                  child: VideoPlayer(c),
                ),
              ),
            ),

          if (_cargando)
            const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            ),

          if (_error != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(
                      Icons.error_outline,
                      size: 40,
                      color: AppColors.danger,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.pal.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _abrir,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            ),

          if (_controles && _error == null)
            _Controles(
              args: widget.args,
              value: c?.value,
              onSeek: (Duration d) => c?.seekTo(d),
              onPlayPause: () {
                if (c == null) return;
                c.value.isPlaying ? c.pause() : c.play();
                _programarOcultado();
              },
              onFullscreen: _toggleInmersivo,
              inmersivo: _inmersivo,
              fmt: _fmt,
              onBack: () => Navigator.of(context).pop(),
            ),
        ],
      ),
    );
  }
}

class _Controles extends StatelessWidget {
  const _Controles({
    required this.args,
    required this.value,
    required this.onSeek,
    required this.onPlayPause,
    required this.onFullscreen,
    required this.inmersivo,
    required this.fmt,
    required this.onBack,
  });

  final PlayerArgs args;
  final VideoPlayerValue? value;
  final ValueChanged<Duration> onSeek;
  final VoidCallback onPlayPause;
  final VoidCallback onFullscreen;
  final bool inmersivo;
  final String Function(Duration) fmt;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final Duration pos = value?.position ?? Duration.zero;
    final Duration total = value?.duration ?? Duration.zero;
    final double fraccion = total.inMilliseconds > 0
        ? pos.inMilliseconds / total.inMilliseconds
        : 0;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Colors.black87, Colors.transparent, Colors.black87],
        ),
      ),
      child: Column(
        children: <Widget>[
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: <Widget>[
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.white,
                    ),
                    onPressed: onBack,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          args.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        if (args.subtitle != null)
                          Text(
                            args.subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.65),
                              fontSize: 11.5,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (args.isSample)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'MUESTRA CC',
                        style: TextStyle(
                          color: AppColors.gold,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Column(
              children: <Widget>[
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 3,
                    activeTrackColor: AppColors.accent,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: AppColors.accent,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 14,
                    ),
                  ),
                  child: Slider(
                    value: fraccion.clamp(0.0, 1.0),
                    onChanged: (double v) => onSeek(
                      Duration(
                        milliseconds: (total.inMilliseconds * v).round(),
                      ),
                    ),
                  ),
                ),
                Row(
                  children: <Widget>[
                    Text(
                      fmt(pos),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11.5,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      fmt(total),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  IconButton(
                    icon: const Icon(
                      Icons.replay_10_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: () => onSeek(pos - const Duration(seconds: 10)),
                  ),
                  const SizedBox(width: 18),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: AppColors.accent.withValues(alpha: 0.5),
                          blurRadius: 22,
                        ),
                      ],
                    ),
                    child: IconButton(
                      iconSize: 34,
                      icon: Icon(
                        (value?.isPlaying ?? false)
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.white,
                      ),
                      onPressed: onPlayPause,
                    ),
                  ),
                  const SizedBox(width: 18),
                  IconButton(
                    icon: const Icon(
                      Icons.forward_10_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: () => onSeek(pos + const Duration(seconds: 10)),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      inmersivo
                          ? Icons.fullscreen_exit_rounded
                          : Icons.fullscreen_rounded,
                      color: Colors.white,
                    ),
                    onPressed: onFullscreen,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
