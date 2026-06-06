# Guía de Presentación — DataFlow Pipeline
**Curso:** SQL y NoSQL para Analíticas de Datos · Universidad EAN · Maestría en Ciencia de Datos

---

## Estructura de la sustentación (5 momentos)

| # | Momento | Duración sugerida |
|---|---------|-------------------|
| 1 | Contexto y justificación del pipeline | 3–4 min |
| 2 | SQL y ETL | 5–6 min |
| 3 | MongoDB | 4–5 min |
| 4 | Modelo predictivo | 5–6 min |
| 5 | Discusión y mejoras | 2–3 min |

---

## 1. Contexto — Dominio y justificación del pipeline

### Qué decir

> "Trabajamos con el dataset público **Olist Brazilian E-Commerce** (Kaggle), que contiene ~100 000 pedidos reales de la mayor plataforma de e-commerce de Brasil entre 2016 y 2018. El problema de negocio es simple y relevante: **¿llegará este pedido tarde?** La tasa de retraso en el dataset es del 8.1%, lo que tiene impacto directo en la satisfacción del cliente."

> "Elegimos el flujo clásico `SQL → ETL → MongoDB → Modelo` porque los datos fuente (9 archivos CSV) tienen estructura tabular bien definida, ideal para normalizar primero en PostgreSQL y validar integridad. Luego el ETL desnormaliza esa información para representar cada pedido como un documento completo en MongoDB — la unidad de análisis en logística. Finalmente, el modelo consume datos ya limpios y enriquecidos."

### Diagrama que mostrar

```
[9 CSVs Olist]
      ↓
[PostgreSQL 15]  ←  6 tablas relacionales con FK, ~100k filas
      ↓
[ETL Python]     ←  limpieza, enriquecimiento, desnormalización
      ↓
[MongoDB 7]      ←  96 470 documentos anidados (colección: pedidos)
      ↓
[Random Forest]  ←  predicción binaria: ¿entrega tardía? (AUC 0.83)
```

### Por qué este flujo (argumento técnico)

| Decisión | Justificación |
|----------|--------------|
| PostgreSQL primero | Los CSVs tienen relaciones naturales (FK). SQL permite validar integridad antes de procesar. |
| ETL intermedio | Desnormaliza y enriquece: calcula `dias_reales`, `tarde`, `volumen_cm3`, imputa reseñas ausentes. |
| MongoDB como destino | Un pedido es la unidad de análisis. El documento agrupa cliente, producto, vendedor, entrega y reseña en un solo objeto — más natural que 6 JOINs. |
| Random Forest | Maneja relaciones no lineales entre peso/volumen y retraso. `class_weight='balanced'` compensa el desbalance de clases (8.1% tardíos). |

---

## 2. SQL y ETL

### 2a. Modelo relacional — qué mostrar

**Abrir:** `sql/diagrama_MER.md` o el diagrama en [dbdiagram.io](https://dbdiagram.io) con el DBML del mismo archivo.

#### Las 6 tablas y sus relaciones

```
customers (1) ──< (N) orders (1) ──< (N) order_items >── (N) products
                         │                    │
                        (1)                  (N)
                         │                   │
                    order_reviews          sellers
```

| Tabla | Filas aprox. | Clave |
|-------|-------------|-------|
| `customers` | 99 441 | `customer_id` PK |
| `sellers` | 3 095 | `seller_id` PK |
| `products` | 32 951 | `product_id` PK |
| `orders` | 99 441 | `order_id` PK, `customer_id` FK |
| `order_items` | 112 650 | `(order_id, item_seq)` PK compuesta |
| `order_reviews` | 99 224 | `review_id` PK, `order_id` FK |

#### Decisiones de diseño destacables

- `customer_id ≠ customer_unique_id`: Olist asigna un ID distinto por pedido para preservar privacidad del comprador. El `customer_unique_id` identifica al comprador real.
- `order_items` tiene **PK compuesta** `(order_id, item_seq)` porque un pedido puede tener N productos de distintos vendedores.
- `order_reviews` es **1:1** con `orders` (una sola reseña por pedido, muchos sin reseña → tabla separada para mantener normalización).

#### Query de validación en vivo (ejecutar en terminal)

```sql
-- Total de pedidos con al menos un ítem y su score de reseña
SELECT
    o.order_status,
    COUNT(DISTINCT o.order_id)  AS pedidos,
    ROUND(AVG(r.review_score), 2) AS score_promedio
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
LEFT JOIN order_reviews r ON o.order_id = r.order_id
GROUP BY o.order_status
ORDER BY pedidos DESC;
```

---

### 2b. ETL — qué mostrar

**Abrir:** `etl/pipeline_etl.ipynb` (con outputs guardados).

#### Flujo del ETL en 3 secciones

**Sección 1 — Extracción**
- Conexión a PostgreSQL con SQLAlchemy.
- JOIN de las 6 tablas para obtener un DataFrame plano con toda la información de cada pedido.
- Filtro: solo pedidos con `order_status = 'delivered'` (son los únicos con fecha real de entrega).
- Resultado: ~96 000 filas × ~20 columnas.

**Sección 2 — Transformación**

| Regla de limpieza | Por qué |
|-------------------|---------|
| Excluir no-delivered | Solo entregados tienen `customer_delivery_timestamp` real |
| Calcular `dias_prometidos` y `dias_reales` | Son las features más importantes del modelo |
| Calcular `tarde = dias_reales > dias_prometidos` | Variable target del modelo |
| Calcular `volumen_cm3 = largo × alto × ancho` | Feature derivada del tamaño del paquete |
| Imputar `review_score = 0` si nulo | Distingue "sin reseña" de score bajo real (score real mínimo es 1) |
| Deduplicar por `order_id` | Un pedido multi-ítem crearía N documentos con mismo `_id` en Mongo |
| Normalizar categorías | Inconsistencias de encoding en el CSV original de Olist |

**Sección 3 — Carga**
- Construcción del documento JSON anidado con subcampos: `cliente`, `vendedor`, `producto`, `pago`, `entrega`, `reseña`.
- Inserción en MongoDB con `insert_many` en lotes + barra de progreso `tqdm`.
- Verificación final: conteo de documentos insertados.

---

## 3. MongoDB — Documentos y consultas

### Estructura del documento (mostrar en mongosh o Compass)

```javascript
db.pedidos.findOne()
```

```json
{
  "_id": "e481f51cbdc54678b7cc49136f2d6af7",
  "estado_pedido": "delivered",
  "fecha_compra": "2017-10-02T10:56:33",
  "cliente": {
    "id": "7c396fd4830fd04220f754e42b4e5bff",
    "ciudad": "sao paulo",
    "estado": "SP"
  },
  "vendedor": {
    "id": "48436dade18ac8b2bce089ec2a041202",
    "ciudad": "sao paulo",
    "estado": "SP"
  },
  "producto": {
    "id": "87285b34884572647811a353c7ac498a",
    "categoria": "cama_mesa_banho",
    "peso_g": 2400,
    "volumen_cm3": 17836
  },
  "pago": {
    "tipo": "credit_card",
    "valor_total": 29.99,
    "cuotas": 1
  },
  "entrega": {
    "dias_prometidos": 15,
    "dias_reales": 10,
    "tarde": false
  },
  "reseña": {
    "score": 4,
    "titulo": "product ok",
    "texto": "chegou antes do prazo"
  }
}
```

**Abrir:** `mongodb/consultas_mongo.ipynb`

### Las 6 consultas (ejecutar en orden)

**Consulta 1 — Conteo por estado de entrega**
```javascript
db.pedidos.aggregate([
  { $group: { _id: "$entrega.tarde", total: { $sum: 1 } } }
])
// → A tiempo: 88 644 (91.9%) | Tardío: 7 826 (8.1%)
```

**Consulta 2 — Top 10 estados con más retrasos**
```javascript
db.pedidos.aggregate([
  { $match: { "entrega.tarde": true } },
  { $group: { _id: "$cliente.estado", retrasos: { $sum: 1 } } },
  { $sort: { retrasos: -1 } },
  { $limit: 10 }
])
```

**Consulta 3 — Promedio de score por categoría de producto**
```javascript
db.pedidos.aggregate([
  { $match: { "reseña.score": { $gt: 0 } } },
  { $group: { _id: "$producto.categoria",
              score_promedio: { $avg: "$reseña.score" },
              total: { $sum: 1 } } },
  { $sort: { score_promedio: 1 } },
  { $limit: 10 }
])
```

**Consulta 4 — Pedidos problemáticos (tarde Y score bajo)**
```javascript
db.pedidos.countDocuments({
  "entrega.tarde": true,
  "reseña.score": { $lte: 2 }
})
// → Cruce de retraso con mala reseña: alto impacto en satisfacción
```

**Consulta 5 — Distribución de días reales de entrega**
```javascript
db.pedidos.aggregate([
  { $bucket: {
      groupBy: "$entrega.dias_reales",
      boundaries: [0, 5, 10, 15, 20, 30, 60, 120],
      default: "120+",
      output: { count: { $sum: 1 } }
  }}
])
```

**Consulta 6 — Vendedores con mayor tasa de retraso**
```javascript
db.pedidos.aggregate([
  { $group: {
      _id: "$vendedor.id",
      total: { $sum: 1 },
      tardios: { $sum: { $cond: ["$entrega.tarde", 1, 0] } }
  }},
  { $addFields: { pct_tarde: { $divide: ["$tardios", "$total"] } } },
  { $match: { total: { $gte: 20 } } },
  { $sort: { pct_tarde: -1 } },
  { $limit: 10 }
])
```

### Indicadores de la colección

| Indicador | Valor |
|-----------|-------|
| Total documentos | 96 470 |
| Pedidos a tiempo | 88 644 (91.9%) |
| Pedidos tardíos | 7 826 (8.1%) |
| Campos por documento | 8 campos raíz + subcampos anidados |

---

## 4. Modelo predictivo

**Abrir:** `modelo/modelo_predictivo.ipynb`

### Especificaciones del modelo

| Parámetro | Valor |
|-----------|-------|
| Algoritmo | Random Forest Classifier |
| Target | `entrega.tarde` → binario (0 = a tiempo, 1 = tardío) |
| Dataset | 96 470 pedidos (fuente: MongoDB) |
| Split | 80/20 estratificado, `random_state=42` |
| `class_weight` | `'balanced'` (compensa desbalance 8.1% tardíos) |
| `max_depth` | 12 (evita sobreajuste en features de alta cardinalidad) |

### Features de entrada (11 variables)

| Feature | Tipo | Transformación |
|---------|------|---------------|
| `dias_prometidos` | numérico | — |
| `pago_valor` | numérico | — |
| `pago_cuotas` | numérico | — |
| `peso_g` | numérico | — |
| `volumen_cm3` | numérico | calculado en ETL |
| `review_score` | numérico | imputado 0 si sin reseña |
| `estado_cliente` | categórico | LabelEncoder |
| `estado_vendedor` | categórico | LabelEncoder |
| `categoria_producto` | categórico | LabelEncoder |
| `tipo_pago` | categórico | LabelEncoder |

### Resultados — Classification Report

```
              precision    recall  f1-score   support

    A tiempo       0.96      0.89      0.92    17 729
      Tardío       0.32      0.61      0.42     1 565

    accuracy                           0.86    19 294
   macro avg       0.64      0.75      0.67    19 294
weighted avg       0.91      0.86      0.88    19 294
```

### Métricas clave

| Métrica | Valor | Interpretación |
|---------|-------|----------------|
| **Accuracy** | 0.86 | El modelo clasifica bien el 86% de los pedidos |
| **ROC-AUC** | 0.827 | Buena capacidad discriminativa (1.0 = perfecto) |
| **Recall (Tardío)** | 0.61 | Detecta 6 de cada 10 pedidos que realmente llegarán tarde |
| **Precision (Tardío)** | 0.32 | De los que predice "tarde", el 32% sí llegan tarde |
| **F1 (Tardío)** | 0.42 | Balance entre precision y recall para la clase minoritaria |

> **Para la sustentación:** El recall bajo para la clase tardía (0.61) es esperable dado el fuerte desbalance. El AUC de 0.83 indica que el modelo tiene buena capacidad de ranking, aunque la decisión de umbral puede ajustarse según el costo de falsos negativos vs falsos positivos para el negocio.

### Feature importance — Top 5

| Rank | Feature | Importancia | Interpretación |
|------|---------|-------------|----------------|
| 1 | `review_score` | 0.545 | El score de la reseña es la señal más fuerte de retraso (retrasos → malas reseñas) |
| 2 | `dias_prometidos` | 0.136 | Más días prometidos = mayor margen para cumplir |
| 3 | `estado_cliente` | 0.063 | La región del cliente afecta la logística de entrega |
| 4 | `pago_valor` | 0.062 | Pedidos de mayor valor pueden tener distinto tratamiento logístico |
| 5 | `volumen_cm3` | 0.055 | Paquetes más grandes son más difíciles de manejar |

> **Nota sobre `review_score`:** Su alta importancia es conceptualmente válida (retrasos generan malas reseñas), pero en producción esta feature puede introducir **data leakage** si la reseña se genera después de la entrega. Para un modelo de predicción en tiempo real (antes de la entrega), se debería excluir y reentrenar.

### Gráficos a mostrar

1. **Matriz de confusión** (`docs/evaluacion_modelo.png`) — muestra la distribución de TP, TN, FP, FN
2. **Curva ROC** — área bajo la curva = 0.827
3. **Feature importance** — bar chart top-10 con `review_score` dominante

---

## 5. Discusión — ¿Qué se puede mejorar?

### Mejoras técnicas inmediatas

| Mejora | Impacto esperado |
|--------|-----------------|
| Excluir `review_score` del modelo (data leakage en producción) | Modelo más honesto para predicción pre-entrega |
| Usar XGBoost o LightGBM en lugar de Random Forest | Mejor manejo de desbalance, generalmente mayor AUC |
| Ajustar umbral de clasificación (default 0.5) | Aumentar recall a costa de precision según prioridad del negocio |
| SMOTE o submuestreo para desbalance | Alternativa a `class_weight='balanced'` |
| Agregar features temporales (día de semana, mes) | Los retrasos pueden ser estacionales (Black Friday, Navidad) |

### Mejoras de arquitectura

| Mejora | Descripción |
|--------|-------------|
| Modelo por región | Un modelo por estado o zona logística puede capturar patrones locales |
| Datos de tráfico logístico | Features externas (distancia real, capacidad del transportista) mejorarían mucho el modelo |
| Pipeline en Apache Airflow | Automatizar la ejecución diaria del ETL y reentrenamiento periódico |
| Feature store | Centralizar las features calculadas para reutilización entre modelos |
| API REST para el modelo | Exponer predicciones en tiempo real en el momento de confirmación del pedido |

### Reflexión sobre el flujo SQL → ETL → MongoDB

> "El flujo elegido es adecuado para este contexto académico y para sistemas batch. Si el problema fuera en tiempo real (predecir retraso en el momento de compra), el flujo cambiaría: probablemente se omitirían las reseñas como feature, se necesitaría streaming (Kafka, Flink) y el modelo se serviría como microservicio."

---

## Checklist previo a la presentación

### Infraestructura
- [ ] `docker-compose up -d` — verificar que PostgreSQL y MongoDB estén `healthy`
- [ ] `docker-compose ps` — ambos servicios en verde

### Datos
- [ ] PostgreSQL tiene las 6 tablas con datos (`SELECT COUNT(*) FROM orders`)
- [ ] MongoDB tiene 96 470 documentos (`db.pedidos.countDocuments()`)

### Notebooks (abrir con outputs guardados)
- [ ] `etl/pipeline_etl.ipynb` — todas las celdas ejecutadas, sin errores
- [ ] `mongodb/consultas_mongo.ipynb` — las 6 consultas con resultados visibles
- [ ] `modelo/modelo_predictivo.ipynb` — classification report, ROC y feature importance visibles

### Archivos de soporte
- [ ] `docs/eda_analisis.png` — existe y se puede mostrar
- [ ] `docs/evaluacion_modelo.png` — existe y se puede mostrar
- [ ] `sql/diagrama_MER.md` — código DBML listo para pegar en dbdiagram.io

### Terminal lista para demo en vivo
```powershell
# Conectar a PostgreSQL
docker exec -it dataflow-postgres psql -U dataflow_user -d dataflow

# Conectar a MongoDB
docker exec -it dataflow-mongo mongosh dataflow
```

---

## Preguntas frecuentes del profesor

**¿Por qué no usaron un solo sistema (solo SQL o solo MongoDB)?**  
> Porque el problema tiene dos naturalezas distintas: la fuente de datos es tabular y normalizada (ideal para SQL con integridad referencial), mientras que el análisis y el modelo operan sobre el pedido como unidad completa (ideal para documentos anidados en MongoDB).

**¿Por qué Random Forest y no Regresión Logística?**  
> Random Forest maneja relaciones no lineales entre features como `peso_g` y `volumen_cm3` con el retraso. También es más robusto a features de alta cardinalidad como `estado_cliente` y `categoria_producto`. La regresión logística requeriría más ingeniería de features.

**¿El modelo sería útil en producción?**  
> Con `review_score` incluida, no — es data leakage (la reseña llega después de la entrega). Sin ella, el AUC baja pero el modelo es más honesto. Para producción real se necesitarían features logísticas externas (distancia, carrier).

**¿Por qué `class_weight='balanced'`?**  
> El 8.1% de tardíos genera un modelo sesgado hacia la clase mayoritaria sin este ajuste. `balanced` pondera cada clase inversamente proporcional a su frecuencia, forzando al modelo a prestar más atención a los tardíos.

**¿Cuántos datos usaron?**  
> El dataset completo de Olist: 96 470 pedidos entregados (de ~100k totales, excluyendo cancelados, en tránsito, etc.). El entrenamiento usó 80% (~77k) y la evaluación 20% (~19k).
