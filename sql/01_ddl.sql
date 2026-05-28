-- =============================================================
-- DataFlow — DDL
-- Base de datos: dataflow
-- Motor: PostgreSQL 15
-- =============================================================

-- Limpiar si existe (útil para re-ejecutar en desarrollo)
DROP TABLE IF EXISTS order_reviews  CASCADE;
DROP TABLE IF EXISTS order_items    CASCADE;
DROP TABLE IF EXISTS orders         CASCADE;
DROP TABLE IF EXISTS products       CASCADE;
DROP TABLE IF EXISTS sellers        CASCADE;
DROP TABLE IF EXISTS customers      CASCADE;

-- =============================================================
-- 1. CUSTOMERS
-- =============================================================
CREATE TABLE customers (
    customer_id         VARCHAR(50)  PRIMARY KEY,
    customer_unique_id  VARCHAR(50)  NOT NULL,
    zip_code            VARCHAR(10),
    city                VARCHAR(100),
    state               CHAR(2)
);

COMMENT ON TABLE customers IS 'Compradores registrados en la plataforma Olist';
COMMENT ON COLUMN customers.customer_unique_id IS 'ID real del cliente; customer_id cambia por pedido';

-- =============================================================
-- 2. SELLERS
-- =============================================================
CREATE TABLE sellers (
    seller_id   VARCHAR(50)  PRIMARY KEY,
    zip_code    VARCHAR(10),
    city        VARCHAR(100),
    state       CHAR(2)
);

COMMENT ON TABLE sellers IS 'Vendedores registrados en la plataforma Olist';

-- =============================================================
-- 3. PRODUCTS
-- =============================================================
CREATE TABLE products (
    product_id              VARCHAR(50)  PRIMARY KEY,
    category_name           VARCHAR(100),
    name_length             INT,
    description_length      INT,
    photos_qty              INT,
    weight_g                NUMERIC(10,2),
    length_cm               NUMERIC(8,2),
    height_cm               NUMERIC(8,2),
    width_cm                NUMERIC(8,2)
);

COMMENT ON TABLE products IS 'Catálogo de productos listados en Olist';

-- =============================================================
-- 4. ORDERS
-- =============================================================
CREATE TABLE orders (
    order_id                    VARCHAR(50)  PRIMARY KEY,
    customer_id                 VARCHAR(50)  NOT NULL REFERENCES customers(customer_id),
    order_status                VARCHAR(30),
    purchase_timestamp          TIMESTAMP,
    approved_at                 TIMESTAMP,
    carrier_delivery_timestamp  TIMESTAMP,
    customer_delivery_timestamp TIMESTAMP,
    estimated_delivery_date     TIMESTAMP
);

COMMENT ON TABLE orders IS 'Cabecera de cada pedido realizado en la plataforma';
COMMENT ON COLUMN orders.order_status IS 'Valores: created, approved, processing, shipped, delivered, canceled, unavailable';

-- =============================================================
-- 5. ORDER_ITEMS
-- =============================================================
CREATE TABLE order_items (
    order_id        VARCHAR(50)     NOT NULL REFERENCES orders(order_id),
    item_seq        INT             NOT NULL,
    product_id      VARCHAR(50)     NOT NULL REFERENCES products(product_id),
    seller_id       VARCHAR(50)     NOT NULL REFERENCES sellers(seller_id),
    shipping_limit  TIMESTAMP,
    price           NUMERIC(10,2)   NOT NULL CHECK (price >= 0),
    freight_value   NUMERIC(10,2)   NOT NULL CHECK (freight_value >= 0),
    PRIMARY KEY (order_id, item_seq)
);

COMMENT ON TABLE order_items IS 'Líneas de cada pedido: producto, vendedor, precio y flete';

-- =============================================================
-- 6. ORDER_REVIEWS
-- =============================================================
CREATE TABLE order_reviews (
    review_id           VARCHAR(50)  PRIMARY KEY,
    order_id            VARCHAR(50)  NOT NULL REFERENCES orders(order_id),
    review_score        INT          CHECK (review_score BETWEEN 1 AND 5),
    comment_title       TEXT,
    comment_message     TEXT,
    creation_date       TIMESTAMP,
    answer_timestamp    TIMESTAMP
);

COMMENT ON TABLE order_reviews IS 'Reseñas de los compradores (1-5 estrellas) con comentario opcional';

-- =============================================================
-- ÍNDICES para mejorar rendimiento en JOINs del ETL
-- =============================================================
CREATE INDEX idx_orders_customer    ON orders(customer_id);
CREATE INDEX idx_items_order        ON order_items(order_id);
CREATE INDEX idx_items_product      ON order_items(product_id);
CREATE INDEX idx_items_seller       ON order_items(seller_id);
CREATE INDEX idx_reviews_order      ON order_reviews(order_id);
CREATE INDEX idx_orders_status      ON orders(order_status);
CREATE INDEX idx_products_category  ON products(category_name);
