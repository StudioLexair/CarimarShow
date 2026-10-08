# Política de seguridad

## Reportar una vulnerabilidad

**No abras un issue público ni un pull request** para una vulnerabilidad de
seguridad: eso la publica antes de que haya arreglo.

Escríbe en privado a través del formulario de avisos de seguridad de GitHub:

> **https://github.com/StudioLexair/SinFlix/security/advisories/new**

o, si prefieres correo, a la dirección del maintainer en el perfil del
repositorio. Responderemos en un plazo orientativo de **72 horas** con un
acuse de recibo y, después, con una estimación de arreglo.

### Qué incluir

- Descripción del problema y de cómo lo has encontrado.
- Pasos concretos para reproducirlo, o un PoC mínimo.
- Versión de la app o commit afectado.
- Si lo sabes: qué haría falta para explotarlo y qué datos quedarían expuestos.

### Qué esperar

1. Acuse de recibo en ≤72 h.
2. Confirmación o rechazo razonado.
3. Corrección en una rama privada y, si aplica, una release con el arreglo.
4. Crédito público si lo deseas, cuando se publique el arreglo.

Mantenemos la vulnerabilidad en privado hasta que haya una versión corregida
disponible. Coordinaremos la divulgación contigo.

## Alcance

Está en alcance todo lo que vive en este repositorio:

- La aplicación Flutter y sus seis destinos compilados.
- La web de descarga (`site/`) y la app web publicada en GitHub Pages.
- El esquema de Supabase y sus políticas RLS (`supabase/migrations/`).
- Los workflows de CI/CD (`.github/workflows/`).

## Fuera de alcance

- Vulnerabilidades en servicios de terceros (TMDB, Supabase, GitHub). Si es un
  fallo de configuración **nuestra** sobre ellos, sí está en alcance.
- Ataques que requieran acceso físico al dispositivo del usuario.
- Resultados de escáneres automáticos sin prueba de explotación.
- Autocompletado de contraseñas, avisos de `mixed content` y similares en
  dominios que no controlamos.

## Modelo de amenaza, en una frase

La clave pública de Supabase va empaquetada en la app **a propósito** y es
pública por diseño: lo que protege los datos de cada usuario son las políticas
RLS, no el secreto de la clave. Un reporte del tipo «he encontrado la anon key
en el binario» no es una vulnerabilidad; uno del tipo «puedo leer la lista de
otro usuario con la anon key» sí lo es, y de las graves.

## Buenas prácticas que ya aplicamos

- `.env` y `key.properties` en `.gitignore`; los secretos viajan por
  `--dart-define` o por secretos de GitHub Actions, nunca por el bundle.
- RLS activado en todas las tablas con políticas de propietario, escritas como
  `(select auth.uid())` para evaluarlas una vez por consulta.
- Solo la clave *publishable/anon* toca el cliente; la *secret key* de Supabase
  no aparece nunca fuera del panel.
- Trigger de tope por usuario para que un cliente abusivo no pueda agotar la
  base de datos de los demás.
- Checksums SHA-256 publicados en cada release para verificar las descargas.
- Los binarios de Android se firman con un keystore guardado como secreto del
  repositorio, nunca en el árbol de código.

Si encuentras algo que contradice esta lista, es exactamente el tipo de cosa
que queremos saber.
