# Food Store — TP5: índices, vistas y vistas materializadas
Base: `food_store_copia` (copia de `food_store_dev`) — PostgreSQL 18 + DBeaver.

## Estructura (§7)
```
food-store/
├── schema.sql (heredado, sin modificar — DDL de food_store_copia)
├── data.sql (heredado TP3, ampliado: 10 cat / 50002 prod / 20001 cli / 200001 ped / 200000 det)
├── queries.sql (heredado TP3+TP4: carga de trabajo real a indexar)
├── indices.sql (nuevo — Parte A: 3 aceptados + 1 descartado comentado)
├── views.sql (nuevo — Partes B y C: V1/V2/V3 + MV con índice único)
├── specs/ (especificaciones de Kiro, 8 archivos)
├── duia.md (bitácora de uso de IA)
├── informe_mediciones.md (EXPLAIN ANALYZE antes/después, lectura y escritura)
└── README.md (cómo reproducir las pruebas de este trabajo)
```

## Cómo reproducir las pruebas de este trabajo (protocolo cátedra)
1. **Copia:** `CREATE DATABASE food_store_copia WITH TEMPLATE food_store_dev;` (nunca sobre la dev).
2. **Respaldo:** DBeaver → Backup → `backups/backup_YYYYMMDD.dump`.
3. **Transacción:** botón Auto→Manual. `BEGIN;` + script + `SELECT` de verificación + `COMMIT;` (o `ROLLBACK;`). Luego `ANALYZE pedido; ANALYZE producto; ANALYZE pedido_producto;`.
4. **Parte A:** cada Q con `EXPLAIN (ANALYZE, BUFFERS)` ANTES → `CREATE INDEX` de `indices.sql` → `ANALYZE` → EXPLAIN DESPUÉS. Resultados en `informe_mediciones.md` (Q1 43.185→0.031 ms, Q2 9.581→0.248 ms, Q3 19.779→14.065 sigue Seq, escritura 500+500 en 0.03 s).
5. **Parte B:** ejecutar `views.sql` por bloques y verificar equivalencia con `EXCEPT` en ambos sentidos (=0). V2 expone 6 columnas sin `telefono`.
6. **Parte C:** `SELECT * FROM mv_facturacion_categoria_mes` (0.038 ms vs ~430 ms original). Refresco: `REFRESH MATERIALIZED VIEW CONCURRENTLY mv_facturacion_categoria_mes;` (diario 02:00).
