# TP3 Parte 5 + DUIA - Registro competencia y bitácora

## Registro competencia (consigna común: listado productos por categoría + precio + orden)
| Equipo | Estrategia aplicada | Tiempo antes (ms) | Tiempo después (ms) | Mejora (x) |
|---|---|---|---|---|
| Fabri | `idx_producto_cat_precio_activo (id_categoria,precio_lista) WHERE activo` ataca Filter+Bitmap de Q1 | 2.059 | 1.604 | 1.28x |
| Fabri (Q3) | `idx_producto_precio (precio_lista)` Seq Scan -> Bitmap Index Scan | 3.409 | 1.646 | 2.07x |

Gana tiempo real (EXPLAIN ANALYZE), no costo estimado. Documentado incluso lo que no funcionó (Q2).

## DUIA - Declaración de Uso de IA (obligatoria)
| Herramienta | Para qué se usó | Prompt / spec (resumen) | Se aceptó / se descartó — por qué |
|---|---|---|---|
| OpenCode | Script carga masiva 50k/20k/200k con generate_series | "50k productos parejo categorías, precio 500-5000 stock 0-200, 20k clientes email único, 200k pedidos fecha<=now + detalles precio<=lista, sin PL/pgSQL" | Aceptado con cambios: se agregó OVERRIDING SYSTEM VALUE por IDENTITY GENERATED ALWAYS (error 428C9), y precio_unitario=500 para garantizar R1 sin JOIN |
| OpenCode | 3 índices Q1/Q2/Q3 a partir de planes reales | "plan real + qué nodo ataca + por qué cambiaría" | Q1 aceptado (1.28x), Q3 aceptado (2.07x), Q2 descartado como no efectivo (sigue viejo índice, 0.066->0.045 por cache, planner lo descarta por 10 filas) |
| OpenCode | Explicación nodo por nodo plan Q3 con índice | "explicá este plan sin más contexto" | Descartada parcialmente: confunde cost con ms, atribuye a índice equivocado, invierte hit/read, ignora Rows Removed 44466 |
| OpenCode | SQL Parte 4 spec1 resumen y spec2 EXISTS | specs precisas con tablas, filtro activa=TRUE, columnas, orden, corte | Aceptadas, verificadas con EXCEPT 0 filas (nota: TARJETA da 0 filas por carga solo EFECTIVO, se prueba con EFECTIVO) |

## Entregables checklist
- [x] `sql/carga_masiva_tp3.sql` (leído, OVERRIDING, transacción, ANALYZE)
- [x] `sql/tabla_parte2.md` + capturas Resultados 5/6/8/13
- [x] `sql/tabla_parte3.md`
- [x] `sql/consultas_parte4.sql` + EXCEPT
- [x] Registro competencia + DUIA (este archivo)
- [ ] Defensa oral: explicar OVERRIDING, Bitmap vs Index Scan, cost vs actual, hit vs read
