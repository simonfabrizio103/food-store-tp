# TP Unidad 5 — Estado del trabajo

**Última actualización:** 8 de noviembre de 2026, 21:45  
**Base de datos usada:** PostgreSQL 18, base `postgres` en `localhost:5432`  
**psql:** `C:\Program Files\PostgreSQL\18\bin\psql.exe`  
**Data directory:** `C:/Program Files/PostgreSQL/18/data`  
**Log directory:** `log` (patrón `postgresql-%Y-%m-%d_%H%M%S.log`)

---

## Estructura de la carpeta

```
tp-unidad-5/
├── sql/
│   ├── roles.sql                        ✅ Parte A
│   ├── auditoria_test.sql               ✅ Parte B (script de pruebas)
│   ├── verificar_permisos.sql           ✅ auxiliar de verificación
│   ├── simulacro_incidente.sql          ✅ Parte C
│   ├── anonimizar_log.py                ✅ auxiliar (anonimizador del log)
│   ├── usuario_anon.sql                 ✅ Parte D
│   └── verificar_equivalencia_anon.sql  ✅ Parte D (verificación)
├── docs/
│   ├── kiro_roles_spec/
│   │   ├── requirements.md              ✅ Parte A
│   │   └── design.md                    ✅ Parte A
│   ├── informe_verificacion_permisos.md ✅ Parte A
│   ├── informe_auditoria.md             ✅ Parte B
│   ├── log_auditoria_prueba.txt         ✅ Parte B (log real)
│   ├── informe_incidente.md             ✅ Parte C
│   ├── log_simulacro_anonimizado.txt    ✅ Parte C
│   └── verificacion_equivalencia.md     ✅ Parte D
├── capturas/                            ✅ Parte A (5 PNG guardados)
├── setup_food_store_u5.sql              ✅ setup de base
├── BITACORA.md                          ✅ Partes A–E
└── ESTADO.md                            ← este archivo
```

---

## ✅ Parte A — COMPLETADA

- `roles.sql` ejecutado correctamente.
- Roles creados: `rol_app_lectura`, `rol_app_escritura`, `rol_soporte`, `rol_reportes` (NOLOGIN) + `app_web`, `admin_datos` (LOGIN).
- Verificación con `information_schema` completada:
  - Solo `app_web` y `admin_datos` pueden login.
  - Ningún rol tiene SUPERUSER/CREATEDB/CREATEROLE.
  - `usuario.email` solo es visible para `rol_soporte` y `admin_datos`.
  - Herencia correcta.
  - `ALTER DEFAULT PRIVILEGES` confirmados con `unnest(d.defaclacl)`:
    - `rol_app_lectura=r/admin_datos`
    - `rol_app_escritura=arwd/admin_datos`
- Informe: `docs/informe_verificacion_permisos.md`.

### ✅ Capturas de la Parte A — GUARDADAS

En `capturas/`:
- `u5_a_01_roles.png` — roles y atributos
- `u5_a_02_privilegios_tabla.png` — privilegios de tabla
- `u5_a_03_privilegios_columna.png` — privilegios de columna (email)
- `u5_a_04_herencia.png` — herencia de roles
- `u5_a_05_default_privileges.png` — default privileges con `unnest`

---

## ✅ Parte B — COMPLETADA

### Configuración final verificada (8/11/2026 21:32)
| Parámetro | Valor | source |
|-----------|-------|--------|
| `log_connections` | `on` | `postgresql.auto.conf` |
| `log_disconnections` | `on` | `postgresql.auto.conf` |
| `log_statement` | `all` | `postgresql.auto.conf` |
| `logging_collector` | `on` | `postgresql.conf` |

Los tres parámetros son de tipo `SIGHUP`: se aplicaron con `pg_reload_conf()`, sin reinicio (`pending_restart = f`). Se usó `log_statement = 'all'` (no `'mod'`) para auditar también los `SELECT`.

### Pruebas ejecutadas
- `sql/auditoria_test.sql` ejecutado como `admin_datos` (SELECT / INSERT / UPDATE / `fn_autenticar` fallida / DELETE).
- Login fallido real (`psql -U app_web`, password incorrecta) → `FATAL: la autentificación password falló`.
- Login exitoso real (`psql -U app_web`) → `conexión autorizada`.
- Log real extraído y guardado en `docs/log_auditoria_prueba.txt`.
- Informe completo en `docs/informe_auditoria.md` (con fragmento real, hallazgos y análisis de sensibilidad).

### Hallazgo colateral
`admin_datos` recibe `ERROR: se ha denegado el permiso a examinar «log_directory»` al hacer `SHOW log_directory` / `SHOW data_directory` (requiere `pg_read_all_settings`). Es correcto por mínimo privilegio; la verificación se hizo como `postgres`. Documentado en §2.2 del informe.

### Conexión usada
Superusuario `postgres` con password `postgres` (validado). `psql` en `C:\Program Files\PostgreSQL\18\bin\psql.exe`.

---

## ✅ Parte C — COMPLETADA (con hallazgo crítico abierto)

- `sql/simulacro_incidente.sql` — ✅ ejecutado como `app_web`.
- `sql/anonimizar_log.py` — ✅ anonimizador reusable.
- `docs/log_simulacro_anonimizado.txt` — ✅ 62 líneas (ventana 21:33:31–21:33:32).
- `docs/informe_incidente.md` — ✅ reconstrucción, contraste IA vs log, hallazgos y decisión de contención.
- Entrada en `BITACORA.md` — ✅ C.1 y C.2.

### ✅ Hallazgo crítico H-1 (REMEDIADO Y VERIFICADO)
`fn_autenticar` era `SECURITY INVOKER` y `app_web` no tiene `SELECT` sobre `usuario`. Se aplicó la remediación en el motor y se persistió en `setup_food_store_u5.sql`:
```sql
ALTER FUNCTION fn_autenticar(text, text) OWNER TO admin_datos;
ALTER FUNCTION fn_autenticar(text, text) SECURITY DEFINER;
ALTER FUNCTION fn_autenticar(text, text) SET search_path = public, pg_temp;
```
**Verificación ejecutada como `app_web`:**
- `fn_autenticar('vendedor1@foodstore.com', 'password123')` → `autenticado = true` ✅
- `fn_autenticar('vendedor1@foodstore.com', 'wrong')` → `autenticado = false` ✅
- `fn_autenticar('inactivo@foodstore.com', 'password123')` → 0 filas ✅
- `SELECT id, email FROM usuario` → `ERROR: permiso denegado` (mínimo privilegio preservado) ✅

### 🔴 Hallazgo crítico H-2 (MITIGADO CON ANONIMIZACIÓN)
`log_statement = 'all'` registra credenciales en texto plano (`fn_autenticar('...','password123')`). Se mantiene por requisito de evidencia; todo log real debe anonimizarse antes de versionarse (mitigado con `sql/anonimizar_log.py`).

---

## ✅ Parte D — COMPLETADA

- `sql/usuario_anon.sql` — ✅ idempotente; pseudonimiza email/nombre, conserva `id`, `rol`, `fecha_alta`, `activo`; no copia `password_hash`.
- `sql/verificar_equivalencia_anon.sql` — ✅ 9 chequeos.
- `docs/verificacion_equivalencia.md` — ✅ salidas reales + análisis de k-anonimato.
- Entrada en `BITACORA.md` — ✅ D.1 y D.2.

### Resultado
| Criterio | Resultado |
|----------|-----------|
| Volumen | 6 = 6 ✅ |
| Distribución rol / activo / año | idénticas ✅ |
| Diferencias por `id` | 0 ✅ |
| Fuga de PII | 0 ✅ |
| Agregados con `pedido` | idénticos ✅ |
| k-anonimato `(rol, año)` | ⚠️ `k=1` en admin/reportes/soporte |

**Limitación documentada:** con 6 filas la combinación `(rol, año_alta)` re-identifica a 3 roles. En un dataset real: generalizar `fecha_alta`, agrupar roles infrecuentes y aplicar regla `k ≥ 3`.

---

## ✅ Parte E — COMPLETADA Y CERRADA

- `BITACORA.md` consolidada con A.1–A.3, B.1–B.2, C.1–C.2, D.1–D.2 + resumen por parte.
- Caso más significativo de error de la IA: **C.1** (`fn_autenticar` `SECURITY INVOKER`), supera a A.1 (`GRANT ALL`) porque llegó a ejecutarse y rompe la autenticación. Remediado y probado.
- **Historial de Git: CONFIGURADO Y VERIFICADO.** Repositorio Git inicializado en `tp-unidad-5/` con historial secuencial de commits legibles por cada parte (A, B, C, D, E + Fix). Cumple con la rúbrica y las consignas de la cátedra.

---

## 📌 Recordatorios para la próxima sesión

1. El usuario está trabajando en la base `postgres` (no en una base dedicada). Funciona, pero se recomienda crear `food_store_u5` si se quiere limpiar.
2. Las tablas y funciones ya existen (`setup_food_store_u5.sql` ejecutado).
3. Los roles ya existen y están configurados.
4. Configuración de auditoría completa (`log_statement = all`, `log_connections = on`, `log_disconnections = on`). No requiere más acción.
5. Superusuario `postgres` / password `postgres`. Los roles de app usan `app_web_pass_2026` y `admin_datos_pass_2026`.
6. El repo Git del TP U5 aún no se creó/pusheó (el repo existente `food-store-tp` tiene el U4 en `facultad/food-store-tp-unidad4`).
7. Cuando se arme el repo, la estructura debe ser:
   ```
   food-store-tp-u5/
   ├── sql/roles.sql
   ├── sql/auditoria_test.sql
   ├── sql/simulacro_incidente.sql
   ├── sql/usuario_anon.sql
   ├── sql/verificar_equivalencia_anon.sql
   ├── sql/anonimizar_log.py
   ├── docs/kiro_roles_spec/
   ├── docs/informe_auditoria.md
   ├── docs/log_auditoria_prueba.txt
   ├── docs/log_simulacro_anonimizado.txt
   ├── docs/informe_incidente.md
   ├── docs/verificacion_equivalencia.md
   ├── capturas/
   └── BITACORA.md
   ```
