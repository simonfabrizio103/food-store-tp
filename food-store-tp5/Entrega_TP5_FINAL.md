# TP5 Semana 5 — Índices, vistas y vistas materializadas en Food Store
Fabri — UTN. Base food_store_copia (nunca toqué la dev). PostgreSQL 18 + DBeaver en Manual, con backup antes como dice el protocolo.

## 1. Punto de partida: no toqué las tablas
Parto de lo de TP3/TP4 sin modificar nada: 10 categorías (Pizzas + 9 masivas), 50002 productos, 20001 clientes, 200001 pedidos y 200000 detalles. Los índices de TP3/TP4 ya están (cat_precio_activo, pedido_cliente_fecha, producto_precio, pedprod_cover, pedido_cliente_cover) y los verifiqué en pg_indexes antes de medir, porque en TP3 ya me pasó de medir sin haberlos creado.

Mapeo consigna → real, que en la defensa lo preguntan siempre: `usuario` es `cliente`, `detalle_pedido` es `pedido_producto`, no tengo `estado/eliminado/contraseña`. Entonces vigencia = `activo/activa`, y el dato sensible a ocultar es `telefono` (hace de contraseña). Todo lo de esta semana son objetos nuevos, cero ALTER a las tablas base.

## 2. Parte A — Las 3 que sí hacían Seq Scan
Medí antes con EXPLAIN ANALYZE, como siempre. Busqué tres que hoy barren tablas grandes:

Q1 reporte de cierre: pedidos de un mes con forma_pago. Hace Seq Scan en pedido (200k) porque fecha no tiene índice y forma_pago es 100% EFECTIVO. Q2 reposición: productos de una categoría con stock bajo y vigentes. Barre producto (50k) con Filter en stock. Q3 tickets grandes: detalle con cantidad alta y precio alto. Barre pedido_producto (200k).

| Consulta | Antes | Qué le puse | Después | Mejora |
|---|---|---|---|---|
| Q1 cierre mes `fecha BETWEEN + forma_pago` | Seq Scan pedido 200k, ~80 ms | idx_pedido_fecha_forma (fecha,forma_pago) | Bitmap Heap + Bitmap Index, ~10 ms | ~8x, la acepté |
| Q2 stock bajo `id_categoria=3 AND stock<10 vigente` | Seq/Bitmap + Filter, ~12 ms | idx_producto_cat_stock_vig (categoria,stock) INCLUDE(nombre) WHERE activo | Index-Only/Bitmap, ~2 ms | ~6x, la acepté |
| Q3 detalle `cantidad>=4 AND precio>400` | Seq Scan detalle 200k, ~55 ms | idx_pedprod_cantidad_precio (cantidad,precio) | Bitmap Heap + Index, ~16 ms | ~3.4x, la acepté |

Q1 antes: [CAPTURA EXPLAIN Q1 Seq Scan]
Q1 después (usa índice nuevo): [CAPTURA Bitmap on idx_pedido_fecha_forma]
Q2 antes / después: [CAPTURAS]
Q3 antes (Seq Scan) / después (Bitmap): [CAPTURAS]

Ojo: los creé uno por uno en la copia, con ANALYZE después de cada uno. Si medís sin ANALYZE el plan te miente.

### La que descarté (sobreindexación, la pide el punto 6)
La IA me propuso `CREATE INDEX idx_pedido_forma_pago ON pedido(forma_pago);` y la descarté por escrito. Motivo: forma_pago tiene un solo valor (todo EFECTIVO), selectividad 1.0, el planificador jamás lo usa y siempre prefiere Seq Scan. Sin WHERE parcial no recorta nada y es redundante con mi IDX1 (fecha,forma_pago) que ya cubre cualquier filtro útil. Solo sumaría 10-20% en cada INSERT. No se crea. Spec en `specs/spec_indice_descartado.md`.

### Costo en escritura
Medí 500 INSERT en pedido_producto (precio 500 para respetar R1) con \timing: antes ~900 ms, después con los 3 índices ~1100 ms (+~22%). Se acepta: la lectura diaria (cierre, reposición) gana 3-8x y la carga masiva es semanal. El descartado habría sumado costo sin ganancia, por eso quedó afuera.

## 3. Parte B — Tres vistas y la de seguridad
Las generé de los specs, no a mano. Las tres con CREATE OR REPLACE VIEW en `views.sql`.

V1 `v_productos_vigentes`: producto + categoría, solo vigentes (p.activo AND c.activa). Columnas id, nombre_producto, precio, stock, nombre_categoria. V2 `v_pedidos_con_cliente` (la de seguridad): pedido + cliente SIN telefono. Expongo id_pedido, fecha, forma_pago, id_cliente, nombre_cliente, email. Con esto puedo hacer GRANT SELECT sobre la vista sin dar acceso a cliente. V3 `v_detalle_pedido_extendido`: detalle + nombre producto + subtotal (cantidad*precio).

Verificación: para cada una corrí la consulta manual equivalente y EXCEPT en ambos sentidos = 0. V1 me dio 50002 filas en ambas, V2 200001, V3 200000. Conteo + muestra 5. [CAPTURAS EXCEPT vacíos + SELECT column_name de V2 sin telefono].

## 4. Parte C — La materializada (facturación por categoría y mes)
Reusé la Q-A del TP4, que es el agregado más caro que tengo: 4 tablas, GROUP por mes, 3 Hash Join + Sort a disco, ~430 ms para 130 filas. La materialicé con WITH DATA y le puse índice único (id_categoria, mes) para poder hacer REFRESH CONCURRENTLY después.

`SELECT * FROM mv_facturacion_categoria_mes` me da ~130 filas en ~5 ms contra ~430 ms de la original. Unas 80x. [CAPTURAS ambos EXPLAIN].

Refresco: diario a las 02:00 con `REFRESH MATERIALIZED VIEW CONCURRENTLY`. Implica desfase de hasta 24 h: sirve para reporte gerencial, NO para caja/stock en vivo. Si alguien mira después de un cierre sin refresh, ve el día anterior. Lo dejo documentado porque en la defensa lo preguntan.

## 5. DUIA + defensa
| Uso IA | Prompt | Qué decidí |
|---|---|---|
| Kiro specs 3 índices | consulta + frecuencia + columnas + criterio Seq→Index | Acepté los 3, atacan Seq 200k/50k |
| OpenCode índices | spec como contexto, qué nodo ataca, no redundante con TP3/4 | Acepté compuestos + parcial, descarté forma_pago solo |
| Kiro specs vistas + MV | columnas, vigencia, qué ocultar | Acepté V1/V2/V3 + MV con ux |
| OpenCode vistas | generar + equivalencia EXCEPT | Acepté, EXCEPT 0 en las 3 |

Si en la defensa me preguntan: IDX1 cambia Seq→Bitmap porque fecha es rango selectivo (1/12), IDX2 es parcial más chico + Index-Only, IDX3 evita leer 200k. El descartado no se usa nunca por cardinalidad 1. V2 es la segura (sin telefono). La MV gana 80x pero queda desactualizada hasta el refresh.

### Anexos
1. `indices.sql` (3 CREATE + descartado comentado)
2. `views.sql` (V1, V2, V3 + MV + índice único)
3. `specs/` 7 archivos
4. Capturas: 6 EXPLAIN Q1-Q3, pg_indexes, 3 EXCEPT vacíos, MV vs original, columnas V2
