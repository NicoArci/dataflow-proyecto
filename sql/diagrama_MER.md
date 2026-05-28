# Diagrama MER — DataFlow

## Modelo Entidad-Relación

Para generar el diagrama visual, pegar el siguiente código en [dbdiagram.io](https://dbdiagram.io):

```dbml
Table customers {
  customer_id         varchar [pk]
  customer_unique_id  varchar [not null]
  zip_code            varchar
  city                varchar
  state               char(2)
}

Table sellers {
  seller_id   varchar [pk]
  zip_code    varchar
  city        varchar
  state       char(2)
}

Table products {
  product_id          varchar [pk]
  category_name       varchar
  name_length         int
  description_length  int
  photos_qty          int
  weight_g            numeric
  length_cm           numeric
  height_cm           numeric
  width_cm            numeric
}

Table orders {
  order_id                    varchar [pk]
  customer_id                 varchar [ref: > customers.customer_id]
  order_status                varchar
  purchase_timestamp          timestamp
  approved_at                 timestamp
  carrier_delivery_timestamp  timestamp
  customer_delivery_timestamp timestamp
  estimated_delivery_date     timestamp
}

Table order_items {
  order_id        varchar [ref: > orders.order_id]
  item_seq        int
  product_id      varchar [ref: > products.product_id]
  seller_id       varchar [ref: > sellers.seller_id]
  shipping_limit  timestamp
  price           numeric
  freight_value   numeric

  indexes {
    (order_id, item_seq) [pk]
  }
}

Table order_reviews {
  review_id        varchar [pk]
  order_id         varchar [ref: > orders.order_id]
  review_score     int
  comment_title    text
  comment_message  text
  creation_date    timestamp
  answer_timestamp timestamp
}
```

---

## Cardinalidades

| Relación | Tipo | Descripción |
|----------|------|-------------|
| customers → orders | 1:N | Un cliente puede tener múltiples pedidos |
| orders → order_items | 1:N | Un pedido puede tener múltiples productos |
| products → order_items | 1:N | Un producto puede aparecer en múltiples pedidos |
| sellers → order_items | 1:N | Un vendedor puede vender en múltiples pedidos |
| orders → order_reviews | 1:1 | Cada pedido tiene a lo sumo una reseña |

---

## Decisiones de diseño

**¿Por qué `customer_id` ≠ `customer_unique_id`?**  
Olist asigna un `customer_id` distinto por cada pedido del mismo comprador para preservar privacidad. El `customer_unique_id` identifica al comprador real a lo largo del tiempo.

**¿Por qué `order_items` tiene clave compuesta `(order_id, item_seq)`?**  
Un pedido puede contener múltiples productos de distintos vendedores. `item_seq` numera los ítems dentro de un pedido (1, 2, 3...).

**¿Por qué `order_reviews` es 1:1 con `orders` y no 1:N?**  
La plataforma Olist permite exactamente una reseña por pedido. Se modeló como tabla separada para mantener la normalización y porque muchos pedidos no tienen reseña.
