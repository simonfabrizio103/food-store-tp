# Trabajo Práctico — Unidad 6: Mantenimiento, Respaldo y Recuperación
**Tecnicatura Universitaria en Programación — Base de Datos II (UTN FRM)**  
**Ciclo Lectivo:** 2026 | **Estudiante:** Fabrizio Simon | **Motor:** PostgreSQL 18.6  
**Proyecto Integrador:** Food Store | **Base Principal:** `foodstore` (96 MB) | **Base Descartable:** `foodstore_restore_test`

---

## 📋 Resumen del Trabajo Práctico

Este trabajo de laboratorio integra las disciplinas de respaldo automatizado, monitoreo continuo, mantenimiento de almacenamiento y recuperación ante desastres (Disaster Recovery) sobre la base de datos `foodstore`:

1. **Parte 1 — Especificación (`SPEC_U6.md`):** Matriz operacional de 4 tareas mínimas (respaldo diario, chequeo diario, mantenimiento semanal, recuperación semanal) con evidencia, horarios y criterios de confirmación de éxito.
2. **Parte 2 — Respaldo Automatizable (`backup_foodstore.ps1`):** Script PowerShell que genera volcados custom (`-Fc`) comprimidos con timestamp en `backups/`, registra logs detallados en `logs/`, finaliza con código de error ante fallos y prohíbe contraseñas embebidas.
3. **Parte 3 — Monitoreo y Mantenimiento (`health_check.sql` y `maintenance.sql`):** Auditoría de tamaño (96 MB), conexiones activas, consultas no ociosas, diagnóstico de autovacuum y ejecución de `VACUUM (ANALYZE, VERBOSE)` no bloqueante (rechazo justificado de `VACUUM FULL`).
4. **Parte 4 — Simulacro de Desastre Contra Reloj (`restore_test.ps1`):** Recreación automatizada de `foodstore_restore_test`, restauración con `pg_restore --no-owner --no-privileges`, y cronometraje de **RTO = 4.84 segundos** y **RPO = 1.70 minutos**, con validación lógica de integridad (conteo de filas y 0 registros inválidos).
5. **Parte 5 — Informe Post-Incidente (`informe_u6.md` e `informe_u6.pdf`):** Documento ejecutivo de 1 página con métricas comparativas, problemas reales y plan de mejoras.

---

## 📁 Estructura del Directorio

```text
food-store-tp-u6/
├── backups/                             # Archivos de volcado .dump generados
│   ├── foodstore_20261110_155059.dump
│   └── foodstore_20261110_155301.dump
├── logs/                                # Logs de auditoría, respaldo y simulacro
│   ├── backup_20261110_155059.log
│   ├── backup_20261110_155301.log
│   ├── health_check_output.txt
│   ├── restore_test_20261110_155348.log
│   └── restore_test_20261110_155445.log
├── backup_foodstore.ps1                 # Script de respaldo automatizado (Parte 2)
├── health_check.sql                     # Consultas de monitoreo de base y conexiones (Parte 3)
├── maintenance.sql                      # Diagnóstico y mantenimiento seguro con VACUUM ANALYZE (Parte 3)
├── restore_test.ps1                     # Automatización del simulacro contra reloj y medición de RTO (Parte 4)
├── validate_restore.sql                 # Consultas de validación de integridad lógica (Parte 4)
├── SPEC_U6.md                           # Especificación formal del plan de mantenimiento (Parte 1)
├── informe_u6.md                        # Informe post-incidente en Markdown (Parte 5)
├── informe_u6.pdf                       # Informe post-incidente oficial en PDF (1 página) (Parte 5)
├── generar_pdf_u6.py                    # Compilador ReportLab del informe PDF
├── BITACORA.md                          # Registro de interacciones con IA y corrección humana
└── README.md                            # Guía general del proyecto
```

---

## 🚀 Guía Rápida de Ejecución

### 1. Generar Respaldo
```powershell
$env:PGPASSWORD = "tu_password"
.\backup_foodstore.ps1
```

### 2. Ejecutar Monitoreo de Salud
```powershell
psql -U postgres -d foodstore -f health_check.sql
```

### 3. Ejecutar Mantenimiento No Bloqueante
```powershell
psql -U postgres -d foodstore -f maintenance.sql
```

### 4. Ejecutar Simulacro Contra Reloj y Validación de Integridad
```powershell
.\restore_test.ps1
```

### 5. Compilar Informe en PDF
```powershell
python generar_pdf_u6.py
```
