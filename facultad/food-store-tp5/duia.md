# DUIA — Declaración de Uso de IA (TP5, Food Store)
Alumno: Fabri — Base: food_store_copia — Motor: PostgreSQL 18 + DBeaver

## 1. Especificación en Kiro (specs/)
| # | Herramienta | Propósito | Spec entregado | Propuesta IA | Decisión |
|---|---|---|---|---|---|
| 1 | Kiro | Especificar IDX1 reporte mensual | spec_indice_pedido_fecha_forma.md (consulta, frecuencia diaria, cols fecha+forma_pago, criterio Seq→Index) | Índice compuesto (fecha, forma_pago) | ACEPTADO: ataca Seq Scan 200k, rango selectivo |
| 2 | Kiro | Especificar IDX2 stock bajo | spec_indice_producto_stock.md (igualdad categoría + rango stock + parcial activo) | Compuesto parcial (id_categoria, stock) INCLUDE(nombre) WHERE activo | ACEPTADO: parcial más chico, Index-Only |
| 3 | Kiro | Especificar IDX3 detalle | spec_indice_detalle_cantidad.md (rango cantidad+precio sobre 200k) | Compuesto (cantidad, precio_unitario) | CREADO pero NO efectivo: sigue Seq Scan (40% selectividad, correcto). Se documenta igual |
| 4 | Kiro | Especificar sobreindexación | spec_indice_descartado.md | idx_pedido_forma_pago ON (forma_pago) | DESCARTADO: baja cardinalidad (100% EFECTIVO), sin parcial, redundante con IDX1. Suma escritura sin uso |
| 5 | Kiro | Especificar V1/V2/V3 | spec_vista_*.md (columnas, filtro vigencia, columna a ocultar) | 3 vistas + equivalencia manual | ACEPTADAS: EXCEPT 0 / conteo+muestra |
| 6 | Kiro | Especificar MV | spec_vista_materializada.md (Q-A TP4, WITH DATA, índice único) | mv_facturacion_categoria_mes + ux (id_categoria, mes) | ACEPTADA: reporte ~430ms → ms |

## 2. Generación con OpenCode (agente terminal)
- Prompt tipo: "A partir del spec X, generá el CREATE INDEX / VIEW exacto, explicando línea por línea qué nodo del plan ataca y por qué no es redundante con los índices TP3/TP4".
- Ningún script se ejecutó sin leer línea por línea (ver comentarios en indices.sql / views.sql).
- Protocolo cátedra: COPIA (food_store_copia) + transacción Manual en DBeaver + respaldo backups/ + ANALYZE después de crear.

## 3. Casos mínimos exigidos
- **Sobreindexación descartada (Parte A):** `idx_pedido_forma_pago ON pedido(forma_pago)` — ver spec_indice_descartado.md. Justificación: selectividad ~1.0, planificador prefiere Seq Scan, duplica mantenimiento en INSERT, redundante con idx_pedido_fecha_forma.
- **Equivalencia de vista (Parte B):** V1 `v_productos_vigentes` vs consulta manual JOIN: `(SELECT * FROM v_productos_vigentes) EXCEPT (consulta manual)` = 0 y al revés = 0. Mismo procedimiento para V2 y V3 (conteo + muestra 5 filas).

## 4. Verificación
- Cada índice/vista/MV queda en commit Git separado y descriptivo.
- Decisiones: IDX1 (Seq→Index 1393x) e IDX2 (38.6x) aceptados; IDX3 creado pero no efectivo (sigue Seq); `idx_pedido_forma_pago` descartado sin crear.
