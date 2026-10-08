-- ══════════════════════════════════════════════════════════════════════════
--  SinFlix — esquema inicial de Supabase
-- ══════════════════════════════════════════════════════════════════════════
--
--  Aplica este archivo en tu proyecto Supabase:
--
--    · Opción A (CLI):  supabase db push
--    · Opción B (web):  Dashboard → SQL Editor → pega y ejecuta
--
--  Crea tres cosas:
--    1. `public.profiles`  → perfil visible de cada usuario
--    2. `public.watchlist` → «Mi lista», sincronizada entre dispositivos
--    3. Políticas RLS      → cada usuario solo accede a sus propias filas
--
--  El script es idempotente: se puede ejecutar varias veces sin romper nada.
-- ══════════════════════════════════════════════════════════════════════════

-- ── Extensiones ──────────────────────────────────────────────────────────
create extension if not exists "pgcrypto";

-- ══════════════════════════════════════════════════════════════════════════
--  1. PERFILES
-- ══════════════════════════════════════════════════════════════════════════

create table if not exists public.profiles (
  id           uuid primary key references auth.users (id) on delete cascade,
  display_name text        not null default '',
  avatar_url   text,
  theme_mode   text        not null default 'system'
               check (theme_mode in ('system', 'light', 'dark')),
  adult_content boolean    not null default false,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

comment on table public.profiles is
  'Perfil público de cada usuario de SinFlix. Una fila por cada auth.users.';

-- ── Trigger: crear el perfil automáticamente al registrarse ───────────────
-- Sin esto, el primer arranque de un usuario nuevo no tendría fila y la app
-- tendría que crearla a mano (con riesgo de condiciones de carrera).
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  raw_name text;
begin
  raw_name := coalesce(
    new.raw_user_meta_data ->> 'display_name',
    split_part(coalesce(new.email, ''), '@', 1)
  );

  insert into public.profiles (id, display_name, avatar_url)
  values (
    new.id,
    trim(raw_name),
    new.raw_user_meta_data ->> 'avatar_url'
  )
  on conflict (id) do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ── `updated_at` automático ──────────────────────────────────────────────
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

-- ══════════════════════════════════════════════════════════════════════════
--  2. MI LISTA
-- ══════════════════════════════════════════════════════════════════════════
--
--  Diseño: los datos del título se denormalizan (título, póster, sinopsis…).
--  Cuesta un poco más de espacio pero evita una llamada a TMDB por cada fila
--  al pintar la lista, y hace que la pantalla funcione sin conexión.
-- ══════════════════════════════════════════════════════════════════════════

create table if not exists public.watchlist (
  user_id         uuid        not null references auth.users (id) on delete cascade,
  media_type      text        not null check (media_type in ('movie', 'tv')),
  tmdb_id         integer     not null check (tmdb_id > 0),

  title           text        not null default '',
  poster_path     text,
  backdrop_path   text,
  overview        text        not null default '',
  vote_average    numeric(4,2) not null default 0,
  vote_count      integer     not null default 0,
  release_date    timestamptz,
  genre_ids       integer[]   not null default '{}',
  original_language text,

  status          text        not null default 'planned'
                  check (status in ('planned', 'watching', 'completed')),
  progress_percent integer    check (progress_percent is null or (progress_percent between 0 and 100)),
  note            text,

  added_at        timestamptz not null default now(),
  updated_at      timestamptz not null default now(),

  primary key (user_id, media_type, tmdb_id)
);

comment on table public.watchlist is
  'Títulos guardados por el usuario. Clave primaria compuesta: un título no se guarda dos veces.';

-- Índices de apoyo para las consultas habituales de la app.
create index if not exists watchlist_user_added_idx
  on public.watchlist (user_id, added_at desc);
create index if not exists watchlist_user_status_idx
  on public.watchlist (user_id, status);

drop trigger if exists watchlist_set_updated_at on public.watchlist;
create trigger watchlist_set_updated_at
  before update on public.watchlist
  for each row execute function public.set_updated_at();

-- ══════════════════════════════════════════════════════════════════════════
--  3. SEGURIDAD (RLS)
-- ══════════════════════════════════════════════════════════════════════════
--
--  Sin estas políticas, la clave `anon` (que va empaquetada en la app y por
--  tanto es pública) permitiría leer y escribir datos de cualquier usuario.
--  Con RLS activado, cada consulta queda restringida a `auth.uid()`.
-- ══════════════════════════════════════════════════════════════════════════

alter table public.profiles  enable row level security;
alter table public.watchlist enable row level security;

-- ── profiles ─────────────────────────────────────────────────────────────
drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own"
  on public.profiles for select
  using (auth.uid() = id);

drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own"
  on public.profiles for insert
  with check (auth.uid() = id);

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
  on public.profiles for update
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- ── watchlist ────────────────────────────────────────────────────────────
-- Las cuatro operaciones se limitan al propietario de la fila.
drop policy if exists "watchlist_select_own" on public.watchlist;
create policy "watchlist_select_own"
  on public.watchlist for select
  using (auth.uid() = user_id);

drop policy if exists "watchlist_insert_own" on public.watchlist;
create policy "watchlist_insert_own"
  on public.watchlist for insert
  with check (auth.uid() = user_id);

drop policy if exists "watchlist_update_own" on public.watchlist;
create policy "watchlist_update_own"
  on public.watchlist for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "watchlist_delete_own" on public.watchlist;
create policy "watchlist_delete_own"
  on public.watchlist for delete
  using (auth.uid() = user_id);

-- ══════════════════════════════════════════════════════════════════════════
--  4. REALTIME
-- ══════════════════════════════════════════════════════════════════════════
--
--  Publica la tabla en el canal `supabase_realtime` para que la lista se
--  sincronice entre dispositivos en tiempo real (la app usa `.stream()`).
-- ══════════════════════════════════════════════════════════════════════════

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'watchlist'
  ) then
    alter publication supabase_realtime add table public.watchlist;
  end if;
exception
  -- En proyectos antiguos la publicación puede no existir; no es fatal: la app
  -- sigue funcionando con consultas normales, solo sin sincronización en vivo.
  when undefined_object then
    raise notice 'Publicación supabase_realtime no disponible: sin sincronización en vivo.';
end
$$;

-- ══════════════════════════════════════════════════════════════════════════
--  Verificación rápida (descomenta para probar en el SQL Editor)
-- ══════════════════════════════════════════════════════════════════════════
-- select table_name from information_schema.tables
--   where table_schema = 'public' and table_name in ('profiles', 'watchlist');
--
-- select relname, relrowsecurity, relforcerowsecurity
--   from pg_class where relname in ('profiles', 'watchlist');
