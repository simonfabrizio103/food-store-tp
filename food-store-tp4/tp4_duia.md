# TP4 Parte 4 + DUIA

## Competencia (consulta común Q-A facturación)
| Equipo | Estrategia | Antes (ms) | Después (ms) | Mejora |
|---|---|---|---|---|
| Fabri | idx_pedprod_producto_cover + idx_pedido_cliente_cover (covering para Hash) | 430 | 423.68 | 1.01x (no efectiva, sigue Hash + Seq, correcto para total) |

## DUIA TP4
| Herramienta | Para qué | Prompt resumen | Decisión |
|---|---|---|---|
| OpenCode | Q-A/Q-B analíticas + índices join | "plan real 3 Hash Join + external merge Disk, qué nodo ataca" | Descartadas como no efectivas (siguen Hash, Seq más barato que 200k lookups) |
| OpenCode | Explicación plan join Q-B | "nodo por nodo, externa/interna" | Corregida: no es Nested Loop, es Hash; costo≠tiempo |
| OpenCode | R1 RANK + R2 NOT EXISTS + v2 | "ranking empate comparte, productos nunca vendidos" | Aceptadas: R1 20 filas puesto 1 (15000), R2 2 filas (Muzza/Napolitana), EXCEPT 0 por conteo+muestra |
