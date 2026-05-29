#requires -Version 5.1
<#
.SYNOPSIS
  Aplica migrations 0033/0034/0035 e faz deploy da Edge Function lender-api.

.PARAMETER Token
  Personal Access Token do Supabase. Gere em:
    https://supabase.com/dashboard/account/tokens

.EXAMPLE
  .\scripts\deploy-credora.ps1 -Token sbp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
#>
param(
  [Parameter(Mandatory = $true)]
  [string]$Token
)

$ErrorActionPreference = "Stop"
$PROJECT_REF = "kyvbnntoxslrtrsiejzc"
$API_QUERY = "https://api.supabase.com/v1/projects/$PROJECT_REF/database/query"

function Invoke-SupabaseSql {
  param([string]$Path)
  $name = Split-Path $Path -Leaf
  Write-Host "  -> $name" -ForegroundColor DarkCyan
  $sql = Get-Content -Raw -Encoding UTF8 $Path
  $body = @{ query = $sql } | ConvertTo-Json -Depth 5 -Compress
  try {
    $res = Invoke-RestMethod `
      -Uri $API_QUERY `
      -Method POST `
      -Headers @{ "Authorization" = "Bearer $Token"; "Content-Type" = "application/json" } `
      -Body $body
    Write-Host "     OK ($($res.Count) row(s))" -ForegroundColor Green
  } catch {
    $err = $_.ErrorDetails.Message
    if (-not $err) { $err = $_.Exception.Message }
    Write-Host "     FAIL: $err" -ForegroundColor Red
    throw
  }
}

# 1. Migrations
Write-Host "[1/4] Aplicando migration 0033 (RPC get_lender_report)..." -ForegroundColor Cyan
Invoke-SupabaseSql "supabase\migrations\0033_lender_report.sql"

Write-Host "[2/4] Aplicando migration 0034 (lender-api tables)..." -ForegroundColor Cyan
Invoke-SupabaseSql "supabase\migrations\0034_lender_api.sql"

Write-Host "[3/4] Aplicando migration 0035 (native coverage + carbon)..." -ForegroundColor Cyan
Invoke-SupabaseSql "supabase\migrations\0035_native_coverage.sql"

# 2. Edge Function deploy
Write-Host "[4/4] Deploy Edge Function lender-api..." -ForegroundColor Cyan
$env:SUPABASE_ACCESS_TOKEN = $Token
$deploy = & npx -y supabase functions deploy lender-api --project-ref $PROJECT_REF --no-verify-jwt 2>&1
$deploy | ForEach-Object { Write-Host "     $_" }
if ($LASTEXITCODE -ne 0) {
  Write-Host "     deploy FAILED (exit $LASTEXITCODE)" -ForegroundColor Red
  exit 1
}

# 3. Smoke test: backfill native coverage e listar lender_clients
Write-Host "`n[smoke] compute_native_coverage_batch + select..." -ForegroundColor Cyan
$smoke = @{
  query = "SELECT public.compute_native_coverage_batch() AS batch_result, (SELECT COUNT(*) FROM lender_clients) AS lenders, (SELECT COUNT(*) FROM property_native_coverage) AS native_rows;"
} | ConvertTo-Json -Compress
$res = Invoke-RestMethod -Uri $API_QUERY -Method POST -Headers @{ "Authorization" = "Bearer $Token"; "Content-Type" = "application/json" } -Body $smoke
$res | ConvertTo-Json -Depth 5 | Write-Host

Write-Host "`nDONE. Endpoint pronto:" -ForegroundColor Green
Write-Host "  GET https://$PROJECT_REF.supabase.co/functions/v1/lender-api/property/<uuid>" -ForegroundColor Green
Write-Host "       Header: X-Lender-Key: <api_key gerada via create_lender_client>" -ForegroundColor Green
