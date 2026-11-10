# Especificación y Plan de Mantenimiento — Unidad 6: Food Store
**Tecnicatura Universitaria en Programación — Base de Datos II (UTN FRM)**  
**Motor:** PostgreSQL 16+ (PostgreSQL 18.6) | **Base Principal:** `foodstore` | **Base de Pruebas:** `foodstore_restore_test`

---

## 1. Propósito y Alcance

Este documento define la política operacional de respaldo, monitoreo preventivo, mantenimiento de almacenamiento y simulacros de recuperación ante desastres para la base de datos de producción `foodstore`. El objetivo es garantizar la continuidad operativa, minimizar la pérdida de datos y asegurar un procedimiento de recuperación probado y auditable.

---

## 2. Plan Operativo de Mantenimiento

| Tarea | Frecuencia Propuesta | Horario Sugerido | Evidencia Generada | Condición de Éxito (Criterio de Validación) |
| :--- | :--- | :--- | :--- | :--- |
| **Respaldo de Food Store** | Diaria | 02:00 AM (ventana valle) | Archivo `.dump` con timestamp en `backups/` y log en `logs/`. | `pg_dump` finaliza con código de salida `0`, archivo `.dump` generado con tamaño mayor a cero y log sin errores fatales. |
| **Chequeo de Salud (Monitoreo)** | Diaria | 07:00 AM (previo a operación) | Salida formateada de `health_check.sql` en logs diarios. | Conexiones activas < 80% de `max_connections`, sin consultas bloqueadas (> 5 min), ratio de commits vs rollbacks > 98%. |
| **Revisión de Mantenimiento** | Semanal | Domingos 03:00 AM | Registro de tuplas muertas y ejecución en `maintenance.sql`. | Proporción de tuplas muertas (`n_dead_tup`) < 10% del total de tuplas vivas. `VACUUM (ANALYZE)` ejecutado sin bloqueos exclusivos. |
| **Restauración de Prueba** | Semanal | Domingos 04:30 AM | Log de `restore_test.ps1` sobre `foodstore_restore_test`. | `pg_restore` código `0`, conteos de tablas coincidentes y 0 registros inconsistentes (precio/stock/cantidad >= 0). |

---

## 3. Reglas Técnicas y Directivas de Seguridad

1. **Gestión Segura de Credenciales:** Queda estrictamente prohibido incluir contraseñas en texto plano dentro de scripts (`.ps1`, `.sh` o `.sql`) o versionarlas en repositorios Git. Se emplean variables de entorno protegidas (`$env:PGPASSWORD`) o archivos de credenciales con permisos restringidos (`pgpass.conf`).
2. **Formato de Respaldo Estándar:** Los respaldos se generan en formato personalizado comprimido (`-Fc`). Este formato optimiza el espacio en disco, incorpora metadatos de tabla y habilita la restauración granular y concurrente con `pg_restore`.
3. **Aislamiento de Pruebas Destructivas:** La base de datos `foodstore` no se reemplaza ni se elimina durante los ensayos. Todas las pruebas de recuperación se realizan contra una base descartable aislada (`foodstore_restore_test`), la cual es destruida y recreada exclusivamente para la verificación.
4. **Política de Mantenimiento No Bloqueante:** Se prohíbe taxativamente el uso de `VACUUM FULL` como tarea periódica automática, dado que adquiere un bloqueo exclusivo (`AccessExclusiveLock`) que interrumpe la disponibilidad del servicio. Se privilegia el mantenimiento preventivo mediante `autovacuum` y `VACUUM (ANALYZE)` ordinario en ventanas controladas.
5. **Objetivos de Resiliencia (RPO y RTO):**
   - **RPO Objetivo (Recovery Point Objective):** $\le 24$ horas con respaldo diario (ampliable a $\le 15$ minutos mediante archivado continuo de WAL en producción).
   - **RTO Objetivo (Recovery Time Objective):** $\le 5$ minutos para la reconstrucción completa del esquema y datos en el entorno local de desarrollo.
