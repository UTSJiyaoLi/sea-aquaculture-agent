$ErrorActionPreference = "Stop"

$rootDir = Split-Path -Parent $PSScriptRoot
$cmdPath = Join-Path $rootDir "deploy\local_start_frontend.cmd"
$frontendDir = Join-Path $rootDir "apps\web"

if (-not (Test-Path $cmdPath)) {
    Write-Error "Missing script: $cmdPath"
}

if (-not $env:FRONTEND_DIR) {
    $env:FRONTEND_DIR = $frontendDir
}

cmd /c "`"$cmdPath`""
