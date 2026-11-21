$ErrorActionPreference='Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
$secret=((Get-Content -LiteralPath '.env') | Where-Object { $_.StartsWith('OPERATOR_PASSWORD=') }).Split('=')[1]
$env:LOAD_BASIC_AUTH=[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("operator:$secret"))
try { docker compose --profile load run --rm k6 } finally { Remove-Item Env:LOAD_BASIC_AUTH }
if($LASTEXITCODE -ne 0){throw 'load-test failed'}

