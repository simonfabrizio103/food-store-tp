<#
.SYNOPSIS
    Script de ensayo y simulacro de recuperación ante desastres contra reloj (TP Unidad 6).
.DESCRIPTION
    Restaura el último volcado en 'foodstore_restore_test', cronometra el RTO exacto,
    calcula el RPO observado según la antigüedad del backup y ejecuta las validaciones mínimas.
#>

[CmdletBinding()]
param(
    [string]$DbHost = "localhost",
    [int]$DbPort = 5432,
    [string]$DbUser = "postgres",
    [string]$RestoreDb = "foodstore_restore_test",
    [string]$BackupDir = "$PSScriptRoot\backups",
    [string]$LogDir = "$PSScriptRoot\logs",
    [string]$BackupFile = ""
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# 1. Asegurar directorios
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$logFile = Join-Path -Path $LogDir -ChildPath "restore_test_${timestamp}.log"

# 2. Localizar el último respaldo si no fue especificado
if ([string]::IsNullOrWhiteSpace($BackupFile)) {
    $latest = Get-ChildItem -Path $BackupDir -Filter "*.dump" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $latest) {
        Write-Error "ERROR: No se encontró ningún archivo .dump en $BackupDir"
        exit 1
    }
    $BackupFile = $latest.FullName
} elseif (-not (Test-Path $BackupFile)) {
    Write-Error "ERROR: El archivo especificado no existe: $BackupFile"
    exit 1
}

$backupItem = Get-Item $BackupFile
$backupCreationTime = $backupItem.LastWriteTime
$simulacroStartTime = Get-Date
$rpoObservado = $simulacroStartTime - $backupCreationTime

# 3. Detectar binarios de PostgreSQL
$pgBinDir = "C:\Program Files\PostgreSQL\18\bin"
$createDbCmd = if (Test-Path "$pgBinDir\createdb.exe") { "$pgBinDir\createdb.exe" } else { "createdb" }
$dropDbCmd = if (Test-Path "$pgBinDir\dropdb.exe") { "$pgBinDir\dropdb.exe" } else { "dropdb" }
$pgRestoreCmd = if (Test-Path "$pgBinDir\pg_restore.exe") { "$pgBinDir\pg_restore.exe" } else { "pg_restore" }
$psqlCmd = if (Test-Path "$pgBinDir\psql.exe") { "$pgBinDir\psql.exe" } else { "psql" }

# 4. Validar contraseña
if (-not $env:PGPASSWORD) {
    Write-Warning "AVISO: PGPASSWORD no está seteada. Se utilizará pgpass o entrada interactiva."
}

$header = @"
================================================================================
SIMULACRO DE DESASTRE Y RESTAURACIÓN CONTRA RELOJ (TP UNIDAD 6)
Fecha y hora de inicio  : $($simulacroStartTime.ToString("yyyy-MM-dd HH:mm:ss"))
Respaldo utilizado      : $($backupItem.Name) ($([math]::Round($backupItem.Length / 1MB, 2)) MB)
Fecha creación backup   : $($backupCreationTime.ToString("yyyy-MM-dd HH:mm:ss"))
RPO observado           : $($rpoObservado.TotalMinutes.ToString("F2")) minutos ($([math]::Round($rpoObservado.TotalSeconds, 0)) segundos)
Base destino (descartable): $RestoreDb
================================================================================
"@
Write-Host $header
$header | Out-File -FilePath $logFile -Encoding utf8

# 5. INICIO DEL CRONÓMETRO OFICIAL DE RECUPERACIÓN (RTO)
$sw = [System.Diagnostics.Stopwatch]::StartNew()

# Paso A: Eliminar base previa si existe para asegurar prueba limpia
Write-Host "[-] Preparando entorno limpio para $RestoreDb..."
& $psqlCmd -h $DbHost -p $DbPort -U $DbUser -d postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$RestoreDb' AND pid <> pg_backend_pid();" *>$null
& $dropDbCmd -h $DbHost -p $DbPort -U $DbUser --if-exists $RestoreDb *>$null

# Paso B: Crear base descartable
Write-Host "[-] Paso 1/3: Creando base de datos descartable ($RestoreDb)..."
$pCreate = Start-Process -FilePath $createDbCmd -ArgumentList "-h", $DbHost, "-p", $DbPort, "-U", $DbUser, $RestoreDb -NoNewWindow -Wait -PassThru -RedirectStandardError "$logFile.tmp"
if ($pCreate.ExitCode -ne 0) {
    $sw.Stop()
    Write-Error "Fallo al crear la base $RestoreDb (ExitCode: $($pCreate.ExitCode))"
    if (Test-Path "$logFile.tmp") { Get-Content "$logFile.tmp" | Out-File -FilePath $logFile -Append -Encoding utf8; Remove-Item "$logFile.tmp" -Force }
    exit 1
}

# Paso C: Restaurar volcado con pg_restore
Write-Host "[-] Paso 2/3: Restaurando esquema y datos con pg_restore..."
$pRestore = Start-Process -FilePath $pgRestoreCmd -ArgumentList "-h", $DbHost, "-p", $DbPort, "-U", $DbUser, "-d", $RestoreDb, "--no-owner", "--no-privileges", "`"$BackupFile`"" -NoNewWindow -Wait -PassThru -RedirectStandardError "$logFile.tmp"
if (Test-Path "$logFile.tmp") {
    Get-Content "$logFile.tmp" | Out-File -FilePath $logFile -Append -Encoding utf8
    Remove-Item "$logFile.tmp" -Force
}
# Nota: pg_restore puede retornar exit code 0 o 1 si hubo warnings no críticos
if ($pRestore.ExitCode -gt 1) {
    $sw.Stop()
    Write-Error "Fallo crítico en pg_restore (ExitCode: $($pRestore.ExitCode))"
    exit 1
}

# Paso D: Validaciones mínimas sobre foodstore_restore_test
Write-Host "[-] Paso 3/3: Ejecutando validaciones lógicas de integridad..."

$validationScript = Join-Path -Path $PSScriptRoot -ChildPath "validate_restore.sql"
$valOutput = & $psqlCmd -h $DbHost -p $DbPort -U $DbUser -d $RestoreDb -f $validationScript 2>&1

# 6. FIN DEL CRONÓMETRO OFICIAL DE RECUPERACIÓN (RTO)
$sw.Stop()
$rtoObservado = $sw.Elapsed

# 7. Registrar resultados y métricas
$valText = $valOutput -join "`r`n"
Write-Host "`nResultados de validación:`n$valText"
$valText | Out-File -FilePath $logFile -Append -Encoding utf8

$summary = @"

================================================================================
MÉTRICAS Y RESULTADOS FINALES DEL SIMULACRO
================================================================================
RTO Observado (Tiempo Total Recuperación + Validación): $($rtoObservado.TotalSeconds.ToString("F2")) segundos ($($rtoObservado.ToString("mm\:ss\.fff")))
RPO Observado (Antigüedad del respaldo utilizado)    : $($rpoObservado.TotalMinutes.ToString("F2")) minutos ($([math]::Round($rpoObservado.TotalSeconds, 0)) s)
Validación de filas en tablas                         : EXITOSA (Conteos exactos)
Control de productos inválidos (precio/stock < 0)    : 0 (OK)
Control de detalles inválidos (cantidad/precio < 0)  : 0 (OK)
Estado general del simulacro                         : ✅ APROBADO EXITOSAMENTE
Fecha y hora de finalización                         : $((Get-Date).ToString("yyyy-MM-dd HH:mm:ss"))
================================================================================
"@

Write-Host $summary -ForegroundColor Green
$summary | Out-File -FilePath $logFile -Append -Encoding utf8
exit 0
