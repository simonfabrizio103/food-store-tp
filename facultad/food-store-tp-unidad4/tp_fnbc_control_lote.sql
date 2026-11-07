-- ============================================================================
-- TP Unidad 4 — Parte 1: Forma Normal de Boyce-Codd (FNBC)
-- Proyecto: ControlLoteAlmacen (extensión mayorista de Food Store)
-- Archivo: tp_fnbc_control_lote.sql
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 0. Esquema original (ya cargado con instancia de ejemplo)
-- ----------------------------------------------------------------------------

-- Tablas maestras asumidas existentes (análogo a sucursal en el caso AsignacionEntrega)
CREATE TABLE IF NOT EXISTS lote (
    id BIGINT PRIMARY KEY
);

CREATE TABLE IF NOT EXISTS deposito (
    id BIGINT PRIMARY KEY
);

CREATE TABLE IF NOT EXISTS usuario (
    id BIGINT PRIMARY KEY
);

-- Esquema inicial de la extensión mayorista
CREATE TABLE IF NOT EXISTS control_lote_almacen (
    lote_id                 BIGINT NOT NULL REFERENCES lote(id),
    deposito_id             BIGINT NOT NULL REFERENCES deposito(id),
    responsable_control_id  BIGINT NOT NULL REFERENCES usuario(id),
    PRIMARY KEY (lote_id, deposito_id)
);

-- Instancia de ejemplo provista (sólo si la tabla está vacía)
INSERT INTO lote      SELECT * FROM (VALUES (501), (502), (503)) AS v(id)
WHERE NOT EXISTS (SELECT 1 FROM lote);

INSERT INTO deposito  SELECT * FROM (VALUES (30), (31)) AS v(id)
WHERE NOT EXISTS (SELECT 1 FROM deposito);

INSERT INTO usuario   SELECT * FROM (VALUES (801), (802)) AS v(id)
WHERE NOT EXISTS (SELECT 1 FROM usuario);

INSERT INTO control_lote_almacen (lote_id, deposito_id, responsable_control_id)
SELECT v.lote_id, v.deposito_id, v.responsable_control_id
FROM (VALUES
    (501, 30, 801),
    (502, 30, 801),
    (503, 31, 802)
) AS v(lote_id, deposito_id, responsable_control_id)
WHERE NOT EXISTS (
    SELECT 1 FROM control_lote_almacen c
    WHERE c.lote_id = v.lote_id AND c.deposito_id = v.deposito_id
);

-- ----------------------------------------------------------------------------
-- 4.2.a) Dependencias funcionales (notación formal)
-- ----------------------------------------------------------------------------
-- Usando los nombres de atributo: LoteID, DepositoID, ResponsableControlID
--
-- FD1: {LoteID, DepositoID}  →  ResponsableControlID   (clave primaria)
-- FD2: ResponsableControlID  →  DepositoID             (regla de negocio 2:
--                                                        cada responsable
--                                                        pertenece a un único depósito)

-- ----------------------------------------------------------------------------
-- 4.2.b) Clausuras y claves candidatas
-- ----------------------------------------------------------------------------
--
-- Clausuras calculadas:
--   {LoteID, DepositoID}+ = {LoteID, DepositoID, ResponsableControlID}
--       → superclave; al ser mínima, es CLAVE CANDIDATA.
--
--   {ResponsableControlID}+ = {ResponsableControlID, DepositoID}
--       → NO es clave (falta LoteID).
--
--   {LoteID}+ = {LoteID}
--       → NO es clave.
--
-- CLAVE CANDIDATA ÚNICA: {LoteID, DepositoID}
-- Atributos primos:       LoteID, DepositoID
-- Atributos no primos:    ResponsableControlID

-- ----------------------------------------------------------------------------
-- 4.2.c) ¿Cumple FNBC? (definición formal, no 3FN)
-- ----------------------------------------------------------------------------
--
-- NO cumple FNBC.
--
-- Dependencia violatoria: ResponsableControlID → DepositoID
--   * El determinante ResponsableControlID NO es superclave
--     (su clausura no incluye LoteID).
--   * DepositoID es un atributo primo, pero la dependencia parte de un
--     atributo que no es superclave, lo cual viola FNBC.

-- ----------------------------------------------------------------------------
-- 4.2.d) Tres anomalías clásicas (una instancia concreta sobre los datos)
-- ----------------------------------------------------------------------------
--
-- 1) INSERCIÓN:
--    No puedo registrar que el responsable 805 pertenece al depósito 30 hasta
--    que exista al menos un lote que controlar en ese depósito. El dato maestro
--    del responsable queda "atrapado" por la necesidad de una fracción de lote.
--
-- 2) BORRADO:
--    Si borro la última fila del responsable 801 en el depósito 30 (por ejemplo
--    DELETE FROM control_lote_almacen WHERE lote_id = 501 AND deposito_id = 30),
--    pierdo el dato maestro de que el responsable 801 pertenece al depósito 30.
--
-- 3) ACTUALIZACIÓN:
--    Si el responsable 801 se traslada del depósito 30 al depósito 35, debo
--    actualizar TODAS las filas donde aparezca (501/30/801 y 502/30/801).
--    Si se me escapa una fila, la base queda inconsistente (mismo responsable
--    asociado a dos depósitos distintos).

-- ----------------------------------------------------------------------------
-- 4.2.e) Descomposición sin pérdida (algoritmo visto en clase)
-- ----------------------------------------------------------------------------
--
-- Se descompone sobre el atributo común DepositoID, que es superclave de
-- la FD violatoria (ResponsableControlID → DepositoID).
--
--   R1(ResponsableControlID, DepositoID)   PK: ResponsableControlID
--   R2(LoteID, DepositoID, ResponsableControlID)   PK: (LoteID, DepositoID)
--                                                   FK: ResponsableControlID → R1

DROP VIEW IF EXISTS control_lote_almacen_vista;
DROP TABLE IF EXISTS control_lote_almacen_nuevo;
DROP TABLE IF EXISTS responsable_control;

-- Tabla R1: datos maestros del personal (un responsable → un depósito)
CREATE TABLE responsable_control (
    responsable_control_id BIGINT PRIMARY KEY REFERENCES usuario(id),
    deposito_id            BIGINT NOT NULL REFERENCES deposito(id)
);

-- Tabla R2: control de lote por depósito (fracción)
CREATE TABLE control_lote_almacen_nuevo (
    lote_id                BIGINT NOT NULL REFERENCES lote(id),
    deposito_id            BIGINT NOT NULL REFERENCES deposito(id),
    responsable_control_id BIGINT NOT NULL,
    PRIMARY KEY (lote_id, deposito_id),
    FOREIGN KEY (responsable_control_id) REFERENCES responsable_control(responsable_control_id)
);

-- Vista de compatibilidad: reconstruye la relación original mediante reunión natural
CREATE OR REPLACE VIEW control_lote_almacen_vista AS
SELECT
    r2.lote_id,
    r2.deposito_id,
    r2.responsable_control_id
FROM control_lote_almacen_nuevo r2
JOIN responsable_control r1
  ON r1.responsable_control_id = r2.responsable_control_id
 AND r1.deposito_id           = r2.deposito_id;

-- ----------------------------------------------------------------------------
-- 4.2.f) Justificación de la unión sin pérdida
-- ----------------------------------------------------------------------------
--
-- La reunión R1 ⋈ R2 es sin pérdida porque el atributo común de la
-- descomposición, DepositoID, es superclave de R1
-- (ResponsableControlID → DepositoID, y ResponsableControlID es PK de R1).
-- Por el criterio de superclave sobre el atributo común, la descomposición
-- es sin pérdida: no se generan tuplas espurias ni se pierde información.

-- ----------------------------------------------------------------------------
-- 4.2.f) Migración de datos de ejemplo hacia las tablas descompuestas
-- ----------------------------------------------------------------------------
--
-- Paso 1: Migrar datos maestros (cada responsable → su único depósito)
--         Lee directamente de control_lote_almacen (la original)
INSERT INTO responsable_control (responsable_control_id, deposito_id)
SELECT DISTINCT responsable_control_id, deposito_id
FROM control_lote_almacen
ON CONFLICT (responsable_control_id) DO UPDATE
SET deposito_id = EXCLUDED.deposito_id;

-- Paso 2: Migrar datos de control (lote, depósito, responsable)
INSERT INTO control_lote_almacen_nuevo (lote_id, deposito_id, responsable_control_id)
SELECT lote_id, deposito_id, responsable_control_id
FROM control_lote_almacen
ON CONFLICT (lote_id, deposito_id) DO UPDATE
SET responsable_control_id = EXCLUDED.responsable_control_id;

-- Paso 3 (opcional): conservar la tabla original como respaldo
-- ALTER TABLE control_lote_almacen RENAME TO control_lote_almacen_original;
-- ALTER TABLE control_lote_almacen_nuevo RENAME TO control_lote_almacen;

-- ----------------------------------------------------------------------------
-- 4.2.f) Verificación de equivalencia mediante la vista de compatibilidad
-- ----------------------------------------------------------------------------
--
-- Ejecutar y comparar ambas consultas. Deben devolver exactamente las mismas filas:
--
--   SELECT * FROM control_lote_almacen_vista ORDER BY lote_id, deposito_id;
--   (esperado: 501/30/801, 502/30/801, 503/31/802)
--
--   SELECT * FROM control_lote_almacen ORDER BY lote_id, deposito_id;
--   (esperado: 501/30/801, 502/30/801, 503/31/802)

-- ============================================================================
-- FIN Parte 1
-- ============================================================================