<#
.SYNOPSIS
  Carga los datos de demostración SINTÉTICOS (un usuario verificado y 6 vacas) en la base de Render.

.DESCRIPTION
  Pide la "External Database URL" de la base y la contraseña del usuario de demostración sin
  mostrarlas. Ninguna de las dos queda en un archivo, en el historial de PowerShell ni en la línea de
  comandos de Docker: viajan como variables de entorno de este proceso y se borran al terminar.
  Requiere Docker (no hace falta instalar psql).

.EXAMPLE
  .\seed_demo.ps1 -Email demo@agrovet.co -Name "Ganadero demo"
#>
param(
    [Parameter(Mandatory = $true)][string]$Email,
    [string]$Name = 'Ganadero demo'
)

$ErrorActionPreference = 'Stop'

function Read-Secret([string]$prompt) {
    $secure = Read-Host -Prompt $prompt -AsSecureString
    $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) }
}

function Add-SslMode([string]$url) {
    # La conexión externa de Render exige TLS
    if ($url -match 'sslmode=') { return $url }
    if ($url.Contains('?')) { return "$url&sslmode=require" }
    return "$url`?sslmode=require"
}

$databaseUrl = Read-Secret 'External Database URL de agrovet-db (postgresql://...)'
if (-not $databaseUrl.StartsWith('postgresql://') -and -not $databaseUrl.StartsWith('postgres://')) {
    throw 'La dirección debe empezar con postgresql:// (cópiela de Connections > External Database URL).'
}
$password = Read-Secret 'Contraseña del usuario de demostración (8 a 72 caracteres)'
$again = Read-Secret 'Repita la contraseña'
if ($password -ne $again) { throw 'Las contraseñas no coinciden.' }
if ($password.Length -lt 8 -or $password.Length -gt 72) { throw 'La contraseña debe tener entre 8 y 72 caracteres.' }

$names = 'DATABASE_URL', 'DEMO_EMAIL', 'DEMO_NAME', 'DEMO_PASSWORD', 'PGCLIENTENCODING'
try {
    $env:DATABASE_URL = Add-SslMode $databaseUrl
    $env:DEMO_EMAIL = $Email
    $env:DEMO_NAME = $Name
    $env:DEMO_PASSWORD = $password
    $env:PGCLIENTENCODING = 'UTF8'
    # Solo el nombre de cada variable va en la línea de comandos; Docker toma el valor de este proceso
    docker run --rm -e DATABASE_URL -e DEMO_EMAIL -e DEMO_NAME -e DEMO_PASSWORD -e PGCLIENTENCODING `
        -v "${PSScriptRoot}:/seed:ro" postgres:15-alpine `
        sh -c 'psql "$DATABASE_URL" -X -q -f /seed/seed_demo.sql'
    if ($LASTEXITCODE -ne 0) { throw "La carga falló (código $LASTEXITCODE). No se cambió nada." }
    Write-Host "Listo: ingrese en la app con $Email y la contraseña que acaba de escribir."
}
finally {
    foreach ($n in $names) { Remove-Item "Env:$n" -ErrorAction SilentlyContinue }
    $password = $null; $again = $null; $databaseUrl = $null
}
