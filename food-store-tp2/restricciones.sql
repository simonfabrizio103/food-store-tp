-- sql/restricciones.sql
-- Restricciones de integridad para Food Store
-- R1: precio_unitario no puede superar precio_lista
-- R2: pedido.fecha no puede ser futura

-- ============================================================
-- R1: Validar precio_unitario <= precio_lista
-- ============================================================

CREATE OR REPLACE FUNCTION fn_restriccion_precio_unitario()
RETURNS TRIGGER AS $$
DECLARE
    v_precio_lista NUMERIC;
BEGIN
    SELECT precio_lista INTO v_precio_lista
    FROM producto
    WHERE id_producto = NEW.id_producto;

    IF NEW.precio_unitario > v_precio_lista THEN
        RAISE EXCEPTION
            'R1: precio_unitario (%) no puede superar precio_lista (%) del producto %',
            NEW.precio_unitario, v_precio_lista, NEW.id_producto;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_restriccion_precio_unitario
    BEFORE INSERT OR UPDATE ON pedido_producto
    FOR EACH ROW
    EXECUTE FUNCTION fn_restriccion_precio_unitario();

-- ============================================================
-- R2: Validar pedido.fecha <= now()
-- ============================================================

CREATE OR REPLACE FUNCTION fn_restriccion_fecha_futura()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.fecha > NOW() THEN
        RAISE EXCEPTION
            'R2: La fecha del pedido (%) no puede ser futura (ahora: %)',
            NEW.fecha, NOW();
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_restriccion_fecha_futura
    BEFORE INSERT OR UPDATE ON pedido
    FOR EACH ROW
    EXECUTE FUNCTION fn_restriccion_fecha_futura();
