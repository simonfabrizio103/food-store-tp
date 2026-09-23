# Informe técnico — Primera entrega parcial del TPI (Food Store)
Fabri — Base de Datos II — PostgreSQL 18 + DBeaver (Manual) — Repo: food-store-tp

## 1. Qué elementos se implementaron en cada unidad
- **Unidad 1 (TP1, `food-store-tp1/`):** modelo ER (diagrama), pasaje a relacional con N:M resuelta en `pedido_producto`, normalización hasta 3FN/BCNF con dependencias funcionales, DDL en `Food Store.sql`: ENUM `forma_pago_enum`, IDENTITY, TIMESTAMPTZ, PK/FK con acciones justificadas, UNIQUE, CHECKs, flags de baja lógica con DEFAULT.
- **Unidad 2 (TP2, `food-store-tp2/`):** reglas R1/R2 con funciones + triggers PL/pgSQL, transacciones (3 escenarios: no repetible, fantasma, bloqueo, con READ COMMITTED vs REPEATABLE READ), protocolo copia-transacción-respaldo.
- **Unidad 3 (TP3/TP4/TP5):** carga masiva 200k (TP3), plan de indexado con EXPLAIN ANALYZE (TP3: 2.07x/1.46x; TP4: covering no efectivas documentadas; TP5: Q1 1393x, Q2 38.6x, Q3 no efectiva), vistas + MV con índice único (TP5), ventanas RANK y anti-joins (TP4).
- **Cierre (`food-store-parcial/`):** consulta con HAVING, procedimiento `sp_baja_producto` + CALL, demo de borrado lógico.

## 2. Cómo se probó el funcionamiento
Siempre sobre `food_store_copia` (jamás la dev), DBeaver en Manual, respaldo previo. DDL structural con COMMIT; experimentos con ROLLBACK. Cada objeto: spec Kiro → generación OpenCode → lectura línea por línea → EXPLAIN/SELECT de verificación → EXCEPT en ambos sentidos para equivalencias.

## 3. Qué resultados se obtuvieron
| Objetivo | Evidencia | Resultado |
|---|---|---|
| 1. ER | diagrama TP1 | 5 entidades, N:M detectada |
| 2. Relacional | `Food Store.sql` | intermedia `pedido_producto`, FKs justificadas |
| 3. 3FN/BCNF | desarrollo TP1 | DF documentadas |
| 4. DDL | schema + índices | ENUM/IDENTITY/TZ/UNIQUE/CHECKs |
| 5. DML | queries + `h1_having.png` | JOIN, GROUP BY, HAVING (6 filas), EXISTS, RANK |
| 6. Vistas/funciones/proc. | views.sql, triggers, `b0_procedure.png` | 3 vistas + MV + 2 funciones + 1 procedimiento |
| 7. Reglas | restricciones.sql | CHECK/UNIQUE/triggers R1-R2 verificados con INSERT |
| 8. Transacciones | informe_concurrencia | 3 anomalías reproducidas y resueltas |
| 9. Borrado lógico | `b1/b2/b3` | CALL → vista 50001/0 filas → ROLLBACK → 50002 |

## 4. Consultas optimizadas y diferencias antes/después
- TP3 Q3 precio: Seq Scan 3.394 ms → Bitmap 1.636 ms (2.07x). Q1: 2.101 → 1.430 ms (1.46x).
- TP4 Q-A/Q-B: covering propuestos, sin mejora (430→423.6, 152.9→155.8) — Hash correcto para agregación total, documentado.
- TP5 Q1: Parallel Seq 43.185 ms → Index Scan 0.031 ms (1393x). Q2: 9.581 → 0.248 ms (38.6x). Q3: sigue Seq (40% selectividad, correcto).
- MV facturación: ~430 ms → 0.038 ms (~11300x), refresh diario CONCURRENTLY.

## 5. Uso de IA
Kiro (especificar) + OpenCode (generar), como exige la cátedra; sin otras IA. Decisiones aceptadas: índices compuestos/parciales, vistas, MV, procedimiento. Descartadas con justificación: índice solo en `forma_pago` (cardinalidad 1), covering TP4 (no efectivo), explicaciones de planes con costo confundido con tiempo. Bitácoras DUIA en cada TP.
