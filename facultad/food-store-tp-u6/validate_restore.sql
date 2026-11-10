-- ============================================================================
-- TRABAJO PRÁCTICO — UNIDAD 6: MANTENIMIENTO, RESPALDO Y RECUPERACIÓN
-- Archivo: validate_restore.sql
-- Ejecución sobre foodstore_restore_test
-- ============================================================================

\echo '====================================================================='
\echo '1. CONTEO DE FILAS DE TABLAS PRINCIPALES'
\echo '====================================================================='
SELECT 'categoria' AS tabla, COUNT(*) AS filas FROM categoria
UNION ALL SELECT 'cliente', COUNT(*) FROM cliente
UNION ALL SELECT 'producto', COUNT(*) FROM producto
UNION ALL SELECT 'pedido', COUNT(*) FROM pedido
UNION ALL SELECT 'detalle_pedido', COUNT(*) FROM detalle_pedido;

\echo '====================================================================='
\echo '2. INTEGRIDAD: CONTROL DE PRODUCTOS INVÁLIDOS (DEBE SER 0)'
\echo '====================================================================='
SELECT COUNT(*) AS productos_invalidos
FROM producto
WHERE precio < 0 OR stock < 0;

\echo '====================================================================='
\echo '3. INTEGRIDAD: CONTROL DE DETALLES INVÁLIDOS (DEBE SER 0)'
\echo '====================================================================='
SELECT COUNT(*) AS detalles_invalidos
FROM detalle_pedido
WHERE cantidad <= 0 OR precio_unitario < 0;
