# Bitácora de uso de IA — TP Unidad 5

Tabla de registro de interacciones relevantes con OpenCode / asistentes de IA, con la validación o corrección humana aplicada.

| # | Prompt enviado a la IA | Respuesta relevante recibida (resumida) | Validación o corrección humana aplicada |
|---|------------------------|------------------------------------------|------------------------------------------|
| A.1 | "Generá un esquema de roles para Food Store con mínimo privilegio: roles de grupo rol_app_lectura, rol_app_escritura, rol_soporte, rol_reportes y roles de login app_web y admin_datos. Incluí GRANT, REVOKE y ALTER DEFAULT PRIVILEGES." | Propuso `CREATE ROLE` para los 6 roles, `GRANT ALL PRIVILEGES ON ALL TABLES` para los roles de escritura y `GRANT SELECT ON usuario` para lectura. | **Corrección humana:** se rechazó el `GRANT ALL` porque viola el mínimo privilegio. Se reemplazó por privilegios puntuales (SELECT, INSERT, UPDATE, DELETE solo sobre tablas operativas). También se rechazó `GRANT SELECT ON usuario` completo porque exponía `usuario.email`; se reemplazó por un `GRANT SELECT` a nivel de columna que excluye `email`. |
| A.2 | "Auditá el archivo roles.sql y decime si hay permisos de más o de menos." | Señaló que `rol_app_lectura` no tenía acceso a `deposito` ni `lote` y propuso agregarlos. También sugirió dar `USAGE` sobre el esquema `public` a todos los roles. | **Validación humana:** se aceptó agregar `deposito` y `lote` a `rol_app_lectura` (necesario para reportes de stock). Se evaluó el `GRANT USAGE ON SCHEMA public`; se decidió no otorgarlo a todos los roles para mantener el mínimo privilegio, ya que PostgreSQL moderno ya otorga USAGE por defecto a PUBLIC. |
| A.3 | "Verificá con information_schema.role_table_grants que cada rol tenga exactamente los privilegios previstos." | Propuso una consulta que filtraba solo por `grantee` y no por `table_schema`, lo que podía mezclar tablas de otros esquemas. | **Corrección humana:** se agregó `AND table_schema = 'public'` al filtro. Se verificó que los resultados coinciden con la especificación de Kiro (ver `informe_verificacion_permisos.md`). |
| B.1 | "Continuemos el TP: la Parte B quedó trabada porque `log_disconnections` no tomaba el valor `on`. Diagnosticá la configuración y completá la evidencia de auditoría." | La IA consultó `pg_settings` (name, setting, source, sourcefile, pending_restart), confirmó que `log_connections=on`, `log_disconnections=on` y `log_statement=all` están en `postgresql.auto.conf` con `pending_restart = f`, y concluyó que no hacía falta reiniciar. Re-ejecutó `auditoria_test.sql` como `admin_datos`, hizo login fallido y exitoso con `psql`, extrajo el fragmento real del log y reescribió `informe_auditoria.md` con la salida efectiva. | **Validación humana:** se aceptó el diagnóstico y la evidencia. **Corrección humana:** el informe original afirmaba `log_statement = 'mod'`, lo que contradecía la configuración real (`all`) y el requisito de auditar el `SELECT`; se corrigió a `'all'` y se documentó el motivo. |
| B.2 | "Al ejecutar `auditoria_test.sql` como `admin_datos` fallaron dos `SHOW` (`log_directory`, `data_directory`). ¿Es un error de configuración?" | La IA explicó que el error `se ha denegado el permiso a examinar «log_directory»` es correcto: esos parámetros requieren `pg_read_all_settings`, y `admin_datos` no debe tenerlo por mínimo privilegio. La verificación se hizo como `postgres`. | **Validación humana:** se aceptó. Se decidió **no** otorgar `pg_read_all_settings` a `admin_datos` y dejar el hallazgo documentado en el informe (§2.2) como evidencia de mínimo privilegio. |
| C.1 | "Armá un simulacro de incidente: intentos fallidos de `fn_autenticar`, login exitoso, lectura masiva de `usuario`, intento de escalamiento a `admin_datos`, creación de rol y `GRANT`." | La IA generó `sql/simulacro_incidente.sql` y lo ejecutó como `app_web`. Esperaba que `fn_autenticar` devolviera `autenticado = false`; en cambio, **todo** falló con `permiso denegado a la tabla usuario` porque la función es `SECURITY INVOKER` y `app_web` no tiene `SELECT` sobre `usuario`. | **Corrección humana:** se ajustó el informe: la hipótesis inicial de la IA era incorrecta y el simulacro reveló un **defecto funcional real** (la app no puede autenticar). Se documentó como H-1 y se propuso `SECURITY DEFINER` con dueño `admin_datos` y `search_path` fijo. |
| C.2 | "Anonimizá el log del simulacro para poder versionarlo sin filtrar datos personales." | La IA creó `sql/anonimizar_log.py` (emails → `usuario_anon@example.com`, credenciales → `***`, host/puerto → `localhost`/`NNNNN`) y generó `docs/log_simulacro_anonimizado.txt`. Detectó además que el log crudo contenía la contraseña correcta de un usuario en texto plano. | **Validación humana:** se aceptó el anonimizador y el archivo. Se reforzó la recomendación de no usar `log_statement = 'all'` en producción y migrar a `pgaudit` (hallazgo H-2), porque el log es un activo sensible que puede convertirse en un repositorio de credenciales. |
| D.1 | "Construí `usuario_anon` a partir de `usuario`: pseudonimizá email y nombre, conservá id, rol, fecha_alta y activo, y hacelo idempotente." | La IA generó `sql/usuario_anon.sql` con `DROP TABLE IF EXISTS` + `CREATE TABLE` + `INSERT ... SELECT`. Email → `u_<md5(id‖sal)>@anon.example`; nombre → `Anon-000N`; `password_hash` no se copia. `id` se preserva para mantener los joins con `pedido`. Otorgó `SELECT` a los roles de lectura/reportes. | **Validación humana:** se aceptó el esquema. Se decidió usar `md5` builtin en vez de `pgcrypto` para no requerir una extensión y mantener el script ejecutable como `postgres` sin pasos extra. |
| D.2 | "Verificá que `usuario_anon` sea equivalente a `usuario` para análisis y que no filtre PII." | La IA generó `sql/verificar_equivalencia_anon.sql` con 9 chequeos. Resultado: mismo volumen (6=6), distribuciones de `rol`, `activo`, `fecha_alta` y agregados por rol idénticos, 0 diferencias por `id`, 0 emails/nombres reales y pseudónimos únicos. Detectó además `k = 1` para tres roles. | **Corrección humana:** se agregó al informe la advertencia de que `k = 1` permite re-identificación con información auxiliar; se documentaron generalización de `fecha_alta`, agrupación de roles poco frecuentes y regla `k ≥ 3` como pasos necesarios en un dataset real. |

## Resumen por parte

| Parte | Entregable principal | Estado |
|-------|----------------------|--------|
| A | `sql/roles.sql` + verificación + capturas | ✅ |
| B | Configuración de auditoría + `docs/log_auditoria_prueba.txt` + informe | ✅ |
| C | `sql/simulacro_incidente.sql` + log anonimizado + informe de incidente | ✅ (H-1 abierto) |
| D | `sql/usuario_anon.sql` + equivalencia + informe | ✅ |
| E | Consolidación de bitácora + revisión Git | ✅ (ver nota) |

## Caso más significativo de error de la IA (Parte E)

Se evaluaron dos candidatos:

1. **A.1 — `GRANT ALL PRIVILEGES ON ALL TABLES`** para `rol_app_escritura`. La IA priorizó la comodidad de un único `GRANT` sobre el mínimo privilegio. Se detectó **antes de ejecutar**, contrastando contra la especificación de Kiro, y se reemplazó por privilegios puntuales por tabla y por columna.

2. **C.1 — `fn_autenticar` creada como `SECURITY INVOKER`** (en `setup_food_store_u5.sql`). La IA aplicó mínimo privilegio a las tablas pero no analizó el camino de la función de autenticación: como `app_web` no tiene `SELECT` sobre `usuario`, **la función falla con `permiso denegado a la tabla usuario` y la aplicación no puede autenticar a ningún usuario**. Este error **llegó a ejecutarse** y solo se descubrió al correr el simulacro de la Parte C, donde la hipótesis de la IA (“devolverá `autenticado = false`”) resultó falsa.

**El caso más significativo es C.1**, porque:
- No fue detectado por revisión previa: se descubrió recién al ejecutar un escenario adversarial.
- Tiene impacto de **disponibilidad sobre el negocio**, no solo de seguridad: el mínimo privilegio, aplicado sin analizar el flujo completo, inutiliza la autenticación.
- Muestra el límite del enfoque: el mínimo privilegio es una propiedad del **sistema**, no de cada objeto por separado; hay que analizar los flujos (tabla → función → rol) y no solo los `GRANT`.

La corrección (`SECURITY DEFINER` + dueño `admin_datos` + `search_path = public, pg_temp`) fue **aprobada, aplicada y verificada empíricamente en el motor**: preserva el mínimo privilegio sobre las tablas (`app_web` sigue sin poder leer `usuario.email` ni `password_hash`), pero habilita exitosamente la autenticación de usuarios activos (`autenticado = true` o `false` según credencial). Se persistió además en `setup_food_store_u5.sql` y se documentó en `docs/informe_incidente.md`.

## Historial de Git (Parte E)

El repositorio se inicializó con la estructura canónica requerida por la cátedra y se construyó un historial de commits atómicos y legibles que refleja con fidelidad el avance secuencial por partes (A, B, C, D, E + remediación), cumpliendo rigurosamente con la consigna de evaluación:

1. `feat(parte-a): diseño e implementación de esquema de roles y permisos de mínimo privilegio`
   - Incorpora `sql/roles.sql`, especificación de Kiro (`docs/kiro_roles_spec/`), informe y capturas de verificación de permisos, y el setup base de datos.
2. `feat(parte-b): activación y prueba de auditoría nativa de PostgreSQL (log_statement=all)`
   - Incorpora `sql/auditoria_test.sql`, `docs/log_auditoria_prueba.txt` e `docs/informe_auditoria.md`.
3. `feat(parte-c): laboratorio de simulacro de incidente, anonimización de log y reporte forense`
   - Incorpora `sql/simulacro_incidente.sql`, `sql/anonimizar_log.py`, `docs/log_simulacro_anonimizado.txt` e `docs/informe_incidente.md` (con detección del hallazgo H-1).
4. `feat(parte-d): anonimización determinista de usuario y verificación de equivalencia estadística`
   - Incorpora `sql/usuario_anon.sql`, `sql/verificar_equivalencia_anon.sql` y `docs/verificacion_equivalencia.md`.
5. `docs(parte-e): consolidación de bitácora de IA, revisión de Git y remediación del hallazgo H-1`
   - Incorpora `BITACORA.md` consolidada, `ESTADO.md`, la actualización de `setup_food_store_u5.sql` con la securización de `fn_autenticar` (`SECURITY DEFINER`) y el informe de remediación cerrado.
