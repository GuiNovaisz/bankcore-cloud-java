$ErrorActionPreference='Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
& ./scripts/configure.ps1
docker compose --parallel 1 up -d --build --wait --wait-timeout 240
if($LASTEXITCODE -ne 0){throw 'dev-up failed'}

