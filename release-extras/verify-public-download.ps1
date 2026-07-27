[CmdletBinding()]
param(
    [string]$Url = "https://github.com/marcusash/ai-maker/releases/latest/download/new-user-pc-setup.zip"
)

$ErrorActionPreference = "Stop"

Write-Host "Checking public download endpoint..."
Write-Host "URL: $Url"

$head = Invoke-WebRequest -Uri $Url -Method Head -MaximumRedirection 10
if ($head.StatusCode -lt 200 -or $head.StatusCode -ge 400) {
    throw "HEAD check failed with status $($head.StatusCode)"
}

$tmp = Join-Path $env:TEMP "new-user-pc-setup.public-check.zip"
if (Test-Path $tmp) {
    Remove-Item $tmp -Force
}

Invoke-WebRequest -Uri $Url -OutFile $tmp -MaximumRedirection 10
$size = (Get-Item $tmp).Length
if ($size -lt 1024) {
    throw "Downloaded file is unexpectedly small ($size bytes)"
}

Write-Host "PASS: Download succeeded ($size bytes)"
