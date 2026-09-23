-- ============================================================
-- TPI parcial — Cierre de gaps (food_store_copia, DBeaver Manual)
-- Obj 5: HAVING / Obj 6: PROCEDURE + CALL / Obj 9: demo borrado lógico
-- Todo reversible con ROLLBACK. Probar por bloques.
-- ============================================================

-- ------------------------------------------------------------
-- BLOQUE 1 (Obj. 5) — Facturación por categoría con HAVING
-- Esperado: ~10 filas (carga pareja, ~30M por categoría).
-- Captura: resultado + conteo.
-- ------------------------------------------------------------
SELECT c.nombre AS categoria,
       SUM(d.cantidad * d.precio_unitario) AS facturacion
FROM categoria c
JOIN producto p ON p.id_categoria = c.id_categoria
JOIN pedido_producto d ON d.id_producto = p.id_producto
GROUP BY c.nombre
HAVING SUM(d.cantidad * d.precio_unitario) > 20000000
ORDER BY facturacion DESC;

-- ------------------------------------------------------------
-- BLOQUE 2 (Obj. 6) — Procedimiento de baja lógica + CALL
-- Crear una vez (sí commitear solo este CREATE).
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_baja_producto(p_id BIGINT)
LANGUAGE plpgsql AS
$$
BEGIN
    UPDATE producto SET activo = FALSE
    WHERE id_producto = p_id AND activo = TRUE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'producto % inexistente o ya dado de baja', p_id;
    END IF;
END;
$$;

-- ------------------------------------------------------------
-- BLOQUE 3 (Obj. 9) — Demo borrado lógico y su impacto (ROLLBACK final)
-- 1) CALL da de baja el producto 3.
-- 2) La vista ya no lo trae (impacto en consultas).
-- 3) El índice parcial WHERE activo=TRUE ya no lo contiene
--    (verificar: EXPLAIN muestra Index Cond sin Filter extra en Q2).
-- 4) ROLLBACK: la base queda intacta.
-- Capturas: CALL ok + SELECT vista (0 filas) + conteo V1 (50001).
-- ------------------------------------------------------------
BEGIN;
CALL sp_baja_producto(3);
SELECT * FROM v_productos_vigentes WHERE id_producto = 3;  -- 0 filas esperado
SELECT COUNT(*) FROM v_productos_vigentes;                 -- 50001 esperado
ROLLBACK;
SELECT COUNT(*) FROM v_productos_vigentes;                 -- 50002 (restaurado)
