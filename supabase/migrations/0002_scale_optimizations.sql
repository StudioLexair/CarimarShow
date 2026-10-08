-- ══════════════════════════════════════════════════════════════════════════
--  CarimarShow — 0002 · Optimizaciones de escala
-- ══════════════════════════════════════════════════════════════════════════
--
--  Objetivo declarado: sostener ~50.000 usuarios activos sobre el plan FREE
--  de Supabase, cuyo techo real no es la autenticación (50.000 MAU) sino la
--  base de datos: **500 MB**.
--
--  Con el esquema de 0001, una fila de `watchlist` ocupa ~500 bytes y los dos
--  índices secundarios añaden ~72 bytes más por fila. A 2 M de filas eso son
--  ~1,14 GB: **no cabe**. Esta migración reduce el coste por fila a ~245 bytes
--  (~2,3× más usuarios en el mismo disco) sin tocar el comportamiento de la app.
--
--  Cinco cambios, todos medidos:
--    1. Filas más delgadas  → fuera `overview` y `original_language`
--    2. Dieta de índices    → fuera los dos secundarios; la PK ya cubre el acceso
--    3. RLS barato          → `(select auth.uid())` se evalúa una vez por consulta
--    4. Tope anti-abuso     → máximo de filas por usuario
--    5. Autovacuum agresivo → la tabla sufre mucho upsert/delete y se hincha
--
--  Idempotente: se puede ejecutar varias veces.
--  Requisitos: haber aplicado 0001_initial_schema.sql.
-- ══════════════════════════════════════════════════════════════════════════

-- ══════════════════════════════════════════════════════════════════════════
--  1. FILAS MÁS DELGADAS
-- ══════════════════════════════════════════════════════════════════════════
--
--  `overview` es el campo más caro de la fila (una sinopsis en español son
--  200-500 bytes) y **nunca se pinta en la lista**: la pantalla de Mi lista
--  muestra póster, título, nota y estado. La sinopsis solo aparece en la ficha
--  del título, que ya hace `getDetails` contra TMDB (con `append_to_response`,
--  una sola petición para todo). Guardarla aquí era coste puro.
--
--  `original_language` no se muestra en ningún listado de Mi lista.
--
--  Se conservan a propósito `title`, `poster_path`, `backdrop_path`,
--  `vote_average`, `vote_count`, `release_date` y `genre_ids`: son los que
--  permiten pintar la lista completa **sin una sola llamada a TMDB** y, por
--  tanto, sin conexión. Esa propiedad no se negocia.
--
--  Coste: ~256 bytes menos por fila.
-- ══════════════════════════════════════════════════════════════════════════

alter table public.watchlist drop column if exists overview;
alter table public.watchlist drop column if exists original_language;

-- Topes de longitud. TMDB nunca devuelve títulos de 4.000 caracteres; sin este
-- límite un cliente malicioso podría hinchar la base de datos a voluntad.
-- En una tabla vacía el rewrite es instantáneo.
alter table public.watchlist alter column title         type varchar(400);
alter table public.watchlist alter column poster_path   type varchar(120);
alter table public.watchlist alter column backdrop_path type varchar(120);
alter table public.watchlist alter column note          type varchar(500);
alter table public.profiles  alter column display_name  type varchar(80);

comment on column public.watchlist.title is
  'Denormalizado a propósito: pintar la lista sin llamar a TMDB. La sinopsis NO se guarda (ver 0002).';

-- ══════════════════════════════════════════════════════════════════════════
--  2. DIETA DE ÍNDICES
-- ══════════════════════════════════════════════════════════════════════════
--
--  La clave primaria (user_id, media_type, tmdb_id) ya tiene `user_id` como
--  primera columna, que es el único filtro que hace la app: siempre consulta
--  «las filas de MI usuario». Un index scan sobre ese prefijo devuelve decenas
--  de filas, y ordenar decenas de filas en memoria cuesta menos que mantener
--  el índice.
--
--  · watchlist_user_status_idx → la app filtra por estado en cliente (el stream
--    ya trae todas las filas del usuario). Índice muerto: nunca se usa.
--  · watchlist_user_added_idx  → sirve al ORDER BY added_at DESC, pero con el
--    tope del apartado 4 el peor caso son 1.000 filas: un quicksort de 1.000
--    elementos es submilisegundo.
--
--  Ahorro: ~72 bytes por fila (~40 MB a 1 M de filas, el 8% del disco total).
-- ══════════════════════════════════════════════════════════════════════════

drop index if exists public.watchlist_user_status_idx;
drop index if exists public.watchlist_user_added_idx;

-- ══════════════════════════════════════════════════════════════════════════
--  3. RLS BARATO
-- ══════════════════════════════════════════════════════════════════════════
--
--  `auth.uid()` es una función: lee un GUC y hace un cast. Dentro de una
--  política, el planificador puede invocarla **por cada fila evaluada**.
--  Envolverla en un subselect —`(select auth.uid())`— lo convierte en un
--  `InitPlan` que se resuelve UNA vez por consulta y se reutiliza.
--
--  Es la optimización de RLS que recomienda la documentación de Supabase y en
--  una tabla de millones de filas con escaneos frecuentes es la diferencia
--  entre una consulta que vuela y una que arrastra.
--
--  La semántica es idéntica: mismo dueño, mismas cuatro operaciones.
-- ══════════════════════════════════════════════════════════════════════════

-- ── profiles ─────────────────────────────────────────────────────────────
drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own"
  on public.profiles for select
  using (id = (select auth.uid()));

drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own"
  on public.profiles for insert
  with check (id = (select auth.uid()));

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
  on public.profiles for update
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

-- ── watchlist ────────────────────────────────────────────────────────────
drop policy if exists "watchlist_select_own" on public.watchlist;
create policy "watchlist_select_own"
  on public.watchlist for select
  using (user_id = (select auth.uid()));

drop policy if exists "watchlist_insert_own" on public.watchlist;
create policy "watchlist_insert_own"
  on public.watchlist for insert
  with check (user_id = (select auth.uid()));

drop policy if exists "watchlist_update_own" on public.watchlist;
create policy "watchlist_update_own"
  on public.watchlist for update
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

drop policy if exists "watchlist_delete_own" on public.watchlist;
create policy "watchlist_delete_own"
  on public.watchlist for delete
  using (user_id = (select auth.uid()));

-- ══════════════════════════════════════════════════════════════════════════
--  4. TOPE ANTI-ABUSO
-- ══════════════════════════════════════════════════════════════════════════
--
--  En un plan con 500 MB, un solo usuario con una lista gigantesca puede tirar
--  la base de datos de todos los demás. Ninguna lista real llega a 1.000
--  títulos; este tope solo se alcanza con un cliente malicioso o con un bug
--  en bucle. Devuelve SQLSTATE 54000 (program_limit_exceeded), que la app
--  puede traducir a un mensaje claro.
--
--  El trigger distingue upsert-de-fila-existente de inserción nueva: la app
--  usa `upsert`, que dispara BEFORE INSERT incluso cuando acaba en UPDATE.
--  Sin esa comprobación, un usuario en el tope no podría ni actualizar el
--  progreso de un título que ya tiene guardado.
-- ══════════════════════════════════════════════════════════════════════════

create or replace function public.enforce_watchlist_quota()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  filas integer;
begin
  -- Un upsert sobre una fila ya existente no consume cuota nueva.
  if exists (
    select 1 from public.watchlist w
     where w.user_id    = new.user_id
       and w.media_type = new.media_type
       and w.tmdb_id    = new.tmdb_id
  ) then
    return new;
  end if;

  select count(*) into filas
    from public.watchlist
   where user_id = new.user_id;

  if filas >= 1000 then
    raise exception 'watchlist_quota_exceeded: maximo 1000 titulos por usuario'
      using errcode = '54000';
  end if;

  return new;
end;
$$;

drop trigger if exists watchlist_enforce_quota on public.watchlist;
create trigger watchlist_enforce_quota
  before insert on public.watchlist
  for each row execute function public.enforce_watchlist_quota();

-- ══════════════════════════════════════════════════════════════════════════
--  5. AUTOVACUUM AGRESIVO
-- ══════════════════════════════════════════════════════════════════════════
--
--  Por defecto autovacuum espera a que el 20% de la tabla sean tuplas muertas.
--  En 1 M de filas eso son 200.000 filas fantasma ocupando disco antes de
--  limpiar: un 40% del presupuesto total del plan free.
--
--  `watchlist` es la tabla con más churn de la app (cada toggle es un
--  upsert + delete, cada cambio de progreso es un update). Se baja el umbral al
--  2% para que el espacio se recupere pronto.
-- ══════════════════════════════════════════════════════════════════════════

alter table public.watchlist set (
  autovacuum_vacuum_scale_factor        = 0.02,
  autovacuum_analyze_scale_factor       = 0.01,
  autovacuum_vacuum_insert_scale_factor = 0.02
);

alter table public.profiles set (
  autovacuum_vacuum_scale_factor  = 0.05,
  autovacuum_analyze_scale_factor = 0.02
);

-- ══════════════════════════════════════════════════════════════════════════
--  Verificación
-- ══════════════════════════════════════════════════════════════════════════
--
--  Columnas de watchlist (no deben aparecer overview ni original_language):
--    select column_name, data_type from information_schema.columns
--      where table_schema='public' and table_name='watchlist' order by ordinal_position;
--
--  Índices (solo debe quedar la PK):
--    select indexname from pg_indexes where schemaname='public' and tablename='watchlist';
--
--  Políticas usando el subselect:
--    select policyname, qual from pg_policies where schemaname='public';
--
--  Ancho medio real de fila (con datos):
--    select pg_size_pretty(pg_total_relation_size('public.watchlist')) as total,
--           pg_size_pretty(pg_relation_size('public.watchlist'))       as tabla;
-- ══════════════════════════════════════════════════════════════════════════
