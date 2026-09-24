-- ============================================================
-- TP3 Parte 1 - Carga masiva Food Store (food_store_copia)
-- Tablas reales: categoría, cliente, pedido, pedido_producto, producto
-- Restricciones detectadas en tu base:
--  cliente_pkey, cliente_email UNIQUE(email),
--  producto_precio_lista CHECK(precio_lista>=0),
--  producto_stock_check CHECK(stock>=0),
--  pedido_producto_cantidad CHECK(cantidad>0),
--  pedido_producto_precio CHECK(precio_unitario>=0),
--  R1 trigger: precio_unitario <= precio_lista,
--  R2 trigger: fecha <= NOW()
-- Columnas producto (deducidas 6 filas):
--  id_producto, nombre, precio_lista, stock, activo, id_categoria
--  !! VERIFICAR fila 1-3 antes de ejecutar (error 42703 si difiere)
-- Protocolo cátedra: COPIA + Transacción + RESPALDO + ANALYZE
-- ============================================================
-- PASO 0 (fuera de este script, una sola vez):
--  1. COPIA: CREATE DATABASE food_store_copia WITH TEMPLATE food_store_dev;
--  2. RESPALDO: DBeaver > Backup > backups/backup_YYYYMMDD.dump
--  3. DBeaver botón Auto -> Manual
-- Ejecutar este script con: BEGIN; ... verificar ... COMMIT; y luego ANALYZE
-- ============================================================

BEGIN;

-- ------------------------------------------------------------
-- 1. Asegurar 10 categorías (tenés 1, necesitamos varias para reparto parejo)
-- Si ya hay >=10 no inserta nada (WHERE COUNT<10).
-- ------------------------------------------------------------
INSERT INTO categoria (id_categoria, nombre, activa)
OVERRIDING SYSTEM VALUE
SELECT m.max_id + g.i, 'Categoria masiva ' || g.i, TRUE
FROM (SELECT COALESCE(MAX(id_categoria), 0) AS max_id FROM categoria) m
CROSS JOIN generate_series(1, 9) AS g(i)
WHERE (SELECT COUNT(*) FROM categoria) < 10
ON CONFLICT (id_categoria) DO NOTHING;
-- Verificación: SELECT COUNT(*) FROM categoría; -- debe dar 10

-- ------------------------------------------------------------
-- 2. 50.000 productos repartidos parejo entre categorías
-- precio_lista 500-5000, stock 0-200, activo=TRUE (vigente)
-- id_producto = max_existente + i  -> evita choques de PK
-- id_categoria = rotación pareja con módulo sobre el total
-- ------------------------------------------------------------
INSERT INTO producto (id_producto, nombre, precio_lista, stock, activo, id_categoria)
OVERRIDING SYSTEM VALUE
SELECT
  pm.max_id + g.i AS id_producto,
  'Producto masivo ' || (pm.max_id + g.i) AS nombre,
  500 + ((random() * 4500)::int) AS precio_lista,  -- 500..5000, cumple CHECK >=0
  (random() * 200)::int AS stock,                  -- 0..200, cumple CHECK >=0
  TRUE AS activo,
  cm.min_id + ((g.i - 1) % cm.total) AS id_categoria  -- reparto parejo
FROM generate_series(1, 50000) AS g(i)
CROSS JOIN (SELECT COALESCE(MAX(id_producto), 0) AS max_id FROM producto) pm
CROSS JOIN (SELECT COALESCE(MIN(id_categoria), 1) AS min_id, COUNT(*) AS total FROM categoria) cm;
-- Verificación: SELECT COUNT(*) FROM producto; -- debe ser 2 + 50000 = 50002

-- ------------------------------------------------------------
-- 3. 20.000 clientes con email único (UNIQUE email)
-- ------------------------------------------------------------
INSERT INTO cliente (id_cliente, nombre, email, telefono)
OVERRIDING SYSTEM VALUE
SELECT
  cm.max_id + g.i AS id_cliente,
  'Cliente masivo ' || (cm.max_id + g.i) AS nombre,
  'cliente_' || (cm.max_id + g.i) || '@mail.com' AS email,  -- único por id
  '11-5555-' || LPAD(((cm.max_id + g.i) % 10000)::text, 4, '0') AS telefono
FROM generate_series(1, 20000) AS g(i)
CROSS JOIN (SELECT COALESCE(MAX(id_cliente), 0) AS max_id FROM cliente) cm
ON CONFLICT (id_cliente) DO NOTHING;
-- Nota: si email ya existe por otro formato, fallará por UNIQUE -> avisar.
-- Verificación: SELECT COUNT(*) FROM cliente; -- debe ser 1 + 20000 = 20001

-- ------------------------------------------------------------
-- 4. 200.000 pedidos con fecha <= NOW() (respeta R2) y forma_pago válida
-- Se usa 'EFECTIVO' porque es el valor existente confirmado en tu muestra.
-- id_cliente en round-robin sobre todos los clientes -> todos tienen pedidos
-- ------------------------------------------------------------
INSERT INTO pedido (id_pedido, fecha, forma_pago, id_cliente)
OVERRIDING SYSTEM VALUE
SELECT
  pm.max_id + g.i AS id_pedido,
  NOW() - ((random() * 365)::int || ' days')::interval
        - ((random() * 86400)::int || ' seconds')::interval AS fecha, -- pasado, cumple R2
  'EFECTIVO' AS forma_pago,
  cli.min_id + ((g.i - 1) % cli.total) AS id_cliente
FROM generate_series(1, 200000) AS g(i)
CROSS JOIN (SELECT COALESCE(MAX(id_pedido), 0) AS max_id FROM pedido) pm
CROSS JOIN (SELECT MIN(id_cliente) AS min_id, COUNT(*) AS total FROM cliente) cli;
-- Verificación: SELECT COUNT(*) FROM pedido; -- debe ser 1 + 200000

-- ------------------------------------------------------------
-- 5. 200.000 detalles (1 por pedido) con R1 garantizado sin JOIN
-- Truco: precio_unitario=500 <= precio_lista (500..5000 en nuevos productos)
-- OJO: solo referenciamos productos NUEVOS (rango nuevo), no los 2 viejos
-- (uno viejo tenía precio_lista=50, con 500 violaría R1).
-- cantidad 1..5 cumple CHECK(cantidad>0), precio 500 cumple CHECK>=0
-- PK (id_pedido,id_producto) única porque es 1 detalle por pedido.
-- ------------------------------------------------------------
INSERT INTO pedido_producto (id_pedido, id_producto, cantidad, precio_unitario)
SELECT
  ped_base.max_ped - 199999 + g.i - 1 AS id_pedido,  -- recorre los 200k nuevos
  prod_base.max_prod - 49999 + ((g.i - 1) % 50000) AS id_producto, -- round-robin nuevos
  1 + ((g.i - 1) % 5) AS cantidad,  -- 1..5
  500 AS precio_unitario             -- 500 <= lista(500..5000) => R1 OK
FROM generate_series(1, 200000) AS g(i)
CROSS JOIN (SELECT MAX(id_pedido) AS max_ped FROM pedido) ped_base
CROSS JOIN (SELECT MAX(id_producto) AS max_prod FROM producto) prod_base;
-- Verificación:
-- SELECT COUNT(*) FROM pedido_producto; -- 0 + 200000
-- SELECT * FROM pedido_producto LIMIT 5;

-- ------------------------------------------------------------
-- 6. Ajustar secuencias/identity para que próximos INSERT con DEFAULT no choquen
-- pg_get_serial_sequence devuelve NULL si no hay secuencia -> COALESCE lo ignora
-- ------------------------------------------------------------
SELECT setval(pg_get_serial_sequence('categoria','id_categoria'), COALESCE((SELECT MAX(id_categoria) FROM categoria),1)) WHERE pg_get_serial_sequence('categoria','id_categoria') IS NOT NULL;
SELECT setval(pg_get_serial_sequence('producto','id_producto'), COALESCE((SELECT MAX(id_producto) FROM producto),1)) WHERE pg_get_serial_sequence('producto','id_producto') IS NOT NULL;
SELECT setval(pg_get_serial_sequence('cliente','id_cliente'), COALESCE((SELECT MAX(id_cliente) FROM cliente),1)) WHERE pg_get_serial_sequence('cliente','id_cliente') IS NOT NULL;
SELECT setval(pg_get_serial_sequence('pedido','id_pedido'), COALESCE((SELECT MAX(id_pedido) FROM pedido),1)) WHERE pg_get_serial_sequence('pedido','id_pedido') IS NOT NULL;

-- ------------------------------------------------------------
-- 7. Verificar antes de commitear (no borrar estos SELECT)
-- ------------------------------------------------------------
SELECT 'categoria' AS t, COUNT(*) FROM categoria UNION ALL
SELECT 'producto', COUNT(*) FROM producto UNION ALL
SELECT 'cliente', COUNT(*) FROM cliente UNION ALL
SELECT 'pedido', COUNT(*) FROM pedido UNION ALL
SELECT 'pedido_producto', COUNT(*) FROM pedido_producto;

-- Si todo da 10 / 50002 / 20001 / 200001 / 200000 -> COMMIT; si no -> ROLLBACK;
COMMIT;

-- ------------------------------------------------------------
-- 8. FUERA de la transacción: actualizar estadísticas del optimizador
-- Obligatorio por TP Parte 1 punto 4 antes de medir EXPLAIN ANALYZE
-- ------------------------------------------------------------
-- ANALYZE categoría;
-- ANALYZE producto;
-- ANALYZE cliente;
-- ANALYZE pedido;
-- ANALYZE pedido_producto;
