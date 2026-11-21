$ErrorActionPreference='Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
docker run --rm -v "${PWD}:/workspace" -w /workspace maven:3.9.11-eclipse-temurin-21 mvn -B -ntp verify
if($LASTEXITCODE -ne 0){throw 'verify failed'}

