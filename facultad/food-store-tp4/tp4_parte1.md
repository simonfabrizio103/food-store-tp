# TP4 Parte 1 - Tabla 1.2 (food_store_copia, base TP3)

## Q-A Facturación por categoría y mes (4 tablas)
- **Antes:** 3x Hash Join + Sort external merge Disk 9688kB, Seq Scan pedido_producto 200k. `actual ~388..430 ms rows=130`. External merge = se desborda a disco (temp 2283).
- **Cambio:** `idx_pedprod_producto_cover (id_producto,id_pedido) INCLUDE(cantidad,precio)` + `idx_pedido_cliente_cover (id_cliente,id_pedido)`. Esperaba Index-Only y menos heap.
- **Después:** Sigue Hash + Seq Scan pedido 200001 + producto 50002. `Execution 423.680 ms`.
- **Mejora:** 430->423.6 ms ~1.01x. **No efectiva**. Por qué: agregación total, hash entra en memoria, 200k lookups serían peor. Se documenta igual.

## Q-B Ranking gasto Top 100 (3 tablas)
- **Antes:** 2x Parallel Hash Join (d.id_pedido=p.id_pedido, p.id_cliente=cl.id_cliente) + Parallel Seq Scan pedido/pedido_producto + Seq Scan cliente. `Execution 152.988 ms`.
- **Cambio:** mismos índices (covering para join).
- **Después:** Mismos Parallel Hash Join + Seq Scan. `Execution 155.805 ms`.
- **Mejora:** 152.9->155.8 ms ~0.98x (ruido). **No efectiva**. Hash es óptimo para full scan.

## R1 Ranking ventana (Parte 3, bonus)
- Plan: mismos Hash Joins + Window RANK. `Execution 168.130 ms rows=20`. Sirve para lectura crítica join externa/interna.

## R2 Productos nunca vendidos (Parte 3)
- Plan: `Hash Right Anti Join cost 1641..7858 rows=77 actual 33.5..34.1 rows=2` (los 2 viejos Muzza/Napolitana). `Seq Scan pedido_producto 200k + Seq Scan producto 50002 Filter activo`. `Execution 34.526 ms`.
- Ideal para equivalencia NOT EXISTS vs LEFT JOIN IS NULL (2 filas).
