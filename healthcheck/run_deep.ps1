# Weekly chessdiary deep check (deep_check.py), for Windows Task Scheduler.
# deploy.sh also runs deep_check.py after every deploy.
#
# --- One-time setup (normal PowerShell is enough) ---
#   $action   = New-ScheduledTaskAction -Execute "powershell.exe" `
#       -Argument '-NoProfile -ExecutionPolicy Bypass -File "C:\src\ChessDiary\healthcheck\run_deep.ps1"'
#   $trigger  = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 11:30AM
#   $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
#       -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 1)
#   Register-ScheduledTask -TaskName "ChessDiaryDeepCheck" -Action $action -Trigger $trigger -Settings $settings `
#       -Description "Weekly deep check for chessdiary (browser tests, page sweep, security rules) -- reports via Telegram"
#
# To remove it: Unregister-ScheduledTask -TaskName "ChessDiaryDeepCheck" -Confirm:$false

$ErrorActionPreference = "Stop"

$ProjectRoot = $PSScriptRoot
Set-Location $ProjectRoot

$LogDir = Join-Path $ProjectRoot "logs"
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

$PythonExe = "python"
if (Get-Command py -ErrorAction SilentlyContinue) {
    $PythonExe = "py"
}

$Timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$LogPath = Join-Path $LogDir "deep_$Timestamp.log"

Write-Output "$(Get-Date): Starting chessdiary deep check. Full output: $LogPath"

& $PythonExe (Join-Path $ProjectRoot "deep_check.py") --reason weekly *> $LogPath
$ExitCode = $LASTEXITCODE

if ($ExitCode -eq 0) {
    Write-Output "$(Get-Date): Deep check completed -- all checks passed."
} else {
    Write-Output "$(Get-Date): Deep check completed -- failures (exit code $ExitCode). See $LogPath and the Telegram report."
}

exit $ExitCode
