-- ============================================================================
-- TP Unidad 5 — Parte D: anonimización de usuario y tabla usuario_anon
-- Archivo: usuario_anon.sql
--
-- Objetivo: construir una versión anonimizada/pseudonimizada de `usuario`
-- que preserve la utilidad analítica (rol, fecha_alta, activo, id) sin
-- exponer datos personales (email, nombre).
--
-- Decisiones de diseño:
--   - `id` se conserva para poder seguir uniendo con `pedido.usuario_id`.
--     El id es un identificador interno, no un dato personal por sí mismo.
--   - `email` -> pseudónimo determinístico `u_<md5(id||sal)>@anon.example`.
--     La sal debe tratarse como secreto; sin ella no se puede revertir.
--   - `nombre` -> se descarta; se reemplaza por una etiqueta genérica.
--   - `rol`, `fecha_alta`, `activo` se conservan (atributos analíticos).
--
-- Ejecutar como admin_datos (dueño lógico) o postgres.
-- Es idempotente: se puede re-ejecutar para refrescar la tabla.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. (Re)crear la tabla anonimizada con esquema canónico
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS usuario_anon;

CREATE TABLE usuario_anon (
    id            BIGINT PRIMARY KEY,
    email_pseud   TEXT NOT NULL UNIQUE,
    nombre_pseud  TEXT NOT NULL,
    rol           TEXT NOT NULL,
    fecha_alta    DATE NOT NULL,
    activo        BOOLEAN NOT NULL
);

COMMENT ON TABLE usuario_anon IS
    'Versión pseudonimizada de usuario para análisis. Sin email ni nombre reales.';

-- ----------------------------------------------------------------------------
-- 2. Cargar desde usuario con pseudonimización determinística
--    Sal fija del TP: 'food-store-u5-2026'. En producción debe ser secreta
--    y rotarse junto con el proceso de seudonimización.
-- ----------------------------------------------------------------------------
INSERT INTO usuario_anon (id, email_pseud, nombre_pseud, rol, fecha_alta, activo)
SELECT
    u.id,
    'u_' || substr(md5(u.id::text || 'food-store-u5-2026'), 1, 16) || '@anon.example',
    'Anon-' || lpad(u.id::text, 4, '0'),
    u.rol,
    u.fecha_alta,
    u.activo
FROM usuario u
ORDER BY u.id;

-- ----------------------------------------------------------------------------
-- 3. Privilegios: solo lectura para reportes/lectura; sin acceso a usuario real
-- ----------------------------------------------------------------------------
GRANT SELECT ON TABLE usuario_anon TO rol_app_lectura, rol_reportes, rol_soporte, rol_app_escritura;

-- ============================================================================
-- FIN usuario_anon.sql
-- ============================================================================
