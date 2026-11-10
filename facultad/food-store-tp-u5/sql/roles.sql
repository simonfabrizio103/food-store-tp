-- ============================================================================
-- TP Unidad 5 — Parte A: Roles y permisos de mínimo privilegio
-- Proyecto: Food Store
-- Archivo: roles.sql
-- Ejecutar DESPUÉS de setup_food_store_u5.sql
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Crear roles de grupo (NO LOGIN)
-- ----------------------------------------------------------------------------

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'rol_app_lectura') THEN
        CREATE ROLE rol_app_lectura NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'rol_app_escritura') THEN
        CREATE ROLE rol_app_escritura NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'rol_soporte') THEN
        CREATE ROLE rol_soporte NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'rol_reportes') THEN
        CREATE ROLE rol_reportes NOLOGIN;
    END IF;
END
$$;

-- ----------------------------------------------------------------------------
-- 2. Crear roles de login
-- ----------------------------------------------------------------------------

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'app_web') THEN
        CREATE ROLE app_web LOGIN PASSWORD 'app_web_pass_2026';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'admin_datos') THEN
        CREATE ROLE admin_datos LOGIN PASSWORD 'admin_datos_pass_2026';
    END IF;
END
$$;

-- ----------------------------------------------------------------------------
-- 3. Privilegios de tabla por rol
-- ----------------------------------------------------------------------------

-- rol_app_lectura: SELECT sobre tablas de catálogo y transacciones.
-- NO se otorga SELECT sobre usuario completo (solo columnas no sensibles).
GRANT SELECT ON TABLE pedido, detalle_pedido, producto, categoria, deposito, lote TO rol_app_lectura;
GRANT SELECT (id, nombre, rol, fecha_alta, activo) ON TABLE usuario TO rol_app_lectura;

-- rol_app_escritura: INSERT/UPDATE/DELETE sobre tablas operativas + SELECT
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE pedido, detalle_pedido, producto, categoria TO rol_app_escritura;
GRANT SELECT (id, nombre, rol, fecha_alta, activo) ON TABLE usuario TO rol_app_escritura;

-- rol_soporte: SELECT sobre todas las tablas, incluyendo usuario.email (dato sensible)
GRANT SELECT ON TABLE pedido, detalle_pedido, producto, categoria, deposito, lote TO rol_soporte;
GRANT SELECT ON TABLE usuario TO rol_soporte;

-- rol_reportes: SELECT sobre tablas de transacciones y catálogo (sin email)
GRANT SELECT ON TABLE pedido, detalle_pedido, producto, categoria TO rol_reportes;
GRANT SELECT (id, nombre, rol, fecha_alta, activo) ON TABLE usuario TO rol_reportes;

-- ----------------------------------------------------------------------------
-- 4. Herencia: roles de login heredan de roles de grupo
-- ----------------------------------------------------------------------------

GRANT rol_app_lectura, rol_app_escritura TO app_web;
GRANT rol_app_lectura, rol_app_escritura, rol_soporte, rol_reportes TO admin_datos;

-- ----------------------------------------------------------------------------
-- 5. ALTER DEFAULT PRIVILEGES
-- Las tablas futuras creadas por admin_datos heredan la política
-- ----------------------------------------------------------------------------

ALTER DEFAULT PRIVILEGES
    FOR ROLE admin_datos
    IN SCHEMA public
    GRANT SELECT ON TABLES TO rol_app_lectura;

ALTER DEFAULT PRIVILEGES
    FOR ROLE admin_datos
    IN SCHEMA public
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO rol_app_escritura;

-- ----------------------------------------------------------------------------
-- 6. Revocar privilegios peligrosos (defensa en profundidad)
-- ----------------------------------------------------------------------------

-- Ningún rol de aplicación debe poder crear bases de datos ni roles
ALTER ROLE rol_app_lectura NOCREATEDB NOCREATEROLE;
ALTER ROLE rol_app_escritura NOCREATEDB NOCREATEROLE;
ALTER ROLE rol_soporte NOCREATEDB NOCREATEROLE;
ALTER ROLE rol_reportes NOCREATEDB NOCREATEROLE;
ALTER ROLE app_web NOCREATEDB NOCREATEROLE;
ALTER ROLE admin_datos NOCREATEDB NOCREATEROLE;

-- ----------------------------------------------------------------------------
-- FIN roles.sql
-- ============================================================================