Param(
  [string[]]$Hosts = @(
    "fire.local.test.dk",
    "api.local.test.dk",
    "fire.local.test",
    "api.local.test",
    "localhost",
    "127.0.0.1"
  ),
  [string]$CertDir = "$(Split-Path -Parent $MyInvocation.MyCommand.Path)\certs",
  [string]$CertFile = "dev-local.crt",
  [string]$KeyFile  = "dev-local.key"
)

$ErrorActionPreference = "Stop"

function Require-Command([string]$Name) {
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    Write-Host "Missing required command: $Name" -ForegroundColor Red
    Write-Host "Install mkcert (pick one):" -ForegroundColor Yellow
    Write-Host "  winget install --id FiloSottile.mkcert" -ForegroundColor Yellow
    Write-Host "  choco install mkcert" -ForegroundColor Yellow
    throw "mkcert not found in PATH"
  }
}

Require-Command "mkcert"

New-Item -ItemType Directory -Force -Path $CertDir | Out-Null

Write-Host "Installing/trusting local CA (mkcert -install)..." -ForegroundColor Cyan
Write-Host "If this prompts for admin rights, accept it." -ForegroundColor Cyan
mkcert -install | Out-Host

$certPath = Join-Path $CertDir $CertFile
$keyPath  = Join-Path $CertDir $KeyFile

Write-Host "Generating dev cert:" -ForegroundColor Cyan
Write-Host "  $certPath" -ForegroundColor Cyan
Write-Host "  $keyPath" -ForegroundColor Cyan
Write-Host "Hosts:" -ForegroundColor Cyan
$Hosts | ForEach-Object { Write-Host "  - $_" -ForegroundColor Cyan }

# mkcert outputs files in PEM format, compatible with Traefik
mkcert -cert-file $certPath -key-file $keyPath @Hosts | Out-Host

Write-Host "Done. Restart Traefik to pick up the new cert:" -ForegroundColor Green
Write-Host "  docker compose --project-name firecasting-dev -f .\deploy\dev\compose.yml --env-file .\deploy\dev\.env up -d --force-recreate traefik" -ForegroundColor Green
