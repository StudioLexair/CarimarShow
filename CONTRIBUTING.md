# Contribuir a SinFlix

Gracias por pasarte. Este documento es corto a propósito: las reglas de verdad
son tres y caben en un párrafo.

1. **Una rama por cambio**, con nombre descriptivo (`fix/paginacion-duplicados`).
2. **El CI debe estar verde** antes de pedir revisión: formato, análisis sin
   warnings y los 131 tests.
3. **Sin secretos en commits, issues ni PRs.** Ni tokens, ni claves, ni
   capturas del dashboard. Si alguno se cuela, se considera comprometido y se
   revoca.

## Poner el entorno

```bash
git clone https://github.com/StudioLexair/SinFlix.git
cd SinFlix
flutter pub get
flutter test        # debe pasar todo sin configurar nada (modo demo)
./scripts/run.sh    # si tienes .env con tu token de TMDB
```

La app funciona **sin ninguna credencial**: arranca con el catálogo de
demostración. No necesitas cuenta de Supabase ni token de TMDB para
desarrollar y pasar los tests.

## Antes de escribir código

- **Cambia el contrato antes que la UI.** La arquitectura vive en que
  `presentation` depende de interfaces de `domain`, nunca de implementaciones.
  Si tu cambio obliga a una pantalla a saber qué fuente de datos usa, el diseño
  se está rompiendo: repiensa el cambio en `domain/` primero.
- **Tolerancia en el parseo, no excepciones.** Los datos de TMDB vienen
  incompletos y con tipos inconsistentes. Usa los lectores de
  `data/mappers/json_utils.dart` (`Json.str`, `Json.intOr`, `Json.dateOrNull`)
  en lugar de casts directos.
- **Cada `await` en un Notifier, comprueba `ref.mounted`.** En Riverpod 3, tocar
  `state` con una ref descartada lanza `UnmountedRefException`.

## Convenciones

- Formato: `dart format lib test` (el CI lo exige).
- Análisis: cero warnings e infos (`flutter analyze --fatal-infos`).
- Tests: si tocas lógica de mapeo o de repositorio, añade o ajusta el test que
  la cubre. Los mapeadores y el repositorio local son donde vive la lógica
  real; ahí es donde más valor tiene testear.
- Commits: estilo convencional (`feat:`, `fix:`, `docs:`, `chore:`…). El
  changelog de cada release se genera leyendo el historial.
- Idioma: los comentarios y la documentación van en español; los identificadores
  de código en inglés.

## Cómo probar tu cambio en varias plataformas

```bash
flutter devices              # qué destinos tienes
flutter run -d chrome        # web
flutter run -d linux         # escritorio
flutter run -d <emulador>    # Android
```

El diseño es adaptable de verdad (2 → 7 columnas). Si tocas UI, comprueba al
menos un ancho estrecho y uno ancho: `flutter run -d chrome` y redimensionar la
ventana es la forma rápida.

## Pull requests

1. Abre el PR contra `main`.
2. Rellena la plantilla: qué cambia, por qué, y cómo lo has probado.
3. Espera al CI verde. Si algo falla, el log dice exactamente qué puerta
   (formato / análisis / tests) y por qué.
4. Un maintainer revisa. Los cambios de esquema (`supabase/migrations/`)
   requieren especial cuidado: **las migraciones nunca se editan una vez
   aplicadas**, se añade una nueva (`0003_...`).

## Reportar fallos

Usa la plantilla de issue. Lo que más ayuda: versión de la app, plataforma y
arquitectura, pasos exactos para reproducir y, si es un fallo visual, captura.

Para vulnerabilidades de seguridad, **no abras un issue público**: mira
[SECURITY.md](SECURITY.md).

## Qué no aceptaríamos

- Código que reproduzca o aloje contenido con copyright. SinFlix es un
  catálogo: muestra metadatos públicos y enlaza tráilers oficiales. Nunca
  streaming ni descargas de vídeo.
- Dependencias que exijan `build_runner` sin una razón de peso. El proyecto
  evita deliberadamente la generación de código (`freezed`,
  `json_serializable`, `riverpod_generator`): un clon debe funcionar con
  `flutter pub get` y nada más. Ver `docs/ARCHITECTURE.md`, decisión 5.
