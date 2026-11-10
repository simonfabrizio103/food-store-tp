-- ============================================================================
-- TP Unidad 5 — Parte C: simulacro de incidente
-- Archivo: simulacro_incidente.sql
-- Ejecutar como app_web (rol de aplicación, mínimo privilegio).
--
-- Escenario simulado:
--   Un atacante que ya obtuvo credenciales de app_web intenta:
--     1. Adivinar contraseñas de usuarios de la aplicación (fn_autenticar).
--     2. Autenticarse con una credencial válida.
--     3. Leer masivamente la tabla usuario (incluido email).
--     4. Escalar privilegios a admin_datos.
-- El objetivo es generar evidencia en el log y comprobar qué logra y qué no.
-- ============================================================================

\echo '=== C.1 — Intentos fallidos de autenticación (fn_autenticar) ==='
SELECT * FROM fn_autenticar('admin@foodstore.com', 'admin');
SELECT * FROM fn_autenticar('admin@foodstore.com', '123456');
SELECT * FROM fn_autenticar('soporte@foodstore.com', 'qwerty');

\echo '=== C.2 — Autenticación exitosa (credencial válida) ==='
SELECT * FROM fn_autenticar('vendedor1@foodstore.com', 'password123');

\echo '=== C.3 — Lectura masiva de usuario (columnas permitidas) ==='
SELECT id, nombre, rol, activo FROM usuario ORDER BY id;

\echo '=== C.4 — Intento de lectura de la columna sensible email (debe fallar) ==='
SELECT id, email FROM usuario ORDER BY id;

\echo '=== C.5 — Intento de escalamiento a admin_datos (debe fallar) ==='
SET ROLE admin_datos;

\echo '=== C.6 — Intento de crear un rol (debe fallar) ==='
CREATE ROLE rol_atacante LOGIN PASSWORD 'x';

\echo '=== C.7 — Intento de otorgarse privilegios (debe fallar) ==='
GRANT rol_soporte TO app_web;

-- ============================================================================
-- FIN simulacro_incidente.sql
-- ============================================================================
