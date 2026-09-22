# TP3 Parte 3 - Lectura crítica (plan Q3 después con índice)

Plan real usado (Resultados 13 (3)):
```
Bitmap Heap Scan on producto (cost=107.81..694.01 rows=5616 width=34) (actual time=0.428..1.505 rows=5536 loops=1)
  Recheck Cond: (precio_lista > '4500'::numeric)
  Heap Blocks: exact=516
  Buffers: shared hit=516 read=17
  -> Bitmap Index Scan on idx_producto_precio (cost=0.00..106.41 rows=5616 width=0) (actual time=0.378..0.378 rows=5536 loops=1)
       Index Cond: (precio_lista > '4500'::numeric)
Planning Time: 0.091 ms
Execution Time: 1.646 ms
```

Prompt a IA: "Explicá en lenguaje natural, nodo por nodo, este plan sin más contexto."

| Afirmación de la IA (ejemplo típico) | ¿Correcta? | Corrección / evidencia del plan real |
|---|---|---|
| "cost=107.81..694.01 significa que tardó entre 107 y 694 ms" | No | `cost` es costo estimado en unidades abstractas (startup..total), no tiempo. Tiempo real es `actual time=0.428..1.505` + `Execution Time:1.646 ms`. Confunde estimado con real. |
| "La mejora se debe al índice idx_producto_cat_precio_activo" | No | El plan dice `Bitmap Index Scan on idx_producto_precio`. Atribuye al índice equivocado. El compuesto es para Q1, no Q3. |
| "Ya no hay filas descartadas, el índice es perfecto" (ignora Rows Removed) | No / Imprecisa | En el ANTES había `Rows Removed by Filter:44466`. En el DESPUÉS no aparece porque el `Index Cond` filtra, pero hay `Recheck Cond` + `Heap Blocks:516` (va al heap a rechequear). Ignorar `Rows Removed` pierde la prueba de selectividad (5536/50002 ~11%). |
| "Buffers: shared hit=516 significa 516 lecturas a disco" | No | `hit`=páginas en cache (RAM), `read`=disco. Acá `hit=516 read=17`: casi todo cache, solo 17 disco. Invierte el significado. |
| "Planning Time 0.091 ms es despreciable, no importa" | Sí (con matiz) | Correcto que es bajo vs 1.646 ms, pero en Q1 Planning fue 0.291 ms vs Execution 1.604 ms (18%). No siempre despreciable; hay que comparar, no asumir. |

Conclusión: IA acierta estructura (Bitmap Heap + Bitmap Index), pero confunde cost/tiempo, índice y buffers. Verificación manual obligatoria.
