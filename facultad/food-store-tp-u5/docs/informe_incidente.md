# Parte C ÔÇö Informe del simulacro de incidente

**Fecha del simulacro:** 8 de noviembre de 2026, 21:33:31 (-03)  
**Motor:** PostgreSQL 18 ÔÇö base `postgres` (`localhost:5432`)  
**Archivo de evidencia:** `docs/log_simulacro_anonimizado.txt`  
**Script del simulacro:** `sql/simulacro_incidente.sql`  
**Anonimizador:** `sql/anonimizar_log.py`

---

## 1. Escenario simulado

Se parte de una hip├│tesis de amenaza: **un atacante ya obtuvo credenciales v├ílidas de `app_web`** (el rol de login de la aplicaci├│n) y opera desde la red local. Con esa posici├│n intenta:

1. Adivinar contrase├▒as de usuarios de la aplicaci├│n mediante `fn_autenticar`.
2. Autenticarse con una credencial v├ílida.
3. Leer masivamente la tabla `usuario`.
4. Escalar privilegios (`SET ROLE admin_datos`).
5. Persistir creando un rol propio (`CREATE ROLE`).
6. Otorgarse privilegios adicionales (`GRANT rol_soporte TO app_web`).

El objetivo del laboratorio es **generar evidencia en el log y verificar qu├® logra y qu├® no** un actor con ese nivel de acceso.

---

## 2. Evidencia: fragmento del log anonimizado

```text
LOG:  conexi├│n recibida: host=localhost port=NNNNN
LOG:  conexi├│n autenticada: identidad=┬½app_web┬╗ m├®todo=scram-sha-256 (pg_hba.conf:117)
LOG:  conexi├│n autorizada: usuario=app_web base_de_datos=postgres nombre_de_aplicaci├│n=psql
LOG:  sentencia: SELECT * FROM fn_autenticar('usuario_anon@example.com', '***');
ERROR:  permiso denegado a la tabla usuario
CONTEXTO:  sentencia SQL: ┬½SELECT u.id, u.nombre, u.rol,
           (u.password_hash = md5(p_password)) AS autenticado
    FROM usuario u
    WHERE u.email = p_email AND u.activo = TRUE┬╗
    funci├│n PL/pgSQL fn_autenticar(text,text) en la l├¡nea 3 en RETURN QUERY
SENTENCIA:  SELECT * FROM fn_autenticar('usuario_anon@example.com', '***');
... (se repite 4 veces: 4 intentos de fn_autenticar, todos con ERROR)
LOG:  sentencia: SELECT id, nombre, rol, activo FROM usuario ORDER BY id;
LOG:  sentencia: SELECT id, email FROM usuario ORDER BY id;
ERROR:  permiso denegado a la tabla usuario
SENTENCIA:  SELECT id, email FROM usuario ORDER BY id;
LOG:  sentencia: SET ROLE admin_datos;
ERROR:  se ha denegado el permiso para definir el rol ┬½admin_datos┬╗
LOG:  sentencia: CREATE ROLE rol_atacante LOGIN PASSWORD '***';
ERROR:  se ha denegado el permiso para crear el rol
DETALLE:  S├│lo los roles con el atributo CREATEROLE pueden crear roles.
LOG:  sentencia: GRANT rol_soporte TO app_web;
ERROR:  se ha denegado el permiso para otorgar el rol ┬½rol_soporte┬╗
DETALLE:  S├│lo los roles con la opci├│n ADMIN en el rol ┬½rol_soporte┬╗ pueden otorgar este rol.
LOG:  desconexi├│n: duraci├│n de sesi├│n: 0:00:00.038 usuario=app_web base=postgres host=localhost port=NNNNN
```

El archivo completo (62 l├¡neas, ventana 21:33:31ÔÇô21:33:32) est├í en `docs/log_simulacro_anonimizado.txt`.

---

## 3. Reconstrucci├│n de la secuencia

A partir **solo del log** (sin mirar el script) se reconstruye:

| # | Evento | Evidencia |
|---|--------|-----------|
| 1 | Conexi├│n autenticada como `app_web` por `scram-sha-256`, cliente `psql` | `conexi├│n autenticada` / `conexi├│n autorizada` |
| 2 | Cuatro invocaciones a `fn_autenticar` con distintos emails/contrase├▒as | cuatro `sentencia: SELECT * FROM fn_autenticar(...)` |
| 3 | Las cuatro fallaron, **pero no por credencial inv├ílida**: fallaron por `permiso denegado a la tabla usuario` | `ERROR: permiso denegado a la tabla usuario` + `CONTEXTO ... fn_autenticar` |
| 4 | Lectura masiva de `usuario` limitada a `id, nombre, rol, activo` | `sentencia: SELECT id, nombre, rol, activo FROM usuario` |
| 5 | Intento de leer `email` | `ERROR: permiso denegado a la tabla usuario` |
| 6 | Intento de escalar a `admin_datos` | `ERROR: se ha denegado el permiso para definir el rol` |
| 7 | Intento de crear un rol | `ERROR: ... crear el rol` + `DETALLE: CREATEROLE` |
| 8 | Intento de auto-otorgarse `rol_soporte` | `ERROR: ... otorgar el rol` + `DETALLE: ADMIN option` |
| 9 | Desconexi├│n, sesi├│n de ~38 ms | `desconexi├│n: duraci├│n de sesi├│n: 0:00:00.038` |

**Conclusi├│n de la reconstrucci├│n:** el actor ten├¡a una sesi├│n leg├¡tima de aplicaci├│n y ejecut├│ una secuencia t├¡pica de reconocimiento + escalamiento, pero **todas las acciones sensibles fueron bloqueadas por el modelo de m├¡nimo privilegio**. Lo ├║nico que obtuvo fue la lista de usuarios sin datos personales (id, nombre, rol, activo), que igualmente es informaci├│n ├║til para un atacante (enumeraci├│n de cuentas y roles).

---

## 4. Contraste: qu├® esperaba la IA vs. qu├® mostr├│ el log

| Hip├│tesis de la IA antes de ejecutar | Lo que mostr├│ el log | Veredicto |
|--------------------------------------|----------------------|-----------|
| `fn_autenticar` devolver├¡a `autenticado = false` en los intentos fallidos | La funci├│n **ni siquiera se ejecut├│**: `permiso denegado a la tabla usuario` | ÔØî La hip├│tesis era incorrecta |
| El login exitoso dejar├¡a rastro claro de ÔÇ£credencial v├ílidaÔÇØ | El ├║nico login es el de la sesi├│n de base; no hay evidencia de autenticaci├│n de aplicaci├│n exitosa | ÔØî No se pudo validar por este medio |
| `SET ROLE admin_datos` fallar├¡a | Fall├│, como se esperaba | Ô£à Confirmado |
| `CREATE ROLE` / `GRANT` fallar├¡an | Fallaron, con el motivo exacto en `DETALLE` | Ô£à Confirmado |
| `SELECT id, email FROM usuario` fallar├¡a | Fall├│, como se esperaba | Ô£à Confirmado |

El contraste dej├│ al descubierto un **defecto funcional real** que la IA no hab├¡a previsto: `fn_autenticar` es `SECURITY INVOKER`, por lo que se ejecuta con los privilegios de `app_web`, y `app_web` no tiene `SELECT` sobre `usuario` (se le neg├│ a prop├│sito, incluido `email`). Resultado: **la aplicaci├│n no puede autenticar a ning├║n usuario**. El m├¡nimo privilegio se aplic├│ correctamente sobre las tablas, pero se olvid├│ el camino de la funci├│n de autenticaci├│n.

---

## 5. Hallazgos

### 5.1. H-1 (cr├¡tico, funcional): `fn_autenticar` no es ejecutable por `app_web`
- **S├¡ntoma:** `ERROR: permiso denegado a la tabla usuario` dentro de `fn_autenticar`.
- **Causa:** la funci├│n es `SECURITY INVOKER` (default) y `app_web` no tiene `SELECT` sobre `usuario` (ni sobre `email`/`password_hash`).
- **Impacto:** la autenticaci├│n de la aplicaci├│n queda completamente rota. Es una falla de disponibilidad, no de seguridad: el m├¡nimo privilegio ÔÇ£funcionaÔÇØ pero inutiliza el negocio.
- **Remediaci├│n propuesta:** recrear la funci├│n como `SECURITY DEFINER`, con un due├▒o que tenga `SELECT` sobre `usuario` (por ejemplo `admin_datos`) y un `search_path` fijo para evitar *search_path hijacking*:

```sql
ALTER FUNCTION fn_autenticar(text, text) OWNER TO admin_datos;
ALTER FUNCTION fn_autenticar(text, text) SECURITY DEFINER;
ALTER FUNCTION fn_autenticar(text, text) SET search_path = public, pg_temp;
```

> Esto **no** otorga `SELECT` a `app_web`: la funci├│n corre con los privilegios de su due├▒o y solo expone el resultado acotado (`usuario_id, nombre, rol, autenticado`). Es el patr├│n est├índar para funciones de autenticaci├│n.

### 5.2. H-2 (cr├¡tico, confidencialidad): `log_statement = all` registra credenciales en claro
- La sentencia `SELECT * FROM fn_autenticar('admin@foodstore.com', 'password123')` queda **en el log con el email y la contrase├▒a en texto plano**. En el log real (no anonimizado) aparece la contrase├▒a correcta de `vendedor1`.
- **Impacto:** el archivo de log se convierte en un repositorio de credenciales. Cualquiera con lectura del log (incluido un backup mal protegido) obtiene accesos v├ílidos.
- **Remediaci├│n:** no usar `log_statement = 'all'` en producci├│n; migrar a `pgaudit` con `pgaudit.log = 'write,ddl,role'` y sin `pgaudit.log_parameter`; o usar `log_statement = 'mod'` y auditar lecturas con triggers/vistas auditadas. En el TP se mantiene `all` por requisito de evidencia, pero **todo log con datos reales debe anonimizarse antes de versionarse** (por eso existe `sql/anonimizar_log.py`).

### 5.3. H-3 (medio): enumeraci├│n de cuentas posible
- `app_web` puede leer `id, nombre, rol, activo` de todos los usuarios. No es un dato personal sensible, pero facilita la enumeraci├│n de cuentas y la planificaci├│n de ataques a contrase├▒as. Es un trade-off aceptado por el modelo de m├¡nimo privilegio de la Parte A; si no se necesita, conviene restringirlo a una vista sin `nombre`.

### 5.4. H-4 (bajo): la IP de origen es `localhost`
- El simulacro se hizo desde la misma m├íquina; en un incidente real el log aportar├¡a la IP del atacante. El log s├¡ conserva usuario, base, aplicaci├│n y timestamps, suficientes para correlaci├│n.

---

## 6. Decisi├│n de contenci├│n

Con la evidencia del log se decide:

1. **Contener la sesi├│n, no la cuenta:** la evidencia muestra actividad an├│mala (4 intentos de autenticaci├│n + lectura masiva + escalamiento) **desde una sesi├│n leg├¡tima de `app_web`**. La acci├│n inmediata es **rotar la contrase├▒a de `app_web`** y **revisar d├│nde se almacena**, porque el patr├│n sugiere credencial comprometida m├ís que fuerza bruta externa.
2. **No revocar privilegios de tabla de `app_web`:** el intento de escalamiento ya fall├│; revocarlos no agrega seguridad y s├¡ rompe la aplicaci├│n. La contenci├│n correcta es **rotar credenciales** y **revisar el origen** de la sesi├│n.
3. **Corregir `fn_autenticar` (H-1)** antes de cualquier prueba funcional: hoy la aplicaci├│n no puede autenticar. La correcci├│n es `SECURITY DEFINER` con due├▒o `admin_datos` y `search_path` fijo.
4. **Reducir la exposici├│n del log (H-2):** rotar el archivo actual, restringir ACL, y no versionar logs con datos reales; usar el anonimizador para las entregas.
5. **Agregar detecci├│n:** alertar sobre m├ís de N `ERROR: permiso denegado` o `SET ROLE` fallidos por sesi├│n; hoy el log lo registra pero nadie lo mira.

### Prioridad

| Prioridad | Acci├│n | Motivo |
|-----------|--------|--------|
| P0 | Rotar contrase├▒a de `app_web` | Credencial potencialmente comprometida |
| P0 | Corregir `fn_autenticar` a `SECURITY DEFINER` | Autenticaci├│n rota (H-1) |
| P1 | Restringir/anonymizar logs, migrar a `pgaudit` | Credenciales en claro (H-2) |
| P2 | Alertas sobre errores de permiso repetidos | Detecci├│n temprana |
| P3 | Evaluar restringir `SELECT` de `usuario` a una vista | Enumeraci├│n de cuentas (H-3) |

---

## 7. M├®todo de anonimizaci├│n

`sql/anonimizar_log.py` procesa el log de PostgreSQL y aplica:

| Dato | Reemplazo |
|------|-----------|
| Emails (`admin@foodstore.com`, etc.) | `usuario_anon@example.com` |
| Argumentos de `fn_autenticar` / `fn_resetear_password` | `('usuario_anon@example.com', '***')` |
| `CREATE ROLE ... PASSWORD '...'` | `... PASSWORD '***'` |
| `host=::1`, `host=127.0.0.1` | `host=localhost` |
| `port=<n├║mero>` | `port=NNNNN` |

Se conservan: timestamps, roles de base de datos (`app_web`, `admin_datos`), sentencias SQL (sin valores sensibles), mensajes de error y duraci├│n de sesi├│n ÔÇö que es exactamente lo necesario para la reconstrucci├│n forense.

**Limitaci├│n:** la anonimizaci├│n es por patr├│n; si una sentencia incluyera un dato personal en una posici├│n no prevista (por ejemplo, en un `INSERT ... VALUES`), el script no lo detectar├¡a. Por eso el log crudo nunca debe salir del servidor.
