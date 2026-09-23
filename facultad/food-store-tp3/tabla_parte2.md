# TP3 Parte 2 - Tabla 2.2 Resultados (food_store_copia)

## Q1 - Productos por categoría + precio + orden
```sql
SELECT id_producto,nombre,precio_lista FROM producto
WHERE id_categoria=1 AND precio_lista BETWEEN 1000 AND 3000 AND activo=TRUE
ORDER BY precio_lista;
```
- **Plan ANTES:** `Sort + Bitmap Heap Scan + Bitmap Index Scan on idx_producto_categoria`
  `cost=777.65..783.04 rows=2157`, `actual 1.905..1.968 rows=2170`, `Rows Removed by Filter:2832`,
  `Heap Blocks:516`, `Execution Time:2.059 ms`
- **Cambio:** `CREATE INDEX idx_producto_cat_precio_activo ON producto(id_categoria,precio_lista) INCLUDE(nombre) WHERE(activo=TRUE);`
  Ataca Filter + parte del costo: mete precio en el índice, evita filtrar 2832 filas en heap.
- **Plan DESPUÉS:** `Sort + Bitmap Heap Scan + Bitmap Index Scan on idx_producto_cat_precio_activo`
  `cost=781.39..787.11 rows=2289`, `actual 1.448..1.508 rows=2170`,
  `Recheck Cond:(id_categoria=1 AND precio_lista>=1000 AND <=3000)`, sin `Rows Removed`,
  `Execution Time:1.604 ms`
- **Mejora:** 2.059 -> 1.604 ms = **1.28x (22% menos)**. No elimina Sort (Bitmap no preserva orden),
  pero elimina el Filter. ACEPTADA.

## Q2 - Historial pedidos por cliente
```sql
SELECT id_pedido,fecha,forma_pago FROM pedido WHERE id_cliente=100 ORDER BY fecha DESC;
```
- **Plan ANTES:** `Sort + Bitmap Heap Scan + Bitmap Index Scan on idx_pedido_cliente`
  `cost=42.19..42.22 rows=10`, `actual 0.052..0.053 rows=10`, `Execution Time:0.066 ms`
- **Cambio:** `CREATE INDEX idx_pedido_cliente_fecha ON pedido(id_cliente,fecha DESC) INCLUDE(forma_pago);`
  Esperaba eliminar Sort entregando orden directo.
- **Plan DESPUÉS:** `Sort + Bitmap Heap Scan + Bitmap Index Scan on idx_pedido_cliente`
  (sigue usando el viejo), `actual 0.033..0.033 rows=10`, `Execution Time:0.045 ms`
- **Mejora:** 0.066 -> 0.045 ms = **1.46x aparente, pero NO usa el índice nuevo**.
  Planificador lo descarta por costo (10 filas: Bitmap+Sort más barato que Index Scan ordenado).
  Se documenta como propuesta NO EFECTIVA (qué se esperaba, qué pasó, por qué).
  Para forzarla habría que `DROP INDEX idx_pedido_cliente` en la copia.

## Q3 nueva - Filtro solo por precio (reemplaza Q3 original rápida)
```sql
SELECT id_producto,nombre,precio_lista FROM producto WHERE precio_lista > 4500;
```
- **Plan ANTES:** `Seq Scan on producto cost=0.00..1141.03 rows=5471`,
  `actual 0.012..3.272 rows=5536`, `Filter:(precio_lista>'4500')`,
  `Rows Removed by Filter:44466`, `Buffers hit=516`, `Execution Time:3.409 ms`
- **Cambio:** `CREATE INDEX idx_producto_precio ON producto(precio_lista);`
  Ataca Seq Scan completo (50002 filas para devolver 5536).
- **Plan DESPUÉS:** `Bitmap Heap Scan + Bitmap Index Scan on idx_producto_precio`
  `cost=107.81..694.01 rows=5616`, `actual 0.428..1.505 rows=5536`,
  `Index Cond:(precio_lista>'4500')`, `Execution Time:1.646 ms`
- **Mejora:** 3.409 -> 1.646 ms = **2.07x**. Seq Scan -> Index. ACEPTADA.

## Archivos
- `sql/carga_masiva_tp3.sql` (Parte 1, con OVERRIDING SYSTEM VALUE)
- `sql/indices_tp3.sql` (los 3 CREATE INDEX)
- Planes guardados en capturas Resultados 5 / 6 / 8 / 13
