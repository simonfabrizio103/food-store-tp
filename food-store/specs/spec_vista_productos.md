# spec: vista_productos_vigentes
Objetivo: reporte estándar "productos vigentes con su categoría" (catálogo).
Columnas a exponer: id_producto, nombre_producto, precio_lista, stock, nombre_categoria.
Filtro vigencia: producto.activo = TRUE AND categoria.activa = TRUE.
Seguridad: no hay contraseña en este esquema; no se exponen columnas sensibles.
Equivalencia: comparar con SELECT manual JOIN producto-categoria con mismo filtro.
