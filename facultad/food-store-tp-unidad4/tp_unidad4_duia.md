# DUIA — TP Unidad 4

## Decisión de diseño

Se optó por una **tabla precalculada con trigger** en lugar de vista materializada porque:
1. Permite actualizaciones en tiempo real sin necesidad de refresh manual.
2. El trigger garantiza consistencia mediante recálculo automático ante cambios en `detalle_pedido` y `pedido`.
3. Es reversible sin pérdida: la tabla puede descartarse y recalcularse desde las tablas fuente.

## Justificación de la desnormalización

El `EXPLAIN ANALYZE` antes mostraba un plan dominado por `Seq Scan on detalle_pedido` con múltiples JOINs. Después, el plan usa un `Bitmap Heap Scan` sobre `categoria_venta_dia` con índice en `fecha`, reduciendo el tiempo de 0.123 ms a 0.077 ms.

## Reversibilidad

La desnormalización es reversible: la tabla `categoria_venta_dia` se puede eliminar en cualquier momento y los datos se recuperan mediante la consulta original de 4 tablas.
