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
            │  ACC ~0.78 ROC ~0.83│
            └────────────────────┘
```

---

## Resultados del modelo

| Métrica | Valor |
|---------|-------|
| Accuracy | ~0.78 |
| F1-score | ~0.74 |
| ROC-AUC | ~0.83 |

> Los valores exactos se encuentran en `modelo/modelo_predictivo.ipynb`

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
    └── arquitectura.md          # decisiones de diseño
```

---

## Tecnologías usadas

![Python](https://img.shields.io/badge/Python-3.11-blue)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-15-blue)
![MongoDB](https://img.shields.io/badge/MongoDB-7-green)
![scikit-learn](https://img.shields.io/badge/scikit--learn-1.4-orange)
![Docker](https://img.shields.io/badge/Docker-Compose-blue)
