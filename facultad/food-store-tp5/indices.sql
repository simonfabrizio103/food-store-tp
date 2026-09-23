-- ============================================================
-- TP5 Parte A — indices.sql (Food Store, base food_store_copia)
-- Esquema real: categoria, producto, cliente (=usuario),
--   pedido, pedido_producto (=detalle_pedido)
-- Protocolo cátedra: probar en COPIA + transacción + ANALYZE.
-- Preexistentes TP3/TP4: idx_producto_categoria, idx_pedido_cliente,
--   idx_producto_cat_precio_activo, idx_pedido_cliente_fecha,
--   idx_producto_precio, idx_pedprod_producto_cover, idx_pedido_cliente_cover
-- ============================================================

-- ------------------------------------------------------------
-- IDX1 ACEPTADO — Reporte mensual por fecha+forma_pago (Q1)
-- Q1: SELECT id_pedido, fecha, forma_pago FROM pedido
--     WHERE fecha BETWEEN '2025-06-01' AND '2025-06-30'
--       AND forma_pago='EFECTIVO';
-- Antes: Seq Scan sobre pedido (200k), Filter fecha+forma_pago.
-- Por qué mejora: B-tree compuesto, igualdad en 2da col + rango en 1ra;
--   Bitmap Heap Scan solo sobre ~1/12 de la tabla en vez de 200k.
-- Tipo: B-tree compuesto. Orden: fecha ASC (rango), forma_pago 2da.
-- ------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_pedido_fecha_forma
ON pedido (fecha, forma_pago);

-- ------------------------------------------------------------
-- IDX2 ACEPTADO — Stock bajo por categoría, parcial vigente (Q2)
-- Q2: SELECT id_producto, nombre, stock FROM producto
--     WHERE id_categoria=3 AND stock<10 AND activo=TRUE;
-- Antes: Seq Scan / Bitmap sobre idx_producto_categoria + Filter stock
--   (Rows Removed masivos sobre 50k).
-- Por qué mejora: parcial WHERE activo=TRUE (índice más chico, solo vigentes),
--   igualdad en id_categoria + rango en stock. INCLUDE(nombre) → Index-Only.
-- Tipo: B-tree compuesto parcial.
-- ------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_producto_cat_stock_vig
ON producto (id_categoria, stock) INCLUDE (nombre)
WHERE (activo = TRUE);

-- ------------------------------------------------------------
-- IDX3 ACEPTADO — Detalle por cantidad+precio (Q3)
-- Q3: SELECT id_pedido, id_producto, cantidad, precio_unitario
--     FROM pedido_producto WHERE cantidad>=4 AND precio_unitario>400;
-- Antes: Seq Scan sobre pedido_producto (200k).
-- Por qué mejora: B-tree compuesto ataca ambas condiciones de rango,
--   Bitmap Heap Scan en vez de leer 200k filas.
-- Tipo: B-tree compuesto.
-- ------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_pedprod_cantidad_precio
ON pedido_producto (cantidad, precio_unitario);

-- ------------------------------------------------------------
-- ÍNDICE DESCARTADO (documentado, NO ejecutar):
-- CREATE INDEX idx_pedido_forma_pago ON pedido(forma_pago);
-- Motivo: columna de bajísima cardinalidad (100% 'EFECTIVO'),
--   sin parcial, redundante con IDX1. Sobreindexación: suma costo
--   de escritura sin ningún plan que lo use. Ver specs/spec_indice_descartado.md
-- ------------------------------------------------------------

-- Después de crearlos (fuera de transacción):
-- ANALYZE pedido; ANALYZE producto; ANALYZE pedido_producto;
