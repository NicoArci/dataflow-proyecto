# DataFlow 🔄
### Pipeline de Datos con Modelo Predictivo — Universidad EAN

> **Curso:** SQL y NoSQL para Analíticas de Datos · Maestría en Ciencia de Datos  
> **Dataset:** [Olist Brazilian E-Commerce](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) · Kaggle

---

## ¿Qué hace este proyecto?

Implementa un pipeline completo de datos sobre pedidos de e-commerce brasileño:

```
CSV Olist  →  PostgreSQL  →  ETL Python  →  MongoDB  →  Random Forest
  fuente       6 tablas       limpieza      documentos    predicción de
                              + enriq.       anidados      entrega tardía
```

El modelo predice si un pedido llegará **tarde o a tiempo** basado en características del pedido, producto, vendedor y cliente.

---

## Requisitos

- Docker y Docker Compose
- Python 3.11+
- Jupyter Notebook / JupyterLab
- Kaggle CLI (para descargar el dataset) o descarga manual

---

## Instalación

### 1. Clonar el repositorio

```bash
git clone <url-del-repo>
cd dataflow-proyecto
```

### 2. Descargar el dataset

```bash
# Opción A: Kaggle CLI
kaggle datasets download -d olistbr/brazilian-ecommerce
unzip brazilian-ecommerce.zip -d data/

# Opción B: Descarga manual desde https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce
# Colocar los CSVs en la carpeta data/
```

### 3. Configurar variables de entorno

```bash
cp .env.example .env
# Editar .env si se desean cambiar credenciales
```

### 4. Levantar las bases de datos

```bash
docker-compose up -d
# Esperar ~30 segundos para que PostgreSQL y MongoDB inicien
docker-compose ps  # verificar que ambos estén "healthy"
```

### 5. Cargar el esquema SQL

```bash
docker exec -i dataflow-postgres psql -U dataflow_user -d dataflow < sql/01_ddl.sql
docker exec -i dataflow-postgres psql -U dataflow_user -d dataflow < sql/02_dml_inserts.sql
```

### 6. Instalar dependencias Python

```bash
pip install -r requirements.txt
```

### 7. Ejecutar los notebooks en orden

```bash
jupyter notebook
```

| Orden | Notebook | Descripción |
|-------|----------|-------------|
| 1️⃣ | `etl/pipeline_etl.ipynb` | ETL: extrae de PG, transforma, carga en Mongo |
| 2️⃣ | `mongodb/consultas_mongo.ipynb` | Consultas y validación de colección |
| 3️⃣ | `modelo/modelo_predictivo.ipynb` | EDA, entrenamiento y evaluación |

---

## Arquitectura

```
┌─────────────────────────────────────────────────────────┐
│                     Docker Network                       │
│                                                         │
│  ┌──────────────────┐      ┌──────────────────┐        │
│  │   PostgreSQL 15  │      │    MongoDB 7     │        │
│  │   puerto: 5432   │      │   puerto: 27017  │        │
│  │                  │      │                  │        │
│  │  customers       │      │  db: dataflow    │        │
│  │  sellers         │      │  col: pedidos    │        │
│  │  products        │      │                  │        │
│  │  orders          │      │  documentos con  │        │
│  │  order_items     │      │  estructura      │        │
│  │  order_reviews   │      │  anidada         │        │
│  └────────┬─────────┘      └────────▲─────────┘        │
│           │                         │                   │
└───────────┼─────────────────────────┼───────────────────┘
            │                         │
            └──────── ETL Python ─────┘
                  pipeline_etl.ipynb
                  
                         │
                         ▼
                  
            ┌────────────────────┐
            │  Random Forest     │
            │  Clasificación     │
            │  entrega tardía    │
            │  ACC 0.86 AUC 0.83 │
            └────────────────────┘
```

---

## Modelo Entidad-Relación (PostgreSQL)

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

> Diagrama DBML completo (para [dbdiagram.io](https://dbdiagram.io)) en `sql/diagrama_MER.md`.

---

## Resultados del modelo

Entrenado con 96,470 pedidos (80/20 split estratificado, `random_state=42`).  
Tasa de retraso en el dataset: **8.1%** — clase desbalanceada compensada con `class_weight='balanced'`.

### Classification Report

```
              precision    recall  f1-score   support

    A tiempo       0.96      0.89      0.92     17,729
      Tardío       0.32      0.61      0.42      1,565

    accuracy                           0.86     19,294
   macro avg       0.64      0.75      0.67     19,294
weighted avg       0.91      0.86      0.88     19,294
```

### Métricas clave

| Métrica | Valor |
|---------|-------|
| Accuracy | **0.86** |
| F1-score (Tardío) | **0.42** |
| ROC-AUC | **0.8271** |
| Recall (Tardío) | 0.61 |
| Precision (Tardío) | 0.32 |

### Top 5 features por importancia

| Feature | Importancia |
|---------|-------------|
| `review_score` | 0.545 |
| `dias_prometidos` | 0.136 |
| `estado_cliente` | 0.063 |
| `pago_valor` | 0.062 |
| `volumen_cm3` | 0.055 |

> Reporte completo, curva ROC y matriz de confusión en `modelo/modelo_predictivo.ipynb`.

---

## Capturas del pipeline

### EDA — Análisis Exploratorio

![EDA análisis de entregas](docs/eda_analisis.png)

> Balance de clases, distribución de días prometidos, score de reseñas por clase y tasa de retraso por estado del cliente.

### Evaluación del modelo

![Evaluación del modelo](docs/evaluacion_modelo.png)

> Matriz de confusión, curva ROC (AUC = 0.827) y feature importance top-10.

---

## MongoDB — Colección `pedidos`

| Indicador | Valor |
|-----------|-------|
| Total documentos | **96,470** |
| Pedidos a tiempo | 88,644 (91.9%) |
| Pedidos tardíos | 7,826 (8.1%) |
| Estructura | Documentos anidados: `cliente`, `vendedor`, `producto`, `pago`, `entrega`, `reseña` |

---

## Estructura del repositorio

```
dataflow-proyecto/
├── CLAUDE.md                    # contexto para Claude Code
├── README.md                    # este archivo
├── docker-compose.yml           # infraestructura local
├── .env.example                 # plantilla de variables de entorno
├── requirements.txt             # dependencias Python
│
├── data/                        # CSVs de Olist (no incluidos en repo)
│   └── .gitkeep
│
├── sql/
│   ├── 01_ddl.sql               # esquema de base de datos
│   ├── 02_dml_inserts.sql       # datos de prueba
│   ├── 03_queries_validacion.sql# consultas de verificación
│   └── diagrama_MER.md          # descripción del modelo entidad-relación
│
├── etl/
│   └── pipeline_etl.ipynb       # pipeline ETL completo
│
├── mongodb/
│   └── consultas_mongo.ipynb    # consultas y análisis en MongoDB
│
├── modelo/
│   └── modelo_predictivo.ipynb  # EDA + modelo + métricas
│
└── docs/
    ├── arquitectura.md          # decisiones de diseño
    ├── diagrama_MER_ascii.md    # diagrama MER en ASCII
    ├── eda_analisis.png         # gráficos EDA generados por el notebook
    └── evaluacion_modelo.png    # matriz de confusión, ROC y feature importance
```

---

## Tecnologías usadas

![Python](https://img.shields.io/badge/Python-3.11-blue)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-15-blue)
![MongoDB](https://img.shields.io/badge/MongoDB-7-green)
![scikit-learn](https://img.shields.io/badge/scikit--learn-1.4-orange)
![Docker](https://img.shields.io/badge/Docker-Compose-blue)
