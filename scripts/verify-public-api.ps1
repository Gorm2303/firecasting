[CmdletBinding()]
param(
  [string]$BaseUrl = "https://api.local.test",
  [int]$ConnectTimeoutSec = 3,
  [string]$OutDir = $null
)

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
if ([string]::IsNullOrWhiteSpace($OutDir)) {
  $OutDir = Join-Path $repoRoot "deploy/dev/out"
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

function Out-Path {
  param([Parameter(Mandatory)] [string]$Name)
  Join-Path $OutDir $Name
}

$ErrorActionPreference = "Stop"

function Invoke-Curl {
  param(
    [Parameter(Mandatory)] [string]$Name,
    [Parameter(Mandatory)] [string]$Method,
    [Parameter(Mandatory)] [string]$Url,
    [int]$MaxTimeSec = 15,
    [string[]]$Headers = @(),
    [string]$OutFile = $null,
    [string]$BodyFile = $null,
    [string]$FormFile = $null
  )

  $args = @(
    "-4", "-k", "-sS",
    "--connect-timeout", "$ConnectTimeoutSec",
    "--max-time", "$MaxTimeSec",
    "-X", $Method,
    "-w", "%{http_code}"
  )

  foreach ($h in $Headers) {
    $args += @("-H", $h)
  }

  if ($OutFile) {
    $args += @("-o", $OutFile)
  } else {
    $args += @("-o", "NUL")
  }

  if ($BodyFile) {
    $args += @("--data-binary", "@$BodyFile")
  }

  if ($FormFile) {
    # Field name must match @RequestPart("file")
    $args += @("-F", "file=@$FormFile;type=application/json")
  }

  $args += $Url

  $code = & curl.exe @args
  [pscustomobject]@{
    Name = $Name
    Method = $Method
    Url = $Url
    Status = [int]$code
  }
}

$results = New-Object System.Collections.Generic.List[object]

# 1) Forms + Schemas
$results.Add((Invoke-Curl -Name "GET /api/forms/advanced-simulation" -Method GET -Url "$BaseUrl/api/forms/advanced-simulation" -Headers @("accept: application/json") -OutFile (Out-Path "forms.json")))
$results.Add((Invoke-Curl -Name "GET /api/simulation/schema/simulation" -Method GET -Url "$BaseUrl/api/simulation/schema/simulation" -Headers @("accept: application/json") -OutFile (Out-Path "schema-sim.json")))
$results.Add((Invoke-Curl -Name "GET /api/simulation/schema/phase" -Method GET -Url "$BaseUrl/api/simulation/schema/phase" -Headers @("accept: application/json") -OutFile (Out-Path "schema-phase.json")))

# 2) Start (normal) with a known-good payload based on schema options
$startReq = @{ 
  startDate = (Get-Date -Format "yyyy-MM-dd")
  overallTaxRule = "Capital"
  taxPercentage = 0.0
  returnPercentage = 5.0
  seed = 1
  phases = @(
    @{
      phaseType = "DEPOSIT"
      durationInMonths = 12
      initialDeposit = 1000.0
      monthlyDeposit = 100.0
      yearlyIncreaseInPercentage = 0.0
      lowerVariationPercentage = 0.0
      upperVariationPercentage = 0.0
      withdrawRate = 0.0
      withdrawAmount = 0.0
      taxRules = @()
    }
  )
}
$startRequestPath = Out-Path "start-request.json"
$startResponsePath = Out-Path "start-response.json"
$queuePath = Out-Path "queue.json"
$progressPath = Out-Path "progress.txt"
$exportCsvPath = Out-Path "export.csv"
$bundlePath = Out-Path "bundle.json"
$exportAllCsvPath = Out-Path "export-all.csv"
$runsPath = Out-Path "runs.json"
$lookupPath = Out-Path "lookup.json"
$runDetailsPath = Out-Path "run-details.json"
$runSummariesPath = Out-Path "run-summaries.json"
$runInputPath = Out-Path "run-input.json"
$startAdvancedPath = Out-Path "start-advanced.json"
$importJsonPath = Out-Path "import-json.json"
$importMultipartPath = Out-Path "import-multipart.json"
$replayStatusPath = Out-Path "replay-status.json"
$diffPath = Out-Path "diff.json"

$startReq | ConvertTo-Json -Depth 20 | Set-Content -Encoding utf8 $startRequestPath

$results.Add((Invoke-Curl -Name "POST /api/simulation/start" -Method POST -Url "$BaseUrl/api/simulation/start" -Headers @("accept: application/json", "Content-Type: application/json") -BodyFile $startRequestPath -OutFile $startResponsePath -MaxTimeSec 25))

$startResp = Get-Content -Raw $startResponsePath | ConvertFrom-Json
$simulationId = $startResp.id
if (-not $simulationId) { throw "No id returned from /start" }

# 3) Queue + Progress
$results.Add((Invoke-Curl -Name "GET /api/simulation/queue/{id}" -Method GET -Url "$BaseUrl/api/simulation/queue/$simulationId" -Headers @("accept: application/json") -OutFile $queuePath -MaxTimeSec 10))

# Progress SSE: just validate it answers 200 and emits something quickly
$results.Add((Invoke-Curl -Name "GET /api/simulation/progress/{id} (SSE)" -Method GET -Url "$BaseUrl/api/simulation/progress/$simulationId" -Headers @("accept: text/event-stream") -OutFile $progressPath -MaxTimeSec 5))

# 4) Export + Bundle
$results.Add((Invoke-Curl -Name "GET /api/simulation/{id}/export" -Method GET -Url "$BaseUrl/api/simulation/$simulationId/export" -OutFile $exportCsvPath -MaxTimeSec 25))
$results.Add((Invoke-Curl -Name "GET /api/simulation/{id}/bundle" -Method GET -Url "$BaseUrl/api/simulation/$simulationId/bundle" -Headers @("accept: application/json") -OutFile $bundlePath -MaxTimeSec 25))

# 5) Global export
$results.Add((Invoke-Curl -Name "GET /api/simulation/export" -Method GET -Url "$BaseUrl/api/simulation/export" -OutFile $exportAllCsvPath -MaxTimeSec 25))

# 6) Runs list + lookup + details + summaries + input
$results.Add((Invoke-Curl -Name "GET /api/simulation/runs" -Method GET -Url "$BaseUrl/api/simulation/runs?limit=5" -Headers @("accept: application/json") -OutFile $runsPath -MaxTimeSec 10))
$results.Add((Invoke-Curl -Name "POST /api/simulation/runs/lookup" -Method POST -Url "$BaseUrl/api/simulation/runs/lookup" -Headers @("accept: application/json", "Content-Type: application/json") -BodyFile $startRequestPath -OutFile $lookupPath -MaxTimeSec 15))

$lookup = Get-Content -Raw $lookupPath | ConvertFrom-Json
$runId = $lookup.runId
if (-not $runId) { throw "No runId returned from /runs/lookup" }

$results.Add((Invoke-Curl -Name "GET /api/simulation/runs/{runId}" -Method GET -Url "$BaseUrl/api/simulation/runs/$runId" -Headers @("accept: application/json") -OutFile $runDetailsPath -MaxTimeSec 10))
$results.Add((Invoke-Curl -Name "GET /api/simulation/runs/{runId}/summaries" -Method GET -Url "$BaseUrl/api/simulation/runs/$runId/summaries" -Headers @("accept: application/json") -OutFile $runSummariesPath -MaxTimeSec 10))
$results.Add((Invoke-Curl -Name "GET /api/simulation/runs/{runId}/input" -Method GET -Url "$BaseUrl/api/simulation/runs/$runId/input" -Headers @("accept: application/json") -OutFile $runInputPath -MaxTimeSec 10))

# 7) Start advanced (should usually dedup)
$results.Add((Invoke-Curl -Name "POST /api/simulation/start-advanced" -Method POST -Url "$BaseUrl/api/simulation/start-advanced" -Headers @("accept: application/json", "Content-Type: application/json") -BodyFile $runInputPath -OutFile $startAdvancedPath -MaxTimeSec 25))

# 8) Import (both JSON and multipart)
$results.Add((Invoke-Curl -Name "POST /api/simulation/import (json)" -Method POST -Url "$BaseUrl/api/simulation/import" -Headers @("accept: application/json", "Content-Type: application/json") -BodyFile $bundlePath -OutFile $importJsonPath -MaxTimeSec 25))
$results.Add((Invoke-Curl -Name "POST /api/simulation/import (multipart)" -Method POST -Url "$BaseUrl/api/simulation/import" -Headers @("accept: application/json") -FormFile $bundlePath -OutFile $importMultipartPath -MaxTimeSec 25))

$importResp = Get-Content -Raw $importJsonPath | ConvertFrom-Json
$replayId = $importResp.replayId
if (-not $replayId) { throw "No replayId returned from import" }

$results.Add((Invoke-Curl -Name "GET /api/simulation/replay/{replayId}" -Method GET -Url "$BaseUrl/api/simulation/replay/$replayId" -Headers @("accept: application/json") -OutFile $replayStatusPath -MaxTimeSec 15))

# 9) Diff: pick another run if available, else diff against itself
$existingRuns = Get-Content -Raw $runsPath | ConvertFrom-Json
$otherRunId = ($existingRuns | Where-Object { $_.id -and $_.id -ne $runId } | Select-Object -First 1).id
if (-not $otherRunId) { $otherRunId = $runId }

$results.Add((Invoke-Curl -Name "GET /api/simulation/diff/{a}/{b}" -Method GET -Url "$BaseUrl/api/simulation/diff/$runId/$otherRunId" -Headers @("accept: application/json") -OutFile $diffPath -MaxTimeSec 20))

# Report
$failed = $results | Where-Object { $_.Status -lt 200 -or $_.Status -ge 300 }

"\nResults:" | Write-Host
$results | Select-Object Name, Status, Method, Url | Format-Table -AutoSize | Out-String | Write-Host

if ($failed.Count -gt 0) {
  "\nFAILED:" | Write-Host
  $failed | Select-Object Name, Status | Format-Table -AutoSize | Out-String | Write-Host
  exit 1
}

"\nAll public API calls succeeded." | Write-Host
exit 0
