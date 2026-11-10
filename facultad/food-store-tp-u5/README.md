# Trabajo Práctico — Unidad 5: Administración y Seguridad en Food Store
**Tecnicatura Universitaria en Programación — Base de Datos II (UTN FRM)**  
**Ciclo Lectivo:** 2026  
**Alumno:** Fabrizio Simon  
**Motor:** PostgreSQL 18 (x86_64-windows)  

---

## 📌 Descripción del Trabajo

Este Trabajo Práctico integra las Clases 1 y 2 de la Unidad 5 (Administración y Seguridad):
1. **Parte A — Roles y permisos de mínimo privilegio:** Diseño formal en Kiro (`requirements.md`, `design.md`), implementación en `sql/roles.sql` con roles de grupo, login, permisos a nivel de columna sobre `usuario.email` y `ALTER DEFAULT PRIVILEGES`.
2. **Parte B — Activación y prueba de auditoría:** Auditoría nativa con `log_connections`, `log_disconnections` y `log_statement = all`. Captura de log real (`docs/log_auditoria_prueba.txt`) y análisis forense.
3. **Parte C — Laboratorio de simulacro de incidente:** Ejecución de ataque simulado desde rol `app_web` (`sql/simulacro_incidente.sql`), anonimización estricta (`sql/anonimizar_log.py`), reporte forense (`docs/informe_incidente.md`) y detección del hallazgo crítico H-1.
4. **Parte D — Protección de datos personales (anonimización):** Creación de `usuario_anon` con pseudonimización determinista por `md5(id || sal)` y verificación de equivalencia estadística sobre 6 comprobaciones en `docs/verificacion_equivalencia.md`.
5. **Parte E — Cierre y consolidación de bitácora:** Consolidación de interacciones con IA en `BITACORA.md`, análisis del caso más significativo de corrección humana (C.1), remediación de `fn_autenticar` a `SECURITY DEFINER` y versionado Git por partes.

---

## 📁 Estructura del Entregable (`food-store-tp-u5/`)

```text
food-store-tp-u5/
├── sql/
│   ├── roles.sql                        # Script de roles, permisos y default privileges (Parte A)
│   ├── auditoria_test.sql               # Secuencia de pruebas de auditoría (Parte B)
│   ├── simulacro_incidente.sql          # Secuencia del simulacro de incidente (Parte C)
│   ├── anonimizar_log.py                # Parser Python para anonimizar logs de PostgreSQL (Parte C)
│   ├── usuario_anon.sql                 # DDL y DML de tabla anonimizada (Parte D)
│   ├── verificar_equivalencia_anon.sql  # 9 consultas de equivalencia estadística (Parte D)
│   └── verificar_permisos.sql           # Consultas de verificación sobre information_schema (Parte A)
├── docs/
│   ├── kiro_roles_spec/
│   │   ├── requirements.md              # Especificación de requerimientos de roles (Parte A)
│   │   └── design.md                    # Diseño técnico y justificación de roles (Parte A)
│   ├── informe_auditoria.md             # Informe técnico de configuración y análisis de log (Parte B)
│   ├── log_auditoria_prueba.txt         # Fragmento real de log de auditoría capturado (Parte B)
│   ├── log_simulacro_anonimizado.txt    # Log real del incidente anonimizado (Parte C)
│   ├── informe_incidente.md             # Reconstrucción forense, contraste IA y remediación (Parte C)
│   ├── informe_verificacion_permisos.md # Salida y verificación de roles y privilegios (Parte A)
│   └── verificacion_equivalencia.md     # Resultados comparativos reales y análisis k-anonimato (Parte D)
├── capturas/                            # Capturas de pantalla de la verificación de permisos (Parte A)
│   ├── u5_a_01_roles.png
│   ├── u5_a_02_privilegios_tabla.png
│   ├── u5_a_03_privilegios_columna.png
│   ├── u5_a_04_herencia.png
│   └── u5_a_05_default_privileges.png
├── setup_food_store_u5.sql              # Setup completo de Food Store + funciones securizadas
├── BITACORA.md                          # Bitácora obligatoria de uso crítico de IA (Partes A a E)
├── ESTADO.md                            # Registro técnico detallado del estado del trabajo
└── README.md                            # Este archivo
```

---

## 🔒 Remediación de Seguridad Aplicada (Hallazgo H-1)

Durante el simulacro de la Parte C se descubrió que `fn_autenticar` fue creada originalmente como `SECURITY INVOKER`, impidiendo que `app_web` valide credenciales debido a la restricción de mínimo privilegio sobre la tabla `usuario`.

Se implementó y verificó la remediación estándar en PostgreSQL:
```sql
ALTER FUNCTION fn_autenticar(text, text) OWNER TO admin_datos;
ALTER FUNCTION fn_autenticar(text, text) SECURITY DEFINER;
ALTER FUNCTION fn_autenticar(text, text) SET search_path = public, pg_temp;
```
Con esta configuración, la aplicación puede autenticar credenciales (`autenticado = true/false`) sin otorgar permisos directos a `app_web` sobre columnas sensibles (`email`, `password_hash`).
