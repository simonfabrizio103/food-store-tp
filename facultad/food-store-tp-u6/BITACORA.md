# Bitácora de Uso Crítico de IA — TP Unidad 6: Mantenimiento, Respaldo y Recuperación
**Tecnicatura Universitaria en Programación — Base de Datos II (UTN FRM)**  
**Ciclo Lectivo:** 2026 | **Estudiante:** Fabrizio Simon | **Motor:** PostgreSQL 18.6

---

## 1. Tabla de Interacciones y Validación Crítica

| # | Tarea / Parte | Prompt Enviado a la IA | Respuesta Relevante Recibida (Resumida) | Validación o Corrección Humana Aplicada |
| :--- | :--- | :--- | :--- | :--- |
| **1** | **Parte 1 (Especificación)** | "Redactá una especificación formal de mantenimiento (SPEC_U6.md) de 1 página con frecuencias, evidencias y condiciones de éxito para Food Store." | Propuso un plan con respaldos diarios y restauraciones semanales. Sugirió ejecutar `VACUUM FULL` semanal para 'reducir tamaño en disco'. | **Corrección humana:** Se rechazó enérgicamente el `VACUUM FULL`. Se explicó en la especificación que `VACUUM FULL` adquiere un bloqueo exclusivo total (`AccessExclusiveLock`) inadmisible en producción. Se reemplazó por `autovacuum` preventivo y `VACUUM (ANALYZE)` ordinario no bloqueante. |
| **2** | **Parte 2 (Script de Backup)** | "Generá el script backup_foodstore.ps1 para volcar foodstore en formato custom con timestamp, log y validación de salida." | Entregó el script con `pg_dump -Fc` y captura de error, pero incluyó un parámetro con contraseña por defecto en texto plano. | **Corrección humana:** Se eliminó cualquier contraseña hardcodeada por principio de seguridad y consigna de cátedra. Se forzó la lectura de `$env:PGPASSWORD` o `pgpass`, y se agregó `$process.ExitCode` con corte estricto `exit 1` ante fallos. |
| **3** | **Parte 3 (Monitoreo y Mantenimiento)** | "Creá health_check.sql y maintenance.sql para auditar tamaño, conexiones, tuplas muertas y consultas activas en PostgreSQL 16+." | Diseñó las consultas sobre `pg_stat_database`, `pg_stat_user_tables` y `pg_stat_activity`. | **Validación y ajuste:** Se validó la sintaxis en PostgreSQL 18.6. En `maintenance.sql` se agregó la justificación técnica formal requerida y la verificación de parámetros de `pg_settings` (`autovacuum_vacuum_threshold`, etc.). |
| **4** | **Parte 4 (Simulacro contra reloj)** | "Automatizá el simulacro de recuperación contra reloj en restore_test.ps1 midiendo RTO con cronómetro y validando integridad lógica." | Diseñó la recreación con `createdb` y `pg_restore`, pero sin banderas de roles ni archivo separado de validación. | **Corrección humana:** Se detectó que la ausencia de `--no-owner --no-privileges` arrojaba advertencias de roles en la base descartable. Se agregaron ambas banderas y se estructuró la medición exacta con `[System.Diagnostics.Stopwatch]`, registrando un RTO real de **4.84 segundos**. |
| **5** | **Parte 5 (Informe Post-Incidente)** | "Sintetizá el informe post-incidente en 1 página con RPO, RTO, problemas encontrados y mejoras operacionales." | Propuso el contenido del informe pero excedía la extensión máxima de 1 página. | **Corrección humana:** Se condensó en tablas ejecutivas comparativas (objetivo vs observado), y se construyó un generador ReportLab (`generar_pdf_u6.py`) para compilar un PDF de exactamente 1 página sin desbordes. |

---

## 2. Caso Más Significativo de Corrección Humana (Rechazo de `VACUUM FULL`)

El caso más representativo de intervención crítica del equipo ocurrió durante la formulación de la política de mantenimiento en la **Parte 1 y Parte 3**:

- **Propuesta de la IA:** La IA sugirió programar un `VACUUM FULL` semanal nocturno bajo la premisa genérica de "devolver espacio no utilizado al sistema operativo".
- **Detección y Criterio del Equipo:** El equipo identificó que aplicar `VACUUM FULL` en un sistema transaccional activo (como Food Store) constituye una mala práctica de alto riesgo:
  1. Adquiere un bloqueo `AccessExclusiveLock`, impidiendo cualquier lectura (`SELECT`) o escritura concurrente durante todo el proceso.
  2. Duplica el consumo de espacio temporal en disco al recrear físicamente cada archivo de tabla.
  3. Genera saturación innecesaria del subsistema de I/O.
- **Resolución Técnica Adoptada:** Se descartó el comando y se estableció el uso de **`VACUUM (ANALYZE, VERBOSE)` ordinario**, el cual opera con bloqueo ligero `ShareUpdateExclusiveLock`, permitiendo operaciones concurrentes, marcando espacio libre en el *Free Space Map* (FSM) y actualizando las estadísticas de `pg_statistic` sin degradación de servicio.
