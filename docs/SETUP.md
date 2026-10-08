# Guía de configuración

CarimarShow funciona **sin configurar nada** (modo demo). Esta guía explica cómo
activar cada capacidad real. Todos los pasos son independientes: puedes hacer
solo el 1, o el 1 y el 2, o ninguno.

| Paso | Qué activa | Tiempo |
|---|---|---|
| [1. TMDB](#1-tmdb-catálogo-real) | Catálogo real de películas y series | 5 min |
| [2. Supabase](#2-supabase-cuentas-y-sincronización) | Cuentas de usuario y Mi lista sincronizada | 15 min |
| [3. Ejecutar](#3-ejecutar) | — | — |
| [4. Publicar](#4-publicar-por-plataforma) | Builds por plataforma | — |

---

## 1. TMDB (catálogo real)

### 1.1 Obtener el token

1. Crea una cuenta gratis en <https://www.themoviedb.org>.
2. Entra en **Settings → API** (<https://www.themoviedb.org/settings/api>).
3. Pulsa *Create* / *Request an API Key* y elige **Developer**.
4. Acepta los términos y rellena el formulario (para desarrollo sirve poner tu
   nombre y `http://localhost`).
5. Copia el **API Read Access Token**. Es un JWT largo que empieza por `eyJ...`

> Hay dos credenciales en esa página. Usa el **Read Access Token** (v4), no el
> `api_key` (v3): viaja en una cabecera `Authorization` en lugar de en la URL,
> así no acaba en logs de servidor ni en el historial de red. La app también
> acepta `api_key` si es lo único que tienes.

### 1.2 Configurar

```bash
cp .env.example .env
```

Edita `.env`:

```dotenv
TMDB_READ_TOKEN=eyJhbGciOiJIUzI1NiJ9.eyJhdWQiOi...   # el largo
TMDB_LANGUAGE=es-ES
TMDB_REGION=ES
```

### 1.3 Comprobar

```bash
./scripts/run.sh
```

El aviso de «modo demo» debe desaparecer. Si en su lugar ves
**«Credenciales inválidas»**, el token está mal copiado, caducado o revocado.

<details>
<summary>Opciones de idioma y región</summary>

`TMDB_LANGUAGE` usa el formato BCP-47. Los más habituales:

| Valor | Resultado |
|---|---|
| `es-ES` | Español de España |
| `es-MX` | Español latino |
| `en-US` | Inglés |
| `ca-ES` | Catalán |

`TMDB_REGION` (ISO-3166-1) afecta a las fechas de estreno y a la disponibilidad:
`ES`, `MX`, `AR`, `US`…

Cambiándolo se rellenan automáticamente los textos de la ficha (sinopsis,
géneros, títulos). La interfaz de la app sigue en español: son cosas distintas.

</details>

---

## 2. Supabase (cuentas y sincronización)

**Opcional.** Sin esto, la app usa sesión local y guarda Mi lista en el
dispositivo: totalmente funcional, pero no sincroniza entre dispositivos.

### 2.1 Crear el proyecto

1. Regístrate en <https://supabase.com> (plan gratuito suficiente).
2. **New project** → elige organización, nombre (`carimarshow`), contraseña de base
   de datos y región cercana.
3. Espera ~2 minutos al aprovisionamiento.

### 2.2 Copiar las credenciales

En **Settings → API**:

- **Project URL** → `SUPABASE_URL` (algo como `https://abcdefgh.supabase.co`)
- **Publishable key** (en proyectos antiguos, *anon public*) →
  `SUPABASE_PUBLISHABLE_KEY`

Añádelas a `.env`:

```dotenv
SUPABASE_URL=https://abcdefgh.supabase.co
SUPABASE_PUBLISHABLE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6...
```

> `SUPABASE_ANON_KEY` también se acepta como alias heredado. Si defines las dos,
> manda `SUPABASE_PUBLISHABLE_KEY`.

> ⚠️ **Nunca uses la `secret key`.** La clave publishable/anon va empaquetada
> dentro de la app, así que es pública por diseño. Eso no es un fallo: la
> seguridad la aportan las políticas RLS del paso siguiente.

### 2.3 Aplicar el esquema

El archivo [`supabase/migrations/0001_initial_schema.sql`](../supabase/migrations/0001_initial_schema.sql)
crea las tablas, índices, triggers, **políticas RLS** y la suscripción Realtime.
Es idempotente: puedes ejecutarlo varias veces.

**Opción A — desde la web (más sencilla)**

1. Dashboard → **SQL Editor** → *New query*.
2. Pega el contenido completo del archivo.
3. **Run**.

**Opción B — con el CLI de Supabase**

```bash
supabase login
supabase link --project-ref abcdefgh        # el subdominio de tu URL
supabase db push
```

### 2.4 Configurar la confirmación por correo

En **Authentication → Sign In / Providers → Email** decide si quieres exigir
confirmación:

| Ajuste | Comportamiento |
|---|---|
| *Confirm email* **activado** | Al registrarse, la app muestra «Revisa tu correo» y el usuario entra tras confirmar |
| *Confirm email* **desactivado** | El registro inicia sesión directamente |

Ambos flujos están implementados; para desarrollar suele ser más cómodo
desactivarlo.

### 2.5 Verificar

```bash
./scripts/run.sh
```

- La pantalla de acceso debe ofrecer **Crear cuenta** además del modo invitado.
- En **Perfil → Tus datos → Sincronización** debe decir *«En la nube (Supabase)»*.
- Prueba la sincronización real: añade un título en el navegador, abre la app en
  otro dispositivo con la misma cuenta y aparecerá sin refrescar.

<details>
<summary>Qué crea exactamente la migración</summary>

**`public.profiles`** — perfil visible de cada usuario.
Un trigger sobre `auth.users` crea la fila automáticamente al registrarse, con
el nombre tomado de los metadatos o del correo.

**`public.watchlist`** — Mi lista.
Clave primaria compuesta `(user_id, media_type, tmdb_id)`: un título no puede
guardarse dos veces. Los datos del título (título, póster, sinopsis, nota) están
**denormalizados a propósito**, para pintar la lista sin llamar a TMDB por cada
fila y que la pantalla funcione sin conexión.

**RLS** — activado en ambas tablas, con políticas que limitan `SELECT`, `INSERT`,
`UPDATE` y `DELETE` a `auth.uid() = user_id`. Sin esto, la clave pública
permitiría leer la lista de cualquier usuario.

**Realtime** — publica `watchlist` en `supabase_realtime`, que es lo que usa
`.stream()` en el cliente para la sincronización en vivo.

**Índices** — `(user_id, added_at desc)` para el listado y
`(user_id, status)` para los filtros por estado.

</details>

<details>
<summary>Solución de problemas</summary>

**«Falta la tabla `watchlist`»**
La migración no se aplicó. Vuelve al paso 2.3.

**«Permisos insuficientes» / error 42501**
Las políticas RLS no se crearon o tu sesión no coincide con el `user_id`.
Comprueba en el SQL Editor:

```sql
select relname, relrowsecurity from pg_class
  where relname in ('profiles', 'watchlist');
```

Ambas deben dar `relrowsecurity = true`.

**El registro dice que ya existe la cuenta**
Ese correo ya está registrado. Usa *Iniciar sesión* o *¿Olvidaste tu contraseña?*.

**No llega el correo de confirmación**
Revisa spam. En el plan gratuito de Supabase el límite es de 2 correos por hora
por proyecto; para desarrollar, desactiva la confirmación (paso 2.4).

**Todo funciona pero no sincroniza entre dispositivos**
Realtime no está activo para la tabla. Comprueba:

```sql
select * from pg_publication_tables where tablename = 'watchlist';
```

Si no sale ninguna fila, ejecuta:

```sql
alter publication supabase_realtime add table public.watchlist;
```

</details>

---

## 3. Ejecutar

```bash
flutter pub get
flutter devices          # lista los destinos disponibles
./scripts/run.sh         # con .env
```

Destinos habituales:

```bash
./scripts/run.sh -d chrome        # web
./scripts/run.sh -d linux         # escritorio Linux
./scripts/run.sh -d macos         # escritorio macOS
./scripts/run.sh -d windows       # escritorio Windows
./scripts/run.sh -d emulator-5554 # Android
```

Sin `.env`, o directamente:

```bash
flutter run --dart-define=TMDB_READ_TOKEN=eyJ... \
            --dart-define=SUPABASE_URL=https://xxx.supabase.co \
            --dart-define=SUPABASE_PUBLISHABLE_KEY=eyJ...
```

### Tests

```bash
flutter test                                            # todo
flutter analyze                                         # lint y tipos
dart format --set-exit-if-changed lib test              # formato
```

---

## 4. Publicar por plataforma

### Web

```bash
flutter build web --release --dart-define=TMDB_READ_TOKEN=... \
                              --dart-define=SUPABASE_URL=... \
                              --dart-define=SUPABASE_PUBLISHABLE_KEY=...
```

El resultado está en `build/web/`, listo para cualquier hosting estático
(Netlify, Vercel, GitHub Pages, Firebase Hosting).

Para que las rutas profundas (`/title/movie/155`) funcionen al recargar, el
hosting debe redirigir todo a `index.html`.

### Identificador de paquete (antes de publicar)

Las seis plataformas se generaron con el identificador provisional
`com.carimarshow.app`. **Cámbialo antes de publicar en una tienda**: es
inmutable una vez subida la app.

| Plataforma | Dónde |
|---|---|
| Android | `android/app/build.gradle.kts` → `namespace` y `applicationId`, **y** mover `MainActivity.kt` a la carpeta que corresponda al nuevo paquete |
| iOS / macOS | `PRODUCT_BUNDLE_IDENTIFIER` en `ios/Runner.xcodeproj/project.pbxproj` y en `macos/Runner/Configs/AppInfo.xcconfig` |
| Web / Linux / Windows | No aplica |

Los **nombres visibles** ya están puestos a `CarimarShow` en las seis plataformas
(etiqueta de Android, `CFBundleDisplayName` en iOS, título de ventana en
Windows y Linux, `PRODUCT_NAME` en macOS, `<title>` y manifiesto en web).

### Android

```bash
flutter build appbundle --release --dart-define=TMDB_READ_TOKEN=...
```

Antes: configura el firmado en `android/key.properties` (archivo **fuera** de
git; ya está en `.gitignore`) y crea un keystore.

### iOS

```bash
flutter build ipa --release --dart-define=TMDB_READ_TOKEN=...
```

Requiere macOS con Xcode y una cuenta de Apple Developer. Ajusta el *bundle id*
en `ios/Runner.xcodeproj`.

### Escritorio

```bash
flutter build linux --release
flutter build macos --release
flutter build windows --release
```

> **Los `--dart-define` se hornean en tiempo de compilación.** No existe una
> forma de cambiar el token de TMDB en una build ya publicada: hay que
> recompilar. Si necesitas rotar credenciales sin recompilar, muévelas a un
> servicio de configuración remota y cárgalas en el arranque.

---

## Seguridad: resumen rápido

1. `.env` **nunca** se sube (ya está en `.gitignore`).
2. Solo la **clave pública** de Supabase va en la app. La *secret key* jamás.
3. Las **RLS** son las que protegen los datos, no el secreto de la clave.
4. El token de TMDB se inyecta con `--dart-define`, no como archivo del bundle.
5. Si un token se expone en cualquier sitio → **revócalo y genera otro**.
6. `scripts/run.sh` nunca imprime valores de secretos, solo nombres de variables.
