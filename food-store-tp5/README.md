# TP5 — Índices, vistas y vistas materializadas (Food Store)
Base: `food_store_copia` (copia de `food_store_dev`) — PostgreSQL 18 + DBeaver.

## Estructura (exigida en §7)
```
food-store-tp5/
├── indices.sql, views.sql
├── specs/ (7 specs de Kiro)
├── duia.md, informe_mediciones.md, README.md
```
`schema.sql / data.sql / queries.sql` son heredados de TP3-TP4 y viven en `sql/` (no se duplican ni se modifican las tablas base):
- `sql/carga_masiva_tp3.sql` (= data.sql ampliado: 10 cat / 50002 prod / 20001 cli / 200001 ped / 200000 det)
- `sql/consultas_parte4.sql` + `sql/tp4_parte3.sql` (= queries.sql de negocio y analíticas)
- `sql/indices_tp3.sql` + `sql/indices_tp4.sql` (índices preexistentes verificados en `01_pg_indexes.png`)

## Cómo reproducir (protocolo cátedra)
1. **Copia:** `CREATE DATABASE food_store_copia WITH TEMPLATE food_store_dev;`
2. **Respaldo:** DBeaver → Backup → `backups/backup_YYYYMMDD.dump`
3. **Transacción:** botón Auto→Manual. `BEGIN;` + script + `SELECT` verificación + `COMMIT;` (o `ROLLBACK;`). Luego `ANALYZE pedido; ANALYZE producto; ANALYZE pedido_producto;`
4. **Medir:** cada Q con `EXPLAIN (ANALYZE, BUFFERS)` ANTES → `CREATE INDEX` → `ANALYZE` → EXPLAIN DESPUÉS. Pegar planes en `informe_mediciones.md`.
5. **Vistas:** ejecutar `views.sql` por bloques (V1, V2, V3, MV + índice único). Verificar equivalencia con `EXCEPT` ambos sentidos (=0).
6. **MV:** `SELECT * FROM mv_facturacion_categoria_mes LIMIT 5;` + medir vs consulta original. Refresh: `REFRESH MATERIALIZED VIEW CONCURRENTLY mv_facturacion_categoria_mes;`

## Commits sugeridos (§5, uno por pieza)
```
git add food-store-tp5/specs/spec_indice_pedido_fecha_forma.md food-store-tp5/indices.sql
git commit -m "Índice compuesto pedido(fecha,forma_pago) — reduce Seq Scan en reporte mensual"
... (repetir por cada índice, cada vista y la MV)
```
El historial debe mostrar el diff de cada pieza para la defensa oral.

## Defensa (recordatorio §8)
Por qué se creó cada índice (qué plan cambió), su costo en escritura, por qué se descartó
`idx_pedido_forma_pago`, y qué garantiza cada vista (V2: oculta telefono = contraseña).
