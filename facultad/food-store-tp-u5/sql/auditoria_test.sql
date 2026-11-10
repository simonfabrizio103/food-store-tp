-- ============================================================================
-- TP Unidad 5 — Parte B: Activación y prueba de auditoría
-- Archivo: auditoria_test.sql
-- Ejecutar DESPUÉS de activar log_connections, log_disconnections y log_statement
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Verificar la configuración actual de auditoría
-- ----------------------------------------------------------------------------
SHOW log_connections;
SHOW log_disconnections;
SHOW log_statement;
SHOW log_directory;
SHOW data_directory;

-- ----------------------------------------------------------------------------
-- 2. Secuencia de operaciones de prueba
--    (al menos: una lectura, una inserción, una actualización y un login fallido)
-- ----------------------------------------------------------------------------

-- 2.1 LECTURA: consultar una tabla (SELECT)
SELECT id, nombre, rol
FROM usuario
WHERE activo = TRUE
ORDER BY id
LIMIT 3;

-- 2.2 INSERCIÓN: insertar un pedido de prueba
INSERT INTO pedido (id, fecha, usuario_id, eliminado)
VALUES (9999, CURRENT_DATE, 2, FALSE);

-- 2.3 ACTUALIZACIÓN: modificar el pedido insertado
UPDATE pedido
SET eliminado = TRUE
WHERE id = 9999;

-- 2.4 LOGIN FALLIDO (a nivel de función de autenticación)
--     Llama a fn_autenticar con una contraseña incorrecta.
--     Devuelve autenticado = false, pero NO genera un "login failed" en el log
--     de conexiones (porque la sesión ya está abierta).
SELECT * FROM fn_autenticar('admin@foodstore.com', 'password_incorrecta');

-- 2.5 LOGIN FALLIDO (a nivel de conexión real)
--     Esto debe ejecutarse desde una terminal (psql), NO desde DBeaver,
--     para que PostgreSQL registre el intento en el log de conexiones:
--
--     En Windows (PowerShell):
--       $env:PGPASSWORD="password_incorrecta"
--       & "C:\Program Files\PostgreSQL\16\bin\psql.exe" -h localhost -U app_web -d postgres -c "SELECT 1"
--
--     El log registrará algo como:
--       FATAL:  password authentication failed for user "app_web"
--
-- 2.6 LOGIN EXITOSO (para comparar en el log)
--     Desde terminal:
--       $env:PGPASSWORD="app_web_pass_2026"
--       & "C:\Program Files\PostgreSQL\16\bin\psql.exe" -h localhost -U app_web -d postgres -c "SELECT current_user;"

-- ----------------------------------------------------------------------------
-- 3. Limpieza de los datos de prueba (opcional)
-- ----------------------------------------------------------------------------
DELETE FROM pedido WHERE id = 9999;

-- ============================================================================
-- FIN auditoria_test.sql
-- ============================================================================