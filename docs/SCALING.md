# Escala: qué soporta CarimarShow y dónde está el techo

Este documento responde a una pregunta concreta con números, no con
intenciones: **¿cuántos usuarios activos aguanta el plan gratuito de Supabase
y qué se hizo para estirarlo?**

Respuesta corta: **~50.000 usuarios activos con listas de hasta ~30 títulos de
media**. Por encima de eso, el límite ya no es de ingeniería sino de dinero:
hay que pasar a Pro.

---

## Los techos reales del plan gratuito

No todos los límites del free tier importan igual. Ordenados por cuál muerde
primero:

| Recurso | Límite free | ¿Cuánto aguanta CarimarShow? | Veredicto |
|---|---|---|---|
| **Base de datos** | 500 MB | ~1,8 M de filas de `watchlist` tras 0002 | ⚠️ **El que muerde primero** |
| **Realtime (conexiones)** | 200 simultáneas | ~200 usuarios con la lista abierta a la vez | ⚠️ Segundo en morder |
| **Egreso (transferencia)** | 5 GB/mes | De sobra: las imágenes vienen del CDN de TMDB | ✅ |
| **Usuarios activos (MAU)** | 50.000 | Justo el objetivo | ✅ Al límite por diseño |
| **Correos de auth** | 2/hora | Sin confirmación por correo (autoconfirm) | ✅ Resuelto |
| **Proyectos activos** | 2 | `carimarshow-production` + `carimarshow-staging` | ✅ Justo |
| **Pausa por inactividad** | 7 días | N/A con uso real | ✅ |

Fíjate en el detalle importante: **el límite de MAU no es el problema**. Supabase
te deja autenticar a 50.000 usuarios gratis. Lo que te echa abajo antes es el
disco y las conexiones en vivo. Por eso toda la optimización va ahí.

---

## Optimización 1 — filas más delgadas (migración 0002)

Una fila de `watchlist` con el esquema original (`0001`) pesaba ~500 bytes. El
culpable era uno solo:

| Campo | Bytes aprox. | ¿Se pinta en «Mi lista»? |
|---|---|---|
| `overview` (sinopsis) | **~250** | ❌ Nunca. Solo aparece en la ficha, que ya la pide a TMDB |
| `original_language` | ~6 | ❌ No se muestra |
| resto (título, póster, fondo, nota, votos, fecha, géneros) | ~245 | ✅ Sí, es lo que pinta la lista |

`overview` ocupaba **la mitad de cada fila para no usarse jamás en la lista**.
La migración `0002_scale_optimizations.sql` lo elimina (y con él
`original_language`). Resultado: ~245 bytes por fila, un **2,0×** de capacidad
en el mismo disco.

Lo que **sí** se conserva a propósito es exactamente lo que la pantalla
necesita para pintarse **sin una sola llamada a TMDB**: título, póster, fondo,
nota, votos, fecha y géneros. Esa propiedad —que «Mi lista» funcione sin
conexión— no se negocia.

## Optimización 2 — dieta de índices

El esquema original tenía dos índices secundarios además de la clave primaria.
Costaban ~72 bytes por fila (≈40 MB a un millón de filas, el 8% del disco) y
ninguno se usaba:

- `watchlist_user_status_idx` → la app filtra por estado **en cliente**; el
  stream ya trae todas las filas del usuario. Índice muerto.
- `watchlist_user_added_idx` → servía al `ORDER BY added_at DESC`. Pero la PK
  `(user_id, media_type, tmdb_id)` ya tiene `user_id` como primera columna, que
  es el único filtro que hace la app. Un index scan sobre ese prefijo devuelve
  decenas de filas, y ordenar decenas de filas en memoria es gratis.

Con el tope anti-abuso (optimización 4), el peor caso son 1.000 filas por
usuario: un quicksort de 1.000 elementos sigue siendo submilisegundo. Se
eliminaron los dos.

## Optimización 3 — RLS que se evalúa una vez, no por fila

Las políticas usaban `auth.uid()` a pelo. Esa función lee un GUC y hace un cast,
y el planificador puede invocarla **por cada fila evaluada**. En una tabla de
millones de filas con escaneos frecuentes, eso se nota.

```sql
-- Antes: la función puede ejecutarse por fila
using (user_id = auth.uid())

-- Después: el subselect se resuelve UNA vez por consulta (InitPlan)
using (user_id = (select auth.uid()))
```

La semántica es idéntica; solo cambia cuántas veces se paga la función. Es la
optimización de RLS que documenta el propio Supabase.

## Optimización 4 — tope anti-abuso

En un plan con 500 MB, **un solo usuario** con una lista gigante puede tirar la
base de datos de todos los demás. Un trigger limita la lista a 1.000 títulos por
usuario (ninguna lista real se acerca; solo lo alcanza un cliente malicioso o
un bug en bucle). Devuelve `SQLSTATE 54000`, que la app puede traducir a un
mensaje claro.

El trigger distingue «upsert sobre una fila que ya existe» de «inserción
nueva», porque la app usa `upsert`: sin esa comprobación, un usuario en el tope
no podría ni actualizar el progreso de un título ya guardado.

## Optimización 5 — autovacuum agresivo

Por defecto, autovacuum espera a que el **20%** de la tabla sean tuplas muertas
antes de limpiar. En un millón de filas eso son 200.000 filas fantasma ocupando
disco —un 40% del presupuesto entero— antes de que nadie reaccione.

`watchlist` es la tabla con más *churn* de la app: cada toggle es un upsert +
delete, cada cambio de progreso un update. Se baja el umbral al 2% para que el
espacio se recupere pronto:

```sql
alter table public.watchlist set (
  autovacuum_vacuum_scale_factor        = 0.02,
  autovacuum_analyze_scale_factor       = 0.01,
  autovacuum_vacuum_insert_scale_factor = 0.02
);
```

## Optimización 6 — lo que NO pasa por Supabase

El egreso (5 GB/mes) podría ser el límite si las imágenes viajaran por tu base
de datos. No lo hacen:

- **Pósters y fondos** → CDN de TMDB (`image.tmdb.org`), con el tamaño justo al
  uso (`w154`/`w342`/`w1280`, nunca `original`). Cero bytes de tu cuota.
- **Caché de géneros** → se piden una vez por sesión, no por pantalla.
- **`append_to_response`** → la ficha completa en **una** petición a TMDB en
  lugar de cinco.
- **Retardo de búsqueda de 400 ms** → sin esto, cada tecla es una petición y
  TMDB responde 429. Menos peticiones también es menos carga de auth en
  Supabase cuando hay sesión de por medio.

---

## La cuenta final

| Escenario | Filas en `watchlist` | Disco estimado | ¿Cabe en 500 MB? |
|---|---|---|---|
| 50.000 usuarios × 10 títulos | 500.000 | ~135 MB | ✅ con holgura |
| 50.000 usuarios × 20 títulos | 1.000.000 | ~270 MB | ✅ 54% del disco |
| 50.000 usuarios × 30 títulos | 1.500.000 | ~405 MB | ✅ 81%, justo |
| 50.000 usuarios × 40 títulos | 2.000.000 | ~540 MB | ❌ Se pasa |

*(Cálculo: 245 B/fila + ~10% de sobrecarga de página. El índice de la PK añade
~45 B por fila y ya va incluido.)*

**Conclusión:** el objetivo de 50.000 usuarios activos es alcanzable en el plan
gratuito mientras la lista media se mantenga por debajo de ~30 títulos. A partir
de ahí el siguiente paso es de presupuesto, no de código.

## Cuándo pasar a Pro (y qué ganas)

| Señal | Qué significa |
|---|---|
| Disco > ~350 MB en el dashboard | Vas camino del techo de 500 MB |
| Errores de conexión en horas punta | Superaste las 200 conexiones Realtime |
| Usuarios reportando «no sincroniza» | Ídem, por saturación del canal |
| Necesitas confirmar correos reales | 2 correos/hora no dan para producción |

El plan Pro (25 $/mes por proyecto) sube el disco a 8 GB, las conexiones
Realtime a 500 y los correos a 3/hora con SMTP propio configurable. Con 8 GB,
el escenario de 40 títulos por usuario (540 MB) deja de ser un problema y el
techo pasa a estar en ~700.000 usuarios.

> Mientras tanto, **autoconfirm activado**: el free tier solo envía 2 correos de
> auth por hora, así que exigir confirmación por correo a 50.000 usuarios es
> imposible. Con autoconfirm el registro entra directo. Si algún día quieres
> confirmación real, configura un SMTP propio (Resend, Postmark…) antes.

## Cómo vigilarlo

En el dashboard de Supabase, pestaña **Database → Storage**, y **Reports**.
Consulta rápida desde el SQL Editor:

```sql
select pg_size_pretty(pg_total_relation_size('public.watchlist')) as watchlist_total,
       pg_size_pretty(pg_total_relation_size('public.profiles'))  as profiles_total,
       pg_size_pretty(pg_database_size(current_database()))       as base_datos;
```

Y cuántas filas hay por usuario (para detectar al que se pasa):

```sql
select user_id, count(*) as titulos
  from public.watchlist
 group by user_id
 order by titulos desc
 limit 10;
```

---

*Las cifras de tamaño de fila son estimaciones basadas en el ancho medio de los
tipos de Postgres y en longitudes reales de metadatos de TMDB. Mídelas en tu
instancia con la consulta de arriba cuando tengas tráfico real.*
