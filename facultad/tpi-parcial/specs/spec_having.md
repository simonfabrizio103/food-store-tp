# spec: having_facturacion_categoria (Obj. 5)
Objetivo: cubrir GROUP BY/HAVING, único faltante del objetivo 5 (JOIN, agregación,
subconsultas y ventana ya están en TP3/TP4).
Consulta: facturación total por categoría, solo categorías con facturación > 20.000.000.
Tablas: categoria-producto-pedido_producto. GROUP BY nombre, HAVING SUM(...).
Criterio: devuelve ~10 filas (carga pareja) y el HAVING filtra de verdad
(comprobar quitándolo: trae lo mismo acá, pero el nodo Filter/Having aparece en el plan).
