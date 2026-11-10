-- ============================================================================
-- Setup completo para TP Unidad 5 ÔÇö Food Store
-- Crea las tablas de Food Store (unidades 1-4) + funciones de autenticaci├│n
-- Ejecutar en la base de datos que uses para el TP U5 (recomendado: food_store_copia)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 0. Limpieza (opcional, para empezar de cero)
-- ----------------------------------------------------------------------------
DROP VIEW IF EXISTS control_lote_almacen_vista CASCADE;
DROP TABLE IF EXISTS control_lote_almacen_nuevo CASCADE;
DROP TABLE IF EXISTS responsable_control CASCADE;
DROP TABLE IF EXISTS control_lote_almacen CASCADE;
DROP TABLE IF EXISTS detalle_pedido CASCADE;
DROP TABLE IF EXISTS pedido CASCADE;
DROP TABLE IF EXISTS producto CASCADE;
DROP TABLE IF EXISTS categoria CASCADE;
DROP TABLE IF EXISTS usuario CASCADE;
DROP TABLE IF EXISTS deposito CASCADE;
DROP TABLE IF EXISTS lote CASCADE;
DROP TABLE IF EXISTS usuario_anon CASCADE;

-- ----------------------------------------------------------------------------
-- 1. Tablas maestras
-- ----------------------------------------------------------------------------

CREATE TABLE categoria (
    id     BIGINT PRIMARY KEY,
    nombre TEXT NOT NULL
);

CREATE TABLE producto (
    id           BIGINT PRIMARY KEY,
    nombre       TEXT NOT NULL,
    categoria_id BIGINT NOT NULL REFERENCES categoria(id),
    precio       NUMERIC(10,2) NOT NULL,
    stock        INT NOT NULL DEFAULT 0
);

CREATE TABLE usuario (
    id            BIGINT PRIMARY KEY,
    email         TEXT NOT NULL UNIQUE,
    nombre        TEXT NOT NULL,
    rol           TEXT NOT NULL,
    fecha_alta    DATE NOT NULL DEFAULT CURRENT_DATE,
    activo        BOOLEAN NOT NULL DEFAULT TRUE,
    password_hash TEXT NOT NULL
);

CREATE TABLE pedido (
    id         BIGINT PRIMARY KEY,
    fecha      DATE NOT NULL,
    usuario_id BIGINT REFERENCES usuario(id),
    eliminado  BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE TABLE detalle_pedido (
    id          BIGINT PRIMARY KEY,
    pedido_id   BIGINT NOT NULL REFERENCES pedido(id),
    producto_id BIGINT NOT NULL REFERENCES producto(id),
    cantidad    INT NOT NULL DEFAULT 1,
    subtotal    NUMERIC(12,2) NOT NULL,
    eliminado   BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE TABLE deposito (
    id     BIGINT PRIMARY KEY,
    nombre TEXT NOT NULL
);

CREATE TABLE lote (
    id          BIGINT PRIMARY KEY,
    descripcion TEXT
);

-- ----------------------------------------------------------------------------
-- 2. Funciones de autenticaci├│n (Clase 2)
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fn_autenticar(p_email TEXT, p_password TEXT)
RETURNS TABLE(usuario_id BIGINT, nombre TEXT, rol TEXT, autenticado BOOLEAN)
LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    SELECT u.id, u.nombre, u.rol,
           (u.password_hash = md5(p_password)) AS autenticado
    FROM usuario u
    WHERE u.email = p_email AND u.activo = TRUE;
END;
$$;

CREATE OR REPLACE FUNCTION fn_resetear_password(p_email TEXT, p_nueva_password TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE usuario
    SET password_hash = md5(p_nueva_password)
    WHERE email = p_email AND activo = TRUE;
    RETURN FOUND;
END;
$$;

-- ----------------------------------------------------------------------------
-- 3. Datos de ejemplo
-- ----------------------------------------------------------------------------

INSERT INTO categoria (id, nombre) VALUES
    (1, 'Bebidas'),
    (2, 'L├ícteos'),
    (3, 'Panader├¡a'),
    (4, 'Limpieza'),
    (5, 'Verduler├¡a');

INSERT INTO producto (id, nombre, categoria_id, precio, stock) VALUES
    (101, 'Coca Cola 2.25L', 1, 1290, 100),
    (102, 'Sprite 2.25L', 1, 1190, 80),
    (103, 'Leche entera 1L', 2, 450, 200),
    (104, 'Yogur natural', 2, 280, 150),
    (105, 'Pan de molde', 3, 320, 60),
    (106, 'Facturas docena', 3, 850, 40),
    (107, 'Detergente lavanda', 4, 580, 90),
    (108, 'Jab├│n lavavajillas', 4, 420, 120),
    (109, 'Tomate 1kg', 5, 680, 70),
    (110, 'Papa 1kg', 5, 340, 110);

-- Usuarios con passwords hasheadas (md5 de 'password123')
INSERT INTO usuario (id, email, nombre, rol, fecha_alta, activo, password_hash) VALUES
    (1, 'admin@foodstore.com',    'Administrador', 'admin',    '2024-01-15', TRUE,  md5('password123')),
    (2, 'vendedor1@foodstore.com','Juan P├®rez',    'vendedor', '2024-02-10', TRUE,  md5('password123')),
    (3, 'vendedor2@foodstore.com','Mar├¡a G├│mez',   'vendedor', '2024-03-05', TRUE,  md5('password123')),
    (4, 'soporte@foodstore.com',  'Carlos Ruiz',   'soporte',  '2024-04-20', TRUE,  md5('password123')),
    (5, 'reportes@foodstore.com', 'Ana L├│pez',     'reportes', '2024-05-12', TRUE,  md5('password123')),
    (6, 'inactivo@foodstore.com', 'Pedro D├¡az',    'vendedor', '2024-06-01', FALSE, md5('password123'));

INSERT INTO pedido (id, fecha, usuario_id, eliminado) VALUES
    (1001, CURRENT_DATE, 2, FALSE),
    (1002, CURRENT_DATE, 3, FALSE),
    (1003, CURRENT_DATE, 2, FALSE),
    (1004, CURRENT_DATE - 1, 3, FALSE),
    (1005, CURRENT_DATE, 2, TRUE);

INSERT INTO detalle_pedido (id, pedido_id, producto_id, cantidad, subtotal, eliminado) VALUES
    (10001, 1001, 101, 2, 2580, FALSE),
    (10002, 1001, 103, 1, 450,  FALSE),
    (10003, 1002, 105, 1, 320,  FALSE),
    (10004, 1002, 107, 2, 1160, FALSE),
    (10005, 1002, 109, 1, 680,  FALSE),
    (10006, 1003, 102, 1, 1190, FALSE),
    (10007, 1003, 104, 2, 560,  FALSE),
    (10008, 1003, 106, 1, 850,  FALSE),
    (10009, 1003, 110, 1, 340,  FALSE),
    (10010, 1004, 101, 1, 1290, FALSE),
    (10011, 1005, 105, 1, 320,  TRUE),
    (10012, 1001, 110, 1, 340,  TRUE);

INSERT INTO deposito (id, nombre) VALUES
    (30, 'Dep├│sito Central'),
    (31, 'Dep├│sito Norte');

INSERT INTO lote (id, descripcion) VALUES
    (501, 'Lote de bebidas'),
    (502, 'Lote de l├ícteos'),
    (503, 'Lote de panader├¡a');

-- ----------------------------------------------------------------------------
-- 4. Tabla usuario_anon (para Parte D ÔÇö anonimizaci├│n)
-- ----------------------------------------------------------------------------

CREATE TABLE usuario_anon (
    id         BIGINT PRIMARY KEY,
    email      TEXT NOT NULL,
    nombre     TEXT NOT NULL,
    rol        TEXT NOT NULL,
    fecha_alta DATE NOT NULL,
    activo     BOOLEAN NOT NULL
);

INSERT INTO usuario_anon (id, email, nombre, rol, fecha_alta, activo)
SELECT
    id,
    'anon' || id || '@example.com',
    'Usuario Anon ' || id,
    rol,
    fecha_alta,
    activo
FROM usuario;

-- ============================================================================
-- FIN setup
-- ============================================================================
