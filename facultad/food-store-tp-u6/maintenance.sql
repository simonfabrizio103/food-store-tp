-- ============================================================================
-- TRABAJO PRÁCTICO — UNIDAD 6: MANTENIMIENTO, RESPALDO Y RECUPERACIÓN
-- Archivo: maintenance.sql
-- Motor: PostgreSQL 16+
-- Base de datos objetivo: foodstore
-- ============================================================================

\echo '====================================================================='
\echo '1. DIAGNÓSTICO: PARÁMETROS GLOBALES DEL MOTOR DE AUTOVACUUM'
\echo '====================================================================='
SELECT 
    name AS parametro,
    setting AS valor_actual,
    unit AS unidad,
    short_desc AS descripcion
FROM pg_settings
WHERE name IN (
    'autovacuum',
    'autovacuum_max_workers',
    'autovacuum_naptime',
    'autovacuum_vacuum_threshold',
    'autovacuum_vacuum_scale_factor',
    'autovacuum_analyze_threshold',
    'autovacuum_analyze_scale_factor'
)
ORDER BY name;

\echo '====================================================================='
\echo '2. ESTADO PREVIO DE TUPLAS MUERTAS Y UMBRALES DE AUTOVACUUM'
\echo '====================================================================='
-- Muestra el estado actual y calcula cuándo se dispararía el autovacuum automático
SELECT 
    relname AS tabla,
    n_live_tup AS tuplas_vivas,
    n_dead_tup AS tuplas_muertas,
    ROUND((current_setting('autovacuum_vacuum_threshold')::int + 
           current_setting('autovacuum_vacuum_scale_factor')::float * n_live_tup)::numeric, 0) AS umbral_disparo_autovacuum,
    last_vacuum,
    last_autovacuum,
    last_analyze,
    last_autoanalyze
FROM pg_stat_user_tables
WHERE relname IN ('pedido', 'pedido_producto', 'producto', 'cliente', 'categoria')
ORDER BY n_dead_tup DESC;

\echo '====================================================================='
\echo '3. JUSTIFICACIÓN TÉCNICA DE LA ACCIÓN DE MANTENIMIENTO'
\echo '====================================================================='
/*
CRITERIO DE LA CÁTEDRA Y BUENAS PRÁCTICAS OPERACIONALES:
1. VACUUM FULL NO debe utilizarse como tarea de mantenimiento periódico:
   - Motivo técnico: Requiere un bloqueo exclusivo total ('AccessExclusiveLock'),
     lo cual rechaza cualquier lectura (SELECT) y escritura concurrente en la tabla.
     Además reescribe la tabla completa consumiendo el doble de espacio temporal en disco
     y genera picos de I/O masivos.
2. Acción segura seleccionada: VACUUM (ANALYZE, VERBOSE)
   - Motivo técnico: Adquiere únicamente un bloqueo 'ShareUpdateExclusiveLock', permitiendo
     lecturas (SELECT) e inserciones/modificaciones concurrentes sin interrupción de servicio.
   - Efecto: Recupera el espacio ocupado por tuplas muertas marcándolo como libre en el
     Free Space Map (FSM) para futuras transacciones, actualiza el Visibility Map para
     habilitar Index-Only Scans y refresca las estadísticas de distribución de datos
     en pg_statistic para que el optimizador elija los mejores planes de ejecución.
*/

\echo '====================================================================='
\echo '4. EJECUCIÓN DEL MANTENIMIENTO SEGURO Y NO BLOQUEANTE'
\echo '====================================================================='
VACUUM (ANALYZE, VERBOSE) categoria;
VACUUM (ANALYZE, VERBOSE) cliente;
VACUUM (ANALYZE, VERBOSE) producto;
VACUUM (ANALYZE, VERBOSE) pedido;
VACUUM (ANALYZE, VERBOSE) pedido_producto;

\echo '====================================================================='
\echo '5. ESTADO POSTERIOR DE LAS TABLAS TRAS EL MANTENIMIENTO'
\echo '====================================================================='
SELECT 
    relname AS tabla,
    n_live_tup AS tuplas_vivas,
    n_dead_tup AS tuplas_muertas,
    last_vacuum,
    last_analyze
FROM pg_stat_user_tables
WHERE relname IN ('categoria', 'cliente', 'producto', 'pedido', 'pedido_producto')
ORDER BY relname;
