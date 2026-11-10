# Parte A — Verificación del esquema de roles y permisos

**Fecha:** 8 de noviembre de 2026  
**Base de datos:** PostgreSQL 16+ (entorno de desarrollo)  
**Script verificado:** `roles.sql` (ejecutado sobre `setup_food_store_u5.sql`)

---

## 1. Roles creados y atributos

| Rol | Puede login | CREATEROLE | CREATEDB | SUPERUSER |
|-----|-------------|------------|----------|-----------|
| admin_datos | ✅ | ❌ | ❌ | ❌ |
| app_web | ✅ | ❌ | ❌ | ❌ |
| rol_app_escritura | ❌ | ❌ | ❌ | ❌ |
| rol_app_lectura | ❌ | ❌ | ❌ | ❌ |
| rol_reportes | ❌ | ❌ | ❌ | ❌ |
| rol_soporte | ❌ | ❌ | ❌ | ❌ |

**Análisis:** Solo los dos roles de login (`app_web`, `admin_datos`) pueden conectarse. Ninguno tiene privilegios de creación de roles, creación de bases de datos ni superusuario. Se cumple el principio de mínimo privilegio.

---

## 2. Privilegios de tabla por rol (`information_schema.role_table_grants`)

| Rol | Tabla | Privilegios |
|-----|-------|-------------|
| rol_app_escritura | categoria | DELETE, INSERT, SELECT, UPDATE |
| rol_app_escritura | detalle_pedido | DELETE, INSERT, SELECT, UPDATE |
| rol_app_escritura | pedido | DELETE, INSERT, SELECT, UPDATE |
| rol_app_escritura | producto | DELETE, INSERT, SELECT, UPDATE |
| rol_app_lectura | categoria | SELECT |
| rol_app_lectura | deposito | SELECT |
| rol_app_lectura | detalle_pedido | SELECT |
| rol_app_lectura | lote | SELECT |
| rol_app_lectura | pedido | SELECT |
| rol_app_lectura | producto | SELECT |
| rol_reportes | categoria | SELECT |
| rol_reportes | detalle_pedido | SELECT |
| rol_reportes | pedido | SELECT |
| rol_reportes | producto | SELECT |
| rol_soporte | categoria | SELECT |
| rol_soporte | deposito | SELECT |
| rol_soporte | detalle_pedido | SELECT |
| rol_soporte | lote | SELECT |
| rol_soporte | pedido | SELECT |
| rol_soporte | producto | SELECT |
| rol_soporte | usuario | SELECT |

**Análisis:** Cada rol tiene exactamente los privilegios previstos en la especificación de Kiro:
- `rol_app_escritura`: CRUD completo solo sobre tablas operativas (categoria, detalle_pedido, pedido, producto). No toca usuario, deposito ni lote.
- `rol_app_lectura`: solo SELECT sobre catálogo y transacciones.
- `rol_reportes`: solo SELECT sobre tablas de transacciones y catálogo.
- `rol_soporte`: SELECT sobre todas las tablas, incluyendo usuario.

---

## 3. Privilegios a nivel de columna sobre `usuario.email`

| Rol | Columna | Privilegio |
|-----|---------|------------|
| postgres (owner) | email | UPDATE, SELECT, REFERENCES, INSERT |
| rol_soporte | email | SELECT |

**Análisis:** El permiso a nivel de columna funciona correctamente. Solo `rol_soporte` (y el owner `postgres`) tienen acceso a `usuario.email`. Los roles `rol_app_lectura`, `rol_app_escritura` y `rol_reportes` **no** pueden leer el email, protegiendo el dato personal sensible.

---

## 4. Herencia de roles (`pg_auth_members`)

| Rol miembro | Rol padre |
|-------------|-----------|
| admin_datos | rol_app_escritura |
| admin_datos | rol_app_lectura |
| admin_datos | rol_reportes |
| admin_datos | rol_soporte |
| app_web | rol_app_escritura |
| app_web | rol_app_lectura |

**Análisis:** La herencia es correcta:
- `app_web` hereda de lectura y escritura (lo mínimo para la aplicación web).
- `admin_datos` hereda de los cuatro roles de grupo (alcance administrativo completo).

---

## 5. Default privileges (`pg_default_acl`)

| Rol creador | Tipo de objeto | Privilegio por defecto |
|-------------|----------------|------------------------|
| admin_datos | r (tabla) | `rol_app_lectura=r/admin_datos` (SELECT) |
| admin_datos | r (tabla) | `rol_app_escritura=arwd/admin_datos` (INSERT, SELECT, UPDATE, DELETE) |

**Análisis:** Los `ALTER DEFAULT PRIVILEGES` se aplicaron correctamente. La visualización inicial en DBeaver mostraba el array `defaclacl` truncado; al consultar con `unnest(d.defaclacl)` se confirmaron ambas entradas:
- `rol_app_lectura=r/admin_datos` → SELECT
- `rol_app_escritura=arwd/admin_datos` → a=INSERT, r=SELECT, w=UPDATE, d=DELETE

Esto garantiza que las tablas futuras creadas por `admin_datos` en el esquema `public` hereden automáticamente la política de mínimo privilegio.

---

## Conclusión

El esquema de roles y permisos cumple el principio de mínimo privilegio:
- Solo dos roles pueden conectarse (login).
- Ningún rol tiene SUPERUSER, CREATEDB ni CREATEROLE.
- Cada rol de grupo tiene exactamente los privilegios de su función.
- El permiso a nivel de columna sobre `usuario.email` restringe el dato sensible a `rol_soporte`.
- La herencia de roles es correcta.
- Los `ALTER DEFAULT PRIVILEGES` garantizan que las tablas futuras hereden la política (verificado con `unnest`).
