<#
.SYNOPSIS
  Marca como verificado el correo de una cuenta registrada en el servidor de demostración de Render.

.DESCRIPTION
  En el plan gratuito de Render el correo no sale (SMTP bloqueado), así que el código de verificación
  nunca llega. Después de que alguien se registre en la app, ejecute esto con su correo y ya podrá
  ingresar. Pide la "External Database URL" sin mostrarla. Requiere Docker.

.EXAMPLE
  .\verify_account.ps1 -Email persona@correo.co
#>
param([Parameter(Mandatory = $true)][string]$Email)

$ErrorActionPreference = 'Stop'

$secure = Read-Host -Prompt 'External Database URL de agrovet-db (postgresql://...)' -AsSecureString
$ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
try { $databaseUrl = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr) }
finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) }
if (-not $databaseUrl.StartsWith('postgresql://') -and -not $databaseUrl.StartsWith('postgres://')) {
    throw 'La dirección debe empezar con postgresql:// (cópiela de Connections > External Database URL).'
}
if ($databaseUrl -notmatch 'sslmode=') {
    $databaseUrl += $(if ($databaseUrl.Contains('?')) { '&sslmode=require' } else { '?sslmode=require' })
}

try {
    $env:DATABASE_URL = $databaseUrl
    $env:ACCOUNT_EMAIL = $Email
    docker run --rm -e DATABASE_URL -e ACCOUNT_EMAIL -v "${PSScriptRoot}:/seed:ro" postgres:15-alpine `
        sh -c 'psql "$DATABASE_URL" -X -q -f /seed/verify_account.sql'
    if ($LASTEXITCODE -ne 0) { throw "Falló (código $LASTEXITCODE)." }
    Write-Host 'Si la fila dice email_verified = t, la persona ya puede ingresar. Sin filas: ese correo no está registrado.'
}
finally {
    Remove-Item Env:DATABASE_URL, Env:ACCOUNT_EMAIL -ErrorAction SilentlyContinue
    $databaseUrl = $null
}
