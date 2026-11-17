<#
.SYNOPSIS
  Compila el APK de demostración (arm64) que apunta al servidor de Render, con la demostración local
  como respaldo.

.DESCRIPTION
  -ApiBaseUrl es la dirección del servidor (https://<servicio>.onrender.com). El APK queda con:
    - API_BASE_URL: ingreso con cuenta real, vacas, historial, sincronización, asistente y fotos.
    - DEMO_MODE=true: sigue ofreciendo "Entrar a la demostración", que funciona sin internet ni
      servidor (respaldo si Render está dormido, vencido o caído).
    - UDDER_TRIAGE=true: triaje visual experimental de la ubre, como el APK de demostración actual.
  Con -AlsoWithoutServer compila además el APK solo de demostración (sin API_BASE_URL).
  -BuildName y -BuildNumber cambian la versión solo de este APK (sin tocar pubspec.yaml), para
  instalarlo encima de uno anterior: Android exige un código de versión mayor. Con --split-per-abi el
  código del APK arm64 es 2000 + BuildNumber.
  Revisa que cada APK pese a lo sumo 15 MB, el mismo límite del CI.

.EXAMPLE
  .\tool\build_demo_apk.ps1 -ApiBaseUrl https://agrovet-api.onrender.com -AlsoWithoutServer

.EXAMPLE
  .\tool\build_demo_apk.ps1 -ApiBaseUrl https://agrovet-api.onrender.com -BuildName 0.2.2 -BuildNumber 4
#>
param(
    [Parameter(Mandatory = $true)][string]$ApiBaseUrl,
    [switch]$AlsoWithoutServer,
    # Por defecto mobile\build\demo-apk
    [string]$OutDir,
    # Por defecto, los de pubspec.yaml
    [string]$BuildName,
    [int]$BuildNumber
)

$ErrorActionPreference = 'Stop'
$limit = 15 * 1024 * 1024
if (-not $OutDir) { $OutDir = Join-Path $PSScriptRoot '..\build\demo-apk' }

$ApiBaseUrl = $ApiBaseUrl.TrimEnd('/')
$uri = $null
if (-not [Uri]::TryCreate($ApiBaseUrl, [UriKind]::Absolute, [ref]$uri) -or $uri.Scheme -ne 'https' -or
    $uri.AbsolutePath -ne '/' -or $uri.Query) {
    # La app publicada rechaza HTTP y la ruta la pone el cliente (/api/...)
    throw "La dirección debe ser HTTPS y sin ruta, por ejemplo https://agrovet-api.onrender.com (llegó: $ApiBaseUrl)"
}

$flutter = if ($env:FLUTTER) { $env:FLUTTER } else { 'flutter' }
$mobile = Resolve-Path (Join-Path $PSScriptRoot '..')
New-Item -ItemType Directory -Force $OutDir | Out-Null

function Build-Apk([string[]]$defines, [string]$name) {
    $buildArgs = @('build', 'apk', '--release', '--split-per-abi', '--target-platform', 'android-arm64') +
            ($defines | ForEach-Object { "--dart-define=$_" })
    if ($BuildName) { $buildArgs += @('--build-name', $BuildName) }
    if ($BuildNumber -gt 0) { $buildArgs += @('--build-number', "$BuildNumber") }
    Push-Location $mobile
    try {
        & $flutter @buildArgs
        if ($LASTEXITCODE -ne 0) { throw "flutter build falló (código $LASTEXITCODE)" }
    }
    finally { Pop-Location }
    $target = Join-Path $OutDir $name
    Copy-Item (Join-Path $mobile 'build\app\outputs\flutter-apk\app-arm64-v8a-release.apk') $target -Force
    $size = (Get-Item $target).Length
    $hash = (Get-FileHash $target -Algorithm SHA256).Hash.ToLower()
    Write-Output ("{0}: {1:N0} bytes ({2:N1} MB), SHA-256 {3}" -f $name, $size, ($size / 1MB), $hash)
    if ($size -gt $limit) { throw "$name pasa del límite de 15 MB" }
}

Build-Apk @("API_BASE_URL=$ApiBaseUrl", 'DEMO_MODE=true', 'UDDER_TRIAGE=true') 'agrovet-demo-render-arm64.apk'
if ($AlsoWithoutServer) {
    Build-Apk @('DEMO_MODE=true', 'UDDER_TRIAGE=true') 'agrovet-demo-sin-servidor-arm64.apk'
}
Write-Host "APK en $(Resolve-Path $OutDir)"
