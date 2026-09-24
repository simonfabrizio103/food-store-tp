-- ===========================================================================
-- PROYECTO INTEGRADOR: FOOD STORE
-- SCRIPT DE CREACIÓN DE ESQUEMA (schema.sql)
-- MOTOR: PostgreSQL
-- ===========================================================================

-- 1. TIPOS DE DATOS PERSONALIZADOS (DOMINIOS CERRADOS)
-- Utilizamos un ENUM para restringir las formas de pago a las detectadas en el negocio.
CREATE TYPE forma_pago_enum AS ENUM ('EFECTIVO', 'TARJETA', 'TRANSFERENCIA');

-- ===========================================================================
-- 2. CREACIÓN DE TABLAS (DIMENSIONES / ENTIDADES FUERTES)
-- ===========================================================================

CREATE TABLE cliente (
    id_cliente BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    email VARCHAR(150) NOT NULL UNIQUE, -- Restricción UNIQUE exigida (Regla R6)
    telefono VARCHAR(20) -- Anulable, participación parcial
);

CREATE TABLE categoria (
    id_categoria BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR(80) NOT NULL,
    activa BOOLEAN NOT NULL DEFAULT TRUE -- DEFAULT para la baja lógica (Regla R7)
);

CREATE TABLE producto (
    id_producto BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    precio_lista DECIMAL(10,2) NOT NULL CHECK (precio_lista >= 0), -- CHECK 1 (Regla R5)
    stock INTEGER NOT NULL CHECK (stock >= 0), -- CHECK 2 (Regla R5)
    activo BOOLEAN NOT NULL DEFAULT TRUE, -- DEFAULT para la baja lógica (Regla R7)
    id_categoria BIGINT NOT NULL,
    
    -- FK con ON DELETE RESTRICT: 
    -- Justificación: No podemos borrar una categoría si ya tiene productos asignados, 
    -- dejaría a los productos huérfanos y rompería la consistencia.
    CONSTRAINT fk_producto_categoria 
        FOREIGN KEY (id_categoria) 
        REFERENCES categoria (id_categoria) 
        ON DELETE RESTRICT 
);

-- ===========================================================================
-- 3. CREACIÓN DE TABLAS (TRANSACCIONALES)
-- ===========================================================================

CREATE TABLE pedido (
    id_pedido BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    fecha TIMESTAMPTZ NOT NULL DEFAULT now(), -- Fecha con zona horaria, por defecto el momento de inserción
    forma_pago forma_pago_enum NOT NULL, -- Uso del ENUM cerrado
    id_cliente BIGINT NOT NULL,
    
    -- FK con ON DELETE RESTRICT:
    -- Justificación: Es ilegal borrar físicamente a un cliente que ya tiene comprobantes 
    -- de venta a su nombre, por un tema de auditoría y facturación.
    CONSTRAINT fk_pedido_cliente 
        FOREIGN KEY (id_cliente) 
        REFERENCES cliente (id_cliente) 
        ON DELETE RESTRICT
);

-- Tabla intermedia que resuelve la relación N:M
CREATE TABLE pedido_producto (
    id_pedido BIGINT NOT NULL,
    id_producto BIGINT NOT NULL,
    cantidad INTEGER NOT NULL CHECK (cantidad > 0), -- CHECK 3: No se puede pedir cantidad 0 o negativa
    precio_unitario DECIMAL(10,2) NOT NULL CHECK (precio_unitario >= 0),
    
    -- Clave primaria compuesta por ambas foráneas
    PRIMARY KEY (id_pedido, id_producto),
    
    -- FKs
    CONSTRAINT fk_pp_pedido 
        FOREIGN KEY (id_pedido) 
        REFERENCES pedido (id_pedido) 
        ON DELETE CASCADE, 
        -- Justificación CASCADE: Si un pedido completo se cancela y se elimina el ticket, 
        -- las líneas de detalle de ese ticket deben desaparecer automáticamente.
        
    CONSTRAINT fk_pp_producto 
        FOREIGN KEY (id_producto) 
        REFERENCES producto (id_producto) 
        ON DELETE RESTRICT
        -- Justificación RESTRICT: No se puede borrar físicamente un producto si ya 
        -- figura dentro del detalle de un pedido histórico.
);

-- ===========================================================================
-- 4. CREACIÓN DE ÍNDICES (Optimización de consultas)
-- ===========================================================================

-- Índice 1: Acelera drásticamente la búsqueda y el listado del historial de pedidos de un cliente particular.
CREATE INDEX idx_pedido_cliente ON pedido (id_cliente);

-- Índice 2: Acelera las consultas cuando el usuario filtra el catálogo para listar los productos de una categoría específica (ej: ver todas las pizzas).
CREATE INDEX idx_producto_categoria ON producto (id_categoria);do al momento de la venta para no alterar facturaciones pasadas (Regla R4).