# Arquitectura y Decisiones de Diseño — DataFlow

## ¿Por qué este flujo?

Se eligió el **Flujo Clásico: SQL → ETL → MongoDB → Modelo** porque:

1. Los datos fuente de Olist son CSVs con estructura tabular bien definida → natural para PostgreSQL
2. La desnormalización en el ETL permite representar cada pedido como un documento completo en MongoDB
3. MongoDB almacena los datos enriquecidos (campos calculados como `tarde`, `dias_reales`) listos para el modelo
4. El modelo consume datos ya limpios y enriquecidos, sin necesitar acceder a SQL

## Decisiones de base de datos

### PostgreSQL como fuente
- Permite validar integridad referencial (FK) antes de procesar
- Los JOINs del ETL son explícitos y auditables en SQL
- Facilita las queries de validación post-carga

### MongoDB como destino intermedio
- Los documentos anidados agrupan toda la información de un pedido en un solo objeto (cliente, vendedor, producto, entrega, reseña)
- Refleja la naturaleza del problema: en logística, un "pedido" es la unidad de análisis, no las tablas por separado
- Las consultas de análisis exploratorio (¿cuántos retrasos por estado?) son naturales en MongoDB con `$group`

## Decisiones del ETL

| Regla | Justificación |
|-------|--------------|
| Excluir pedidos no-delivered | Solo los pedidos entregados tienen fechas reales de entrega |
| Imputar review_score=0 | Distingue "sin reseña" de score bajo real (score mínimo es 1) |
| Normalizar categorías | El dataset Olist tiene inconsistencias de encoding en categorías |
| Deduplicar por order_id | Un pedido multi-ítem generaría N documentos con mismo `_id` |

## Decisiones del modelo

| Decisión | Alternativa considerada | Por qué Random Forest |
|----------|------------------------|----------------------|
| Algoritmo | Logistic Regression | RF maneja relaciones no-lineales entre peso/volumen y retraso |
| class_weight='balanced' | Sin peso | La tasa de retraso (~8-12%) causa desbalance que sesga el modelo |
| max_depth=12 | Sin límite | Sin límite el modelo sobreajusta en features de alta cardinalidad (estados) |
| stratify en split | Sin stratify | Garantiza proporción de tardíos igual en train y test |
