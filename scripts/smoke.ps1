$ErrorActionPreference='Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
node tests/e2e.mjs
if($LASTEXITCODE -ne 0){throw 'smoke failed'}

