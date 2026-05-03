# Builds an installable APK with values from dev.env baked in.
#
# Same dev.env parsing as run.ps1: known shell-env names (PUB_CACHE) get
# exported to this PowerShell session before invoking Flutter; everything
# else is forwarded as --dart-define so the values land inside the APK
# via String.fromEnvironment(...).
#
# Usage:
#   .\build.ps1                 # release APK (default)
#   .\build.ps1 debug           # debug APK (faster, larger, dev-signed)
#   .\build.ps1 release --split-per-abi   # extra args after the mode pass through

param(
    [Parameter(Position = 0)]
    [ValidateSet("debug", "profile", "release")]
    [string]$Mode = "release",
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ExtraArgs
)

$ErrorActionPreference = "Stop"

$envFile = Join-Path $PSScriptRoot "dev.env"
if (-not (Test-Path $envFile)) {
    Write-Host "dev.env not found. Copy dev.env.example to dev.env and fill in your values." -ForegroundColor Red
    exit 1
}

$shellEnvNames = @("PUB_CACHE")

$dartDefines = New-Object System.Collections.Generic.List[string]

foreach ($line in Get-Content $envFile) {
    $trimmed = $line.Trim()
    if ($trimmed -eq "" -or $trimmed.StartsWith("#")) { continue }

    $idx = $trimmed.IndexOf("=")
    if ($idx -lt 1) { continue }
    $key = $trimmed.Substring(0, $idx).Trim()
    $value = $trimmed.Substring($idx + 1).Trim()

    if ($shellEnvNames -contains $key) {
        Set-Item -Path "Env:$key" -Value $value
        Write-Host "shell env  $key = $value" -ForegroundColor DarkGray
    } else {
        $dartDefines.Add("--dart-define=$key=$value")
        $masked = if ($value.Length -gt 8) { $value.Substring(0, 4) + "..." } else { "***" }
        Write-Host "dart-define  $key = $masked" -ForegroundColor DarkGray
    }
}

$flutterArgs = @("build", "apk", "--$Mode") + $dartDefines
if ($ExtraArgs) { $flutterArgs += $ExtraArgs }

Write-Host ""
Write-Host "flutter $($flutterArgs -join ' ')" -ForegroundColor Cyan
Write-Host ""
& flutter @flutterArgs
$exit = $LASTEXITCODE

if ($exit -eq 0) {
    $apk = Join-Path $PSScriptRoot "build\app\outputs\flutter-apk\app-$Mode.apk"
    if (Test-Path $apk) {
        $size = "{0:N1} MB" -f ((Get-Item $apk).Length / 1MB)
        Write-Host ""
        Write-Host "APK ready: $apk ($size)" -ForegroundColor Green
        Write-Host "Install:  adb install -r `"$apk`"" -ForegroundColor DarkGray
    }
}
exit $exit
