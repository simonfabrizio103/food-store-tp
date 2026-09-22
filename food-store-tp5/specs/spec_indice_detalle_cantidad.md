# spec: indice_detalle_cantidad_precio
Objetivo: acelerar el filtro analítico sobre detalle "líneas con cantidad alta y precio alto".
Consulta afectada:
  SELECT id_pedido, id_producto, cantidad, precio_unitario FROM pedido_producto
  WHERE cantidad >= 4 AND precio_unitario > 400;
Frecuencia: semanal (análisis de tickets grandes).
Columnas candidatas: cantidad (rango, cardinalidad media 1..5), precio_unitario (rango).
Criterio de aceptación: pasa de Seq Scan sobre pedido_producto (200k) a Bitmap Heap Scan
  con Index Cond, reduciendo Rows Removed.
