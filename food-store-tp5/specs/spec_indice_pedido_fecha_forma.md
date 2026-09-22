# spec: indice_pedido_fecha_forma
Objetivo: acelerar el reporte "pedidos de un mes por forma de pago" (uso diario en caja/cierre).
Consulta afectada:
  SELECT id_pedido, fecha, forma_pago FROM pedido
  WHERE fecha BETWEEN '2025-06-01' AND '2025-06-30'
    AND forma_pago = 'EFECTIVO';
Frecuencia: diaria (cierre de caja) + mensual (reporte).
Columnas candidatas: fecha (alta selectividad por rango), forma_pago (baja selectividad, 1 valor dominante).
Criterio de aceptación: el plan pasa de Seq Scan sobre pedido (200k) a Index/Bitmap Scan
  y el tiempo baja de forma observable.
