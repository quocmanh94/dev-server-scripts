param (
    [Parameter(Mandatory=$false)]
    [ValidateSet("server", "client", "all")]
    [string]$mode = "all"
)

# Загружаем общие функции и конфигурацию
$scriptPath = $MyInvocation.MyCommand.Path
$scriptDir = Split-Path -Parent $scriptPath
. (Join-Path $scriptDir "config.ps1")

# Устанавливаем заголовок окна
$host.UI.RawUI.WindowTitle = Get-LocalizedString "window_title"

# Функция для остановки сервера
function Stop-DayZServer {
    Write-ColorOutput "info.stopping_server" -ForegroundColor "Yellow" -Prefix "СЕРВЕР"
    Stop-Process -Name "DayZServer_x64" -Force -ErrorAction SilentlyContinue
}

# Функция для остановки клиента
function Stop-DayZClient {
    Write-ColorOutput "info.stopping_client" -ForegroundColor "Yellow" -Prefix "КЛИЕНТ"
    Stop-Process -Name "DayZ_x64" -Force -ErrorAction SilentlyContinue
}

# Останавливаем компоненты в зависимости от выбранного режима
switch ($mode) {
    "server" { Stop-DayZServer }
    "client" { Stop-DayZClient }
    "all" {
        Stop-DayZServer
        Stop-DayZClient
    }
}

Write-ColorOutput "info.launch_complete" -ForegroundColor "Green" -Prefix "СИСТЕМА"

# Запускаем таймер
if ($autoCloseTime -gt 0) {
    1..$autoCloseTime | ForEach-Object {
        $timeLeft = $autoCloseTime - $_ + 1
        $host.UI.RawUI.WindowTitle = Get-LocalizedString "window_title_closing" -FormatArgs @($timeLeft)
        Start-Sleep -Seconds 1
    }
}

