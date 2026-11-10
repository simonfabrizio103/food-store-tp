-- ============================================================================
-- TP Unidad 5 — Parte D: verificación de equivalencia usuario vs usuario_anon
-- Archivo: verificar_equivalencia_anon.sql
-- Ejecutar DESPUÉS de usuario_anon.sql
-- ============================================================================

\echo '=== D.1 — Volumen: misma cantidad de filas ==='
SELECT
    (SELECT count(*) FROM usuario)      AS filas_usuario,
    (SELECT count(*) FROM usuario_anon) AS filas_usuario_anon,
    (SELECT count(*) FROM usuario) = (SELECT count(*) FROM usuario_anon) AS equivalente;

\echo '=== D.2 — Distribución por rol (debe coincidir exactamente) ==='
SELECT 'usuario'      AS origen, rol, count(*) FROM usuario      GROUP BY rol
UNION ALL
SELECT 'usuario_anon' AS origen, rol, count(*) FROM usuario_anon GROUP BY rol
ORDER BY rol, origen;

\echo '=== D.3 — Distribución por activo (debe coincidir exactamente) ==='
SELECT 'usuario'      AS origen, activo, count(*) FROM usuario      GROUP BY activo
UNION ALL
SELECT 'usuario_anon' AS origen, activo, count(*) FROM usuario_anon GROUP BY activo
ORDER BY activo, origen;

\echo '=== D.4 — Distribución por año de alta (debe coincidir exactamente) ==='
SELECT 'usuario'      AS origen, extract(year FROM fecha_alta)::int AS anio, count(*) FROM usuario      GROUP BY 2
UNION ALL
SELECT 'usuario_anon' AS origen, extract(year FROM fecha_alta)::int AS anio, count(*) FROM usuario_anon GROUP BY 2
ORDER BY anio, origen;

\echo '=== D.5 — CHECK exacto: conjuntos (rol, fecha_alta, activo) idénticos por id ==='
SELECT count(*) AS diferencias
FROM usuario u
FULL JOIN usuario_anon a USING (id)
WHERE u.rol IS DISTINCT FROM a.rol
   OR u.fecha_alta IS DISTINCT FROM a.fecha_alta
   OR u.activo IS DISTINCT FROM a.activo
   OR u.id IS NULL OR a.id IS NULL;

\echo '=== D.6 — Utilidad analítica: pedidos por rol de usuario (join con pedido) ==='
SELECT 'usuario'      AS origen, u.rol, count(p.id) AS pedidos
FROM usuario u LEFT JOIN pedido p ON p.usuario_id = u.id GROUP BY u.rol
UNION ALL
SELECT 'usuario_anon' AS origen, a.rol, count(p.id) AS pedidos
FROM usuario_anon a LEFT JOIN pedido p ON p.usuario_id = a.id GROUP BY a.rol
ORDER BY rol, origen;

\echo '=== D.7 — Fuga de PII: emails y nombres reales no presentes ==='
SELECT
    (SELECT count(*) FROM usuario_anon
      WHERE email_pseud ~ '^[A-Za-z0-9._%+-]+@foodstore\.com$') AS emails_reales,
    (SELECT count(*) FROM usuario_anon a JOIN usuario u ON u.id = a.id
      WHERE a.nombre_pseud = u.nombre) AS nombres_reales;

\echo '=== D.8 — Unicidad del pseudónimo (ningún email_pseud repetido) ==='
SELECT count(*) AS total, count(DISTINCT email_pseud) AS distintos
FROM usuario_anon;

\echo '=== D.9 — k-anonimato aproximado por (rol, anio_alta) ==='
SELECT rol, extract(year FROM fecha_alta)::int AS anio, count(*) AS k
FROM usuario_anon
GROUP BY rol, anio
ORDER BY k ASC, rol;

-- ============================================================================
-- FIN verificar_equivalencia_anon.sql
-- ============================================================================
