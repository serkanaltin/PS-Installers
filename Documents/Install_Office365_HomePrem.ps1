$officeSetup = Join-Path $PSScriptRoot "office_setup.exe"
$configXml   = Join-Path $PSScriptRoot "configuration.xml"

if (-not (Test-Path -LiteralPath $officeSetup)) {
    $parentRoot  = Split-Path -Parent $PSScriptRoot
    $officeSetup = Join-Path $parentRoot "office_setup.exe"
    $configXml   = Join-Path $parentRoot "configuration.xml"
}

Start-Process -FilePath $officeSetup -ArgumentList "/configure `"$configXml`"" -Wait
