# TP Unidad 4 — FNBC y Desnormalización Controlada en Food Store

Este TP corresponde a la Unidad 4: Forma Normal de Boyce-Codd y Desnormalización Controlada.

## Estructura

| Archivo | Descripción |
|---------|-------------|
| `tp_fnbc_control_lote.sql` | Parte 1: Análisis y aplicación de FNBC sobre `control_lote_almacen` |
| `tp_desnormalizacion_top_categorias.sql` | Parte 2: Desnormalización controlada para top 5 categorías por día |
| `setup_food_store_copia.sql` | Script de montaje de la base de pruebas `food_store_copia` |
| `Entrega_TP_Unidad4_FINAL.pdf` | Informe final con capturas de EXPLAIN ANALYZE y resultados |

## Capturas

Las capturas de pantalla se encuentran en `capturas_tp4_unidad4/`:
- `tp4_unidad4_01_vista_compatibilidad.png` — Vista de compatibilidad FNBC
- `tp4_unidad4_02_tabla_original.png` — Tabla original verificada
- `tp4_unidad4_03_explain_antes.png` — EXPLAIN ANALYBE antes de desnormalizar
- `tp4_unidad4_04_tabla_desnormalizada.png` — Tabla `categoria_venta_dia` con resultados
- `tp4_unidad4_05_explain_despues.png` — EXPLAIN ANALYZE después de desnormalizar
- `tp4_unidad4_06_auditoria.png` — Script de auditoría (resultado vacío)

## Resultados clave

- **FNBC:** El esquema `control_lote_almacen` **no cumple FNBC** por la dependencia `ResponsableControlID → DepositoID`. Se aplicó descomposición sin pérdida en `responsable_control` y `control_lote_almacen_nuevo`.
- **Desnormalización:** Tiempo de ejecución mejoró de **0.123 ms** (antes, Seq Scan) a **0.077 ms** (después, Bitmap Heap Scan sobre tabla desnormalizada con índice).
- **Auditoría:** 0 filas desincronizadas.
