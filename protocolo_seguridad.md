# Protocolo de Seguridad - Food Store
Alumno: Fabri - Motor: PostgreSQL 17 + DBeaver 26.2.0 - Windows 11

## 1. COPIA
Nunca trabajo sobre food_store_dev. Todo lo de IA se prueba en food_store_copia.
Como crearla: Conectado a base `postgres` ejecuto `CREATE DATABASE food_store_copia WITH TEMPLATE food_store_dev;`
Si da error "is being accessed by other users": ejecuto `SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='food_store_dev';` y reintento. Cierro todos los editores de food_store_dev antes.

## 2. TRANSACCIÓN
En DBeaver pongo el botón `Auto` en `Manual` (arriba). Todo script que escribe va así:
BEGIN;
-- pego el script de la IA
-- hago SELECT para ver filas afectadas
ROLLBACK; -- primero inspecciono
Si está bien, repito y cierro con COMMIT;

## 3. RESPALDO
Antes de cualquier ALTER o DROP: Click derecho sobre `food_store_copia` > Herramientas > Backup > Guardar en `C:\Users\Fabri\OneDrive\Documentos\Default Project\backups\backup_YYYYMMDD.dump`