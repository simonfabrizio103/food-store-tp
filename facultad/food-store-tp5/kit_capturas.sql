-- ============================================================
-- TP5 KIT CAPTURAS — pegar en DBeaver conectado a food_store_copia
-- Botón Auto -> Manual. Correr por bloques. No COMMIT necesario (solo SELECT),
-- salvo bloque escritura que usa ROLLBACK para no ensuciar.
-- ============================================================

-- BLOQUE 0: verificar punto de partida (1 captura pg_indexes)
SELECT indexname FROM pg_index i JOIN pg_class c ON c.oid=i.indexrelid
JOIN pg_class t ON t.oid=i.indrelid WHERE t.relname IN ('pedido','producto','pedido_producto')
ORDER BY 1;
-- Debe listar los 7 de TP3/TP4. Si faltan, avisar.

-- BLOQUE 1 (ANTES): 3 EXPLAIN + tiempos — 3 capturas
EXPLAIN (ANALYZE, BUFFERS)
SELECT id_pedido, fecha, forma_pago FROM pedido
WHERE fecha BETWEEN '2025-06-01' AND '2025-06-30' AND forma_pago='EFECTIVO';

EXPLAIN (ANALYZE, BUFFERS)
SELECT id_producto, nombre, stock FROM producto
WHERE id_categoria=3 AND stock<10 AND activo=TRUE;

EXPLAIN (ANALYZE, BUFFERS)
SELECT id_pedido, id_producto, cantidad, precio_unitario FROM pedido_producto
WHERE cantidad>=4 AND precio_unitario>400;

-- BLOQUE 2: crear índices (pegar de indices.sql, 1 por 1) + ANALYZE
-- CREATE INDEX idx_pedido_fecha_forma ON pedido(fecha, forma_pago);
-- CREATE INDEX idx_producto_cat_stock_vig ON producto(id_categoria,stock) INCLUDE(nombre) WHERE(activo=TRUE);
-- CREATE INDEX idx_pedprod_cantidad_precio ON pedido_producto(cantidad, precio_unitario);
-- ANALYZE pedido; ANALYZE producto; ANALYZE pedido_producto;

-- BLOQUE 3 (Después): repetir los 3 EXPLAIN de BLOQUE 1 — 3 capturas
-- (mismo texto, pegar de nuevo para que el plan use los índices)

-- BLOQUE 4: costo escritura — 2 capturas timing
-- ANTES: con \timing o cronómetro DBeaver. En Manual:
BEGIN;
INSERT INTO pedido_producto (id_pedido, id_producto, cantidad, precio_unitario)
SELECT (SELECT MAX(id_pedido) FROM pedido)-499+g.i,
       (SELECT MAX(id_producto) FROM producto)-499+((g.i-1)%500),
       1+((g.i-1)%5), 500
FROM generate_series(1,500) AS g(i);
-- anotar tiempo -> ROLLBACK;
ROLLBACK;
-- Después de crear índices: repetir mismo bloque -> anotar tiempo -> ROLLBACK;

-- BLOQUE 5: vistas + equivalencia — 4 capturas
-- Ejecutar views.sql por bloques (V1, V2, V3), luego:
SELECT COUNT(*) FROM v_productos_vigentes;      -- ~50002
SELECT COUNT(*) FROM v_pedidos_con_cliente;     -- ~200001
SELECT COUNT(*) FROM v_detalle_pedido_extendido;-- ~200000
-- EXCEPT V1 (0 filas = OK):
(SELECT id_producto, nombre_producto, precio_lista, stock, nombre_categoria FROM v_productos_vigentes)
EXCEPT
(SELECT p.id_producto, p.nombre, p.precio_lista, p.stock, c.nombre FROM producto p
 JOIN categoria c ON c.id_categoria=p.id_categoria WHERE p.activo=TRUE AND c.activa=TRUE);
-- Seguridad V2 (no debe aparecer telefono):
SELECT column_name FROM information_schema.columns
WHERE table_name='v_pedidos_con_cliente' ORDER BY 1;

-- BLOQUE 6: materializada — 2 capturas
EXPLAIN ANALYZE SELECT c.nombre, date_trunc('month',pe.fecha)::date AS mes,
 SUM(d.cantidad*d.precio_unitario) FROM categoria c
 JOIN producto pr ON pr.id_categoria=c.id_categoria
 JOIN pedido_producto d ON d.id_producto=pr.id_producto
 JOIN pedido pe ON pe.id_pedido=d.id_pedido
 GROUP BY c.nombre, date_trunc('month',pe.fecha) ORDER BY mes LIMIT 5;
-- (crear la MV de views.sql) luego:
EXPLAIN ANALYZE SELECT * FROM mv_facturacion_categoria_mes ORDER BY mes LIMIT 5;
