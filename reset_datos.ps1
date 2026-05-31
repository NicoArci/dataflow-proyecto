# =============================================================
# DataFlow — Reset de bases de datos para demo
# Uso: .\reset_datos.ps1
# Vacía PostgreSQL y MongoDB para demostrar el pipeline desde cero.
# =============================================================

$ErrorActionPreference = 'Continue'
$ROOT = $PSScriptRoot

function Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function OK($msg)   { Write-Host "    [OK] $msg" -ForegroundColor Green }
function Info($msg) { Write-Host "    $msg" -ForegroundColor Gray }

Write-Host "`n  [RESET] Vaciando bases de datos para demo...`n" -ForegroundColor Yellow

Set-Location $ROOT

# Verificar que los contenedores estén corriendo
$pgStatus = (docker inspect --format "{{.State.Health.Status}}" dataflow-postgres 2>$null) | Select-Object -First 1
if ($pgStatus -ne "healthy") {
    Write-Host "  Contenedores no están corriendo. Levantando Docker primero..." -ForegroundColor Yellow
    docker-compose up -d | Out-Null
    Start-Sleep -Seconds 15
}

# --------------------------------------------------------------
# 1. Vaciar PostgreSQL (TRUNCATE respeta el esquema DDL)
# --------------------------------------------------------------
Step "Vaciando PostgreSQL..."

$antes = docker exec dataflow-postgres psql -U dataflow_user -d dataflow -t -c "SELECT COUNT(*) FROM orders" 2>$null |
         Where-Object { "$_".Trim() -match '^\d+$' } | Select-Object -First 1

docker exec dataflow-postgres psql -U dataflow_user -d dataflow -q -c @"
TRUNCATE order_reviews, order_items, orders, products, sellers, customers
RESTART IDENTITY CASCADE;
"@

$despues = docker exec dataflow-postgres psql -U dataflow_user -d dataflow -t -c "SELECT COUNT(*) FROM orders" 2>$null |
           Where-Object { "$_".Trim() -match '^\d+$' } | Select-Object -First 1

OK "PostgreSQL vaciado: $("$antes".Trim()) pedidos → $("$despues".Trim()) pedidos"
Info "Tablas conservadas: customers, sellers, products, orders, order_items, order_reviews"

# --------------------------------------------------------------
# 2. Vaciar MongoDB
# --------------------------------------------------------------
Step "Vaciando MongoDB (colección pedidos)..."

$antesMongo = python -c "
from pymongo import MongoClient
col = MongoClient('mongodb://localhost:27017/')['dataflow']['pedidos']
print(col.count_documents({}))
" 2>$null

python -c "
from pymongo import MongoClient
client = MongoClient('mongodb://localhost:27017/')
client['dataflow']['pedidos'].drop()
print('OK')
" 2>$null | Out-Null

$despuesMongo = python -c "
from pymongo import MongoClient
col = MongoClient('mongodb://localhost:27017/')['dataflow']['pedidos']
print(col.count_documents({}))
" 2>$null

OK "MongoDB vaciado: $("$antesMongo".Trim()) documentos → $("$despuesMongo".Trim()) documentos"

# --------------------------------------------------------------
# Resumen
# --------------------------------------------------------------
Write-Host @"

  ============================================
   RESET COMPLETADO
  ============================================
   PostgreSQL pedidos  : $("$despues".Trim())
   MongoDB documentos  : $("$despuesMongo".Trim())
  ============================================

  Ahora corre: .\run_pipeline.ps1
  El pipeline detectará las bases vacías y
  cargará todo el dataset desde los CSVs.
"@ -ForegroundColor Yellow
