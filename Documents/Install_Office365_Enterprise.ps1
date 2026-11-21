$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13

Get-AppxPackage -Name "*Microsoft.Office.Desktop*" -AllUsers -ErrorAction SilentlyContinue | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue

$dlLink = "https://officecdn.microsoft.com/pr/wsus/setup.exe"
$workDir = Join-Path $env:TEMP ("ODT_O365Ent_" + [guid]::NewGuid().ToString("N").Substring(0, 8))
New-Item -ItemType Directory -Path $workDir -Force | Out-Null

$setupExe = Join-Path $workDir "setup.exe"
(New-Object System.Net.WebClient).DownloadFile($dlLink, $setupExe)

$configFileContents = @'
<Configuration>
  <Add OfficeClientEdition="64" Channel="Current" MigrateArch="TRUE">
    <Product ID="O365ProPlusRetail">
      <Language ID="tr-tr" />
      <Language ID="MatchOS" />
      <ExcludeApp ID="Groove" />
      <ExcludeApp ID="Lync" />
    </Product>
  </Add>
  <Property Name="FORCEAPPSHUTDOWN" Value="TRUE" />
  <Updates Enabled="TRUE" />
  <RemoveMSI />
  <Display Level="None" AcceptEULA="TRUE" />
</Configuration>
'@

$configFilePath = Join-Path $workDir "Configuration-Office365-Enterprise.xml"
[System.IO.File]::WriteAllText($configFilePath, $configFileContents, (New-Object System.Text.UTF8Encoding($false)))

$proc = Start-Process -FilePath $setupExe -ArgumentList "/configure `"$configFilePath`"" -WorkingDirectory $workDir -Wait -PassThru -WindowStyle Hidden
$exitCode = $proc.ExitCode

Remove-Item -LiteralPath $workDir -Recurse -Force -ErrorAction SilentlyContinue
if ($exitCode -ne 0 -and $exitCode -ne 3010) { exit $exitCode }
