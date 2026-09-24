# Informe de mediciones — TP5 (food_store_copia, PostgreSQL 18 + DBeaver Manual)

## Mapeo esquema (consigna → real)
| Consigna | Esquema real | Nota |
|---|---|---|
| usuario | cliente | `cliente(id_cliente,nombre,email,telefono)` |
| detalle_pedido | pedido_producto | `pedido_producto(id_pedido,id_producto,cantidad,precio_unitario)` |
| usuario.contraseña | cliente.telefono | sensible, oculta en V2 |
| pedido.estado / eliminado | — (no existe) | equivalente: `forma_pago` + rango `fecha` |
| producto.vigente | producto.activo + categoría.activa | filtro de vigencia |

## Parte A — EXPLAIN ANALYZE antes / después (capturas 01–07)

### Q1 — Pedidos de un mes (cierre)
```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT id_pedido, fecha, forma_pago FROM pedido
WHERE fecha BETWEEN '2025-06-01' AND '2025-06-30' AND forma_pago='EFECTIVO';
```
- **Antes [02]:** `Gather + Parallel Seq Scan on pedido`, `Filter fecha`, `Rows Removed 100000` por worker, `Buffers read=1471`, `Exec 43.185 ms`, 0 filas (junio-2025 fuera de la carga NOW()-365; con agosto-2026 daría ~16k con igual plan).
- **Índice:** `CREATE INDEX idx_pedido_fecha_forma ON pedido(fecha, forma_pago); + ANALYZE pedido;`
- **Después [05]:** `Index Scan using idx_pedido_fecha_forma`, `Index Cond fecha`, `Buffers hit=6`, `Exec 0.031 ms`.
- **Mejora: 43.185 → 0.031 ms (1393x). Seq→Index. ACEPTADA.**

### Q2 — Stock bajo por categoría (reposición)
```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT id_producto, nombre, stock FROM producto
WHERE id_categoria=3 AND stock<10 AND activo=TRUE;
```
- **Antes [03]:** `Bitmap Heap Scan on producto` + `Bitmap Index Scan on idx_producto_categoria`, `Recheck (id_categoria=3)`, `Filter (activo AND stock<10)`, `Rows Removed 4760`, `Heap Blocks exact=516`, `Exec 9.581 ms`, 240 filas.
- **Índice:** `CREATE INDEX idx_producto_cat_stock_vig ON producto(id_categoria,stock) INCLUDE(nombre) WHERE(activo=TRUE); + ANALYZE producto;`
- **Después [06]:** `Bitmap Heap Scan` + `Bitmap Index Scan on idx_producto_cat_stock_vig`, `Index Cond (id_categoria=3 AND stock<10)`, `Heap Blocks exact=190`, sin Filter masivo, `Exec 0.248 ms`.
- **Mejora: 9.581 → 0.248 ms (38.6x). ACEPTADA (parcial de manual).**

### Q3 — Detalle cantidad+precio (tickets grandes)
```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT id_pedido, id_producto, cantidad, precio_unitario FROM pedido_producto
WHERE cantidad>=4 AND precio_unitario>400;
```
- **Antes [04]:** `Seq Scan on pedido_producto 200k`, `Filter`, `Rows Removed 120000`, `Exec 19.779 ms`, 80000 filas.
- **Índice:** `CREATE INDEX idx_pedprod_cantidad_precio ON pedido_producto(cantidad, precio_unitario); + ANALYZE pedido_producto;`
- **Después [07]:** sigue `Seq Scan`, `Exec 14.065 ms` (1.4x, ruido de caché hit vs read).
- **NO efectiva (documentada):** 80k/200k = 40% selectividad y `precio>400` coincide con el 100% (todo vale 500 por R1). El optimizador hace bien en secuencial.

### Índice descartado (sobreindexación, punto 4.1.6)
- Propuesta IA: `CREATE INDEX idx_pedido_forma_pago ON pedido(forma_pago);` — **NO creada**.
- Motivo: un solo valor (100% EFECTIVO), selectividad 1.0, sin WHERE parcial, redundante con IDX1 `(fecha,forma_pago)`. Solo sumaría 10–20% por INSERT.

### Costo en escritura (captura 08)
- Test reversible: `WITH nuevos AS (INSERT INTO pedido ... RETURNING) + ranked` → 500 pedidos + 500 detalles, `ROLLBACK` final.
- **Resultado con los 3 índices: 0.03 s, Updated Rows 500.** Se acepta (lectura diaria gana 38–1393x, carga semanal).

## Parte B — Vistas (capturas 09–13)
| Vista | Conteo | Verificación |
|---|---|---|
| v_productos_vigentes | 50002 [09] | EXCEPT ambos sentidos = 0 [13] |
| v_pedidos_con_cliente | 200001 [10] | 6 columnas SIN telefono [12] → GRANT seguro |
| v_detalle_pedido_extendido | 200000 [11] | EXCEPT ambos sentidos = 0 |

## Parte C — Materializada (captura 14)
- Original Q-A TP4: ~430 ms (3 Hash Join + Sort a disco, 130 filas).
- `SELECT * FROM mv_facturacion_categoria_mes`: `Seq Scan 130 filas, Exec 0.038 ms` [14]. **~11300x.**
- Refresco: `REFRESH MATERIALIZED VIEW CONCURRENTLY` (ux sobre `(id_categoria, mes)`), diario 02:00, desfase ≤24 h (gerencial sí, caja no).
