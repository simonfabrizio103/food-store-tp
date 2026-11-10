# Parte C — Informe del simulacro de incidente

**Fecha del simulacro:** 8 de noviembre de 2026, 21:33:31 (-03)  
**Motor:** PostgreSQL 18 — base `postgres` (`localhost:5432`)  
**Archivo de evidencia:** `docs/log_simulacro_anonimizado.txt`  
**Script del simulacro:** `sql/simulacro_incidente.sql`  
**Anonimizador:** `sql/anonimizar_log.py`

---

## 1. Escenario simulado

Se parte de una hipótesis de amenaza: **un atacante ya obtuvo credenciales válidas de `app_web`** (el rol de login de la aplicación) y opera desde la red local. Con esa posición intenta:

1. Adivinar contraseñas de usuarios de la aplicación mediante `fn_autenticar`.
2. Autenticarse con una credencial válida.
3. Leer masivamente la tabla `usuario`.
4. Escalar privilegios (`SET ROLE admin_datos`).
5. Persistir creando un rol propio (`CREATE ROLE`).
6. Otorgarse privilegios adicionales (`GRANT rol_soporte TO app_web`).

El objetivo del laboratorio es **generar evidencia en el log y verificar qué logra y qué no** un actor con ese nivel de acceso.

---

## 2. Evidencia: fragmento del log anonimizado

```text
LOG:  conexión recibida: host=localhost port=NNNNN
LOG:  conexión autenticada: identidad=«app_web» método=scram-sha-256 (pg_hba.conf:117)
LOG:  conexión autorizada: usuario=app_web base_de_datos=postgres nombre_de_aplicación=psql
LOG:  sentencia: SELECT * FROM fn_autenticar('usuario_anon@example.com', '***');
ERROR:  permiso denegado a la tabla usuario
CONTEXTO:  sentencia SQL: «SELECT u.id, u.nombre, u.rol,
           (u.password_hash = md5(p_password)) AS autenticado
    FROM usuario u
    WHERE u.email = p_email AND u.activo = TRUE»
    función PL/pgSQL fn_autenticar(text,text) en la línea 3 en RETURN QUERY
SENTENCIA:  SELECT * FROM fn_autenticar('usuario_anon@example.com', '***');
... (se repite 4 veces: 4 intentos de fn_autenticar, todos con ERROR)
LOG:  sentencia: SELECT id, nombre, rol, activo FROM usuario ORDER BY id;
LOG:  sentencia: SELECT id, email FROM usuario ORDER BY id;
ERROR:  permiso denegado a la tabla usuario
SENTENCIA:  SELECT id, email FROM usuario ORDER BY id;
LOG:  sentencia: SET ROLE admin_datos;
ERROR:  se ha denegado el permiso para definir el rol «admin_datos»
LOG:  sentencia: CREATE ROLE rol_atacante LOGIN PASSWORD '***';
ERROR:  se ha denegado el permiso para crear el rol
DETALLE:  Sólo los roles con el atributo CREATEROLE pueden crear roles.
LOG:  sentencia: GRANT rol_soporte TO app_web;
ERROR:  se ha denegado el permiso para otorgar el rol «rol_soporte»
DETALLE:  Sólo los roles con la opción ADMIN en el rol «rol_soporte» pueden otorgar este rol.
LOG:  desconexión: duración de sesión: 0:00:00.038 usuario=app_web base=postgres host=localhost port=NNNNN
```

El archivo completo (62 líneas, ventana 21:33:31–21:33:32) está en `docs/log_simulacro_anonimizado.txt`.

---

## 3. Reconstrucción de la secuencia

A partir **solo del log** (sin mirar el script) se reconstruye:

| # | Evento | Evidencia |
|---|--------|-----------|
| 1 | Conexión autenticada como `app_web` por `scram-sha-256`, cliente `psql` | `conexión autenticada` / `conexión autorizada` |
| 2 | Cuatro invocaciones a `fn_autenticar` con distintos emails/contraseñas | cuatro `sentencia: SELECT * FROM fn_autenticar(...)` |
| 3 | Las cuatro fallaron, **pero no por credencial inválida**: fallaron por `permiso denegado a la tabla usuario` | `ERROR: permiso denegado a la tabla usuario` + `CONTEXTO ... fn_autenticar` |
| 4 | Lectura masiva de `usuario` limitada a `id, nombre, rol, activo` | `sentencia: SELECT id, nombre, rol, activo FROM usuario` |
| 5 | Intento de leer `email` | `ERROR: permiso denegado a la tabla usuario` |
| 6 | Intento de escalar a `admin_datos` | `ERROR: se ha denegado el permiso para definir el rol` |
| 7 | Intento de crear un rol | `ERROR: ... crear el rol` + `DETALLE: CREATEROLE` |
| 8 | Intento de auto-otorgarse `rol_soporte` | `ERROR: ... otorgar el rol` + `DETALLE: ADMIN option` |
| 9 | Desconexión, sesión de ~38 ms | `desconexión: duración de sesión: 0:00:00.038` |

**Conclusión de la reconstrucción:** el actor tenía una sesión legítima de aplicación y ejecutó una secuencia típica de reconocimiento + escalamiento, pero **todas las acciones sensibles fueron bloqueadas por el modelo de mínimo privilegio**. Lo único que obtuvo fue la lista de usuarios sin datos personales (id, nombre, rol, activo), que igualmente es información útil para un atacante (enumeración de cuentas y roles).

---

## 4. Contraste: qué esperaba la IA vs. qué mostró el log

| Hipótesis de la IA antes de ejecutar | Lo que mostró el log | Veredicto |
|--------------------------------------|----------------------|-----------|
| `fn_autenticar` devolvería `autenticado = false` en los intentos fallidos | La función **ni siquiera se ejecutó**: `permiso denegado a la tabla usuario` | ❌ La hipótesis era incorrecta |
| El login exitoso dejaría rastro claro de “credencial válida” | El único login es el de la sesión de base; no hay evidencia de autenticación de aplicación exitosa | ❌ No se pudo validar por este medio |
| `SET ROLE admin_datos` fallaría | Falló, como se esperaba | ✅ Confirmado |
| `CREATE ROLE` / `GRANT` fallarían | Fallaron, con el motivo exacto en `DETALLE` | ✅ Confirmado |
| `SELECT id, email FROM usuario` fallaría | Falló, como se esperaba | ✅ Confirmado |

El contraste dejó al descubierto un **defecto funcional real** que la IA no había previsto: `fn_autenticar` es `SECURITY INVOKER`, por lo que se ejecuta con los privilegios de `app_web`, y `app_web` no tiene `SELECT` sobre `usuario` (se le negó a propósito, incluido `email`). Resultado: **la aplicación no puede autenticar a ningún usuario**. El mínimo privilegio se aplicó correctamente sobre las tablas, pero se olvidó el camino de la función de autenticación.

---

## 5. Hallazgos

### 5.1. H-1 (crítico, funcional): `fn_autenticar` no es ejecutable por `app_web`
- **Síntoma:** `ERROR: permiso denegado a la tabla usuario` dentro de `fn_autenticar`.
- **Causa:** la función es `SECURITY INVOKER` (default) y `app_web` no tiene `SELECT` sobre `usuario` (ni sobre `email`/`password_hash`).
- **Impacto:** la autenticación de la aplicación queda completamente rota. Es una falla de disponibilidad, no de seguridad: el mínimo privilegio “funciona” pero inutiliza el negocio.
- **Remediación aplicada y verificada:**
Se configuró la función como `SECURITY DEFINER`, con dueño `admin_datos` y `search_path` fijo para mitigar vulnerabilidades de inyección o búsqueda de esquemas (*search_path hijacking*):

```sql
ALTER FUNCTION fn_autenticar(text, text) OWNER TO admin_datos;
ALTER FUNCTION fn_autenticar(text, text) SECURITY DEFINER;
ALTER FUNCTION fn_autenticar(text, text) SET search_path = public, pg_temp;
```

> Esto **no** otorga `SELECT` sobre `usuario` a `app_web`: la función corre con los privilegios de su dueño (`admin_datos`, quien tiene los permisos necesarios vía `rol_soporte`) y solo expone el resultado estricto (`usuario_id, nombre, rol, autenticado`).

**Pruebas de verificación ejecutadas post-remediación con el rol `app_web`:**
1. Credencial válida:
   `SELECT * FROM fn_autenticar('vendedor1@foodstore.com', 'password123');`
   → Devuelve `(2, 'Juan Pérez', 'vendedor', true)`. **Autenticación funcional restablecida.**
2. Credencial inválida:
   `SELECT * FROM fn_autenticar('vendedor1@foodstore.com', 'wrongpassword');`
   → Devuelve `(2, 'Juan Pérez', 'vendedor', false)`. **Rechazo controlado sin error de permisos.**
3. Usuario inactivo:
   `SELECT * FROM fn_autenticar('inactivo@foodstore.com', 'password123');`
   → Devuelve 0 filas. **Control de negocio preservado.**
4. Intento de acceso directo a datos sensibles:
   `SELECT id, email FROM usuario;`
   → `ERROR: permiso denegado a la tabla usuario`. **Principio de mínimo privilegio intacto.**

### 5.2. H-2 (crítico, confidencialidad): `log_statement = all` registra credenciales en claro
- La sentencia `SELECT * FROM fn_autenticar('admin@foodstore.com', 'password123')` queda **en el log con el email y la contraseña en texto plano**. En el log real (no anonimizado) aparece la contraseña correcta de `vendedor1`.
- **Impacto:** el archivo de log se convierte en un repositorio de credenciales. Cualquiera con lectura del log (incluido un backup mal protegido) obtiene accesos válidos.
- **Remediación:** no usar `log_statement = 'all'` en producción; migrar a `pgaudit` con `pgaudit.log = 'write,ddl,role'` y sin `pgaudit.log_parameter`; o usar `log_statement = 'mod'` y auditar lecturas con triggers/vistas auditadas. En el TP se mantiene `all` por requisito de evidencia, pero **todo log con datos reales debe anonimizarse antes de versionarse** (por eso existe `sql/anonimizar_log.py`).

### 5.3. H-3 (medio): enumeración de cuentas posible
- `app_web` puede leer `id, nombre, rol, activo` de todos los usuarios. No es un dato personal sensible, pero facilita la enumeración de cuentas y la planificación de ataques a contraseñas. Es un trade-off aceptado por el modelo de mínimo privilegio de la Parte A; si no se necesita, conviene restringirlo a una vista sin `nombre`.

### 5.4. H-4 (bajo): la IP de origen es `localhost`
- El simulacro se hizo desde la misma máquina; en un incidente real el log aportaría la IP del atacante. El log sí conserva usuario, base, aplicación y timestamps, suficientes para correlación.

---

## 6. Decisión de contención

Con la evidencia del log se decide:

1. **Contener la sesión, no la cuenta:** la evidencia muestra actividad anómala (4 intentos de autenticación + lectura masiva + escalamiento) **desde una sesión legítima de `app_web`**. La acción inmediata es **rotar la contraseña de `app_web`** y **revisar dónde se almacena**, porque el patrón sugiere credencial comprometida más que fuerza bruta externa.
2. **No revocar privilegios de tabla de `app_web`:** el intento de escalamiento ya falló; revocarlos no agrega seguridad y sí rompe la aplicación. La contención correcta es **rotar credenciales** y **revisar el origen** de la sesión.
3. **Corregir `fn_autenticar` (H-1)** antes de cualquier prueba funcional: hoy la aplicación no puede autenticar. La corrección es `SECURITY DEFINER` con dueño `admin_datos` y `search_path` fijo.
4. **Reducir la exposición del log (H-2):** rotar el archivo actual, restringir ACL, y no versionar logs con datos reales; usar el anonimizador para las entregas.
5. **Agregar detección:** alertar sobre más de N `ERROR: permiso denegado` o `SET ROLE` fallidos por sesión; hoy el log lo registra pero nadie lo mira.

### Prioridad y estado de acciones

| Prioridad | Acción | Motivo | Estado |
|-----------|--------|--------|--------|
| P0 | Rotar contraseña de `app_web` | Credencial potencialmente comprometida | Decisión documental |
| P0 | Corregir `fn_autenticar` a `SECURITY DEFINER` | Autenticación rota (H-1) | ✅ **Aplicado y verificado en BD** |
| P1 | Restringir/anonimizar logs, migrar a `pgaudit` | Credenciales en claro (H-2) | Mitigado con script de anonimización |
| P2 | Alertas sobre errores de permiso repetidos | Detección temprana | Recomendación de arquitectura |
| P3 | Evaluar restringir `SELECT` de `usuario` a una vista | Enumeración de cuentas (H-3) | Trade-off asumido |

---

## 7. Método de anonimización

`sql/anonimizar_log.py` procesa el log de PostgreSQL y aplica:

| Dato | Reemplazo |
|------|-----------|
| Emails (`admin@foodstore.com`, etc.) | `usuario_anon@example.com` |
| Argumentos de `fn_autenticar` / `fn_resetear_password` | `('usuario_anon@example.com', '***')` |
| `CREATE ROLE ... PASSWORD '...'` | `... PASSWORD '***'` |
| `host=::1`, `host=127.0.0.1` | `host=localhost` |
| `port=<número>` | `port=NNNNN` |

Se conservan: timestamps, roles de base de datos (`app_web`, `admin_datos`), sentencias SQL (sin valores sensibles), mensajes de error y duración de sesión — que es exactamente lo necesario para la reconstrucción forense.

**Limitación:** la anonimización es por patrón; si una sentencia incluyera un dato personal en una posición no prevista (por ejemplo, en un `INSERT ... VALUES`), el script no lo detectaría. Por eso el log crudo nunca debe salir del servidor.
