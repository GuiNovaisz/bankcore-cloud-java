$ErrorActionPreference='Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
docker compose down
if($LASTEXITCODE -ne 0){throw 'dev-down failed'}

