-- ============================================================================
-- TP Unidad 4 — Parte 2: Desnormalización Controlada
-- Proyecto: Top 5 de categorías por monto vendido en el día (Food Store)
-- Archivo: tp_desnormalizacion_top_categorias.sql
-- Dialecto asumido: PostgreSQL
-- ============================================================================

-- Supuesto: ya existen pobladas las tablas pedido, detalle_pedido, producto, categoria.
-- Este script crea la estructura desnormalizada y su mecanismo de sincronización.

-- ----------------------------------------------------------------------------
-- 5.2.a) Consulta original (referencia). Ejecutar con EXPLAIN ANALYZE en su entorno.
-- ----------------------------------------------------------------------------
/*
SELECT c.nombre AS categoria,
       SUM(dp.subtotal) AS total_vendido
FROM detalle_pedido dp
JOIN producto pr ON pr.id = dp.producto_id
JOIN categoria c ON c.id = pr.categoria_id
JOIN pedido ped ON ped.id = dp.pedido_id
WHERE ped.fecha = CURRENT_DATE
  AND dp.eliminado = FALSE
  AND ped.eliminado = FALSE
GROUP BY c.nombre
ORDER BY total_vendido DESC
LIMIT 5;

-- En su base de datos ejecutar:
--   EXPLAIN (ANALYZE, BUFFERS) <consulta anterior>;
-- Capturar: tiempo de ejecución y el nodo del plan que domina el costo.
-- Estas capturas van al informe final (sección "antes").
*/

-- ----------------------------------------------------------------------------
-- 5.2.b) Patrón elegido: tabla precalculada con disparador (trigger)
-- ----------------------------------------------------------------------------
-- Justificación (máximo un párrafo, respondiendo las tres preguntas):
--
-- La evidencia medida en 5.2.a (plan dominado por scans secuenciales y múltiples
-- JOINs sobre tablas crecientes) motiva la decisión: a medida que crece la base,
-- la consulta del panel tarda cada vez más. El mecanismo que garantiza que el
-- dato redundante no se desincronice es un trigger AFTER INSERT/UPDATE/DELETE
-- sobre detalle_pedido (complementado con triggers sobre pedido y producto) que
-- recalcula la fila afectada en la tabla desnormalizada. Es reversible sin pérdida
-- de información: la tabla desnormalizada se puede descartar en cualquier momento
-- y recalcular desde las tablas fuente mediante la consulta original de 5.1.

-- ----------------------------------------------------------------------------
-- 5.2.c) Estructura desnormalizada (tabla de resumen por fecha y categoría)
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS categoria_venta_dia (
    fecha             DATE        NOT NULL,
    categoria_id      BIGINT      NOT NULL REFERENCES categoria(id),
    categoria_nombre  TEXT        NOT NULL,
    total_vendido     NUMERIC(14,2) NOT NULL DEFAULT 0,
    actualizado_en    TIMESTAMP   NOT NULL DEFAULT now(),
    PRIMARY KEY (fecha, categoria_id)
);

CREATE INDEX IF NOT EXISTS idx_categoria_venta_dia_fecha
    ON categoria_venta_dia(fecha);

-- ----------------------------------------------------------------------------
-- Función de recálculo para una fecha dada
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION recalcular_categoria_venta_dia(fecha_in DATE)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
    -- Upsert: insertar o actualizar totales por categoría para esa fecha
    INSERT INTO categoria_venta_dia (fecha, categoria_id, categoria_nombre, total_vendido, actualizado_en)
    SELECT
        ped.fecha,
        c.id,
        c.nombre,
        COALESCE(SUM(dp.subtotal), 0),
        now()
    FROM detalle_pedido dp
    JOIN producto pr ON pr.id = dp.producto_id
    JOIN categoria c ON c.id = pr.categoria_id
    JOIN pedido ped ON ped.id = dp.pedido_id
    WHERE ped.fecha = fecha_in
      AND dp.eliminado = FALSE
      AND ped.eliminado = FALSE
    GROUP BY ped.fecha, c.id, c.nombre
    ON CONFLICT (fecha, categoria_id)
    DO UPDATE SET
        categoria_nombre = EXCLUDED.categoria_nombre,
        total_vendido = EXCLUDED.total_vendido,
        actualizado_en = EXCLUDED.actualizado_en;

    -- Borrar categorías sin ventas para esa fecha (mantener consistencia exacta)
    DELETE FROM categoria_venta_dia cvd
    WHERE cvd.fecha = fecha_in
      AND NOT EXISTS (
          SELECT 1
          FROM detalle_pedido dp
          JOIN producto pr ON pr.id = dp.producto_id
          JOIN pedido ped ON ped.id = dp.pedido_id
          WHERE ped.fecha = fecha_in
            AND pr.categoria_id = cvd.categoria_id
            AND dp.eliminado = FALSE
            AND ped.eliminado = FALSE
      );
END;
$$;

-- ----------------------------------------------------------------------------
-- Disparador sobre detalle_pedido (inserción, modificación o borrado de un detalle)
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION trg_detalle_pedido_venta_dia()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
    fecha_afectada DATE;
BEGIN
    IF TG_OP = 'DELETE' THEN
        SELECT ped.fecha INTO fecha_afectada
        FROM pedido ped WHERE ped.id = OLD.pedido_id LIMIT 1;
    ELSE
        SELECT ped.fecha INTO fecha_afectada
        FROM pedido ped WHERE ped.id = NEW.pedido_id LIMIT 1;
    END IF;

    IF fecha_afectada IS NOT NULL THEN
        PERFORM recalcular_categoria_venta_dia(fecha_afectada);
    END IF;

    RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS tr_detalle_pedido_venta_dia ON detalle_pedido;

CREATE TRIGGER tr_detalle_pedido_venta_dia
AFTER INSERT OR UPDATE OR DELETE ON detalle_pedido
FOR EACH ROW EXECUTE FUNCTION trg_detalle_pedido_venta_dia();

-- ----------------------------------------------------------------------------
-- Disparador complementario sobre pedido (cambio de fecha o eliminación lógica)
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION trg_pedido_venta_dia()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
    fecha_vieja DATE;
    fecha_nueva DATE;
BEGIN
    IF TG_OP = 'UPDATE' THEN
        fecha_vieja := OLD.fecha;
        fecha_nueva := NEW.fecha;
        IF fecha_vieja IS NOT NULL THEN
            PERFORM recalcular_categoria_venta_dia(fecha_vieja);
        END IF;
        IF fecha_nueva IS NOT NULL AND fecha_nueva IS DISTINCT FROM fecha_vieja THEN
            PERFORM recalcular_categoria_venta_dia(fecha_nueva);
        END IF;
    ELSIF TG_OP = 'DELETE' THEN
        PERFORM recalcular_categoria_venta_dia(OLD.fecha);
    END IF;
    RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS tr_pedido_venta_dia ON pedido;

CREATE TRIGGER tr_pedido_venta_dia
AFTER UPDATE OR DELETE ON pedido
FOR EACH ROW EXECUTE FUNCTION trg_pedido_venta_dia();

-- ----------------------------------------------------------------------------
-- 5.2.d) Consulta sobre la estructura desnormalizada (reporte del panel)
-- ----------------------------------------------------------------------------

SELECT cvd.categoria_nombre AS categoria,
       cvd.total_vendido
FROM categoria_venta_dia cvd
WHERE cvd.fecha = CURRENT_DATE
ORDER BY cvd.total_vendido DESC
LIMIT 5;

-- Ejecutar con EXPLAIN ANALYZE y comparar con la consulta original.
-- Entregar tabla de dos columnas (antes / después) con:
--   - tiempo de ejecución
--   - tipo de nodo dominante de cada plan

-- ----------------------------------------------------------------------------
-- 5.2.e) Script de auditoría de desincronización
-- ----------------------------------------------------------------------------
-- Detecta si el dato redundante (categoria_venta_dia) se desincronizó de su
-- fuente de verdad (las 4 tablas originales).
-- Resultado esperado sobre la base ya migrada: 0 filas (vacío).

WITH real AS (
    SELECT c.id AS categoria_id,
           c.nombre AS categoria_nombre,
           SUM(dp.subtotal) AS total_real
    FROM detalle_pedido dp
    JOIN producto pr ON pr.id = dp.producto_id
    JOIN categoria c ON c.id = pr.categoria_id
    JOIN pedido ped ON ped.id = dp.pedido_id
    WHERE ped.fecha = CURRENT_DATE
      AND dp.eliminado = FALSE
      AND ped.eliminado = FALSE
    GROUP BY c.id, c.nombre
),
desnorm AS (
    SELECT categoria_id, categoria_nombre, total_vendido AS total_desnorm
    FROM categoria_venta_dia
    WHERE fecha = CURRENT_DATE
)
SELECT
    COALESCE(r.categoria_id, d.categoria_id) AS categoria_id,
    COALESCE(r.categoria_nombre, d.categoria_nombre) AS categoria,
    r.total_real      AS total_fuente,
    d.total_desnorm   AS total_desnormalizado,
    (r.total_real - d.total_desnorm) AS diferencia
FROM real r
FULL OUTER JOIN desnorm d ON r.categoria_id = d.categoria_id
WHERE r.total_real IS DISTINCT FROM d.total_desnorm
ORDER BY categoria_id;

-- ============================================================================
-- FIN Parte 2
-- ============================================================================