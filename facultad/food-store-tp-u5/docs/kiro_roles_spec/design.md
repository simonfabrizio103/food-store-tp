# Kiro — Especificación de Roles y Permisos (Design)

## Modelo de herencia
Cada rol de login hereda de los roles de grupo mediante `GRANT rol_grupo TO rol_login`. Esto evita duplicar privilegios.

## Esquema de privilegios por rol

| Rol | Tablas | Columnas | Privilegios |
|-----|--------|----------|-------------|
| rol_app_lectura | pedido, detalle_pedido, producto, categoria, usuario, deposito, lote | Todas | SELECT |
| rol_app_escritura | pedido, detalle_pedido, producto, categoria | Todas | INSERT, UPDATE, DELETE |
| rol_soporte | Todas las tablas del esquema público | Todas | SELECT; INSERT, UPDATE solo en tabla de auditoría propia |
| rol_reportes | pedido, detalle_pedido, producto, categoria | Todas | SELECT; CREATE en esquema propio `reportes_tmp` |
| app_web (login) | Hereda de rol_app_lectura + rol_app_escritura | — | — |
| admin_datos (login) | Hereda de todos los roles de grupo | — | Puede gestionar membresías y roles |

## Permiso a nivel de columna
La tabla `usuario` tiene una columna sensible `email` (datos personales). Solo `rol_soporte` y `admin_datos` pueden leer `usuario.email`. `rol_app_lectura`, `rol_app_escritura` y `rol_reportes` **no** tienen SELECT sobre `usuario.email`.

## ALTER DEFAULT PRIVILEGES
Se ejecutará como `admin_datos` para que las tablas futuras creadas por ese rol hereden automáticamente los mismos privilegios de SELECT para `rol_app_lectura` y `rol_app_escritura`.

## Revisión de seguridad
Ningún rol tiene `GRANT ALL` ni `SUPERUSER`. El principio de mínimo privilegio se cumple porque cada privilegio está justificado por una operación concreta del negocio.
