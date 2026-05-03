# Wrapper for `flutter run` that loads dev.env.
#
# Lines in dev.env that match a known shell-env name (PUB_CACHE) are exported
# to this PowerShell session before launching Flutter. Everything else is
# forwarded as `--dart-define=KEY=VALUE` so it shows up in your Dart code via
# String.fromEnvironment(...).
#
# Usage:
#   1. Copy dev.env.example to dev.env and fill in real values.
#   2. From PowerShell in this directory:  .\run.ps1
#   3. Pass extra Flutter args after --, e.g.:  .\run.ps1 -- --release

param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ExtraArgs
)

$ErrorActionPreference = "Stop"

$envFile = Join-Path $PSScriptRoot "dev.env"
if (-not (Test-Path $envFile)) {
    Write-Host "dev.env not found. Copy dev.env.example to dev.env and fill in your values." -ForegroundColor Red
    exit 1
}

# Names that should be set as PowerShell session env vars rather than passed
# to Dart. Add more here if you ever need other shell-level config.
$shellEnvNames = @("PUB_CACHE")

$dartDefines = New-Object System.Collections.Generic.List[string]

foreach ($line in Get-Content $envFile) {
    $trimmed = $line.Trim()
    if ($trimmed -eq "" -or $trimmed.StartsWith("#")) { continue }

    $idx = $trimmed.IndexOf("=")
    if ($idx -lt 1) {
        Write-Host "Skipping malformed line: $line" -ForegroundColor Yellow
        continue
    }
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

$flutterArgs = @("run") + $dartDefines
if ($ExtraArgs) { $flutterArgs += $ExtraArgs }

Write-Host ""
Write-Host "flutter $($flutterArgs -join ' ')" -ForegroundColor Cyan
Write-Host ""
& flutter @flutterArgs
exit $LASTEXITCODE
