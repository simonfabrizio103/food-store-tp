<#
.SYNOPSIS
    Script de respaldo automatizado para la base de datos Food Store (TP Unidad 6).
.DESCRIPTION
    Genera un volcado en formato custom (-Fc) con timestamp y registra el log de ejecución.
    Cumple con las directivas de seguridad: no almacena contraseñas y finaliza con error si falla.
#>

[CmdletBinding()]
param(
    [string]$DbHost = "localhost",
    [int]$DbPort = 5432,
    [string]$DbUser = "postgres",
    [string]$DbName = "foodstore",
    [string]$BackupDir = "$PSScriptRoot\backups",
    [string]$LogDir = "$PSScriptRoot\logs"
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# 1. Asegurar directorios de salida
if (-not (Test-Path -Path $BackupDir)) {
    New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
}
if (-not (Test-Path -Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

# 2. Generar marcas de tiempo y nombres de archivo
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$dumpFileName = "foodstore_${timestamp}.dump"
$dumpFilePath = Join-Path -Path $BackupDir -ChildPath $dumpFileName
$logFileName = "backup_${timestamp}.log"
$logFilePath = Join-Path -Path $LogDir -ChildPath $logFileName

# 3. Detectar binario pg_dump
$pgDumpCmd = "pg_dump"
if (-not (Get-Command $pgDumpCmd -ErrorAction SilentlyContinue)) {
    $standardPath = "C:\Program Files\PostgreSQL\18\bin\pg_dump.exe"
    if (Test-Path -Path $standardPath) {
        $pgDumpCmd = $standardPath
    } else {
        $found = Get-ChildItem "C:\Program Files\PostgreSQL" -Recurse -Filter "pg_dump.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) {
            $pgDumpCmd = $found.FullName
        } else {
            Write-Error "CRÍTICO: No se encontró el binario pg_dump en el PATH ni en archivos de programa."
            exit 1
        }
    }
}

# 4. Validar credenciales (sin contraseñas hardcodeadas)
if (-not $env:PGPASSWORD) {
    Write-Warning "AVISO: La variable de entorno PGPASSWORD no está configurada. PostgreSQL solicitará contraseña interactiva o usará pgpass."
}

# 5. Ejecutar respaldo y registrar log
$startTime = Get-Date
$logHeader = @"
================================================================================
RESPALDO AUTOMATIZADO DE FOOD STORE (UNIDAD 6)
Fecha y hora de inicio : $($startTime.ToString("yyyy-MM-dd HH:mm:ss"))
Motor de base de datos : PostgreSQL
Base de datos origen   : $DbName
Host / Puerto / Usuario: ${DbHost}:${DbPort} / $DbUser
Archivo de destino     : $dumpFilePath
Formato                : Custom (-Fc, comprimido)
================================================================================
"@

Write-Host $logHeader
$logHeader | Out-File -FilePath $logFilePath -Encoding utf8

$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

# Ejecutar pg_dump capturando salida y errores
$process = Start-Process -FilePath $pgDumpCmd -ArgumentList "-h", $DbHost, "-p", $DbPort, "-U", $DbUser, "-d", $DbName, "-Fc", "-f", "`"$dumpFilePath`"" -NoNewWindow -Wait -PassThru -RedirectStandardError "$logFilePath.tmp"

$stopwatch.Stop()
$elapsed = $stopwatch.Elapsed

# Concatenar salida de error si la hubo
if (Test-Path "$logFilePath.tmp") {
    Get-Content "$logFilePath.tmp" | Out-File -FilePath $logFilePath -Append -Encoding utf8
    Remove-Item "$logFilePath.tmp" -Force
}

# 6. Evaluar código de salida y emitir resultado
if ($process.ExitCode -eq 0 -and (Test-Path -Path $dumpFilePath)) {
    $dumpSize = (Get-Item -Path $dumpFilePath).Length
    $dumpSizeMB = [math]::Round($dumpSize / 1MB, 2)
    
    $logSuccess = @"
--------------------------------------------------------------------------------
ESTADO: EXITOSO
Tiempo transcurrido    : $($elapsed.TotalSeconds.ToString("F2")) segundos
Tamaño del volcado     : $dumpSize bytes ($dumpSizeMB MB)
Código de retorno      : 0
Fecha y hora de fin    : $((Get-Date).ToString("yyyy-MM-dd HH:mm:ss"))
================================================================================
"@
    Write-Host $logSuccess -ForegroundColor Green
    $logSuccess | Out-File -FilePath $logFilePath -Append -Encoding utf8
    exit 0
} else {
    $logError = @"
--------------------------------------------------------------------------------
ESTADO: FALLIDO
Código de retorno      : $($process.ExitCode)
Tiempo transcurrido    : $($elapsed.TotalSeconds.ToString("F2")) segundos
Fecha y hora de fin    : $((Get-Date).ToString("yyyy-MM-dd HH:mm:ss"))
ERROR: pg_dump finalizó con errores. Verifique conectividad y permisos.
================================================================================
"@
    Write-Host $logError -ForegroundColor Red
    $logError | Out-File -FilePath $logFilePath -Append -Encoding utf8
    exit 1
}
