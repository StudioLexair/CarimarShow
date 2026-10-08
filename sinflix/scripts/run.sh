#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════
#  Arranca SinFlix inyectando la configuración del archivo .env
# ══════════════════════════════════════════════════════════════════════════
#
#  Uso:
#      ./scripts/run.sh                      # destino por defecto
#      ./scripts/run.sh -d chrome            # web en Chrome
#      ./scripts/run.sh -d linux             # escritorio Linux
#      ./scripts/run.sh --release            # compilación de release
#
#  Todo lo que sigue a las opciones se pasa tal cual a `flutter run`.
#
#  La configuración se inyecta con --dart-define (no con un asset .env):
#  queda embebida en el binario y nunca hay un archivo de secretos suelto
#  dentro del bundle de la aplicación.
#
#  🔒 ESTE SCRIPT NUNCA IMPRIME EL VALOR DE NINGUNA VARIABLE.
#     Solo muestra los nombres, para que puedas confirmar qué se ha cargado.
#     Aun así, ten en cuenta que los valores SÍ quedan visibles en la lista de
#     procesos del sistema mientras `flutter run` esté activo: es inherente a
#     --dart-define y aplica igual si lanzas el comando a mano.
# ══════════════════════════════════════════════════════════════════════════
set -euo pipefail

cd "$(dirname "$0")/.."

ENV_FILE="${ENV_FILE:-.env}"
DEFINES=()
KEYS=()

# Recorta espacios, tabuladores y saltos de línea por ambos extremos.
trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

# Quita un par de comillas envolventes, si las hay y son del mismo tipo.
unquote() {
  local s="$1"
  if [[ ${#s} -ge 2 ]]; then
    if [[ "$s" == \"*\" ]]; then s="${s:1:${#s}-2}"
    elif [[ "$s" == \'*\' ]]; then s="${s:1:${#s}-2}"
    fi
  fi
  printf '%s' "$s"
}

if [[ -f "$ENV_FILE" ]]; then
  # Se lee línea a línea a propósito: NO se usa `source`, para que un .env con
  # contenido inesperado no acabe ejecutando comandos.
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"                        # saltos de línea de Windows

    [[ -z "$(trim "$line")" ]] && continue      # línea en blanco
    [[ "$(trim "$line")" == \#* ]] && continue  # comentario
    [[ "$line" != *"="* ]] && continue          # no es una asignación

    key="$(trim "${line%%=*}")"
    value="$(trim "${line#*=}")"
    value="$(unquote "$value")"

    # Clave válida: letras, dígitos y guion bajo, empezando por letra.
    if [[ ! "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
      echo "  · línea ignorada (clave no válida: '${key}')"
      continue
    fi

    # Sin valor no hay nada que inyectar: la app ya trata la ausencia como
    # «no configurado», y pasar una variable vacía solo añade ruido.
    if [[ -z "$value" ]]; then
      echo "  · $key sin valor: se omite (modo demo/local para esa clave)"
      continue
    fi

    DEFINES+=("--dart-define=$key=$value")
    KEYS+=("$key")
  done < "$ENV_FILE"

  echo "→ Configuración cargada desde $ENV_FILE"
  if [[ ${#KEYS[@]} -gt 0 ]]; then
    echo "→ Variables inyectadas (valores ocultos):"
    for k in "${KEYS[@]}"; do echo "    · $k"; done
  else
    echo "→ Ninguna variable con valor: la app arrancará en MODO DEMO."
  fi
else
  echo "→ No existe $ENV_FILE: la app arrancará en MODO DEMO (catálogo local)."
  echo "  Cópialo con:  cp .env.example .env"
fi

# Guardia final: si por algún motivo el proyecto tiene un .env versionado,
# mejor avisar que subirlo.
if [[ -f .env ]] && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  if git ls-files --error-unmatch .env >/dev/null 2>&1; then
    echo
    echo "⚠️  ALERTA: el archivo .env está versionado en git."
    echo "   Quítalo del índice:  git rm --cached .env"
    echo "   Y da por expuesto cualquier secreto que haya contenido."
    echo
  fi
fi

echo "→ Ejecutando: flutter run ${KEYS[*]+(${#KEYS[@]} variables)} $*"
echo
# `[@]` y no `[*]`: con `[*]` todos los --dart-define se fusionarían en un
# único argumento y flutter no los interpretaría.
exec flutter run ${DEFINES[@]+"${DEFINES[@]}"} "$@"
