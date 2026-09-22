-- TP4 Parte 1 - Índices propuestos (food_store_copia, base masiva TP3 intacta)
-- Q-A ~430ms: 3x Hash Join + Sort external merge Disk 9688kB, Seq Scan pedido_producto 200k
-- Q-B 152.988ms: 2x Parallel Hash Join + Parallel Seq Scan pedido/pedido_producto + Seq Scan cliente
-- Los Hash Join son correctos para agregación total (toda la tabla), no se espera pasar a Nested Loop
-- (200k loops sería peor). Se ataca el heap con covering para Index-Only.

-- IDX1: join pedido_producto por producto (Q-A: d.id_producto=pr.id_producto)
-- La PK es (id_pedido,id_producto): sirve para buscar por pedido, no por producto.
-- Este índice inverso permite Bitmap/Index-Only en vez de Seq Scan 200k.
CREATE INDEX IF NOT EXISTS idx_pedprod_producto_cover
ON pedido_producto (id_producto, id_pedido) INCLUDE (cantidad, precio_unitario);

-- IDX2: join pedido por cliente + covering para Q-B (p.id_cliente=cl.id_cliente)
-- Ya existe idx_pedido_cliente_fecha (id_cliente,fecha) INCLUDE(forma_pago), pero no trae id_pedido.
-- Este covering trae lo justo para el join+group sin ir al heap.
CREATE INDEX IF NOT EXISTS idx_pedido_cliente_cover
ON pedido (id_cliente, id_pedido);

-- Después: ANALYZE pedido_producto; ANALYZE pedido;
-- Re-medir Q-A y Q-B con EXPLAIN ANALYZE. Se espera que sigan Hash Join
-- (documentar que no cambian por ser agregación total) pero con menos Buffers hit
-- y sin Seq Scan (Index-Only). Si no mejoran, se documenta igual.
