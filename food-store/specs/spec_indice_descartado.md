# spec: indice_descartado_forma_pago_solo (SOBREINDEXACIÓN — NO CREAR)
Objetivo propuesto por IA: "acelerar filtros por forma_pago".
Consulta supuesta: SELECT * FROM pedido WHERE forma_pago = 'EFECTIVO';
Por qué SE DESCARTA:
  1. Baja cardinalidad extrema: 100% de los 200k pedidos son 'EFECTIVO' (carga TP3).
     Selectividad ~1.0 → el planificador jamás lo usa, siempre prefiere Seq Scan.
  2. Sin condición parcial: no recorta nada, duplica costo de escritura en cada INSERT.
  3. Redundante con IDX1 aceptado (forma_pago, fecha): el compuesto ya cubre
     cualquier filtro útil por forma_pago + rango.
Decisión: NO se crea. Se documenta como caso de sobreindexación exigido en 4.1.6.
Propuesta IA descartada: CREATE INDEX idx_pedido_forma_pago ON pedido(forma_pago);
