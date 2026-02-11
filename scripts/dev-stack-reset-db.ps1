[CmdletBinding()]
param(
  [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$composeFile = Join-Path $repoRoot "deploy/dev/compose.yml"

if (-not $Force) {
  $answer = Read-Host "RESET dev DB volume (docker compose down -v). This deletes local Postgres data. Type 'reset' to confirm"
  if ($answer -ne 'reset') {
    Write-Host "Aborted."
    exit 2
  }
}

& docker compose -f $composeFile down -v
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "Dev stack stopped and volumes removed."
