# Informe Post-Incidente — Unidad 6: Mantenimiento, Respaldo y Recuperación
**Tecnicatura Universitaria en Programación — Base de Datos II (UTN FRM)**  
**Proyecto:** Food Store | **Motor:** PostgreSQL 18.6 | **Fecha:** 10 de noviembre de 2026 | **Autor:** Fabrizio Simon  

---

## 1. Datos Generales del Respaldo Utilizado
- **Archivo de respaldo:** `foodstore_20261110_155301.dump`
- **Formato:** Custom (`-Fc`, compresión gzip nativa de PostgreSQL) | **Tamaño:** 3.58 MB (3,752,831 bytes)
- **Fecha y hora de generación del respaldo:** 2026-11-10 15:53:03 (-03:00)
- **Fecha y hora de inicio del simulacro:** 2026-11-10 15:54:45 (-03:00)
- **Base de datos origen:** `foodstore` (96 MB) | **Base descartable de destino:** `foodstore_restore_test`

---

## 2. Métricas de Continuidad: RPO y RTO (Previstos vs. Observados)

| Métrica de Continuidad | Valor Previsto (Objetivo) | Valor Observado en Laboratorio | Estado / Cumplimiento |
| :--- | :--- | :--- | :--- |
| **RPO (Recovery Point Objective)** | $\le 24$ horas (política diaria) | **1.70 minutos** (102 segundos) | ✅ **Excelente** (ventana de datos intacta) |
| **RTO (Recovery Time Objective)** | $\le 5$ minutos (300 segundos) | **4.84 segundos** (00:04.841) | ✅ **Excelente** (recuperación en tiempo récord) |

*Análisis:* El RTO observado de **4.84 segundos** comprende la creación limpia de la base descartable (`createdb`), la descompresión y reconstrucción de índices con `pg_restore` y la ejecución completa de las 3 suites de validación lógica sobre más de 470,000 registros.

---

## 3. Resultado de Validaciones de Integridad y Restricciones Lógicas

| Objeto / Regla Validada | Criterio de Aceptación | Resultado Observado | Veredicto |
| :--- | :--- | :--- | :--- |
| **Volumen de `categoria`** | Coincidir con origen | 10 filas | ✅ Consistente |
| **Volumen de `cliente`** | Coincidir con origen | 20,001 filas | ✅ Consistente |
| **Volumen de `producto`** | Coincidir con origen | 50,002 filas | ✅ Consistente |
| **Volumen de `pedido`** | Coincidir con origen | 200,001 filas | ✅ Consistente |
| **Volumen de `detalle_pedido`** | Coincidir con origen | 200,000 filas | ✅ Consistente |
| **Control de productos inválidos** | `precio < 0 OR stock < 0` = 0 | **0 productos inválidos** | ✅ Integridad total |
| **Control de detalles inválidos** | `cantidad <= 0 OR precio_unitario < 0` = 0 | **0 detalles inválidos** | ✅ Integridad total |

---

## 4. Problema Real Encontrado Durante el Procedimiento
Durante las pruebas iniciales de restauración con `pg_restore`, al no especificar `--no-owner` ni `--no-privileges`, el motor intentó asignar permisos a roles que no siempre están presentes de forma homogénea en entornos descartables de staging/testing. Además, para garantizar que `validate_restore.sql` funcione de forma transparente sobre esquemas que nombran la relación como `pedido_producto` o `detalle_pedido`, se requirió una vista de compatibilidad y columna generada `precio`. Se solventó estandarizando los parámetros de `pg_restore -h localhost -p 5432 -U postgres -d foodstore_restore_test --no-owner --no-privileges` en el script automatizado.

---

## 5. Mejora Concreta para la Siguiente Ejecución
1. **Restauración Concurrente (`-j` jobs):** Habilitar `pg_restore -j 4` para paralelizar la creación de índices y carga de datos en procesadores multinúcleo, reduciendo el RTO en bases superiores a 10 GB.
2. **Archivado Continuo de WAL:** Configurar `archive_mode = on` y `archive_command` para Point-in-Time Recovery (PITR), reduciendo el RPO de 24 horas a menos de 5 minutos en producción real.
3. **Notificación Automática:** Incorporar un hook en `backup_foodstore.ps1` que emita una alerta vía webhook/email ante cualquier `$LASTEXITCODE != 0`.

---

## 6. Asistencia Asistida con OpenCode y Validación Humana
OpenCode asistió en la redacción inicial de los scripts PowerShell (`backup_foodstore.ps1`, `restore_test.ps1`) y las plantillas SQL.  
**Validación y corrección humana aplicada:**
- Se eliminó cualquier sugerencia de credenciales embebidas, forzando el uso exclusivo de `$env:PGPASSWORD` o `pgpass`.
- Se verificó que el script de mantenimiento (`maintenance.sql`) utilizara `VACUUM (ANALYZE)` no bloqueante en lugar de `VACUUM FULL`, respetando estrictamente el principio de no degradar el servicio.
- Se supervisó la ejecución real cronometrada del RTO mediante `[System.Diagnostics.Stopwatch]` y la exactitud de los conteos en `foodstore_restore_test`.
