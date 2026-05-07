$ErrorActionPreference = "Stop"

$rootDir = Split-Path -Parent $PSScriptRoot
$apiBase = if ($env:NEXT_PUBLIC_API_BASE_URL) { $env:NEXT_PUBLIC_API_BASE_URL } else { "http://127.0.0.1:8797" }

if (Get-Command conda -ErrorAction SilentlyContinue) {
    conda activate rag_task
} elseif (Test-Path "$HOME\miniconda3\shell\condabin\conda-hook.ps1") {
    . "$HOME\miniconda3\shell\condabin\conda-hook.ps1"
    conda activate rag_task
} else {
    Write-Error "Conda is not available. Open this script from a shell with conda initialized."
}

Set-Location "$rootDir\apps\web"
npm install
$env:NEXT_PUBLIC_API_BASE_URL = $apiBase
npm run dev -- --port 3007
