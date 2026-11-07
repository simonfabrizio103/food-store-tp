# TP Unidad 4 — Parte 2: Desnormalización Controlada

## Escenario

Panel de administración que muestra el top 5 de categorías por monto vendido en el día. La consulta original recorre 4 tablas (`detalle_pedido`, `producto`, `categoria`, `pedido`).

## Patrón elegido

**Tabla precalculada con disparador (trigger)**

## Estructura desnormalizada

```sql
CREATE TABLE categoria_venta_dia (
    fecha             DATE        NOT NULL,
    categoria_id      BIGINT      NOT NULL REFERENCES categoria(id),
    categoria_nombre  TEXT        NOT NULL,
    total_vendido     NUMERIC(14,2) NOT NULL DEFAULT 0,
    actualizado_en    TIMESTAMP   NOT NULL DEFAULT now(),
    PRIMARY KEY (fecha, categoria_id)
);
```

## Resultados EXPLAIN ANALYZE

| | ANTES | DESPUES |
|---|---|---|
| Tiempo | 0.123 ms | 0.077 ms |
| Nodo dominante | `Seq Scan on detalle_pedido` | `Bitmap Heap Scan on categoria_venta_dia` |

## Auditoría de desincronización

Resultado: **0 filas** (vacio). El dato redundante está sincronizado con su fuente de verdad.
