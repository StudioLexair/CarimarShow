#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════
#  Crea el repositorio de CarimarShow y sube el primer commit
# ══════════════════════════════════════════════════════════════════════════
#
#  Uso:
#      ./scripts/create_repo.sh                 # interactivo
#      ./scripts/create_repo.sh --private       # forzar privado
#      ./scripts/create_repo.sh --public        # forzar público
#      ./scripts/create_repo.sh --name otro     # otro nombre de repo
#
#  ⚠️  ESTE SCRIPT NUNCA PIDE NI MANEJA TOKENS.
#
#  La autenticación la hace tu propia herramienta:
#    · Si tienes GitHub CLI → usa `gh`, que ya tiene tu sesión.
#    · Si no → imprime los comandos exactos para que los ejecutes tú.
#
#  Es deliberado: un token escrito en un script, en el historial del shell o
#  en un chat queda expuesto. Si alguna vez pegas uno en algún sitio,
#  revócalo en GitHub → Settings → Developer settings y genera otro.
# ══════════════════════════════════════════════════════════════════════════
set -euo pipefail

cd "$(dirname "$0")/.."

REPO_NAME="carimarshow"
VISIBILITY=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --private) VISIBILITY="--private"; shift ;;
    --public)  VISIBILITY="--public";  shift ;;
    --name)    REPO_NAME="$2"; shift 2 ;;
    -h|--help) sed -n '2,25p' "$0"; exit 0 ;;
    *) echo "Opción desconocida: $1"; exit 1 ;;
  esac
done

# ── Comprobaciones previas ────────────────────────────────────────────────
command -v git >/dev/null || { echo "✗ git no está instalado"; exit 1; }

if [[ -n "$VISIBILITY" ]]; then :
else
  echo "¿Visibilidad del repositorio?"
  echo "  1) privado  (recomendado)"
  echo "  2) público"
  read -r -p "Elige [1]: " choice
  case "${choice:-1}" in
    2) VISIBILITY="--public" ;;
    *) VISIBILITY="--private" ;;
  esac
fi

echo
echo "→ Repo: $REPO_NAME  ${VISIBILITY}"
echo

# ── Git local ────────────────────────────────────────────────────────────
if [[ ! -d .git ]]; then
  git init -q
  git symbolic-ref HEAD refs/heads/main
  echo "✓ git init (rama main)"
fi

# Identidad: solo se fija si falta, y a nivel local (no global).
if ! git config user.email >/dev/null 2>&1; then
  read -r -p "Tu nombre para los commits: " GIT_NAME
  read -r -p "Tu correo para los commits: " GIT_EMAIL
  git config user.name  "$GIT_NAME"
  git config user.email "$GIT_EMAIL"
  echo "✓ identidad configurada (solo en este repositorio)"
fi

# ── Guardia de seguridad: nada de secretos en el índice ───────────────────
if git ls-files --cached 2>/dev/null | grep -qE '(^|/)\.env$'; then
  echo "✗ ATENCIÓN: el archivo .env está en el índice de git."
  echo "  Quítalo antes de continuar:  git rm --cached .env"
  exit 1
fi
if [[ -f .env ]] && git check-ignore -q .env; then
  echo "✓ .env existe y está correctamente ignorado por git"
elif [[ -f .env ]]; then
  echo "✗ ATENCIÓN: .env existe pero NO está ignorado. Revísalo antes de subir."
  exit 1
fi

git add -A
if git diff --cached --quiet; then
  echo "· No hay cambios que commitear"
else
  git commit -q -m "feat: CarimarShow — app multiplataforma de películas y series

- Flutter para iOS, Android, Web, Windows, macOS y Linux
- Catálogo con la API de TMDB (tendencias, populares, mejor valoradas,
  estrenos, descubrimiento por género y búsqueda)
- Fichas completas: reparto, temporadas y episodios, tráiler, similares
- Cuentas de usuario y «Mi lista» sincronizada con Supabase (RLS + Realtime)
- Modo local/invitado y catálogo de demo: funciona sin configurar nada
- Arquitectura limpia: core / domain / data / presentation
- Riverpod 3, go_router 18, Dio, diseño adaptable de móvil a escritorio
- 131 tests: mapeadores, repositorio local, utilidades y cobertura de UI"
  echo "✓ commit creado"
fi

# ── Publicar ─────────────────────────────────────────────────────────────
if command -v gh >/dev/null 2>&1; then
  if gh auth status >/dev/null 2>&1; then
    echo "→ Creando el repo con GitHub CLI…"
    gh repo create "$REPO_NAME" $VISIBILITY --source=. --remote=origin --push
    echo
    echo "✓ Listo: $(gh repo view --json url -q .url)"
    exit 0
  else
    echo "· gh está instalado pero sin sesión. Ejecuta:  gh auth login"
    echo "  (o sigue los pasos manuales de abajo)"
  fi
else
  echo "· GitHub CLI no está instalado."
  echo "  Instalarlo: https://cli.github.com  (o usa los pasos manuales)"
fi

cat <<EOF

──────────────────────────────────────────────────────────────────────────
 Pasos manuales
──────────────────────────────────────────────────────────────────────────
 1. Crea un repositorio VACÍO en https://github.com/new
    Nombre: $REPO_NAME     Visibilidad: ${VISIBILITY}
    NO marques "Add a README", ni .gitignore, ni licencia: el repo debe
    nacer vacío para que el primer push no genere conflictos.

 2. Añade el remoto y sube (sustituye TU-USUARIO):

      git remote add origin https://github.com/TU-USUARIO/$REPO_NAME.git
      git push -u origin main

    Te pedirá credenciales: usa tu sesión de \`gh auth login\` o un token
    de acceso personal NUEVO con permiso \`repo\`. Escríbelo en el prompt,
    nunca en el comando, y no lo compartas con nadie.
──────────────────────────────────────────────────────────────────────────
EOF
