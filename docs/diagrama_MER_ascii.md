# Diagrama MER — ASCII

```
┌─────────────────────────┐
│        customers        │
├─────────────────────────┤
│ PK  customer_id         │
│     customer_unique_id  │
│     zip_code            │
│     city                │
│     state               │
└────────────┬────────────┘
             │ 1
             │
             │ N
┌────────────▼────────────────────────────────────────────────────┐
│                            orders                               │
├─────────────────────────────────────────────────────────────────┤
│ PK  order_id                                                    │
│ FK  customer_id                                                 │
│     order_status                                                │
│     purchase_timestamp                                          │
│     approved_at                                                 │
│     carrier_delivery_timestamp                                  │
│     customer_delivery_timestamp                                 │
│     estimated_delivery_date                                     │
└──────────┬─────────────────────────────────────────┬───────────┘
           │ 1                                       │ 1
           │                                         │
           │ N                                       │ 1
┌──────────▼──────────────────────┐    ┌─────────────▼───────────┐
│          order_items            │    │       order_reviews      │
├─────────────────────────────────┤    ├─────────────────────────┤
│ PK  (order_id, item_seq)        │    │ PK  review_id            │
│ FK  order_id                    │    │ FK  order_id             │
│ FK  product_id                  │    │     review_score         │
│ FK  seller_id                   │    │     comment_title        │
│     shipping_limit              │    │     comment_message      │
│     price                       │    │     creation_date        │
│     freight_value               │    │     answer_timestamp     │
└───────┬──────────────┬──────────┘    └─────────────────────────┘
        │ N            │ N
        │              │
        │ 1            │ 1
┌───────▼──────────┐  ┌▼────────────────────────┐
│     products     │  │         sellers          │
├──────────────────┤  ├──────────────────────────┤
│ PK  product_id   │  │ PK  seller_id            │
│     category_name│  │     zip_code             │
│     name_length  │  │     city                 │
│     desc_length  │  │     state                │
│     photos_qty   │  └──────────────────────────┘
│     weight_g     │
│     length_cm    │
│     height_cm    │
│     width_cm     │
└──────────────────┘
```

## Cardinalidades

| Relación                          | Tipo | Descripción                                          |
|-----------------------------------|------|------------------------------------------------------|
| `customers` → `orders`            | 1:N  | Un cliente puede tener múltiples pedidos             |
| `orders` → `order_items`          | 1:N  | Un pedido puede contener múltiples ítems             |
| `orders` → `order_reviews`        | 1:1  | Cada pedido tiene a lo sumo una reseña               |
| `products` → `order_items`        | 1:N  | Un producto puede aparecer en múltiples pedidos      |
| `sellers` → `order_items`         | 1:N  | Un vendedor puede vender en múltiples pedidos        |
