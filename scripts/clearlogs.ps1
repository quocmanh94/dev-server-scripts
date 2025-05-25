function Remove-FileForced {
	param([string]$FilePath)
	# Escape special characters in path
	$EscapedPath = $FilePath -replace '\[', '`[' -replace '\]', '`]'
	
	if (Test-Path -LiteralPath $FilePath) {
		Remove-Item -LiteralPath $FilePath -Force -ErrorAction SilentlyContinue
	}
}

# Function to check if a process is running
function Test-ProcessRunning {
	param ([string]$ProcessName, [int]$RetryCount = 3, [int]$RetryDelay = 1)

	for ($i = 0; $i -lt $RetryCount; $i++) {
		$process = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue
		if ($null -eq $process) {
			return $false
		}
		Start-Sleep -Seconds $RetryDelay
	}
	return $true
}

# Server logs cleanup
if ($clearLogsServer) {
	if (Test-ProcessRunning "DayZServer_x64" -RetryCount 2 -RetryDelay 1) {
		Write-ColorOutput "logs.server_running" -ForegroundColor "Yellow" -Prefix "prefixes.logs"
	}
	else {
		Write-ColorOutput "logs.cleaning_server" -ForegroundColor "White" -Prefix "prefixes.logs"

		# Cleanup logs in server folder
		$serverLogs = Get-ChildItem -Path $serverPath -Include "*.log","*.mdmp","*.RPT","*.ADM" -Recurse -ErrorAction SilentlyContinue
		if ($serverLogs) {
			Write-ColorOutput "logs.found_server" -ForegroundColor "White" -Prefix "prefixes.logs" -FormatArgs @($serverLogs.Count)
			foreach ($log in $serverLogs) {
				Write-ColorOutput "logs.deleting" -ForegroundColor "White" -Prefix "prefixes.logs" -FormatArgs @($log.FullName)
				Remove-FileForced $log.FullName
			}
			Write-ColorOutput "logs.server_cleaned" -ForegroundColor "White" -Prefix "prefixes.logs"
		}

		# Cleanup logs in profiles folder
		$profileLogs = Get-ChildItem -Path $profilePath -Include "*.log","*.mdmp","*.RPT","*.ADM" -Recurse -ErrorAction SilentlyContinue
		if ($profileLogs) {
			foreach ($log in $profileLogs) {
				Write-ColorOutput "logs.deleting" -ForegroundColor "White" -Prefix "prefixes.logs" -FormatArgs @($log.FullName)
				Remove-FileForced $log.FullName
			}
		}
		else {
			Write-ColorOutput "logs.profile_not_found" -ForegroundColor "White" -Prefix "prefixes.logs"
		}
	}
}

# Client logs cleanup
if ($clearLogsClient) {
	if (Test-ProcessRunning "DayZ_x64" -RetryCount 2 -RetryDelay 1) {
		Write-ColorOutput "logs.client_running" -ForegroundColor "Yellow" -Prefix "prefixes.logs"
	}
	else {
		Write-ColorOutput "logs.cleaning_client" -ForegroundColor "White" -Prefix "prefixes.logs" -FormatArgs @($clientLogsPath)

		$clientLogs = Get-ChildItem -Path $clientLogsPath -Include "*.log","*.mdmp","*.RPT" -Recurse -ErrorAction SilentlyContinue
		if ($clientLogs) {
			Write-ColorOutput "logs.found_client" -ForegroundColor "White" -Prefix "prefixes.logs" -FormatArgs @($clientLogs.Count)
			foreach ($log in $clientLogs) {
				Write-ColorOutput "logs.deleting" -ForegroundColor "White" -Prefix "prefixes.logs" -FormatArgs @($log.FullName)
				Remove-FileForced $log.FullName
			}
			Write-ColorOutput "logs.client_cleaned" -ForegroundColor "White" -Prefix "prefixes.logs"
		}
	}
}

Write-ColorOutput "logs.complete" -ForegroundColor "White" -Prefix "prefixes.logs"