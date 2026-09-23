Herramienta: OpenCode 1.18.27 Big Pickle
Prompt: 2 restricciones R1 precio_unitario <= precio_lista y R2 fecha <= now() en sql/restricciones.sql
Qué generó: 2 funciones + 2 triggers fn_restriccion_... en 54 líneas
Qué se aceptó: lógica de triggers y RAISE EXCEPTION
Qué se modificó: WHERE id = -> WHERE id_producto = porque columna real es id_producto, si no daba error 42703
Verificación: INSERT fecha futura -> R2 OK, INSERT 999 -> R1 OK (999>100), INSERT 50 -> OK