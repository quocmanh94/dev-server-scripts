# Загрузка локализации
$localesPath = Join-Path $PSScriptRoot "locales.json"
$script:locales = Get-Content -Path $localesPath -Raw | ConvertFrom-Json

# Функция для определения языка системы
function Get-SystemLanguage {
    $systemLocale = (Get-WinSystemLocale).Name
    if ($systemLocale -like "ru*") {
        return "ru"
    }
    return "en"
}

# Определение языка из конфигурации или системы
function Set-CurrentLanguage {
    param (
        [string]$configLang = "auto"
    )

    # Если язык задан явно и существует в локализации
    if ($configLang -ne "auto" -and ($configLang -eq "ru" -or $configLang -eq "en")) {
        $script:currentLocale = $configLang
        return
    }

    # Иначе определяем язык системы
    $script:currentLocale = Get-SystemLanguage
}

# Функция для получения локализованной строки
function Get-LocalizedString {
    param (
        [string]$Key,
        [array]$FormatArgs = @()
    )

    # Разбиваем ключ на части (для вложенных объектов)
    $keyParts = $Key.Split('.')

    # Начинаем с корня локализации для текущего языка
    $current = $script:locales.$script:currentLocale

    # Проходим по частям ключа
    foreach ($part in $keyParts) {
        $current = $current.$part
        if ($null -eq $current) {
            # Получаем имя текущей функции и строку с номером
            $callStack = Get-PSCallStack
            $caller = $callStack[1]
            $location = "$($caller.ScriptName):$($caller.ScriptLineNumber)"

            # Формируем сообщение об ошибке
            $errorMessage = "Missing localization key '$Key' in $script:currentLocale locale at $location"

            # Записываем в лог с уровнем Debug, чтобы не засорять консоль
            Write-Debug $errorMessage

            # Возвращаем ключ в квадратных скобках, чтобы было видно, что это отсутствующий перевод
            return "[$Key]"
        }
    }

    # Если есть аргументы для форматирования
    if ($FormatArgs.Count -gt 0) {
        return [string]::Format($current, $FormatArgs)
    }

    return $current
}

# Скрипт для загрузки конфигурации из JSON файла
$configPath = Join-Path $PSScriptRoot "..\config.json"
$script:isFirstRun = $false

# Обновляем функцию Write-ColorOutput для поддержки прямых строк
function Write-ColorOutput {
    param (
        [Parameter(Mandatory=$true)]
        [AllowEmptyString()]
        [string]$Message,
        [array]$FormatArgs = @(),
        [string]$ForegroundColor = "White",
        [string]$Prefix = "",
        [switch]$NoNewLine,
        [switch]$NoLocalization
    )

    $prefixColor = "DarkGray"

    if ($Prefix) {
        # Устанавливаем фиксированную ширину для префиксов
        $prefix = "[" + (Get-LocalizedString $Prefix).PadRight(7) + "]"
        Write-Host $prefix -ForegroundColor $prefixColor -NoNewline
        Write-Host " " -NoNewline
    }

    # Если строка пустая или не требует локализации, используем её как есть
    $outputMessage = if ($NoLocalization -or $Message -eq "" -or $Message -match "^[=\s]*$") {
        $Message
    } else {
        Get-LocalizedString -Key $Message -FormatArgs $FormatArgs
    }

    if ($NoNewLine) {
        Write-Host $outputMessage -ForegroundColor $ForegroundColor -NoNewline
    } else {
        Write-Host $outputMessage -ForegroundColor $ForegroundColor
    }
}

# Обновляем функцию Write-ConfigParam для корректной обработки пустых значений
function Write-ConfigParam {
    param (
        [string]$LabelKey,
        [string]$Value,
        [string]$ForegroundColor = "White",
        [int]$Padding = 0
    )

    $label = Get-LocalizedString -Key $LabelKey
    Write-Host "$($label.PadRight($padding)): " -ForegroundColor "Cyan" -NoNewline

    # Обрабатываем пустые значения
    if ([string]::IsNullOrEmpty($Value)) {
        $Value = "-"
    }

    # Выводим значение напрямую без локализации
    Write-Host $Value -ForegroundColor $ForegroundColor
}

# Функция для создания ярлыков
function New-DayZShortcut {
    param (
        [string]$scriptPath,
        [string]$shortcutName,
        [string]$arguments,
        [string]$description,
        [string]$iconType
    )

    # Проверяем и создаем папку для ярлыков, если её нет
    $linksFolder = Join-Path $PSScriptRoot "..\links"
    if (-not (Test-Path $linksFolder)) {
        New-Item -ItemType Directory -Path $linksFolder | Out-Null
        Write-ColorOutput "shortcuts.folder_created" -ForegroundColor "Yellow" -Prefix "prefixes.shortcut" -FormatArgs @("links")
    }

    # Проверяем наличие папки с иконками
    $iconsFolder = Join-Path $PSScriptRoot "icons"
    if (-not (Test-Path $iconsFolder)) {
        Write-ColorOutput "shortcuts.icons_not_found" -ForegroundColor "Red" -Prefix "ОШИБКА" -FormatArgs @("icons")
        exit 1
    }

    # Проверяем наличие .ico файла
    $iconFile = Join-Path $iconsFolder "$iconType.ico"
    if (-not (Test-Path $iconFile)) {
        Write-ColorOutput "shortcuts.icon_not_found" -ForegroundColor "Red" -Prefix "ОШИБКА" -FormatArgs @($iconType)
        exit 1
    }

    $WshShell = New-Object -ComObject WScript.Shell
    $shortcutPath = Join-Path $linksFolder "$shortcutName.lnk"
    $shortcut = $WshShell.CreateShortcut($shortcutPath)

    $shortcut.TargetPath = "pwsh.exe"
    $shortcut.Arguments = "-NoLogo -ExecutionPolicy Bypass -File `"$scriptPath`" $arguments"
    $shortcut.Description = $description
    $shortcut.WorkingDirectory = Split-Path $scriptPath -Parent
    $shortcut.IconLocation = "$iconFile,0"

    $shortcut.Save()

    Write-ColorOutput "shortcuts.created" -ForegroundColor "Green" -Prefix "prefixes.shortcut" -FormatArgs @($shortcutName)
}

# Функция для создания всех ярлыков
function New-DayZShortcuts {
    $scriptDir = $PSScriptRoot
    $rootDir = Split-Path $scriptDir -Parent

    # Ярлыки для запуска
    New-DayZShortcut -scriptPath "$rootDir\start.ps1" -shortcutName "Start Server" `
        -arguments "server" -description (Get-LocalizedString "shortcuts.descriptions.start_server") -iconType "server-start"

    New-DayZShortcut -scriptPath "$rootDir\start.ps1" -shortcutName "Start Client" `
        -arguments "client" -description (Get-LocalizedString "shortcuts.descriptions.start_client") -iconType "client-start"

    New-DayZShortcut -scriptPath "$rootDir\start.ps1" -shortcutName "Start All" `
        -arguments "all" -description (Get-LocalizedString "shortcuts.descriptions.start_all") -iconType "all-start"

    # Ярлыки для остановки
    New-DayZShortcut -scriptPath "$scriptDir\kill.ps1" -shortcutName "Kill Server" `
        -arguments "server" -description (Get-LocalizedString "shortcuts.descriptions.kill_server") -iconType "server-stop"

    New-DayZShortcut -scriptPath "$scriptDir\kill.ps1" -shortcutName "Kill Client" `
        -arguments "client" -description (Get-LocalizedString "shortcuts.descriptions.kill_client") -iconType "client-stop"

    New-DayZShortcut -scriptPath "$scriptDir\kill.ps1" -shortcutName "Kill All" `
        -arguments "all" -description (Get-LocalizedString "shortcuts.descriptions.kill_all") -iconType "all-stop"
}

# Функция для обработки путей модов
function Resolve-ModPath {
    param (
        [string]$modPath
    )

    if ($modPath.StartsWith('$steam/')) {
        return $modPath.Replace('$steam/', $steamWorkshopPath)
    }
    elseif ($modPath.StartsWith('$local/')) {
        return $modPath.Replace('$local/', $localModsPath)
    }
    else {
        return $modPath
    }
}

# Добавим функцию для нормализации путей
function Format-Path {
    param (
        [string]$path
    )

    if (-not $path) {
        return $path
    }

    # Заменяем обратные слеши на прямые и добавляем слеш в конце, если его нет
    $normalizedPath = $path.Replace('\', '/')
    if (-not $normalizedPath.EndsWith('/')) {
        $normalizedPath = "$normalizedPath/"
    }

    return $normalizedPath
}

# Добавим новую функцию для поиска пути установки DayZ
function Find-DayZInstallPath {
    $steamPaths = @(
    # Стандартный путь установки Steam
        "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam",
        # Альтернативный путь для 32-битных систем
        "HKLM:\SOFTWARE\Valve\Steam"
    )

    $steamPath = $null
    foreach ($path in $steamPaths) {
        if (Test-Path $path) {
            $steamPath = (Get-ItemProperty -Path $path -Name "InstallPath").InstallPath
            break
        }
    }

    if (-not $steamPath) {
        return $null
    }

    # Получаем список библиотек Steam из файла libraryfolders.vdf
    $libraryFoldersPath = Join-Path $steamPath "steamapps\libraryfolders.vdf"
    if (-not (Test-Path $libraryFoldersPath)) {
        return $null
    }

    $content = Get-Content $libraryFoldersPath -Raw
    # Ищем все пути к библиотекам Steam
    $libraries = [regex]::Matches($content, '"path"\s+"([^"]+)"') | ForEach-Object { $_.Groups[1].Value.Replace("\\", "\") }

    # DayZ App ID
    $dayzAppId = "221100"

    # Проверяем каждую библиотеку на наличие DayZ
    foreach ($lib in $libraries) {
        $dayzPath = Join-Path $lib "steamapps\common\DayZ"
        $dayzExpPath = Join-Path $lib "steamapps\common\DayZ Exp"
        $manifestPath = Join-Path $lib "steamapps\appmanifest_$dayzAppId.acf"

        if (Test-Path $manifestPath) {
            # Нашли установленную игру, нормализуем пути
            $paths = @{
                Release = if (Test-Path $dayzPath) { Format-Path $dayzPath } else { $null }
                Experimental = if (Test-Path $dayzExpPath) { Format-Path $dayzExpPath } else { $null }
                Workshop = if (Test-Path $dayzPath) { Format-Path (Join-Path $dayzPath "!Workshop") } else { $null }
            }
            return $paths
        }
    }

    return $null
}

# Проверка наличия файла конфигурации и создание его, если отсутствует
if (-not (Test-Path $configPath)) {
    $script:isFirstRun = $true
    Set-CurrentLanguage

    # Установка заголовка окна при первом запуске
    $host.UI.RawUI.WindowTitle = Get-LocalizedString "window_title_first_run"

    Write-ColorOutput "first_run.title" -ForegroundColor "Yellow"
    Write-ColorOutput "first_run.searching" -ForegroundColor "White"

    $dayzPaths = Find-DayZInstallPath
    if ($dayzPaths) {
        Write-ColorOutput "first_run.found" -ForegroundColor "Green"
        if ($dayzPaths.Release) {
            Write-ColorOutput "first_run.release_version" -ForegroundColor "White" -FormatArgs @($dayzPaths.Release)
        }
        if ($dayzPaths.Experimental) {
            Write-ColorOutput "first_run.experimental_version" -ForegroundColor "White" -FormatArgs @($dayzPaths.Experimental)
        }
        if ($dayzPaths.Workshop) {
            Write-ColorOutput "first_run.workshop_folder" -ForegroundColor "White" -FormatArgs @($dayzPaths.Workshop)
        }
        Write-ColorOutput " " -NoLocalization
    } else {
        Write-ColorOutput "first_run.not_found" -ForegroundColor "Yellow"
        Write-ColorOutput "first_run.using_defaults" -ForegroundColor "Yellow"
        Write-ColorOutput " " -NoLocalization
    }

    Write-ColorOutput "first_run.creating_config" -ForegroundColor "White"

    # Используем найденные пути или пути по умолчанию с нормализацией
    $defaultGamePath = if ($dayzPaths -and $dayzPaths.Release) { $dayzPaths.Release } else { "e:/SteamLibrary/steamapps/common/DayZ/" }
    $defaultExpGamePath = if ($dayzPaths -and $dayzPaths.Experimental) { $dayzPaths.Experimental } else { "e:/SteamLibrary/steamapps/common/DayZ Exp/" }
    $defaultWorkshopPath = if ($dayzPaths -and $dayzPaths.Workshop) { $dayzPaths.Workshop } else { "e:/SteamLibrary/steamapps/common/DayZ/!Workshop/" }

    $defaultConfig = @{
        active = @{
            serverPreset = "release"
            modPreset = "vanilla"
            autoCloseTime = 20
            lang = "auto"
        }

        serverPresets = @{
            release = @{
                gamePath = $defaultGamePath
                serverPath = "e:/DayZServer/"
                profilePath = "e:/DayZServer/profiles/"
                serverPort = 2400
                serverConfig = "ServerDev.cfg"
                isDiagMode = $false
                isExperimental = $false
                cleanLogs = "all"
                workshop = @{
                    steam = $defaultWorkshopPath
                    local = "e:/PDrive/"
                }
            }

            experimental = @{
                gamePath = $defaultExpGamePath
                serverPath = "e:/DayZServerExperimental/"
                profilePath = "e:/DayZServerExperimental/profiles/"
                serverPort = 2400
                serverConfig = "ServerDev.cfg"
                cleanLogs = "server"
                isDiagMode = $false
                isExperimental = $true
                workshop = @{
                    steam = $defaultWorkshopPath
                    local = "e:/PDrive/"
                }
            }
        }

        modsPresets = @{
            vanilla = @{
                client = @()
                server = @()
            }

            myPreset1 = @{
                client = @(
                    "`$steam/@CF"
                    "`$steam/@Dabs Framework"
                    "`$steam/@VPPAdminTools"
                    "`$steam/@Notifications"
                )
                server = @(
                    "My_serverMod"
                    "`$local/@MPG_Spawner"
                )
            }
        }
    }

    # Сохраняем конфигурацию
    $jsonConfig = $defaultConfig | ConvertTo-Json -Depth 10
    $jsonConfig | Set-Content -Path $configPath -Encoding UTF8

    Write-ColorOutput "first_run.config_created" -ForegroundColor "Green" -FormatArgs @($configPath)

    Write-ColorOutput "first_run.creating_shortcuts" -ForegroundColor "White"
    New-DayZShortcuts
    Write-ColorOutput "first_run.shortcuts_created" -ForegroundColor "Green"

    # Добавляем пустую строку перед списком шагов
    Write-ColorOutput " " -NoLocalization
    Write-ColorOutput "first_run.what_next" -ForegroundColor "Yellow"
    $steps = Get-LocalizedString "first_run.next_steps"
    foreach ($step in $steps) {
        Write-Host $step -ForegroundColor "White"
    }

    if (-not $dayzPaths) {
        Write-ColorOutput "first_run.set_game_paths" -ForegroundColor "White" -Prefix "ВАЖНО"
    }
    return
}

# Загрузка конфигурации
$config = Get-Content -Path $configPath -Raw | ConvertFrom-Json

# Получение выбранных пресетов
$selectedServerPreset = $config.active.serverPreset
$selectedModPreset = $config.active.modPreset
$autoCloseTime = $config.active.autoCloseTime

# Устанавливаем язык по умолчанию из системы
Set-CurrentLanguage $config.active.lang

# Если autoCloseTime не задан, устанавливаем значение по умолчанию
if (-not $autoCloseTime) {
    $autoCloseTime = 20
}

# Проверка существования выбранных пресетов
if (-not $config.serverPresets.$selectedServerPreset) {
    Write-ColorOutput "errors.preset_not_found" -ForegroundColor "Red" -Prefix "ОШИБКА" -FormatArgs @("server", $selectedServerPreset)
    exit 1
}

if (-not $config.modsPresets.$selectedModPreset) {
    Write-ColorOutput "errors.preset_not_found" -ForegroundColor "Red" -Prefix "ОШИБКА" -FormatArgs @("mod", $selectedModPreset)
    exit 1
}

# Загрузка настроек сервера
$serverPreset = $config.serverPresets.$selectedServerPreset
$modPreset = $config.modsPresets.$selectedModPreset

# Установка переменных из пресета сервера
$gamePath = $serverPreset.gamePath
$serverPath = $serverPreset.serverPath
$profilePath = $serverPreset.profilePath
$serverPort = $serverPreset.serverPort
$serverConfig = $serverPreset.serverConfig
$isDiagMode = $serverPreset.isDiagMode
$isExperimental = $serverPreset.isExperimental
$cleanLogsMode = $serverPreset.cleanLogs

# Обработка путей к модам
$steamWorkshopPath = $serverPreset.workshop.steam
$localModsPath = $serverPreset.workshop.local

# После загрузки конфигурации нормализуем все пути
$gamePath = Format-Path $serverPreset.gamePath
$serverPath = Format-Path $serverPreset.serverPath
$profilePath = Format-Path $serverPreset.profilePath
$steamWorkshopPath = Format-Path $serverPreset.workshop.steam
$localModsPath = Format-Path $serverPreset.workshop.local

# Формирование строк модов для клиента и сервера
$clientMods = @()
foreach ($mod in $modPreset.client) {
    $clientMods += (Resolve-ModPath $mod)
}

$serverMods = @()
foreach ($mod in $modPreset.server) {
    $serverMods += (Resolve-ModPath $mod)
}

# Объединение модов в строки для параметров запуска
$mod = $clientMods -join ";"
$serverMod = $serverMods -join ";"

# Определение режима очистки логов
$shouldClearLogs = $cleanLogsMode -ne "none"
$clearLogsClient = $cleanLogsMode -eq "all" -or $cleanLogsMode -eq "client"
$clearLogsServer = $cleanLogsMode -eq "all" -or $cleanLogsMode -eq "server"

# Определение пути к логам клиента в зависимости от типа сборки
if ($isExperimental) {
    $clientLogsPath = "$env:LOCALAPPDATA\DayZ Exp"
} else {
    $clientLogsPath = "$env:LOCALAPPDATA\DayZ"
}

