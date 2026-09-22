-- DROP SCHEMA public;

CREATE SCHEMA public AUTHORIZATION pg_database_owner;

-- Drop table

-- DROP TABLE public.categoria;

CREATE TABLE public.categoria (
	id_categoria int8 GENERATED ALWAYS AS IDENTITY( INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 START 1 CACHE 1 NO CYCLE) NOT NULL,
	nombre varchar(80) NOT NULL,
	activa bool DEFAULT true NOT NULL,
	CONSTRAINT categoria_activa_not_null NOT NULL activa,
	CONSTRAINT categoria_id_categoria_not_null NOT NULL id_categoria,
	CONSTRAINT categoria_nombre_not_null NOT NULL nombre,
	CONSTRAINT categoria_pkey PRIMARY KEY (id_categoria)
);

-- Drop table

-- DROP TABLE public.cliente;

CREATE TABLE public.cliente (
	id_cliente int8 GENERATED ALWAYS AS IDENTITY( INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 START 1 CACHE 1 NO CYCLE) NOT NULL,
	nombre varchar(100) NOT NULL,
	email varchar(150) NOT NULL,
	telefono varchar(20) NULL,
	CONSTRAINT cliente_email_key UNIQUE (email),
	CONSTRAINT cliente_email_not_null NOT NULL email,
	CONSTRAINT cliente_id_cliente_not_null NOT NULL id_cliente,
	CONSTRAINT cliente_nombre_not_null NOT NULL nombre,
	CONSTRAINT cliente_pkey PRIMARY KEY (id_cliente)
);

-- Drop table

-- DROP TABLE public.pedido;

CREATE TABLE public.pedido (
	id_pedido int8 GENERATED ALWAYS AS IDENTITY( INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 START 1 CACHE 1 NO CYCLE) NOT NULL,
	fecha timestamptz DEFAULT now() NOT NULL,
	forma_pago public.forma_pago_enum NOT NULL,
	id_cliente int8 NOT NULL,
	CONSTRAINT pedido_fecha_not_null NOT NULL fecha,
	CONSTRAINT pedido_forma_pago_not_null NOT NULL forma_pago,
	CONSTRAINT pedido_id_cliente_not_null NOT NULL id_cliente,
	CONSTRAINT pedido_id_pedido_not_null NOT NULL id_pedido,
	CONSTRAINT pedido_pkey PRIMARY KEY (id_pedido),
	CONSTRAINT fk_pedido_cliente FOREIGN KEY (id_cliente) REFERENCES public.cliente(id_cliente) ON DELETE RESTRICT
);
CREATE INDEX idx_pedido_cliente ON public.pedido USING btree (id_cliente);
CREATE INDEX idx_pedido_cliente_cover ON public.pedido USING btree (id_cliente, id_pedido);
CREATE INDEX idx_pedido_cliente_fecha ON public.pedido USING btree (id_cliente, fecha DESC) INCLUDE (forma_pago);
CREATE INDEX idx_pedido_fecha_forma ON public.pedido USING btree (fecha, forma_pago);

-- Table Triggers

create trigger trg_restriccion_fecha_futura before
insert
    or
update
    on
    public.pedido for each row execute function fn_restriccion_fecha_futura();

-- Drop table

-- DROP TABLE public.pedido_producto;

CREATE TABLE public.pedido_producto (
	id_pedido int8 NOT NULL,
	id_producto int8 NOT NULL,
	cantidad int4 NOT NULL,
	precio_unitario numeric(10, 2) NOT NULL,
	CONSTRAINT pedido_producto_cantidad_check CHECK ((cantidad > 0)),
	CONSTRAINT pedido_producto_cantidad_not_null NOT NULL cantidad,
	CONSTRAINT pedido_producto_id_pedido_not_null NOT NULL id_pedido,
	CONSTRAINT pedido_producto_id_producto_not_null NOT NULL id_producto,
	CONSTRAINT pedido_producto_pkey PRIMARY KEY (id_pedido, id_producto),
	CONSTRAINT pedido_producto_precio_unitario_check CHECK ((precio_unitario >= (0)::numeric)),
	CONSTRAINT pedido_producto_precio_unitario_not_null NOT NULL precio_unitario,
	CONSTRAINT fk_pp_pedido FOREIGN KEY (id_pedido) REFERENCES public.pedido(id_pedido) ON DELETE CASCADE,
	CONSTRAINT fk_pp_producto FOREIGN KEY (id_producto) REFERENCES public.producto(id_producto) ON DELETE RESTRICT
);
CREATE INDEX idx_pedprod_cantidad_precio ON public.pedido_producto USING btree (cantidad, precio_unitario);
CREATE INDEX idx_pedprod_producto_cover ON public.pedido_producto USING btree (id_producto, id_pedido) INCLUDE (cantidad, precio_unitario);

-- Table Triggers

create trigger trg_restriccion_precio_unitario before
insert
    or
update
    on
    public.pedido_producto for each row execute function fn_restriccion_precio_unitario();

-- Drop table

-- DROP TABLE public.producto;

CREATE TABLE public.producto (
	id_producto int8 GENERATED ALWAYS AS IDENTITY( INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 START 1 CACHE 1 NO CYCLE) NOT NULL,
	nombre varchar(100) NOT NULL,
	precio_lista numeric(10, 2) NOT NULL,
	stock int4 NOT NULL,
	activo bool DEFAULT true NOT NULL,
	id_categoria int8 NOT NULL,
	CONSTRAINT producto_activo_not_null NOT NULL activo,
	CONSTRAINT producto_id_categoria_not_null NOT NULL id_categoria,
	CONSTRAINT producto_id_producto_not_null NOT NULL id_producto,
	CONSTRAINT producto_nombre_not_null NOT NULL nombre,
	CONSTRAINT producto_pkey PRIMARY KEY (id_producto),
	CONSTRAINT producto_precio_lista_check CHECK ((precio_lista >= (0)::numeric)),
	CONSTRAINT producto_precio_lista_not_null NOT NULL precio_lista,
	CONSTRAINT producto_stock_check CHECK ((stock >= 0)),
	CONSTRAINT producto_stock_not_null NOT NULL stock,
	CONSTRAINT fk_producto_categoria FOREIGN KEY (id_categoria) REFERENCES public.categoria(id_categoria) ON DELETE RESTRICT
);
CREATE INDEX idx_producto_cat_precio_activo ON public.producto USING btree (id_categoria, precio_lista) INCLUDE (nombre) WHERE (activo = true);
CREATE INDEX idx_producto_cat_stock_vig ON public.producto USING btree (id_categoria, stock) INCLUDE (nombre) WHERE (activo = true);
CREATE INDEX idx_producto_categoria ON public.producto USING btree (id_categoria);
CREATE INDEX idx_producto_precio ON public.producto USING btree (precio_lista);