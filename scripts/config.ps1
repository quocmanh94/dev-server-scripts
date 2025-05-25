# Load locales
$localesPath = Join-Path $PSScriptRoot "locales.json"
$script:locales = Get-Content -Path $localesPath -Raw | ConvertFrom-Json

# Function to determine system language
function Get-SystemLanguage {
	$systemLocale = (Get-WinSystemLocale).Name
	if ($systemLocale -like "ru*") {
		return "ru"
	}
	return "en"
}

# Set language from config or system
function Set-CurrentLanguage {
	param ([string]$configLang = "auto")

	if ($configLang -ne "auto" -and ($configLang -eq "ru" -or $configLang -eq "en")) {
		$script:currentLocale = $configLang
		return
	}

	$script:currentLocale = Get-SystemLanguage
}

# Function to get localized string
function Get-LocalizedString {
	param ([string]$Key, [array]$FormatArgs = @())

	$keyParts = $Key.Split('.')

	$current = $script:locales.$script:currentLocale

	foreach ($part in $keyParts) {
		$current = $current.$part
		if ($null -eq $current) {
			$callStack = Get-PSCallStack
			$caller = $callStack[1]
			$location = "$( $caller.ScriptName ):$( $caller.ScriptLineNumber )"

			$errorMessage = "Missing localization key '$Key' in $script:currentLocale locale at $location"

			Write-Debug $errorMessage

			return "[$Key]"
		}
	}

	if ($FormatArgs.Count -gt 0) {
		return [string]::Format($current, $FormatArgs)
	}

	return $current
}

$configPath = Join-Path $PSScriptRoot "..\config.json"
$script:isFirstRun = $false

function Write-ColorOutput {
	param ([Parameter(Mandatory = $true)]
		[AllowEmptyString()]
		[string]$Message, [array]$FormatArgs = @(), [string]$ForegroundColor = "White", [string]$Prefix = "", [switch]$NoNewLine, [switch]$NoLocalization)

	$prefixColor = "DarkGray"

	if ($Prefix) {
		$prefix = "[" + (Get-LocalizedString $Prefix).PadRight(7) + "]"
		Write-Host $prefix -ForegroundColor $prefixColor -NoNewline
		Write-Host " " -NoNewline
	}

	$outputMessage = if ($NoLocalization -or $Message -eq "" -or $Message -match "^[=\s]*$") {
		$Message
	}
	else {
		Get-LocalizedString -Key $Message -FormatArgs $FormatArgs
	}

	if ($NoNewLine) {
		Write-Host $outputMessage -ForegroundColor $ForegroundColor -NoNewline
	}
	else {
		Write-Host $outputMessage -ForegroundColor $ForegroundColor
	}
}

function Write-ConfigParam {
	param ([string]$LabelKey, [string]$Value, [string]$ForegroundColor = "White", [int]$Padding = 0)

	$label = Get-LocalizedString -Key $LabelKey
	Write-Host "$($label.PadRight($padding) ): " -ForegroundColor "Cyan" -NoNewline

	if ( [string]::IsNullOrEmpty($Value)) {
		$Value = "-"
	}

	Write-Host $Value -ForegroundColor $ForegroundColor
}

# Function to create shortcuts
function New-DayZShortcut {
	param ([string]$scriptPath, [string]$shortcutName, [string]$arguments, [string]$description, [string]$iconType)

	$linksFolder = Join-Path $PSScriptRoot "..\links"
	if (-not (Test-Path $linksFolder)) {
		New-Item -ItemType Directory -Path $linksFolder | Out-Null
		Write-ColorOutput "shortcuts.folder_created" -ForegroundColor "Yellow" -Prefix "prefixes.shortcut" -FormatArgs @("links")
	}

	$iconsFolder = Join-Path $PSScriptRoot "icons"
	if (-not (Test-Path $iconsFolder)) {
		Write-ColorOutput "shortcuts.icons_not_found" -ForegroundColor "Red" -Prefix "prefixes.error" -FormatArgs @("icons")
		Pause
		exit 1
	}

	$iconFile = Join-Path $iconsFolder "$iconType.ico"
	if (-not (Test-Path $iconFile)) {
		Write-ColorOutput "shortcuts.icon_not_found" -ForegroundColor "Red" -Prefix "prefixes.error" -FormatArgs @($iconType)
		Pause
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

# Function to create all shortcuts
function New-DayZShortcuts {
	$scriptDir = $PSScriptRoot
	$rootDir = Split-Path $scriptDir -Parent

	New-DayZShortcut -scriptPath "$rootDir\start.ps1" -shortcutName "Start Server" `
		-arguments "server" -description (Get-LocalizedString "shortcuts.descriptions.start_server") -iconType "server-start"

	New-DayZShortcut -scriptPath "$rootDir\start.ps1" -shortcutName "Start Client" `
		-arguments "client" -description (Get-LocalizedString "shortcuts.descriptions.start_client") -iconType "client-start"

	New-DayZShortcut -scriptPath "$rootDir\start.ps1" -shortcutName "Start All" `
		-arguments "all" -description (Get-LocalizedString "shortcuts.descriptions.start_all") -iconType "all-start"

	# Stop shortcuts
	New-DayZShortcut -scriptPath "$scriptDir\kill.ps1" -shortcutName "Kill Server" `
		-arguments "server" -description (Get-LocalizedString "shortcuts.descriptions.kill_server") -iconType "server-stop"

	New-DayZShortcut -scriptPath "$scriptDir\kill.ps1" -shortcutName "Kill Client" `
		-arguments "client" -description (Get-LocalizedString "shortcuts.descriptions.kill_client") -iconType "client-stop"

	New-DayZShortcut -scriptPath "$scriptDir\kill.ps1" -shortcutName "Kill All" `
		-arguments "all" -description (Get-LocalizedString "shortcuts.descriptions.kill_all") -iconType "all-stop"
}

# Function to process mod paths
function Resolve-ModPath {
	param ([string]$modPath)

	if ( $modPath.StartsWith('$steam/')) {
		return $modPath.Replace('$steam', $steamWorkshopPath)
	}
	elseif ($modPath.StartsWith('$local/')) {
		return $modPath.Replace('$local', $localModsPath)
	}
	else {
		return $modPath
	}
}

function Format-Path {
	param ([string]$path)

	if (-not $path) {
		return $path
	}

	# Replace backslashes with forward slashes
	$normalizedPath = $path.Replace('\', '/')

	return $normalizedPath
}


function Normalize-Path {
	param ([string]$path)

	if (-not $path) {
		return $path
	}

	$rollbackPath = $path.Replace('/', '\')

	return $rollbackPath
}

function Find-DayZInstallPath {
	$steamPaths = @(
		"HKLM:\SOFTWARE\WOW6432Node\Valve\Steam", "HKLM:\SOFTWARE\Valve\Steam"
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

	$libraryFoldersPath = Join-Path $steamPath "steamapps\libraryfolders.vdf"
	if (-not (Test-Path $libraryFoldersPath)) {
		return $null
	}

	$content = Get-Content $libraryFoldersPath -Raw
	$libraries = [regex]::Matches($content, '"path"\s+"([^"]+)"') | ForEach-Object { $_.Groups[1].Value.Replace("\\", "\") }

	$dayzAppId = "221100"

	foreach ($lib in $libraries) {
		$dayzPath = Join-Path $lib "steamapps\common\DayZ"
		$dayzExpPath = Join-Path $lib "steamapps\common\DayZ Exp"
		$manifestPath = Join-Path $lib "steamapps\appmanifest_$dayzAppId.acf"

		if (Test-Path $manifestPath) {
			$paths = @{
				Release = if (Test-Path $dayzPath) {
					Format-Path $dayzPath
				}
				else {
					$null
				}
				Experimental = if (Test-Path $dayzExpPath) {
					Format-Path $dayzExpPath
				}
				else {
					$null
				}
				Workshop = if (Test-Path $dayzPath) {
					Format-Path (Join-Path $dayzPath "!Workshop")
				}
				else {
					$null
				}
			}
			return $paths
		}
	}

	return $null
}

# Check for config file and create if missing
if (-not (Test-Path $configPath)) {
	$script:isFirstRun = $true
	Set-CurrentLanguage

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
	}
	else {
		Write-ColorOutput "first_run.not_found" -ForegroundColor "Yellow"
		Write-ColorOutput "first_run.using_defaults" -ForegroundColor "Yellow"
		Write-ColorOutput " " -NoLocalization
	}

	Write-ColorOutput "first_run.creating_config" -ForegroundColor "White"

	$defaultGamePath = if ($dayzPaths -and $dayzPaths.Release) {
		$dayzPaths.Release
	}
	else {
		"C:/SteamLibrary/steamapps/common/DayZ"
	}
	$defaultExpGamePath = if ($dayzPaths -and $dayzPaths.Experimental) {
		$dayzPaths.Experimental
	}
	else {
		"C:/SteamLibrary/steamapps/common/DayZ Exp"
	}
	$defaultWorkshopPath = if ($dayzPaths -and $dayzPaths.Workshop) {
		$dayzPaths.Workshop
	}
	else {
		"C:/SteamLibrary/steamapps/common/DayZ/!Workshop"
	}

	$defaultConfig = @{
		active = @{
			serverPreset = "release"
			modPreset = "vanilla"
			autoCloseTime = 10
			lang = "auto"
		}

		serverPresets = @{
			release = @{
				gamePath = $defaultGamePath
				serverPath = ""
				profilePath = ""
				missionPath = ""
				serverPort = 2302
				serverConfig = "serverDZ.cfg"
				isDiagMode = $false
				isExperimental = $false
				isFilePatching = $false
				isDisableBE = $false
				cleanLogs = "all"
				workshop = @{
					steam = $defaultWorkshopPath
					local = ""
				}
			}

			experimental = @{
				gamePath = $defaultExpGamePath
				serverPath = ""
				profilePath = ""
				missionPath = ""
				serverPort = 2400
				serverConfig = "ServerDev.cfg"
				cleanLogs = "server"
				isDiagMode = $false
				isExperimental = $true
				isFilePatching = $false
				isDisableBE = $false
				workshop = @{
					steam = $defaultWorkshopPath
					local = ""
				}
			}

			myPreset1 = @{
				gamePath = $defaultGamePath
				serverPath = "C:/DayZServer"
				profilePath = "C:/DayZServer/profiles"
				missionPath = ""
				serverPort = 2500
				serverConfig = "ServerDev.cfg"
				isDiagMode = $true
				isExperimental = $false
				isFilePatching = $false
				isDisableBE = $false
				cleanLogs = "all"
				workshop = @{
					steam = $defaultWorkshopPath
					local = "C:/PDrive"
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
					"`$steam/@VPPAdminTools"
					"`$steam/@Notifications"
					"`$local/@MyClientMod"
				)
				server = @(
					"My_ServerMod"
					"`$steam/@MPG_Spawner"
				)
			}
		}
	}

	$jsonConfig = $defaultConfig | ConvertTo-Json -Depth 10
	$jsonConfig | Set-Content -Path $configPath -Encoding UTF8

	Write-ColorOutput "first_run.config_created" -ForegroundColor "Green" -FormatArgs @($configPath)

	Write-ColorOutput "first_run.creating_shortcuts" -ForegroundColor "White"
	New-DayZShortcuts
	Write-ColorOutput "first_run.shortcuts_created" -ForegroundColor "Green"

	Write-ColorOutput " " -NoLocalization
	Write-ColorOutput "first_run.what_next" -ForegroundColor "Yellow"
	$steps = Get-LocalizedString "first_run.next_steps"
	foreach ($step in $steps) {
		Write-Host $step -ForegroundColor "White"
	}

	if (-not $dayzPaths) {
		Write-ColorOutput "first_run.set_game_paths" -ForegroundColor "White" -Prefix "prefixes.important"
	}
	return
}

$config = Get-Content -Path $configPath -Raw | ConvertFrom-Json

# Get selected presets
$selectedServerPreset = $config.active.serverPreset
$selectedModPreset = $config.active.modPreset
$autoCloseTime = $config.active.autoCloseTime

# Set default language from system
Set-CurrentLanguage $config.active.lang

# If autoCloseTime is not defined (null), set default value
if ($null -eq $autoCloseTime) {
	$autoCloseTime = 10
}

# Check if selected presets exist
if (-not $config.serverPresets.$selectedServerPreset) {
	Write-ColorOutput "errors.preset_not_found" -ForegroundColor "Red" -Prefix "prefixes.error" -FormatArgs @("server", $selectedServerPreset)
	Pause
	exit 1
}

if (-not $config.modsPresets.$selectedModPreset) {
	Write-ColorOutput "errors.preset_not_found" -ForegroundColor "Red" -Prefix "prefixes.error" -FormatArgs @("mod", $selectedModPreset)
	Pause
	exit 1
}

# Load server settings
$serverPreset = $config.serverPresets.$selectedServerPreset
$modPreset = $config.modsPresets.$selectedModPreset

# Set variables from server preset
$gamePath = $serverPreset.gamePath
$serverPath = $serverPreset.serverPath
$profilePath = $serverPreset.profilePath
$missionPath = $serverPreset.missionPath
$serverPort = $serverPreset.serverPort
$serverConfig = $serverPreset.serverConfig
$isDiagMode = $serverPreset.isDiagMode
$isFilePatching = $serverPreset.isFilePatching
$isDisableBE = $serverPreset.isDisableBE
$isExperimental = $serverPreset.isExperimental
$cleanLogsMode = $serverPreset.cleanLogs

# Process mod paths
$steamWorkshopPath = $serverPreset.workshop.steam
$localModsPath = $serverPreset.workshop.local

# Update path normalization after loading config
$gamePath = Format-Path $serverPreset.gamePath
$serverPath = Format-Path $serverPreset.serverPath
$profilePath = Format-Path $serverPreset.profilePath
$missionPath = Format-Path $serverPreset.missionPath
$steamWorkshopPath = Format-Path $serverPreset.workshop.steam
$localModsPath = Format-Path $serverPreset.workshop.local

# Build mod strings for client and server
$clientMods = @()
foreach ($mod in $modPreset.client) {
	$clientMods += (Resolve-ModPath $mod)
}

$serverMods = @()
foreach ($mod in $modPreset.server) {
	$serverMods += (Resolve-ModPath $mod)
}

# Combine mods into launch parameter strings
$mod = $clientMods -join ";"
$serverMod = $serverMods -join ";"

# Define log cleaning mode
$shouldClearLogs = $cleanLogsMode -ne "none"
$clearLogsClient = $cleanLogsMode -eq "all" -or $cleanLogsMode -eq "client"
$clearLogsServer = $cleanLogsMode -eq "all" -or $cleanLogsMode -eq "server"

# Define client logs path based on build type
if ($isExperimental) {
	$clientLogsPath = "$env:LOCALAPPDATA\DayZ Exp"
}
else {
	$clientLogsPath = "$env:LOCALAPPDATA\DayZ"
}