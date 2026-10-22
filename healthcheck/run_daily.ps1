# Daily chessdiary deep health check, meant for Windows Task Scheduler.
#
# Replaces a Claude cloud routine (claude.ai routines) that hit a hard
# blocker: its cloud sandbox's network egress policy only allows
# *.googleapis.com and a few package registries, rejecting
# chessdiary.app, the Firebase web.app domain, the Render backend, and
# the Telegram relay this check then reported through. That policy
# lives in a pure click-through UI with no API or direct URL (confirmed
# against Anthropic's own docs), so running the same checks from this
# machine's own unrestricted network sidesteps the problem entirely.
#
# --- One-time setup: register this as a Task Scheduler task ---
# Run in an elevated PowerShell prompt:
#
#   $action = New-ScheduledTaskAction -Execute "powershell.exe" `
#       -Argument '-NoProfile -ExecutionPolicy Bypass -File "C:\src\ChessDiary\healthcheck\run_daily.ps1"'
#   $trigger = New-ScheduledTaskTrigger -Daily -At 7:30AM
#   Register-ScheduledTask -TaskName "ChessDiaryHealthCheck" -Action $action -Trigger $trigger `
#       -Description "Daily deep health check for chessdiary (website, backend, Gemini, Firestore) -- reports via Telegram"
#
# To remove it later: Unregister-ScheduledTask -TaskName "ChessDiaryHealthCheck" -Confirm:$false

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
$LogPath = Join-Path $LogDir "run_$Timestamp.log"

Write-Output "$(Get-Date): Starting chessdiary health check. Full output: $LogPath"

& $PythonExe (Join-Path $ProjectRoot "healthcheck.py") *> $LogPath
$ExitCode = $LASTEXITCODE

if ($ExitCode -eq 0) {
    Write-Output "$(Get-Date): Health check completed -- all checks passed."
} else {
    Write-Output "$(Get-Date): Health check completed -- at least one check failed (exit code $ExitCode). See $LogPath and the Telegram report."
}

exit $ExitCode
