# spec: indice_producto_categoria_stock
Objetivo: acelerar la consulta operativa "productos con stock bajo por categoría" (reposición diaria).
Consulta afectada:
  SELECT id_producto, nombre, stock FROM producto
  WHERE id_categoria = 3 AND stock < 10 AND activo = TRUE;
Frecuencia: diaria (control de stock).
Columnas candidatas: id_categoria (igualdad), stock (rango), activo (filtro vigencia, ideal parcial).
Criterio de aceptación: pasa de Seq Scan / Bitmap+Filter sobre producto (50k)
  a Bitmap/Index Scan sobre índice parcial más chico, sin Rows Removed masivos.
