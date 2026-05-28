-- =============================================================
-- DataFlow — DML (Datos de prueba)
-- 5 customers, 3 sellers, 5 products, 6 orders, 8 items, 5 reviews
-- Incluye casos: entrega a tiempo, tardía, sin reseña, cancelado
-- =============================================================

-- ─── CUSTOMERS ───────────────────────────────────────────────
INSERT INTO customers VALUES
('c001', 'unique_c001', '01310-100', 'sao paulo',     'SP'),
('c002', 'unique_c002', '20040-020', 'rio de janeiro','RJ'),
('c003', 'unique_c003', '30130-110', 'belo horizonte','MG'),
('c004', 'unique_c004', '80010-010', 'curitiba',      'PR'),
('c005', 'unique_c005', '40020-010', 'salvador',      'BA');

-- ─── SELLERS ─────────────────────────────────────────────────
INSERT INTO sellers VALUES
('s001', '04571-010', 'sao paulo',     'SP'),
('s002', '91060-000', 'porto alegre',  'RS'),
('s003', '74810-100', 'goiania',       'GO');

-- ─── PRODUCTS ────────────────────────────────────────────────
INSERT INTO products VALUES
('p001', 'electronics',        24, 512, 3, 300.00, 20.0, 10.0, 15.0),
('p002', 'furniture_decor',    18, 320, 2, 4500.00, 80.0, 60.0, 40.0),
('p003', 'health_beauty',      15, 200, 4,  150.00, 12.0,  8.0,  5.0),
('p004', 'computers_accessories', 22, 480, 5, 820.00, 25.0, 15.0, 10.0),
('p005', 'toys',               12, 180, 2,  200.00, 30.0, 20.0, 20.0);

-- ─── ORDERS ──────────────────────────────────────────────────
-- o001: entregado A TIEMPO (real < estimado)
INSERT INTO orders VALUES (
    'o001', 'c001', 'delivered',
    '2018-03-12 10:30:00', '2018-03-12 11:00:00',
    '2018-03-13 08:00:00', '2018-03-19 14:00:00',
    '2018-03-21 23:59:59'
);

-- o002: entregado TARDE (real > estimado)
INSERT INTO orders VALUES (
    'o002', 'c002', 'delivered',
    '2018-04-05 09:15:00', '2018-04-05 10:00:00',
    '2018-04-06 07:00:00', '2018-04-18 16:00:00',
    '2018-04-15 23:59:59'
);

-- o003: entregado A TIEMPO con score alto
INSERT INTO orders VALUES (
    'o003', 'c003', 'delivered',
    '2018-05-20 14:00:00', '2018-05-20 14:30:00',
    '2018-05-21 09:00:00', '2018-05-27 11:00:00',
    '2018-05-30 23:59:59'
);

-- o004: entregado TARDE con score bajo
INSERT INTO orders VALUES (
    'o004', 'c004', 'delivered',
    '2018-06-01 08:00:00', '2018-06-01 09:00:00',
    '2018-06-03 10:00:00', '2018-06-20 17:00:00',
    '2018-06-12 23:59:59'
);

-- o005: cancelado (sin entrega)
INSERT INTO orders VALUES (
    'o005', 'c005', 'canceled',
    '2018-07-10 16:00:00', NULL, NULL, NULL,
    '2018-07-25 23:59:59'
);

-- o006: entregado A TIEMPO, sin reseña
INSERT INTO orders VALUES (
    'o006', 'c001', 'delivered',
    '2018-08-03 11:00:00', '2018-08-03 12:00:00',
    '2018-08-04 08:00:00', '2018-08-10 13:00:00',
    '2018-08-15 23:59:59'
);

-- ─── ORDER_ITEMS ──────────────────────────────────────────────
INSERT INTO order_items VALUES
('o001', 1, 'p001', 's001', '2018-03-14', 189.90,  25.50),
('o002', 1, 'p002', 's002', '2018-04-07', 650.00,  85.00),
('o002', 2, 'p003', 's001', '2018-04-07',  89.90,  12.00),
('o003', 1, 'p004', 's003', '2018-05-22', 420.00,  35.00),
('o004', 1, 'p005', 's002', '2018-06-03', 120.00,  18.50),
('o004', 2, 'p001', 's001', '2018-06-03', 189.90,  25.50),
('o005', 1, 'p003', 's003', '2018-07-12',  89.90,  10.00),
('o006', 1, 'p002', 's002', '2018-08-05', 620.00,  80.00);

-- ─── ORDER_REVIEWS ────────────────────────────────────────────
INSERT INTO order_reviews VALUES
('r001', 'o001', 5, 'Excelente!',        'Chegou antes do prazo, produto perfeito.',    '2018-03-20', '2018-03-21'),
('r002', 'o002', 2, 'Atrasou muito',     'Meu pedido chegou uma semana depois do prazo.','2018-04-20', '2018-04-21'),
('r003', 'o003', 5, 'Muito satisfeito',  'Produto de ótima qualidade, entrega rápida.',  '2018-05-28', '2018-05-29'),
('r004', 'o004', 1, 'Péssima experiência','Produto chegou danificado e com atraso.',      '2018-06-22', '2018-06-23'),
('r005', 'o005', 3, 'Cancelado',         'Tive que cancelar, sem problemas com reembolso.','2018-07-15','2018-07-16');
-- o006 no tiene reseña (caso intencionalmente omitido para el ETL)
