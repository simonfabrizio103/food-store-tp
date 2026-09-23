-- ============================================================
-- TP3 Parte 2 - Índices propuestos (food_store_copia)
-- Planes ANTES ya medidos:
-- Q1 2.059ms: Sort + Bitmap Heap Scan + Bitmap Index idx_producto_categoria
-- Q2 0.066ms: Sort + Bitmap Heap + Bitmap Index idx_pedido_cliente
-- Q3 3.409ms: Seq Scan on producto, Filter precio_lista>4500, Rows Removed 44466
-- Protocolo: leer línea por línea, aplicar en copia, re-medir EXPLAIN ANALYZE
-- ============================================================

-- ------------------------------------------------------------
-- IDX1 para Q1: productos por categoría + rango precio + orden
-- Q1: WHERE id_categoria=1 AND precio_lista BETWEEN 1000 AND 3000
--     AND activo=TRUE ORDER BY precio_lista
-- Ataca: Filter (Rows Removed 2832) + Sort (quicksort 215kB)
-- Por qué mejora: igualdad en 1ra col + rango+orden en 2da col
--   -> Index Scan entrega filas ya ordenadas, evita Sort.
--   Partial WHERE activo=TRUE coincide con filtro (índice más chico).
--   INCLUDE(nombre) permite Index-Only (no va al heap por nombre).
-- ------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_producto_cat_precio_activo
ON producto (id_categoria, precio_lista) INCLUDE (nombre)
WHERE (activo = TRUE);

-- ------------------------------------------------------------
-- IDX2 para Q2: historial por cliente ordenado por fecha
-- Q2: WHERE id_cliente=100 ORDER BY fecha DESC
-- Ataca: Sort (aunque sean 10 filas, hace quicksort)
-- Por qué mejora: (id_cliente, fecha DESC) entrega orden directo,
--   elimina el nodo Sort. INCLUDE(forma_pago) lo hace covering.
-- ------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_pedido_cliente_fecha
ON pedido (id_cliente, fecha DESC) INCLUDE (forma_pago);

-- ------------------------------------------------------------
-- IDX3 para Q3 nueva: filtro solo por precio (Seq Scan 50k)
-- Q3: WHERE precio_lista > 4500 (3.409ms, Rows Removed 44466)
-- Ataca: Seq Scan completo.
-- Por qué mejora: B-tree en precio_lista -> Bitmap/Index Scan solo
--   sobre ~5500 filas en vez de 50002.
-- ------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_producto_precio
ON producto (precio_lista);

-- Después de crearlos:
-- ANALYZE producto; ANALYZE pedido;
-- Re-correr los 3 EXPLAIN ANALYZE y guardar planes DESPUÉS.
