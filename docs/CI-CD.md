# CI/CD — qué se compila solo y cuándo

Tres workflows en `.github/workflows/`. Ninguno necesita intervención manual
salvo crear el tag.

| Workflow | Cuándo corre | Qué hace |
|---|---|---|
| `ci.yml` | Cada push a `main` y cada PR | Formato → análisis → 131 tests → build web de humo |
| `release.yml` | Cada tag `v*.*.*` | Compila 6 destinos, crea el Release con binarios y checksums |
| `site.yml` | Push a `main`, tras cada release, o a mano | Monta la web de descarga + la app web y publica en GitHub Pages |

---

## `ci.yml` — la puerta de calidad

Tres comprobaciones ordenadas de más barata a más cara, para que el fallo
típico se vea en 20 segundos y no en 3 minutos:

1. `dart format --set-exit-if-changed lib test`
2. `flutter analyze --fatal-infos --fatal-warnings`
3. `flutter test` (los 131 tests, incluido el smoke de arranque)

Más dos extras que evitan las dos clases de regresión más tontas:

- **`pubspec.lock` sincronizado**: si alguien cambia `pubspec.yaml` sin
  commitear el lock resuelto, el CI lo detecta haciendo `pub get` y
  comparando. Un lock desincronizado hace que CI y tu máquina compilen cosas
  distintas.
- **Build web de humo**: `dart2js` es más estricto que la VM y cacha imports
  rotos que los tests no ven. Compilar web en cada push cuesta un minuto y
  salva releases enteros.

`concurrency` con `cancel-in-progress: true`: un push nuevo cancela la
ejecución anterior de la misma rama. Si vas a corregir algo enseguida, no
tiene sentido terminar el build viejo.

## `release.yml` — del tag a los binarios

```bash
git tag v1.0.0
git push origin v1.0.0
```

Eso dispara todo. El flujo:

```
meta ──► android ──┐
     ├─► web ─────┤
     ├─► windows ─┤
     ├─► linux ───┼─► publish ─► GitHub Release + dispara site.yml
     ├─► macos-arm64 ┤
     └─► macos-x64 ──┘
```

`meta` resuelve la versión **una sola vez** y la pasa a todos los jobs, para
que los artefactos se llamen igual en los cinco destinos. Sin eso, cada job
deduciría la versión por su cuenta y acabarían desincronizados.

### Lo que produce cada destino

| Destino | Runner | Artefactos |
|---|---|---|
| Android | `ubuntu-latest` | APK por ABI (`arm64-v8a`, `armv7`, `x86_64`), APK universal, AAB |
| Web | `ubuntu-latest` | `*-web.zip` para autohospedar |
| Windows | `windows-latest` | `*-windows-x64.zip` |
| Linux | `ubuntu-latest` | `*-linux-x64.tar.gz` y `*-linux-amd64.deb` |
| macOS Apple Silicon | `macos-15` | `*-macos-arm64.zip` |
| macOS Intel | `macos-13` | `*-macos-x64.zip` (`continue-on-error`: si el runner desaparece, no bloquea) |

`publish` reúne todo, calcula `SHA256SUMS.txt`, genera las notas de versión con
el changelog de commits desde el tag anterior y crea el Release. Al terminar
dispara `site.yml` para que la web ofrezca la versión nueva.

### Convención de nombres de archivo

La web de descarga empareja binarios con plataformas **por nombre de archivo**,
no por metadatos. Si cambias estos nombres, hay que tocar `site/index.html`:

```
carimarshow-<versión>-android-arm64-v8a.apk
carimarshow-<versión>-android-armv7.apk
carimarshow-<versión>-android-x86_64.apk
carimarshow-<versión>-android-universal.apk
carimarshow-<versión>-android.aab
carimarshow-<versión>-windows-x64.zip
carimarshow-<versión>-linux-x64.tar.gz
carimarshow-<versión>-linux-amd64.deb
carimarshow-<versión>-macos-arm64.zip
carimarshow-<versión>-macos-x64.zip
carimarshow-<versión>-web.zip
```

### Firmado de Android

El keystore vive en el secreto `ANDROID_KEYSTORE_BASE64` (PKCS12 en base64).
En el build se materializa en `android/carimarshow-release.keystore` junto a un
`android/key.properties` efímero; ambos están en `.gitignore`. Gradle lee
`key.properties` y firma con `storeType = "PKCS12"`.

Si el secreto no existe, el job **no falla**: firma con la clave de debug y
deja un `::warning`. Un release sin keystore sigue siendo útil (APK
instalable), solo no sirve para subir a una tienda.

> ⚠️ El keystore es la identidad de la app en Android. Si lo pierdes, no puedes
> publicar actualizaciones de esa app jamás. Está respaldado en los secretos
> del repositorio y en `carimarshow-signing/` (fuera de git).

### Por qué el AAB no aparece en la web

El `.aab` es para Google Play, no para instalarlo a mano. Se publica en el
Release como archivo de tienda, pero la landing no lo ofrece como descarga de
usuario (lo marca como `dev`).

## `site.yml` — la web de descarga

Publica dos cosas en el mismo sitio de GitHub Pages:

```
https://studiolexair.github.io/CarimarShow/        landing de descarga
https://studiolexair.github.io/CarimarShow/app/    la app Flutter compilada
```

### El detalle que importa: `release.json`

La landing **no llama a la API de GitHub desde el navegador**. Lee un
`release.json` estático que genera este workflow en el runner, con el token de
GitHub (5.000 peticiones/hora).

Si fuera al revés, todos los visitantes compartirían el límite anónimo de **60
peticiones/hora por IP** y la página se rompería en cuanto tuviera tráfico
detrás de una NAT corporativa o móvil. El JSON se reduce además al mínimo
(nombre, URL, tamaño de cada asset): el payload completo de la API pesa varios
KB por asset en campos que la página no usa.

### Rutas profundas en GitHub Pages

Pages no reescribe URLs. Para que `/app/title/movie/155` sobreviva a un F5, el
workflow copia `index.html` a `404.html` dentro de `/app/`: GitHub sirve ese
archivo (con estado 404) y la SPA arranca y resuelve la ruta. Es el truco
estándar de SPA-en-Pages.

### Permisos

`pages: write` e `id-token: write`: el despliegue usa OIDC, así no hay ningún
token de larga duración guardado en secretos que haya que rotar.

---

## Secretos y variables del repositorio

| Nombre | Tipo | Para qué |
|---|---|---|
| `ANDROID_KEYSTORE_BASE64` | secreto | Keystore PKCS12 de firmado de release |
| `ANDROID_KEYSTORE_PASSWORD` | secreto | Contraseña del keystore |
| `ANDROID_KEY_ALIAS` | secreto | Alias de la clave (`carimarshow`) |
| `ANDROID_KEY_PASSWORD` | secreto | Contraseña de la clave |
| `TMDB_READ_TOKEN` | secreto | **Añádelo tú**: sin él, las releases salen en modo demo |
| `SUPABASE_URL_PROD` / `_STAGING` | variable | URL del proyecto (pública por diseño) |
| `SUPABASE_PUBLISHABLE_KEY_*` | variable | Clave publishable (pública por diseño) |
| `SUPABASE_ANON_KEY_*` | variable | Alias heredado, por compatibilidad |

Las credenciales de Supabase están como **variables**, no secretos, a
propósito: son públicas por diseño (van empaquetadas en la app). Como
variables, un fork puede compilar la app sin que nadie comparta un secreto.
La seguridad real la ponen las políticas RLS, no el secreto de la clave.

`TMDB_READ_TOKEN` sí es secreto de verdad. **Hasta que lo añadas en
Settings → Secrets and variables → Actions, todas las releases y la app web
saldrán en modo demo con el catálogo ficticio.** El workflow lo avisa con un
`::warning` en cada build, así que no pasa desapercibido.

---

## Crear un release paso a paso

```bash
# 1. Asegúrate de que main está verde (CI)
git checkout main && git pull

# 2. Sube el número de versión en pubspec.yaml si hace falta
#    (version: 1.0.0+1  →  nombre+build)

# 3. Etiqueta y empuja
git tag v1.0.0
git push origin v1.0.0

# 4. Sigue el progreso en Actions. Al terminar:
#    · Release en github.com/StudioLexair/CarimarShow/releases
#    · Web actualizada en studiolexair.github.io/CarimarShow
```

Las versiones con guion (`v1.0.0-rc.1`) se publican como **prerelease**
automáticamente, y la web las marca como preliminares.

## iOS

Fuera del pipeline a propósito. Distribuir un `.ipa` instalable exige una
cuenta de Apple Developer (99 $/año) y certificados de distribución; sin ellos
el binario no se instala en ningún iPhone real. El job está escrito y
comentado al final de `release.yml`: cuando tengas los certificados, añade los
tres secretos que lista y cambia el `if:` a `true`.
