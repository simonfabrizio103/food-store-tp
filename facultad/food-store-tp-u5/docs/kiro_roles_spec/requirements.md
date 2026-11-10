# Kiro — Especificación de Roles y Permisos (Requirements)

## Contexto
Food Store necesita un esquema de permisos de mínimo privilegio sobre su base de datos de desarrollo. Cada rol debe tener exactamente los privilegios que necesita para su función, ni más ni menos.

## Roles requeridos

### Roles de grupo (no pueden hacer login directamente)
1. **rol_app_lectura** — Solo lectura sobre tablas de catálogo y transacciones. Habilita consultas de reportes y dashboards. No puede modificar datos.
2. **rol_app_escritura** — Lectura y escritura sobre tablas operativas (pedidos, detalles, productos, categorías). Habilita el flujo normal de ventas. No puede borrar usuarios ni modificar la estructura.
3. **rol_soporte** — Lectura sobre todas las tablas + escritura limitada en tablas de auditoría y logs. Puede consultar historial pero no alterar datos maestros.
4. **rol_reportes** — Solo lectura sobre tablas de transacciones y catálogo. Puede crear vistas temporales en su propio esquema. No puede modificar nada.

### Roles de login (pueden conectarse)
5. **app_web** — Login de la aplicación web frontend. Hereda privilegios de rol_app_lectura y rol_app_escritura.
6. **admin_datos** — Login de administración. Hereda todos los privilegios de los roles de grupo. Puede gestionar usuarios y roles dentro de su alcance.

## Justificación por rol (una oración cada uno)
- **rol_app_lectura**: permite consultar datos de catálogo y transacciones para reportes, sin riesgo de modificación accidental.
- **rol_app_escritura**: habilita el flujo operativo de ventas (insertar pedidos y detalles) pero restringe borrado y cambios estructurales.
- **rol_soporte**: da visibilidad de lectura global para diagnóstico, con escritura restringida a tablas de auditoría propias.
- **rol_reportes**: habilita creación de vistas analíticas temporales sin comprometer integridad de datos fuente.
- **app_web**: identidad de conexión de la frontend, con privilegios limitados a lectura y escritura operativa.
- **admin_datos**: identidad administrativa con alcance completo sobre el esquema de la aplicación.
