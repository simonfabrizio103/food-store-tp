# TP5 Semana 5 — Índices, vistas y vistas materializadas en Food Store
Fabri — UTN. Base food_store_copia (nunca toqué la dev). PostgreSQL 18 + DBeaver en Manual, con backup antes como dice el protocolo.

## 1. Punto de partida: no toqué las tablas
10 categorías (Pizzas + 9 masivas), 50002 productos, 20001 clientes, 200001 pedidos, 200000 detalles. Índices TP3/TP4 verificados en pg_indexes [01] antes de medir.
Mapeo consigna → real: `usuario` es `cliente`, `detalle_pedido` es `pedido_producto`, vigencia = `activo/activa`, sensible a ocultar = `telefono`. Cero ALTER a tablas base.

## 2. Parte A — Mediciones reales
| Consulta | Antes | Índice | Después | Mejora |
|---|---|---|---|---|
| Q1 cierre jun-2025 | Parallel Seq Scan, Removed 100000, 43.185 ms [02] | idx_pedido_fecha_forma | Index Scan, 0.031 ms [05] | 1393x SI |
| Q2 stock cat=3 | Bitmap + Filter, Removed 4760, 9.581 ms [03] | idx_producto_cat_stock_vig (parcial) | Bitmap Index Cond, 0.248 ms [06] | 38.6x SI |
| Q3 detalle | Seq Scan 200k, Removed 120000, 19.779 ms [04] | idx_pedprod_cantidad_precio | sigue Seq Scan, 14.065 ms [07] | 1.4x NO efectiva |

Q1 da 0 filas (junio-2025 fuera de la carga NOW()-365); igual prueba Seq→Index (1471 páginas a 6 buffers). Q3 no usa el índice (40% selectividad, correcto) y se documenta como no efectiva. Descartada sin crear: `idx_pedido_forma_pago` (un valor, redundante con IDX1). Escritura 500+500 con RETURNING + ROLLBACK: 0.03 s [08].

## 3. Parte B — Vistas
V1 50002 [09], V2 200001 sin telefono [10][12], V3 200000 [11]. EXCEPT ambos sentidos = 0 [13].

## 4. Parte C — Materializada
Q-A TP4 ~430 ms → `mv_facturacion_categoria_mes` 0.038 ms [14] (~11300x). `WITH DATA` + índice único `(id_categoria, mes)`. Refresh diario 02:00 `CONCURRENTLY`, desfase 24 h (gerencial sí, caja no).

## 5. DUIA
| Uso IA | Prompt | Decisión |
|---|---|---|
| Kiro specs índices | consulta + frecuencia + columnas | Acepté IDX1/IDX2, Q3 no efectiva |
| OpenCode índices | qué nodo ataca | Acepté 3, descarté pago-solo |
| Kiro vistas + MV | columnas, vigencia, ocultar | Acepté V1/V2/V3 + MV |
| OpenCode vistas | generar + EXCEPT | Acepté, EXCEPT 0 |

### Anexos
`indices.sql`, `views.sql`, `specs/` (8), capturas 01–14. Versión con figuras: `Entrega_TP5_FINAL.pdf`.
