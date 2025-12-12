param ([Parameter(Mandatory = $false)]
	[ValidateSet("server", "client", "all")]
	[string]$mode = "all",

	[Parameter(Mandatory = $false)]
	[switch]$silent = $false)

$scriptPath = $MyInvocation.MyCommand.Path
$scriptDir = Split-Path -Parent $scriptPath
. (Join-Path $scriptDir "config.ps1")

$host.UI.RawUI.WindowTitle = Get-LocalizedString "window_title"

# Function to stop processes by command line arguments
function Stop-ProcessByCommandLine {
	param (
		[string]$ProcessName,
		[string]$CommandLineFilter,
		[string]$ProcessType
	)
	
	$processes = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
	if ($null -eq $processes) {
		return
	}
	
	# Convert single process to array
	if ($processes -isnot [array]) {
		$processes = @($processes)
	}
	
	$foundProcess = $false
	foreach ($proc in $processes) {
		$commandLine = $null
		try {
			$commandLine = (Get-CimInstance Win32_Process -Filter "ProcessId = $($proc.Id)").CommandLine
			if ($commandLine -and $commandLine -match $CommandLineFilter) {
				if (-not $foundProcess) {
					Write-ColorOutput "info.stopping_$ProcessType" -ForegroundColor "Yellow" -Prefix "prefixes.$ProcessType"
					$foundProcess = $true
				}
				Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
			}
		}
		catch {
			# If we can't get command line, skip this process (don't kill without confirmation)
		}
	}
}

# Function to stop the server
function Stop-DayZServer {
	if ($isDiagMode) {
		# In diag mode, server has "-server" argument
		Stop-ProcessByCommandLine -ProcessName "DayZDiag_x64" -CommandLineFilter "-server" -ProcessType "server"
	}
	else {
		# In normal mode, kill DayZServer_x64 or DayZServer_x64_NoBe processes
		$processNames = if ($isDisableBE) {
			@("DayZServer_x64_NoBe")
		}
		else {
			@("DayZServer_x64")
		}
		
		$foundProcess = $false
		foreach ($procName in $processNames) {
			$processes = Get-Process -Name $procName -ErrorAction SilentlyContinue
			if ($processes) {
				if (-not $foundProcess) {
					Write-ColorOutput "info.stopping_server" -ForegroundColor "Yellow" -Prefix "prefixes.server"
					$foundProcess = $true
				}
				if ($processes -isnot [array]) {
					$processes = @($processes)
				}
				foreach ($proc in $processes) {
					Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
				}
			}
		}
	}
}

# Function to stop the client
function Stop-DayZClient {
	if ($isDiagMode) {
		# In diag mode, client has "-connect" argument but not "-server"
		$processes = Get-Process -Name "DayZDiag_x64" -ErrorAction SilentlyContinue
		if ($null -eq $processes) {
			return
		}
		if ($processes -isnot [array]) {
			$processes = @($processes)
		}
		$foundProcess = $false
		foreach ($proc in $processes) {
			try {
				$commandLine = (Get-CimInstance Win32_Process -Filter "ProcessId = $($proc.Id)").CommandLine
				if ($commandLine -and $commandLine -match "-connect" -and $commandLine -notmatch "-server") {
					if (-not $foundProcess) {
						Write-ColorOutput "info.stopping_client" -ForegroundColor "Yellow" -Prefix "prefixes.client"
						$foundProcess = $true
					}
					Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
				}
			}
			catch {
				# If we can't get command line, skip this process
			}
		}
	}
	else {
		# In normal mode, kill DayZ_x64 or DayZ_BE processes
		$processNames = if ($isDisableBE) {
			@("DayZ_x64")
		}
		else {
			@("DayZ_x64", "DayZ_BE")
		}
		
		$foundProcess = $false
		foreach ($procName in $processNames) {
			$processes = Get-Process -Name $procName -ErrorAction SilentlyContinue
			if ($processes) {
				if (-not $foundProcess) {
					Write-ColorOutput "info.stopping_client" -ForegroundColor "Yellow" -Prefix "prefixes.client"
					$foundProcess = $true
				}
				if ($processes -isnot [array]) {
					$processes = @($processes)
				}
				foreach ($proc in $processes) {
					Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
				}
			}
		}
	}
}

switch ($mode) {
	"server" {
		Stop-DayZServer
	}
	"client" {
		Stop-DayZClient
	}
	"all" {
		Stop-DayZServer
		Stop-DayZClient
	}
}

# Wait a bit for processes to fully terminate before cleaning logs
Start-Sleep -Seconds 2

# Clear logs if needed - based on mode
if ($shouldClearLogs) {
	# Save original values
	$originalClearLogsServer = $clearLogsServer
	$originalClearLogsClient = $clearLogsClient
	
	# Set log clearing based on mode
	switch ($mode) {
		"server" {
			# Only clear server logs
			$clearLogsServer = $originalClearLogsServer
			$clearLogsClient = $false
		}
		"client" {
			# Only clear client logs
			$clearLogsServer = $false
			$clearLogsClient = $originalClearLogsClient
		}
		"all" {
			# Clear both server and client logs (use original values)
			$clearLogsServer = $originalClearLogsServer
			$clearLogsClient = $originalClearLogsClient
		}
	}
	
	# Only clear logs if at least one type is enabled
	if ($clearLogsServer -or $clearLogsClient) {
		Write-ColorOutput "info.clearing_logs" -ForegroundColor "Yellow" -Prefix "prefixes.logs"
		. (Join-Path $scriptDir "clearlogs.ps1")
	}
	
	# Restore original values (in case they're used elsewhere)
	$clearLogsServer = $originalClearLogsServer
	$clearLogsClient = $originalClearLogsClient
}

if (!$silent) {
	Write-ColorOutput "info.launch_complete" -ForegroundColor "Green" -Prefix "prefixes.system"

	if ($autoCloseTime -gt 0) {
		1..$autoCloseTime | ForEach-Object {
			$timeLeft = $autoCloseTime - $_ + 1
			$host.UI.RawUI.WindowTitle = Get-LocalizedString "window_title_closing" -FormatArgs @($timeLeft)
			Start-Sleep -Seconds 1
		}
	}
}