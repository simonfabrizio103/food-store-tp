# spec: procedimiento_baja_logica (Obj. 6 + Obj. 9)
Objetivo: cubrir "procedimientos invocados con CALL" (vistas y funciones trigger ya existen)
y dar mecanismo explícito de borrado lógico (flags activo/activa + R7 ya existen).
Procedimiento: sp_baja_producto(p_id BIGINT) en PL/pgSQL — UPDATE producto SET
activo=FALSE donde corresponda; RAISE EXCEPTION si no existe o ya está de baja.
Demo (en copia, reversible): CALL, verificar que v_productos_vigentes ya no lo trae,
ROLLBACK para no alterar la base.
Criterio: CALL funciona, la vista excluye al dado de baja, el ROLLBACK restaura.
