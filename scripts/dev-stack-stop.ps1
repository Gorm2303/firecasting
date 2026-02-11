[CmdletBinding()]
param(
  [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$composeFile = Join-Path $repoRoot "deploy/dev/compose.yml"

if (-not $Force) {
  $answer = Read-Host "Stop dev stack (docker compose down)? Type 'yes' to confirm"
  if ($answer -ne 'yes') {
    Write-Host "Aborted."
    exit 2
  }
}

& docker compose -f $composeFile down
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "Dev stack stopped."
