$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13

$html = (Invoke-WebRequest -UseBasicParsing -Uri "https://www.microsoft.com/en-us/download/details.aspx?id=49117" -ErrorAction SilentlyContinue).Content
$dlLink = [regex]::Match($html, 'https://download\.microsoft\.com/download/[^"''\s]+/officedeploymenttool_[^"''\s]+\.exe').Value
if (-not $dlLink) {
    $dlLink = "https://download.microsoft.com/download/6c1eeb25-cf8b-41d9-8d0d-cc1dbc032140/officedeploymenttool_20527-20150.exe"
}

$workDir = Join-Path $env:TEMP ("ODT_Office_" + [guid]::NewGuid().ToString("N").Substring(0, 8))
New-Item -ItemType Directory -Path $workDir -Force | Out-Null

$odtExe = Join-Path $workDir "odt_installer.exe"
(New-Object System.Net.WebClient).DownloadFile($dlLink, $odtExe)
Start-Process -FilePath $odtExe -ArgumentList "/extract:`"$workDir`" /quiet" -Wait -WindowStyle Hidden
Remove-Item -LiteralPath $odtExe -Force -ErrorAction SilentlyContinue
Remove-Item -Path (Join-Path $workDir "configuration*.xml") -Force -ErrorAction SilentlyContinue

$configFileContents = @'
<Configuration>
  <Add OfficeClientEdition="64" Channel="Current" MigrateArch="TRUE">
    <Product ID="ProPlus2021Retail">
      <Language ID="tr-tr" />
      <Language ID="MatchOS" />
      <ExcludeApp ID="Groove" />
      <ExcludeApp ID="Lync" />
      <ExcludeApp ID="Teams" />
    </Product>
  </Add>
  <Property Name="FORCEAPPSHUTDOWN" Value="TRUE" />
  <Updates Enabled="TRUE" />
  <RemoveMSI />
  <Display Level="None" AcceptEULA="TRUE" />
</Configuration>
'@

$configFilePath = Join-Path $workDir "Configuration-Office2021-ProPlus.xml"
[System.IO.File]::WriteAllText($configFilePath, $configFileContents, (New-Object System.Text.UTF8Encoding($false)))

$setupExe = Join-Path $workDir "setup.exe"
if (Test-Path -LiteralPath $setupExe) {
    $proc = Start-Process -FilePath $setupExe -ArgumentList "/configure `"$configFilePath`"" -Wait -PassThru -WindowStyle Hidden -Verb RunAs
    $exitCode = $proc.ExitCode
} else {
    $exitCode = 1
}

Remove-Item -LiteralPath $workDir -Recurse -Force -ErrorAction SilentlyContinue
if ($exitCode -ne 0 -and $exitCode -ne 3010) { exit $exitCode }
