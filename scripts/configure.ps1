$ErrorActionPreference='Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
$keys=@('POSTGRES_PASSWORD','ACCOUNT_DB_PASSWORD','LEDGER_DB_PASSWORD','TRANSFER_DB_PASSWORD','PROJECTION_DB_PASSWORD','ACCOUNT_MIGRATION_PASSWORD','LEDGER_MIGRATION_PASSWORD','TRANSFER_MIGRATION_PASSWORD','PROJECTION_MIGRATION_PASSWORD','OPERATOR_PASSWORD','SERVICE_PASSWORD','GRAFANA_PASSWORD')
if (Test-Path -LiteralPath '.env') { $lines=Get-Content -LiteralPath '.env' } else {
 $lines=foreach($key in $keys){$bytes=New-Object byte[] 32;[Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes);"$key=$([Convert]::ToHexString($bytes))"}
 [IO.File]::WriteAllLines((Join-Path (Get-Location) '.env'),$lines)
}
New-Item -ItemType Directory -Force -Path artifacts | Out-Null
$secret=($lines | Where-Object { $_.StartsWith('OPERATOR_PASSWORD=') }).Split('=')[1]
[IO.File]::WriteAllText((Join-Path (Get-Location) 'artifacts/prometheus-auth'),$secret)
Write-Output 'Generated local-only credentials in ignored .env and artifacts/.'

