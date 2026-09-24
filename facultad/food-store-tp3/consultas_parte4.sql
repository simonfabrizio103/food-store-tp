-- ============================================================
-- TP3 Parte 4 - Consultas resumen y subconsulta con spec + EXCEPT
-- Esquema real: categoría(id_categoria,nombre,activa),
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
