# Parte B — Informe de configuración de auditoría

**Fecha:** 8 de noviembre de 2026  
**Motor:** PostgreSQL 18  
**Entorno:** desarrollo local (`localhost:5432`, base `postgres`)  
**Configuración efectiva verificada con:** `pg_settings` (ver §1.2)

---

## 1. Parámetros de auditoría modificados

Se activaron los siguientes parámetros mediante `ALTER SYSTEM` + `pg_reload_conf()`. Los cambios quedaron persistidos en `C:/Program Files/PostgreSQL/18/data/postgresql.auto.conf`.

| Parámetro | Valor anterior | Valor nuevo | Propósito |
|-----------|----------------|-------------|-----------|
| `log_connections` | `off` | `on` | Registra cada intento de conexión (exitoso o fallido), con usuario, base de datos y origen. |
| `log_disconnections` | `off` | `on` | Registra la desconexión de cada sesión y su duración. |
| `log_statement` | `none` | `all` | Registra **todas** las sentencias, incluidas las lecturas (`SELECT`), necesarias para reconstruir la actividad de la sesión. |

**Sentencias ejecutadas:**

```sql
ALTER SYSTEM SET log_connections = 'on';
ALTER SYSTEM SET log_disconnections = 'on';
ALTER SYSTEM SET log_statement = 'all';
SELECT pg_reload_conf();
```

> Se usó `log_statement = 'all'` (y no `'mod'`) porque el TP exige evidenciar también las **lecturas**, en particular el `SELECT` sobre `usuario`. El costo es un log más voluminoso y con posible exposición de datos en las sentencias; por eso el archivo de log se trata como activo sensible (§4).

### 1.2. Verificación de la configuración efectiva

```sql
SELECT name, setting, source, sourcefile, sourceline, pending_restart
FROM pg_settings
WHERE name IN ('log_connections','log_disconnections','log_statement',
               'log_directory','logging_collector','data_directory')
ORDER BY name;
```

Resultado (8/11/2026 21:32):

| name | setting | source | sourcefile | pending_restart |
|------|---------|--------|------------|-----------------|
| `log_connections` | `on` | configuration file | `.../data/postgresql.auto.conf` | `f` |
| `log_disconnections` | `on` | configuration file | `.../data/postgresql.auto.conf` | `f` |
| `log_statement` | `all` | configuration file | `.../data/postgresql.auto.conf` | `f` |
| `logging_collector` | `on` | configuration file | `.../data/postgresql.conf` | `f` |
| `log_directory` | `log` | default | — | `f` |
| `data_directory` | `C:/Program Files/PostgreSQL/18/data` | override | — | `f` |

Los tres parámetros de auditoría toman el valor **sin reinicio** (`pending_restart = f`) porque son de tipo `SIGHUP` y se aplican con `pg_reload_conf()`.

---

## 2. Secuencia de operaciones de prueba

Se ejecutó `sql/auditoria_test.sql` conectado como `admin_datos`, seguido de dos intentos de conexión real con `psql`:

1. **Lectura:** `SELECT id, nombre, rol FROM usuario WHERE activo = TRUE ORDER BY id LIMIT 3;` — devuelve 3 filas.
2. **Inserción:** `INSERT INTO pedido (id, fecha, usuario_id, eliminado) VALUES (9999, CURRENT_DATE, 2, FALSE);` — `INSERT 0 1`.
3. **Actualización:** `UPDATE pedido SET eliminado = TRUE WHERE id = 9999;` — `UPDATE 1`.
4. **Login fallido (función):** `SELECT * FROM fn_autenticar('admin@foodstore.com', 'password_incorrecta');` — devuelve `autenticado = f`. Queda registrado como **sentencia**, no como `FATAL` de conexión, porque la sesión ya estaba abierta.
5. **Login fallido (conexión real):** `psql -U app_web` con contraseña incorrecta → `FATAL: la autentificación password falló para el usuario «app_web»`, con el `DETALLE` que indica la línea de `pg_hba.conf` aplicada.
6. **Login exitoso (conexión real):** `psql -U app_web` con la contraseña correcta → `conexión autorizada: usuario=app_web ... nombre_de_aplicación=psql`.
7. **Limpieza:** `DELETE FROM pedido WHERE id = 9999;` — `DELETE 1`.

### 2.1. Fragmento real del log

Extracto de `docs/log_auditoria_prueba.txt` (ventana 21:32:13–21:32:16, archivo `postgresql-2026-11-08_150912.log`):

```text
LOG:  conexión recibida: host=::1 port=57238
LOG:  conexión autenticada: identidad=«admin_datos» método=scram-sha-256 (pg_hba.conf:117)
LOG:  conexión autorizada: usuario=admin_datos base_de_datos=postgres nombre_de_aplicación=psql
LOG:  sentencia: SHOW log_connections;
LOG:  sentencia: SHOW log_disconnections;
LOG:  sentencia: SHOW log_statement;
LOG:  sentencia: SHOW log_directory;
ERROR:  se ha denegado el permiso a examinar «log_directory»
LOG:  sentencia: SELECT id, nombre, rol
        FROM usuario
        WHERE activo = TRUE
        ORDER BY id
        LIMIT 3;
LOG:  sentencia: INSERT INTO pedido (id, fecha, usuario_id, eliminado)
        VALUES (9999, CURRENT_DATE, 2, FALSE);
LOG:  sentencia: UPDATE pedido
        SET eliminado = TRUE
        WHERE id = 9999;
LOG:  sentencia: SELECT * FROM fn_autenticar('admin@foodstore.com', 'password_incorrecta');
LOG:  sentencia: DELETE FROM pedido WHERE id = 9999;
LOG:  desconexión: duración de sesión: 0:00:00.033 usuario=admin_datos base=postgres host=::1 port=57238
LOG:  conexión recibida: host=::1 port=57246
FATAL:  la autentificación password falló para el usuario «app_web»
DETALLE:  La conexión coincidió con el archivo «pg_hba.conf» línea 117: «host all all ::1/128 scram-sha-256»
LOG:  conexión recibida: host=::1 port=55525
LOG:  conexión autenticada: identidad=«app_web» método=scram-sha-256 (pg_hba.conf:117)
LOG:  conexión autorizada: usuario=app_web base_de_datos=postgres nombre_de_aplicación=psql
LOG:  sentencia: SELECT current_user, now();
LOG:  desconexión: duración de sesión: 0:00:00.025 usuario=app_web base=postgres host=::1 port=55525
```

El fragmento completo y sin recortar está en `docs/log_auditoria_prueba.txt`.

### 2.2. Hallazgo colateral: `SHOW log_directory` denegado a `admin_datos`

Al ejecutar `auditoria_test.sql` como `admin_datos` (un rol con LOGIN pero **sin** privilegios de superusuario), las dos últimas sentencias `SHOW` fallaron:

```text
ERROR:  se ha denegado el permiso a examinar «log_directory»
DETALLE:  Sólo roles con privilegios del rol «pg_read_all_settings» pueden examinar este parámetro.
```

Es el comportamiento correcto de mínimo privilegio: `admin_datos` no debe ver rutas internas del servidor. La verificación de la configuración se hizo entonces como `postgres`. Si se quisiera que un rol de auditoría consulte esos parámetros, se le otorgaría `pg_read_all_settings` de forma explícita y justificada, no de forma general.

---

## 3. Qué información del log es útil a fines de auditoría

Con `log_statement = 'all'` el fragmento permite reconstruir, para cada evento:

- **Quién:** el usuario de base de datos (`admin_datos`, `app_web`, `postgres`) y el nombre de aplicación declarado en la conexión (`psql`, `DBeaver`, etc.).
- **Qué:** la sentencia completa ejecutada, incluidas las lecturas (`SELECT`).
- **Cuándo:** el timestamp con zona horaria de cada línea.
- **Desde dónde:** la dirección IP y el puerto de origen en las conexiones (`log_connections`).
- **Cuánto duró / cuándo terminó:** la línea de desconexión con la duración de la sesión (`log_disconnections`).
- **Por qué falló una conexión:** el `FATAL` con el motivo y la regla de `pg_hba.conf` que se aplicó.

**Qué quedaría fuera del alcance de este mecanismo nativo:**

- **Detalle fila por fila:** `log_statement` registra la sentencia, pero no los valores de cada fila afectada. Para eso se necesita `pgaudit` (extensión) o triggers de auditoría propios.
- **Parámetros de bind de consultas preparadas:** el log puede mostrar la sentencia con placeholders (`$1`, `$2`) sin los valores reales.
- **Contexto de aplicación:** el log no sabe qué usuario de la aplicación web (no de la base) ejecutó la operación, salvo que se propague en `application_name` o en una variable de sesión.
- **Integridad del log:** sin firma ni envío a un servidor remoto, un atacante con acceso al sistema operativo podría alterar el archivo. Para auditoría forense se recomienda `syslog`/`log_destination` remoto o WAL de auditoría.
- **Retención:** PostgreSQL no rota ni purga por sí mismo; la retención depende de herramientas externas (logrotate, políticas de Windows).

---

## 4. ¿El archivo de log es un activo sensible?

**Sí.** El archivo de log es un activo sensible porque contiene información sobre la estructura de la base, los usuarios, las sentencias ejecutadas y, potencialmente, datos personales embebidos en consultas. Con `log_statement = 'all'` el riesgo es mayor: por ejemplo, el fragmento de prueba contiene literalmente `fn_autenticar('admin@foodstore.com', 'password_incorrecta')`, es decir, un email y una credencial (aunque incorrecta) en texto plano. Un `INSERT` o `UPDATE` con email, teléfono o password quedaría registrado con sus valores. Un atacante con acceso al log podría inferir esquemas, identificar usuarios privilegiados, reconstruir parte de la actividad y cosechar datos personales.

**Quién debería poder leerlo:** solo el administrador de la base de datos (DBA) y el equipo de seguridad. El archivo debe estar protegido a nivel de sistema operativo con permisos restringidos (en Windows, ACL que excluya a usuarios no administradores; en Linux, `chmod 600` y propietario `postgres`). A nivel del motor, el acceso al directorio de logs debe limitarse al usuario `postgres` y a los administradores del servidor. Nunca debe quedar en una carpeta compartida, en un repositorio Git ni accesible desde la aplicación web.

**Medidas adicionales recomendadas:**

1. No versionar archivos de log en Git; versionar solo **fragmentos anonimizados** (como el de la Parte C).
2. Rotar y retener el log con una política definida (por ejemplo, 30 días) y cifrar los backups.
3. Evaluar `pgaudit` para auditoría selectiva y con menos exposición de datos que `log_statement = all`.
4. Restringir `log_min_duration_statement` / `log_statement` en producción según el riesgo aceptado.
