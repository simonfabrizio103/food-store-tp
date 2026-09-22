-- TP4 Parte 3 - Ranking ventana + subconsulta + EXCEPT
-- Esquema real: cliente, pedido(id_cliente,fecha), pedido_producto(id_pedido,id_producto,cantidad,precio_unitario), producto(activo), categoria(activa)

-- SPEC R1 (ventana, empate comparte puesto):
-- "Para cada cliente con al menos un pedido, nombre, gasto total (SUM cantidad*precio), puesto RANK de mayor a menor gasto, sin colapsar, empate mismo puesto. Orden puesto LIMIT 20."

-- R1 v1 (JOIN + RANK):
SELECT cl.nombre, SUM(d.cantidad*d.precio_unitario) AS gasto,
       RANK() OVER (ORDER BY SUM(d.cantidad*d.precio_unitario) DESC) AS puesto
FROM cliente cl JOIN pedido p ON p.id_cliente=cl.id_cliente
JOIN pedido_producto d ON d.id_pedido=p.id_pedido
GROUP BY cl.id_cliente, cl.nombre ORDER BY puesto LIMIT 20;

-- R1 v2 (CTE + RANK, misma lógica distinta estructura):
WITH gasto AS (
 SELECT cl.id_cliente, cl.nombre, SUM(d.cantidad*d.precio_unitario) AS gasto
 FROM cliente cl JOIN pedido p ON p.id_cliente=cl.id_cliente
 JOIN pedido_producto d ON d.id_pedido=p.id_pedido
 GROUP BY cl.id_cliente, cl.nombre
)
SELECT nombre, gasto, RANK() OVER (ORDER BY gasto DESC) AS puesto
FROM gasto ORDER BY puesto LIMIT 20;

-- Verificación: (R1v1) EXCEPT (R1v2) =0 y al revés =0 (20 filas).

-- SPEC R2 (correlacionada, nunca vendidos):
-- "Productos vigentes (activo=TRUE) sin ningún detalle en pedido_producto. Cols id_producto,nombre. Orden id."

-- R2 v1 (NOT EXISTS):
SELECT pr.id_producto, pr.nombre FROM producto pr
WHERE NOT EXISTS (SELECT 1 FROM pedido_producto d WHERE d.id_producto=pr.id_producto)
AND pr.activo=TRUE ORDER BY pr.id_producto;

-- R2 v2 (LEFT JOIN IS NULL):
SELECT pr.id_producto, pr.nombre FROM producto pr
LEFT JOIN pedido_producto d ON d.id_producto=pr.id_producto
WHERE d.id_pedido IS NULL AND pr.activo=TRUE ORDER BY pr.id_producto;

-- Verificación: ambos dan 2 filas (Muzza 1, Napolitana 2). EXCEPT ambos sentidos =0.
