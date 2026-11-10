# Informe post-incidente — TP Unidad 6: Mantenimiento, Respaldo y Recuperación
**Tecnicatura Universitaria en Programación — Base de Datos II (UTN FRM)**  
**Alumno:** Fabrizio Simon | **Motor:** PostgreSQL 18.6 | **Fecha:** 10 de noviembre de 2026  
**Base principal:** `foodstore` (96 MB) | **Base de prueba descartable:** `foodstore_restore_test`  

---

## 1. Datos del respaldo y del entorno de pruebas
- **Archivo de dump:** `foodstore_20261110_155301.dump`
- **Formato:** Custom de PostgreSQL (`-Fc`, comprimido) | **Tamaño:** 3.58 MB (3,752,831 bytes).
- **Fecha y hora del backup:** 10/11/2026 15:53:03 (-03:00).
- **Momento del simulacro:** 10/11/2026 15:54:45 (-03:00).
- **Entorno:** Base principal `foodstore` intacta (más de 470,000 filas en total); restauración ejecutada exclusivamente sobre la base temporal `foodstore_restore_test`.

---

## 2. Tiempos y métricas: RTO y RPO (Objetivo vs. Observado en el lab)

| Métrica de Continuidad | Objetivo previsto | Lo que me dio en el laboratorio | Conclusión / Estado |
| :--- | :--- | :--- | :--- |
| **RTO (Tiempo de recuperación)** | $\le 5$ minutos (300 s) | **4.84 segundos** (00:04.841) | ✅ **Cumplido sobradísimo** (menos del 2% del margen) |
| **RPO (Pérdida máxima tolerable)** | $\le 24$ horas (política diaria) | **1.70 minutos** (102 segundos) | ✅ **Cumplido** (0 pérdida de transacciones) |

*Análisis:* El RTO de **4.84 segundos** fue cronometrado de punta a punta con `Stopwatch`: incluye borrar la base temporal vieja si existía, crear la base nueva descartable (`createdb`), correr `pg_restore` completo y ejecutar todas las consultas de validación de integridad lógica.

---

## 3. Validaciones de datos y reglas lógicas sobre `foodstore_restore_test`

| Tabla / Control de consistencia | Filas en origen | Filas restauradas | Filas inválidas detectadas | Estado |
| :--- | :--- | :--- | :--- | :--- |
| **`categoria`** | 10 | 10 | 0 | ✅ Idéntico |
| **`cliente`** | 20,001 | 20,001 | 0 | ✅ Idéntico |
| **`producto`** (`precio >= 0 AND stock >= 0`) | 50,002 | 50,002 | **0** (ninguno con precio o stock < 0) | ✅ 100% íntegro |
| **`pedido`** | 200,001 | 200,001 | 0 | ✅ Idéntico |
| **`detalle_pedido`** (`cant > 0 AND precio >= 0`) | 200,000 | 200,000 | **0** (ninguno con cantidad <= 0 o precio < 0) | ✅ 100% íntegro |

Los conteos de filas coincidieron exactamente con la base antes del volcado, y las restricciones lógicas dieron 0 registros inválidos.

---

## 4. Problema real que me encontré durante el procedimiento
Al principio, cuando corrí `pg_restore` pelado sin flags adicionales, el comando me tiraba advertencias de permisos y ownership porque intentaba recrear los mismos dueños y grants específicos de los roles del servidor de origen, que en una base de prueba descartable no hacen falta o pueden no existir.  
**Cómo lo solucioné:** Le agregué obligatoriamente las banderas `--no-owner --no-privileges` al comando dentro de `restore_test.ps1`. Con eso la restauración entró limpia y sin errores de permisos. También me aseguré de mapear con una vista de compatibilidad `detalle_pedido` sobre `pedido_producto` y la columna `precio` para que las consultas de validación de la cátedra corrieran sin tocar nada raro.

---

## 5. Mejoras concretas para la próxima ejecución
1. **Restaurar con jobs en paralelo (`-j`):** Si la base en vez de 96 MB llega a pesar 20 o 50 GB, agregaría `pg_restore -j 4` para restaurar tablas e índices en paralelo usando varios núcleos del CPU y mantener el RTO bajo control.
2. **Archivado continuo de WAL:** Para producción real, no alcanza solo con el backup de la noche; activaría `archive_mode = on` con archivado de WAL para tener Point-in-Time Recovery (PITR) y bajar el RPO real a menos de 5 minutos ante cualquier caída.
3. **Alerta automática si falla:** En `backup_foodstore.ps1`, enganchar una notificación automática (un webhook a Discord/Slack o mail) si `$LASTEXITCODE != 0`, así no dependés de entrar a revisar la carpeta `logs/` a mano.

---

## 6. Asistencia de OpenCode y validación humana
Usé OpenCode para generar la primera versión de los scripts de PowerShell y las consultas de auditoría. Ninguna sugerencia se aceptó a ciegas:
- **Contraseñas:** OpenCode me proponía dejar un parámetro con la password en texto plano. Lo saqué de raíz y forcé que use `$env:PGPASSWORD` para cumplir con las reglas de seguridad.
- **Mantenimiento seguro:** Descarté de plano la idea de meter `VACUUM FULL` semanal porque te mete un bloqueo exclusivo (`AccessExclusiveLock`) y te frena la base; dejé `VACUUM (ANALYZE, VERBOSE)` ordinario que limpia tuplas muertas en caliente sin afectar a los usuarios.
- **Medición real:** En vez de estimar tiempos aproximados, armé el script `restore_test.ps1` con un cronómetro real de sistema para medir el RTO exacto con evidencia en log.
