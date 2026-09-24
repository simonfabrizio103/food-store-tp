# spec: vista_materializada_facturacion
Objetivo: reporte agregado costoso "facturación por categoría y mes" (Q-A del TP4).
Consulta base: categoria JOIN producto JOIN pedido_producto JOIN pedido,
  GROUP BY categoria, date_trunc('month', fecha), SUM(cantidad*precio_unitario).
Agregado: id_categoria, nombre_categoria, mes, facturación, cantidad_lineas.
Opciones: WITH DATA + índice único (id_categoria, mes) para permitir REFRESH CONCURRENTLY.
Criterio: consultar la MV es ≥10x más rápida que la consulta original (~430 ms → <10 ms).
Refresco: diario nocturno (el dato puede tener hasta 24 h de desfase, aceptable para reporte gerencial).
