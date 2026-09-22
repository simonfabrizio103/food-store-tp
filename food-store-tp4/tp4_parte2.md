# TP4 Parte 2 - Lectura crítica join (plan Q-B 155ms, 2 Hash Join paralelos)

Plan real (resumen): Parallel Hash Join (d.id_pedido=p.id_pedido) + Hash (p.id_cliente=cl.id_cliente) + Parallel Seq Scan pedido_producto/pedido + Seq Scan cliente. Execution 155.805 ms, Planning 0.482 ms.

| Afirmación IA | ¿Correcta? | Corrección |
|---|---|---|
| "En el Nested Loop la externa es pedido_producto y la interna pedido" | No | No hay Nested Loop, son **Parallel Hash Join**. No hay externa/interna, hay build/probe (hashea pedido, prueba con detalles). Confunde algoritmos. |
| "El costo 4118..7074 es el tiempo total" | No | Es costo estimado del nodo intermedio (startup..total), no ms. Total real = Execution 155.805 ms. Confunde costo intermedio con total. |
| "El Sort de gasto es lo más caro" | No / imprecisa | No hay Sort explícito salvo Top-N por LIMIT 100; lo caro es hashear 117k filas (Memory 11488kB) + Seq Scans. Ignora Buffers hit=2942. |
| "Con el índice nuevo pasa a Nested Loop y mejora" | No | Sigue Hash Join (correcto para 200k). Nested con 200k loops sería peor. Atribuye cambio que no ocurrió. |
