# spec: vista_pedidos_con_cliente (SEGURIDAD)
Objetivo: reporte "pedidos con datos del usuario" sin exponer dato sensible.
Mapeo consigna→esquema real: tabla usuario = cliente; columna contraseña = telefono
  (dato personal sensible en este esquema, la tabla cliente no tiene password).
Columnas a exponer: id_pedido, fecha, forma_pago, id_cliente, nombre_cliente, email.
Columna a OCULTAR: cliente.telefono (equivale a "contraseña" de la consigna).
Criterio: se puede otorgar SELECT sobre la vista sin dar acceso a la tabla cliente.
Equivalencia: JOIN pedido-cliente manual con mismas columnas debe dar idéntico resultado.
