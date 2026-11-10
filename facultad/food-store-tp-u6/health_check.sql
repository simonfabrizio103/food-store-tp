-- ============================================================================
-- TRABAJO PRÁCTICO — UNIDAD 6: MANTENIMIENTO, RESPALDO Y RECUPERACIÓN
-- Archivo: health_check.sql
-- Motor: PostgreSQL 16+
-- Base de datos objetivo: foodstore
-- ============================================================================

\echo '====================================================================='
\echo '1. TAMAÑO TOTAL DE LA BASE DE DATOS'
\echo '====================================================================='
SELECT 
    datname AS base_de_datos,
    pg_size_pretty(pg_database_size('foodstore')) AS tamano_total
FROM pg_database
WHERE datname = 'foodstore';

\echo '====================================================================='
\echo '2. ACTIVIDAD DE CONEXIONES Y ESTADÍSTICAS TRANSACCIONALES'
\echo '====================================================================='
SELECT 
    datname AS base_de_datos,
    numbackends AS conexiones_activas,
    xact_commit AS transacciones_confirmadas,
    xact_rollback AS transacciones_abortadas,
    CASE 
        WHEN (xact_commit + xact_rollback) > 0 
        THEN ROUND((xact_commit::numeric / (xact_commit + xact_rollback)::numeric) * 100, 2)
        ELSE 100.00 
    END AS porcentaje_exito_transacciones
FROM pg_stat_database
WHERE datname = 'foodstore';

\echo '====================================================================='
\echo '3. ESTADO DE TABLAS: TUPLAS VIVAS, TUPLAS MUERTAS Y AUTONOMÍA'
\echo '====================================================================='
SELECT 
    relname AS tabla,
    n_live_tup AS tuplas_vivas,
    n_dead_tup AS tuplas_muertas,
    CASE 
        WHEN (n_live_tup + n_dead_tup) > 0 
        THEN ROUND((n_dead_tup::numeric / (n_live_tup + n_dead_tup)::numeric) * 100, 2)
        ELSE 0 
    END AS porcentaje_muertas,
    COALESCE(last_autovacuum::text, 'Nunca') AS ultimo_autovacuum,
    COALESCE(last_autoanalyze::text, 'Nunca') AS ultimo_autoanalyze
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC, n_live_tup DESC;

\echo '====================================================================='
\echo '4. SESIONES Y CONSULTAS EN EJECUCIÓN (NO IDLE)'
\echo '====================================================================='
SELECT 
    pid,
    usename AS usuario,
    client_addr AS direccion_ip,
    state AS estado,
    now() - query_start AS duracion,
    query AS consulta_activa
FROM pg_stat_activity
WHERE datname = 'foodstore' 
  AND state <> 'idle'
  AND pid <> pg_backend_pid()
ORDER BY query_start ASC;
