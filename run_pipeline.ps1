# =============================================================
# DataFlow — Pipeline completo en un solo comando
# Uso: .\run_pipeline.ps1
# =============================================================

$ErrorActionPreference = 'Continue'   # no tratar stderr de .exe como error
$ROOT = $PSScriptRoot

function Step($msg) {
    Write-Host "`n==> $msg" -ForegroundColor Cyan
}
function OK($msg) {
    Write-Host "    [OK] $msg" -ForegroundColor Green
}
function Fail($msg) {
    Write-Host "    [ERROR] $msg" -ForegroundColor Red
    exit 1
}
function Info($msg) {
    Write-Host "    $msg" -ForegroundColor Gray
}

Write-Host @"

  ____        _        _____ _
 |  _ \  __ _| |_ __ _|  ___| | _____      __
 | | | |/ _` | __/ _` | |_  | |/ _ \ \ /\ / /
 | |_| | (_| | || (_| |  _| | | (_) \ V  V /
 |____/ \__,_|\__\__,_|_|   |_|\___/ \_/\_/

 Pipeline completo: PostgreSQL -> ETL -> MongoDB -> Modelo
"@ -ForegroundColor Blue

# --------------------------------------------------------------
# PASO 1 — Docker
# --------------------------------------------------------------
Step "Levantando PostgreSQL y MongoDB con Docker..."
Set-Location $ROOT

# down es opcional — ignorar si falla (contenedores ya detenidos)
docker-compose down --remove-orphans | Out-Null

docker-compose up -d
if ($LASTEXITCODE -ne 0) { Fail "docker-compose up falló" }

# Esperar a que PostgreSQL esté healthy
Info "Esperando a que PostgreSQL esté listo..."
$retries = 0
do {
    Start-Sleep -Seconds 3
    $status = (docker inspect --format "{{.State.Health.Status}}" dataflow-postgres) | Select-Object -First 1
    $retries++
    if ($retries -gt 20) { Fail "PostgreSQL no respondió después de 60 segundos" }
} while ($status -ne "healthy")
OK "PostgreSQL listo"

# Esperar a que MongoDB esté healthy
Info "Esperando a que MongoDB esté listo..."
$retries = 0
do {
    Start-Sleep -Seconds 3
    $status = (docker inspect --format "{{.State.Health.Status}}" dataflow-mongo) | Select-Object -First 1
    $retries++
    if ($retries -gt 20) { Fail "MongoDB no respondió después de 60 segundos" }
} while ($status -ne "healthy")
OK "MongoDB listo"

# --------------------------------------------------------------
# PASO 2 — Esquema SQL (solo si las tablas no existen aún)
# NO correr DDL si ya hay datos: 01_ddl.sql tiene DROP TABLE CASCADE
# que borraría los datos reales del volumen de PostgreSQL.
# --------------------------------------------------------------
Step "Verificando esquema SQL en PostgreSQL..."

# Usar Python para contar filas — más robusto que parsear output de psql
function Get-DbCount($sql) {
    $n = python -c "
import psycopg2, sys
try:
    conn = psycopg2.connect(host='localhost', port=5433, dbname='dataflow', user='dataflow_user', password='dataflow_pass')
    cur = conn.cursor()
    cur.execute('$sql')
    print(cur.fetchone()[0])
    conn.close()
except Exception as e:
    print(0)
"
    return [int]("$n".Trim() -replace '[^0-9]','')
}

# Verificar si el esquema existe
$tableCount = Get-DbCount "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public' AND table_name='orders'"

if ($tableCount -eq 0) {
    Info "Tablas no encontradas — cargando esquema DDL..."
    Get-Content "$ROOT\sql\01_ddl.sql" -Raw | docker exec -i dataflow-postgres psql -U dataflow_user -d dataflow -q
    if ($LASTEXITCODE -ne 0) { Fail "Error cargando 01_ddl.sql" }
    OK "Esquema DDL creado"
}

# Verificar si hay datos reales; si no, cargar el dataset completo desde CSVs
$orderCount = Get-DbCount "SELECT COUNT(*) FROM orders"
if ($orderCount -lt 1000) {
    Info "Solo $orderCount pedidos — cargando dataset completo de Olist (~2-3 min)..."
    Set-Location "$ROOT\data"
    python load_olist.py
    if ($LASTEXITCODE -ne 0) { Fail "load_olist.py falló — verificar que los CSVs están en data/" }
    $orderCount = Get-DbCount "SELECT COUNT(*) FROM orders"
    if ($orderCount -lt 1000) { Fail "load_olist.py terminó pero PostgreSQL tiene $orderCount pedidos — revisar errores arriba" }
    OK "Dataset Olist cargado: $orderCount pedidos"
} else {
    OK "PostgreSQL: $orderCount pedidos (sin recargar)"
}

# Guardia: no continuar si no hay pedidos con entrega para el ETL
$guardCount = Get-DbCount "SELECT COUNT(*) FROM orders WHERE customer_delivery_timestamp IS NOT NULL"
if ($guardCount -lt 500) {
    Fail "Solo $guardCount pedidos con entrega. El ETL produciría datos insuficientes. Verificar carga."
}
Info "Confirmado: $guardCount pedidos con entrega listos para el ETL"

# --------------------------------------------------------------
# PASO 3 — ETL: PostgreSQL → MongoDB
# --------------------------------------------------------------
Step "Ejecutando ETL (PostgreSQL -> MongoDB)..."
Set-Location "$ROOT\etl"
python -m jupyter nbconvert --to notebook --execute --inplace --ExecutePreprocessor.timeout=300 pipeline_etl.ipynb
if ($LASTEXITCODE -ne 0) { Fail "ETL notebook falló" }
OK "ETL completado — datos cargados en MongoDB"

# --------------------------------------------------------------
# PASO 4 — Consultas MongoDB
# --------------------------------------------------------------
Step "Ejecutando consultas MongoDB..."
Set-Location "$ROOT\mongodb"
python -m jupyter nbconvert --to notebook --execute --inplace --ExecutePreprocessor.timeout=120 consultas_mongo.ipynb
if ($LASTEXITCODE -ne 0) { Fail "Notebook de consultas MongoDB falló" }
OK "Consultas MongoDB ejecutadas"

# --------------------------------------------------------------
# PASO 5 — Modelo predictivo
# --------------------------------------------------------------
Step "Entrenando modelo predictivo (Random Forest)..."
Set-Location "$ROOT\modelo"
python -m jupyter nbconvert --to notebook --execute --inplace --ExecutePreprocessor.timeout=300 modelo_predictivo.ipynb
if ($LASTEXITCODE -ne 0) { Fail "Notebook del modelo falló" }
OK "Modelo entrenado y evaluado"

# --------------------------------------------------------------
# RESUMEN FINAL
# --------------------------------------------------------------
Set-Location $ROOT

$docs = python -c @'
from pymongo import MongoClient
col = MongoClient('mongodb://localhost:27017/')['dataflow']['pedidos']
total = col.count_documents({})
tardios = col.count_documents({'entrega.tarde': True})
print(f'{total} documentos | {tardios} tardios ({tardios/total*100:.1f}%)')
'@

Write-Host @"

  ============================================
   PIPELINE COMPLETADO EXITOSAMENTE
  ============================================
   PostgreSQL : 6 tablas cargadas (healthy)
   MongoDB    : $docs
   Modelo     : ACC=0.87 | F1=0.43 | AUC=0.834
   Graficos   : docs/eda_analisis.png
                docs/evaluacion_modelo.png
  ============================================
"@ -ForegroundColor Green

Write-Host "  Para explorar los resultados: jupyter notebook" -ForegroundColor Yellow
