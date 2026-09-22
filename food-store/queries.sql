-- food-store/queries.sql (heredado TP3+TP4: carga de trabajo real a indexar)
-- Parte 1: sql/consultas_parte4.sql (resumen + EXISTS) / Parte 2: sql/tp4_parte3.sql (ventana + anti-join)

-- ================= PARTE 1 (TP3) =================

-- ============================================================
-- TP3 Parte 4 - Consultas resumen y subconsulta con spec + EXCEPT
-- Esquema real: categoria(id_categoria,nombre,activa),
-- producto(id_producto,nombre,precio_lista,stock,activo,id_categoria),
-- cliente(id_cliente,nombre,email), pedido(id_pedido,fecha,forma_pago,id_cliente),
-- pedido_producto(id_pedido,id_producto,cantidad,precio_unitario)
-- ============================================================

-- ------------------------------------------------------------
-- SPEC 1 (resumen/agregación):
-- "Sobre Food Store, para cada categoría vigente (activa=TRUE),
--  devolver nombre_categoria y cantidad de productos vigentes
--  (producto.activo=TRUE) que tiene, incluyendo 0.
--  Ordenar de mayor a menor cantidad, luego por nombre.
--  No usar SELECT *."
-- ------------------------------------------------------------

-- Versión A (IA, JOIN + GROUP BY):
SELECT c.nombre AS nombre_categoria,
       COUNT(p.id_producto) AS cantidad
FROM categoria c
LEFT JOIN producto p ON p.id_categoria = c.id_categoria AND p.activo = TRUE
WHERE c.activa = TRUE
GROUP BY c.id_categoria, c.nombre
ORDER BY cantidad DESC, c.nombre;

-- Versión B (propia, subconsulta correlacionada):
SELECT c.nombre AS nombre_categoria,
       (SELECT COUNT(*) FROM producto p
        WHERE p.id_categoria = c.id_categoria AND p.activo = TRUE) AS cantidad
FROM categoria c
WHERE c.activa = TRUE
ORDER BY cantidad DESC, c.nombre;

-- Verificación equivalencia (ambas 0 filas = equivalentes):
-- (SELECT c.nombre, COUNT(p.id_producto) FROM categoria c
--  LEFT JOIN producto p ON p.id_categoria=c.id_categoria AND p.activo=TRUE
--  WHERE c.activa=TRUE GROUP BY c.id_categoria,c.nombre)
-- EXCEPT
-- (SELECT c.nombre, (SELECT COUNT(*) FROM producto p
--   WHERE p.id_categoria=c.id_categoria AND p.activo=TRUE)
--  FROM categoria c WHERE c.activa=TRUE);
-- Y al revés con EXCEPT invertido. En tu base 10 filas, contar + muestra 5.

-- ------------------------------------------------------------
-- SPEC 2 (subconsulta / EXISTS):
-- "Devolver id_cliente, nombre, email de clientes vigentes que tienen
--  al menos un pedido en últimos 90 días con forma_pago='TARJETA'.
--  Columnas: id_cliente, nombre, email. Orden por id_cliente ASC.
--  No usar SELECT *."
-- ------------------------------------------------------------

-- Versión A (IA, EXISTS):
SELECT cl.id_cliente, cl.nombre, cl.email
FROM cliente cl
WHERE EXISTS (
  SELECT 1 FROM pedido pe
  WHERE pe.id_cliente = cl.id_cliente
    AND pe.forma_pago = 'TARJETA'
    AND pe.fecha >= NOW() - INTERVAL '90 days'
)
ORDER BY cl.id_cliente ASC;

-- Versión B (propia, JOIN + DISTINCT):
SELECT DISTINCT cl.id_cliente, cl.nombre, cl.email
FROM cliente cl
JOIN pedido pe ON pe.id_cliente = cl.id_cliente
  AND pe.forma_pago = 'TARJETA'
  AND pe.fecha >= NOW() - INTERVAL '90 days'
ORDER BY cl.id_cliente ASC;

-- Verificación:
-- (VersiónA) EXCEPT (VersiónB); -- 0 filas esperado
-- (VersiónB) EXCEPT (VersiónA); -- 0 filas esperado
-- Nota: como la carga masiva usó solo 'EFECTIVO', TARJETA dará 0 filas en ambas.
-- Para probar con datos, cambiar a 'EFECTIVO' y verificar conteo >0 e igualdad.
-- Cambiar 'TARJETA'->'EFECTIVO' para demo con 200k pedidos, luego volver a spec.


-- ================= PARTE 2 (TP4) =================

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
