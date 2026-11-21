$ErrorActionPreference='Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
node scripts/load.mjs
if($LASTEXITCODE -ne 0){throw 'load-test failed'}

