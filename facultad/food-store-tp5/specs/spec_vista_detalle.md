# spec: vista_detalle_pedido
Objetivo: "detalle de un pedido con el nombre del producto" (impresión de ticket).
Columnas: id_pedido, id_producto, nombre_producto, cantidad, precio_unitario,
  subtotal (cantidad*precio_unitario).
Tablas: pedido_producto JOIN producto (y opcional pedido para fecha).
Equivalencia: consulta manual con JOIN + cálculo debe coincidir fila por fila.
