# DataFlow — Pipeline de Datos con Modelo Predictivo
## Contexto para Claude Code

**Curso:** SQL y NoSQL para Analíticas de Datos — Universidad EAN, Maestría en Ciencia de Datos  
**Calificación total:** 40 puntos  
**Dataset:** [Olist Brazilian E-Commerce](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) (Kaggle, descarga gratuita)

---

## Objetivo del proyecto

Construir un pipeline completo de datos que demuestre:
1. Diseño e implementación de base de datos relacional (PostgreSQL)
2. Proceso ETL documentado (Python/pandas)
3. Colecciones MongoDB con documentos anidados
4. Modelo predictivo de clasificación (scikit-learn)

---

## Stack tecnológico

| Capa | Tecnología |
|------|-----------|
| Base de datos relacional | PostgreSQL 15 (Docker) |
| ETL | Python 3.11, pandas, SQLAlchemy, psycopg2 |
| NoSQL | MongoDB 7 (Docker) |
| Modelo predictivo | scikit-learn (Random Forest Classifier) |
| Notebooks | Jupyter |
| Entorno | docker-compose (PG + Mongo juntos) |

---

## Flujo del pipeline

```
[Archivos CSV Olist]
        ↓
[PostgreSQL] — 6 tablas relacionales con FK
        ↓
[ETL Python] — limpieza, transformación, enriquecimiento
        ↓
[MongoDB] — colección "pedidos" con documentos anidados
        ↓
[Random Forest] — predicción de entrega tardía (clasificación binaria)
```

**Justificación del flujo (para sustentación):**  
Se eligió el flujo clásico SQL → ETL → MongoDB → Modelo porque los datos fuente (CSV Olist) tienen estructura tabular natural para SQL, el ETL enriquece y desnormaliza los datos para representarlos eficientemente en MongoDB, y el modelo se alimenta de los datos ya procesados y limpios.

---

## Estructura del repositorio

```
dataflow-proyecto/
├── CLAUDE.md                    ← este archivo (contexto para Claude Code)
├── README.md                    ← documentación pública del proyecto
├── docker-compose.yml           ← levanta PostgreSQL + MongoDB
├── .env.example                 ← variables de entorno (sin credenciales reales)
│
├── sql/
│   ├── 01_ddl.sql               ← CREATE TABLES, constraints, FK
│   ├── 02_dml_inserts.sql       ← INSERT de datos de prueba (20-30 filas por tabla)
│   ├── 03_queries_validacion.sql← SELECT para verificar integridad
│   └── diagrama_MER.md          ← descripción textual del MER (diagrama se genera con dbdiagram.io)
│
├── etl/
│   └── pipeline_etl.ipynb       ← notebook ETL completo: extracción → transformación → carga
│
├── mongodb/
│   └── consultas_mongo.ipynb    ← notebook con 6+ consultas MongoDB documentadas
│
├── modelo/
│   └── modelo_predictivo.ipynb  ← EDA + entrenamiento + evaluación del modelo
│
└── docs/
    └── arquitectura.md          ← diagrama de arquitectura y decisiones de diseño
```

---

## Tareas pendientes por componente

### SQL (10 pts) — `sql/`
- [ ] Crear `01_ddl.sql` con las 6 tablas y sus relaciones
- [ ] Crear `02_dml_inserts.sql` con datos de prueba (usar subset real de Olist)
- [ ] Crear `03_queries_validacion.sql` con JOINs y agregaciones
- [ ] Documentar el MER en `diagrama_MER.md` y generar imagen con dbdiagram.io

### ETL (8 pts) — `etl/`
- [ ] Crear `pipeline_etl.ipynb` con 3 secciones claras: Extracción, Transformación, Carga
- [ ] Documentar cada regla de limpieza con comentarios en el notebook
- [ ] Verificar que los documentos insertados en Mongo son correctos al final

### MongoDB (10 pts) — `mongodb/`
- [ ] Crear `consultas_mongo.ipynb` con mínimo 6 consultas
- [ ] Incluir consultas con $lookup, $group, $match, $unwind
- [ ] Mostrar que los documentos tienen estructura anidada (cliente, entrega, reseña)

### Modelo (8 pts) — `modelo/`
- [ ] Crear `modelo_predictivo.ipynb` con EDA inicial
- [ ] Entrenar Random Forest con los datos de MongoDB
- [ ] Calcular: Accuracy, Precision, Recall, F1, ROC-AUC
- [ ] Graficar: matriz de confusión, curva ROC, feature importance

### Presentación (4 pts)
- [ ] README.md completo con capturas del pipeline funcionando
- [ ] docker-compose funcional verificado
- [ ] Preparar narrativa de sustentación (ver sección abajo)

---

## Esquema de base de datos (PostgreSQL)

### Tablas y columnas clave

```sql
customers       (customer_id PK, customer_unique_id, city, state, zip_code)
sellers         (seller_id PK, city, state, zip_code)
products        (product_id PK, category_name, weight_g, length_cm, height_cm, width_cm)
orders          (order_id PK, customer_id FK, status, purchase_ts, approved_ts,
                 carrier_ts, delivered_ts, estimated_delivery_ts)
order_items     (order_id FK, item_seq INT, product_id FK, seller_id FK,
                 price NUMERIC, freight_value NUMERIC,
                 PRIMARY KEY (order_id, item_seq))
order_reviews   (review_id PK, order_id FK, score INT CHECK(score BETWEEN 1 AND 5),
                 comment_title TEXT, comment_message TEXT, creation_date TIMESTAMP)
```

### Relaciones
- `orders.customer_id` → `customers.customer_id`
- `order_items.order_id` → `orders.order_id`
- `order_items.product_id` → `products.product_id`
- `order_items.seller_id` → `sellers.seller_id`
- `order_reviews.order_id` → `orders.order_id`

---

## Estructura del documento MongoDB

Cada documento en la colección `pedidos` tiene esta forma:

```json
{
  "_id": "order_id_string",
  "estado_pedido": "delivered",
  "fecha_compra": "2018-03-12T10:30:00",
  "cliente": {
    "id": "customer_unique_id",
    "ciudad": "sao paulo",
    "estado": "SP"
  },
  "vendedor": {
    "id": "seller_id",
    "ciudad": "curitiba",
    "estado": "PR"
  },
  "producto": {
    "id": "product_id",
    "categoria": "electronics",
    "peso_g": 300,
    "volumen_cm3": 1200
  },
  "pago": {
    "tipo": "credit_card",
    "valor_total": 189.90,
    "cuotas": 3
  },
  "entrega": {
    "dias_prometidos": 8,
    "dias_reales": 12,
    "tarde": true
  },
  "reseña": {
    "score": 2,
    "titulo": "produto atrasado",
    "texto": "chegou uma semana depois do prazo"
  }
}
```

---

## Modelo predictivo — especificaciones

**Target:** `entrega.tarde` (booleano → 0/1)  
**Tipo:** Clasificación binaria  
**Algoritmo:** Random Forest Classifier  

**Features de entrada:**

| Feature | Tipo | Transformación |
|---------|------|---------------|
| `dias_prometidos` | numérico | — |
| `precio` | numérico | — |
| `valor_flete` | numérico | — |
| `peso_g` | numérico | — |
| `volumen_cm3` | numérico | — |
| `cuotas` | numérico | — |
| `score_reseña` | numérico | imputar 0 si no hay reseña |
| `estado_cliente` | categórico | LabelEncoder |
| `estado_vendedor` | categórico | LabelEncoder |
| `categoria_producto` | categórico | LabelEncoder |
| `tipo_pago` | categórico | LabelEncoder |

**Métricas requeridas para rúbrica:**
- Accuracy, Precision, Recall, F1-score (classification_report completo)
- ROC-AUC score
- Matriz de confusión (heatmap con seaborn)
- Feature importance (bar chart top-10)
- Train/test split: 80/20, `random_state=42`

---

## Consultas MongoDB requeridas (mínimo 6)

1. **Conteo por estado de entrega** — cuántos pedidos llegaron tarde vs a tiempo
2. **Top 10 estados con más retrasos** — `$group` + `$sort` + `$limit`
3. **Promedio de score por categoría de producto** — `$group` por `producto.categoria`
4. **Pedidos problemáticos** — `$match` donde `entrega.tarde=true` Y `reseña.score <= 2`
5. **Distribución de días reales de entrega** — histograma usando `$bucket`
6. **Vendedores con mayor tasa de retraso** — `$group` por `vendedor.id`, calcular `% tarde`

---

## Variables de entorno (`.env`)

```
POSTGRES_DB=dataflow
POSTGRES_USER=dataflow_user
POSTGRES_PASSWORD=dataflow_pass
POSTGRES_HOST=localhost
POSTGRES_PORT=5432

MONGO_URI=mongodb://localhost:27017/
MONGO_DB=dataflow
MONGO_COLLECTION=pedidos
```

---

## Sustentación — narrativa sugerida

| Momento | Qué decir |
|---------|-----------|
| **Contexto** | "Elegimos e-commerce de Olist porque tiene relaciones naturales SQL y datos ricos para MongoDB. El flujo clásico SQL→ETL→Mongo→Modelo fue elegido porque los CSVs fuente son tabulares, ideal para normalizar primero." |
| **SQL y ETL** | Mostrar el MER, ejecutar un JOIN en vivo, luego correr el notebook ETL y mostrar que Mongo recibe datos. |
| **MongoDB** | Abrir mongosh o Compass, ejecutar las 6 consultas del notebook. Resaltar la estructura anidada del documento. |
| **Modelo** | Mostrar el classification report, el ROC, y el gráfico de feature importance. Comentar que `dias_prometidos` y `peso_g` son los predictores más fuertes. |
| **Discusión** | "Se podría mejorar con un modelo por región, con datos de tráfico logístico, o usando XGBoost para capturar no-linealidades." |

---

## Notas de implementación

- El dataset Olist tiene ~100k órdenes. Para desarrollo local usar un **subset de 5000 órdenes** con `sample(n=5000, random_state=42)` en el ETL.
- Para la sustentación mostrar con el dataset completo si el equipo tiene los recursos.
- Los notebooks deben tener **outputs guardados** (cells ejecutadas) para que el profesor pueda verlos sin correr el código.
- Usar `tqdm` en el ETL para mostrar progreso de inserción en Mongo.
- El `docker-compose.yml` debe incluir healthchecks para que los servicios estén listos antes de correr notebooks.
