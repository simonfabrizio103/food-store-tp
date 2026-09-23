-- ============================================================
-- TP5 Partes B y C — views.sql (Food Store)
-- Mapeo consigna→real: usuario=cliente, detalle_pedido=pedido_producto,
--   contraseña=telefono (dato sensible a ocultar), vigencia=activo/activa
-- ============================================================

-- ------------------------------------------------------------
-- V1 — Productos vigentes con su categoría (catálogo)
-- Spec: specs/spec_vista_productos.md
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW v_productos_vigentes AS
SELECT p.id_producto,
       p.nombre AS nombre_producto,
       p.precio_lista,
       p.stock,
       c.nombre AS nombre_categoria
FROM producto p
JOIN categoria c ON c.id_categoria = p.id_categoria
WHERE p.activo = TRUE AND c.activa = TRUE;

-- Consulta manual equivalente (verificación):
-- SELECT p.id_producto, p.nombre, p.precio_lista, p.stock, c.nombre
-- FROM producto p JOIN categoria c ON c.id_categoria=p.id_categoria
-- WHERE p.activo=TRUE AND c.activa=TRUE;

-- ------------------------------------------------------------
-- V2 — Pedidos con datos del usuario, SIN dato sensible (SEGURIDAD)
-- Spec: specs/spec_vista_pedidos.md
-- Oculta cliente.telefono (= "contraseña" de la consigna).
-- Permite GRANT SELECT ON v_pedidos_con_cliente sin dar acceso a cliente.
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW v_pedidos_con_cliente AS
SELECT pe.id_pedido,
       pe.fecha,
       pe.forma_pago,
       cl.id_cliente,
       cl.nombre AS nombre_cliente,
       cl.email
FROM pedido pe
JOIN cliente cl ON cl.id_cliente = pe.id_cliente;

-- GRANT ejemplo (no ejecutar sin rol creado):
-- GRANT SELECT ON v_pedidos_con_cliente TO rol_reportes;

-- ------------------------------------------------------------
-- V3 — Detalle de pedido con nombre de producto (ticket)
-- Spec: specs/spec_vista_detalle.md
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW v_detalle_pedido_extendido AS
SELECT d.id_pedido,
       d.id_producto,
       pr.nombre AS nombre_producto,
       d.cantidad,
       d.precio_unitario,
       (d.cantidad * d.precio_unitario) AS subtotal
FROM pedido_producto d
JOIN producto pr ON pr.id_producto = d.id_producto;

-- ============================================================
-- Parte C — Vista materializada: facturación por categoría y mes
-- Spec: specs/spec_vista_materializada.md
-- Base: Q-A del TP4 (~430 ms, 3 Hash Join + Sort a disco).
-- ============================================================
DROP MATERIALIZED VIEW IF EXISTS mv_facturacion_categoria_mes;

CREATE MATERIALIZED VIEW mv_facturacion_categoria_mes AS
SELECT c.id_categoria,
       c.nombre AS nombre_categoria,
       date_trunc('month', pe.fecha)::date AS mes,
       SUM(d.cantidad * d.precio_unitario) AS facturacion,
       COUNT(*) AS cantidad_lineas
FROM categoria c
JOIN producto pr ON pr.id_categoria = c.id_categoria
JOIN pedido_producto d ON d.id_producto = pr.id_producto
JOIN pedido pe ON pe.id_pedido = d.id_pedido
GROUP BY c.id_categoria, c.nombre, date_trunc('month', pe.fecha)
WITH DATA;

-- Índice único para permitir REFRESH CONCURRENTLY a futuro:
CREATE UNIQUE INDEX IF NOT EXISTS ux_mv_fact_cat_mes
ON mv_facturacion_categoria_mes (id_categoria, mes);

-- Refresco (documentado, frecuencia diaria nocturna):
-- REFRESH MATERIALIZED VIEW CONCURRENTLY mv_facturacion_categoria_mes;
-- Consulta rápida del reporte:
-- SELECT * FROM mv_facturacion_categoria_mes ORDER BY mes, facturacion DESC;
