-- =============================================================
-- DataFlow — Queries de validación e integridad
-- Ejecutar después de cargar los datos del ETL completo
-- =============================================================

-- ─── 1. Conteo de registros por tabla ─────────────────────────
SELECT 'customers'    AS tabla, COUNT(*) AS registros FROM customers    UNION ALL
SELECT 'sellers',               COUNT(*)              FROM sellers       UNION ALL
SELECT 'products',              COUNT(*)              FROM products      UNION ALL
SELECT 'orders',                COUNT(*)              FROM orders        UNION ALL
SELECT 'order_items',           COUNT(*)              FROM order_items   UNION ALL
SELECT 'order_reviews',         COUNT(*)              FROM order_reviews
ORDER BY tabla;

-- ─── 2. Verificar integridad referencial ──────────────────────
-- Pedidos sin cliente (debe retornar 0 filas)
SELECT o.order_id
FROM orders o
LEFT JOIN customers c ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL;

-- Items sin producto (debe retornar 0 filas)
SELECT oi.order_id, oi.item_seq
FROM order_items oi
LEFT JOIN products p ON oi.product_id = p.product_id
WHERE p.product_id IS NULL;

-- ─── 3. JOIN maestro — vista del pipeline ETL ─────────────────
-- Este es el SELECT que usará el ETL para extraer datos
SELECT
    o.order_id,
    o.order_status,
    o.purchase_timestamp,
    o.customer_delivery_timestamp,
    o.estimated_delivery_date,
    c.customer_unique_id,
    c.city         AS customer_city,
    c.state        AS customer_state,
    s.seller_id,
    s.city         AS seller_city,
    s.state        AS seller_state,
    p.product_id,
    p.category_name,
    p.weight_g,
    p.length_cm * p.height_cm * p.width_cm  AS volume_cm3,
    oi.price,
    oi.freight_value,
    oi.item_seq,
    r.review_score,
    r.comment_title,
    r.comment_message
FROM orders o
JOIN customers    c  ON o.customer_id   = c.customer_id
JOIN order_items  oi ON o.order_id      = oi.order_id
JOIN products     p  ON oi.product_id   = p.product_id
JOIN sellers      s  ON oi.seller_id    = s.seller_id
LEFT JOIN order_reviews r ON o.order_id = r.order_id
ORDER BY o.purchase_timestamp;

-- ─── 4. Análisis de pedidos tardíos ───────────────────────────
SELECT
    order_status,
    COUNT(*)                                            AS total_pedidos,
    COUNT(customer_delivery_timestamp)                  AS con_entrega,
    SUM(CASE
        WHEN customer_delivery_timestamp > estimated_delivery_date
        THEN 1 ELSE 0
    END)                                                AS pedidos_tardios,
    ROUND(
        100.0 * SUM(CASE
            WHEN customer_delivery_timestamp > estimated_delivery_date
            THEN 1 ELSE 0
        END) / NULLIF(COUNT(customer_delivery_timestamp), 0),
    2)                                                  AS pct_tardio
FROM orders
GROUP BY order_status
ORDER BY total_pedidos DESC;

-- ─── 5. Score promedio por categoría ──────────────────────────
SELECT
    p.category_name,
    COUNT(r.review_id)          AS total_resenas,
    ROUND(AVG(r.review_score), 2) AS score_promedio
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
LEFT JOIN order_reviews r ON oi.order_id = r.order_id
GROUP BY p.category_name
ORDER BY score_promedio;

-- ─── 6. Pedidos por estado del cliente ────────────────────────
SELECT
    c.state,
    COUNT(DISTINCT o.order_id)  AS total_pedidos,
    ROUND(AVG(oi.price), 2)     AS ticket_promedio
FROM orders o
JOIN customers c   ON o.customer_id  = c.customer_id
JOIN order_items oi ON o.order_id   = oi.order_id
GROUP BY c.state
ORDER BY total_pedidos DESC
LIMIT 10;
