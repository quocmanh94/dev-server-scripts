# Скрипт для запуска сервера и/или клиента DayZ
param (
    [Parameter(Position = 0)]
    [ValidateSet("all", "server", "client", "")]
    [string]$startType = "all"
)

# Загрузка конфигурации
. "$PSScriptRoot\scripts\config.ps1"

# Установка заголовка окна
$host.UI.RawUI.WindowTitle = Get-LocalizedString "window_title"

# Проверка на первый запуск
if ($script:isFirstRun) {
    Write-ColorOutput "info.press_any_key" -ForegroundColor "Yellow"
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    exit 0
}

# Определение имен исполняемых файлов в зависимости от режима
$serverExeName = if ($isDiagMode) { "DayZDiag_x64.exe" } else { "DayZServer_x64.exe" }
$clientExeName = if ($isDiagMode) { "DayZDiag_x64.exe" } else { "DayZ_BE.exe" }
$isFilePatching = $serverPreset.isFilePatching

# Проверка наличия исполняемых файлов
$serverExe = if ($isDiagMode) { "$gamePath\$serverExeName" } else { "$serverPath\$serverExeName" }
$clientExe = "$gamePath\$clientExeName"

if (($startType -eq "all" -or $startType -eq "server") -and -not (Test-Path $serverExe)) {
    Write-ColorOutput "errors.executable_not_found" -ForegroundColor "Red" -Prefix "prefixes.error" -FormatArgs @("server", $serverExe)
    exit 1
}

if (($startType -eq "all" -or $startType -eq "client") -and -not (Test-Path $clientExe)) {
    Write-ColorOutput "errors.executable_not_found" -ForegroundColor "Red" -Prefix "prefixes.error" -FormatArgs @("client", $clientExe)
    exit 1
}

# Обновляем проверку пути к миссии, убирая Trim('/')
if ($isDiagMode -and [string]::IsNullOrEmpty($missionPath)) {
    Write-ColorOutput "errors.mission_path_required" -ForegroundColor "Red" -Prefix "prefixes.error"
    exit 1
}

if ($isDiagMode -and -not (Test-Path $missionPath)) {
    Write-ColorOutput "errors.mission_path_not_found" -ForegroundColor "Red" -Prefix "prefixes.error" -FormatArgs @($missionPath)
    exit 1
}

# Вывод информации о конфигурации
Write-ColorOutput "info.server_config" -ForegroundColor "Cyan"
Write-ColorOutput "separator" -ForegroundColor "Cyan"
Write-ConfigParam "info.server_preset" -Padding 16 $selectedServerPreset
Write-ConfigParam "info.mod_preset" -Padding 16 $selectedModPreset
if ($isExperimental) {
    Write-ConfigParam "info.build_type" (Get-LocalizedString "info.experimental") "Yellow"
}
if ($isDiagMode) {
    Write-ConfigParam "info.mode" (Get-LocalizedString "info.diagnostic") "Yellow"
    Write-ConfigParam "info.mission_path" $missionPath "Yellow"
}
Write-Host ""

# Остановка процессов только если не указан конкретный тип запуска
if (-not $startType) {
    Write-ColorOutput "info.stopping_server" -ForegroundColor "Yellow" -Prefix "prefixes.server"
    Stop-Process -Name "DayZServer_x64" -Force -ErrorAction SilentlyContinue
    Stop-Process -Name "DayZDiag_x64" -Force -ErrorAction SilentlyContinue

    Write-ColorOutput "info.stopping_client" -ForegroundColor "Yellow" -Prefix "prefixes.client"
    Stop-Process -Name "DayZ_x64" -Force -ErrorAction SilentlyContinue
}
# Иначе останавливаем только нужный процесс
else {
    if ($startType -eq "server") {
        Write-ColorOutput "info.stopping_server" -ForegroundColor "Yellow" -Prefix "prefixes.server"
        Stop-Process -Name "DayZServer_x64" -Force -ErrorAction SilentlyContinue
        Stop-Process -Name "DayZDiag_x64" -Force -ErrorAction SilentlyContinue
    }
    elseif ($startType -eq "client") {
        Write-ColorOutput "info.stopping_client" -ForegroundColor "Yellow" -Prefix "prefixes.client"
        Stop-Process -Name "DayZ_x64" -Force -ErrorAction SilentlyContinue
    }
}

# Очистка логов, если требуется
if ($shouldClearLogs) {
    Write-ColorOutput "info.clearing_logs" -ForegroundColor "Yellow" -Prefix "prefixes.logs"
    . "$PSScriptRoot\scripts\clearlogs.ps1"
}

# Запуск сервера
if ((Test-Path $serverPath) -and (($startType -eq "all" -or $startType -eq "server") -or -not $startType)) {
    # Вывод информации о модах
    if ($mod) {
        Write-ColorOutput "info.client_mods" -ForegroundColor "Cyan" -Prefix "prefixes.system"
        $clientMods | ForEach-Object {
            Write-ColorOutput "info.list_item" -ForegroundColor "White" -Prefix "prefixes.system" -FormatArgs @($_)
        }
        Write-Host ""
    }

    if ($serverMod) {
        Write-ColorOutput "info.server_mods" -ForegroundColor "Cyan" -Prefix "prefixes.system"
        $serverMods | ForEach-Object {
            Write-ColorOutput "info.list_item" -ForegroundColor "White" -Prefix "prefixes.system" -FormatArgs @($_)
        }
        Write-Host ""
    }

    Write-ColorOutput "info.starting_server" -ForegroundColor "Green" -Prefix "prefixes.system" -FormatArgs @($serverPort)

    $serverArgs = @(
        "-config=$serverConfig",
        "-profiles=$profilePath",
        "-port=$serverPort",
        "-dologs",
        "-adminlog",
        "-freezecheck",
        "-logToFile=1",
        "-doScriptLogs=1"
    )

    if ($isDiagMode) {
        $serverArgs += "-server"
        $serverArgs += "-mission=$missionPath"
        $serverArgs += "-newErrorsAreWarnings=1"
    }

    if ($mod) { $serverArgs += """-mod=$mod""" }
    if ($serverMod) { $serverArgs += """-serverMod=$serverMod""" }
    if ($isFilePatching) { $serverArgs += "-filePatching" }

    Start-Process -FilePath $serverExe -ArgumentList $serverArgs
}

# Запуск клиента
if ((Test-Path $gamePath) -and (($startType -eq "all" -or $startType -eq "client") -or -not $startType)) {
    Write-ColorOutput "info.starting_client" -ForegroundColor "Green" -Prefix "prefixes.system" -FormatArgs @($serverPort)

    Push-Location $gamePath

    $clientArgs = @(
        "-connect=127.0.0.1",
        "-port=$serverPort",
        "-nosplash",
        "-noPause",
        "-noBenchmark",
        "-doLogs"
    )

    if ($isDiagMode) {
        $clientArgs += "-newErrorsAreWarnings=1"
    }

    if ($mod) { $clientArgs += """-mod=$mod""" }
    if ($isFilePatching) { $clientArgs += "-filePatching" }

    Start-Process -FilePath $clientExe -ArgumentList $clientArgs
    Pop-Location
}

Write-ColorOutput "info.launch_complete" -ForegroundColor "Green" -Prefix "prefixes.system"

# Автозакрытие консоли только если autoCloseTime больше 0
if ($autoCloseTime -gt 0) {
    1..$autoCloseTime | ForEach-Object {
        $timeLeft = $autoCloseTime - $_ + 1
        $host.UI.RawUI.WindowTitle = Get-LocalizedString "window_title_closing" -FormatArgs @($timeLeft)
        Start-Sleep -Seconds 1
    }
}