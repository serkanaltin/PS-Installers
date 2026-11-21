$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13

# 1. Windows 10/11 üzerinde önceden yüklü gelen "Office" (Microsoft.Office.Desktop) Mağaza/UWP taslak uygulamasını kaldır (Click-to-Run çakışmasını önler)
Get-AppxPackage -Name "*Microsoft.Office.Desktop*" -AllUsers -ErrorAction SilentlyContinue | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.PackageName -like "*Microsoft.Office.Desktop*" } | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue

# 2. Daha önceki yarıda kalmış kurulumlardan asılı kalan setup.exe / OfficeClickToRun işlemlerini temizle
Get-Process -Name "setup", "OfficeC2RClient" -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "*Temp*" -or $_.Path -like "*ClickToRun*" } | Stop-Process -Force -ErrorAction SilentlyContinue

# 3. Doğrudan Microsoft Resmi Office CDN üzerinden saf setup.exe motorunu indir (eski 49117 arşiv paketi hatasını tamamen aşar)
$dlLink = "https://officecdn.microsoft.com/pr/wsus/setup.exe"
$workDir = Join-Path $env:TEMP ("ODT_Office2021_" + [guid]::NewGuid().ToString("N").Substring(0, 8))
New-Item -ItemType Directory -Path $workDir -Force | Out-Null

$setupExe = Join-Path $workDir "setup.exe"
(New-Object System.Net.WebClient).DownloadFile($dlLink, $setupExe)

# 4. Office 2021 Pro Plus (64-Bit Türkçe, Sessiz Kurulum) Yapılandırma Dosyası
$configFileContents = @'
<Configuration>
  <Add OfficeClientEdition="64" Channel="PerpetualVL2021" MigrateArch="TRUE">
    <Product ID="ProPlus2021Volume">
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

$configFilePath = Join-Path $workDir "Configuration-Office2021.xml"
[System.IO.File]::WriteAllText($configFilePath, $configFileContents, (New-Object System.Text.UTF8Encoding($false)))

# 5. Sessiz kurulumu başlat ve tamamlanana kadar bekle
$proc = Start-Process -FilePath $setupExe -ArgumentList "/configure `"$configFilePath`"" -WorkingDirectory $workDir -Wait -PassThru -WindowStyle Hidden
$exitCode = $proc.ExitCode

# Eğer kurumsal/volume kanal yerine Retail kanalı tercih edilirse otomatik yedek olarak ProPlus2021Retail dene
if ($exitCode -ne 0 -and $exitCode -ne 3010) {
    $retailConfig = $configFileContents.Replace('Channel="PerpetualVL2021"', 'Channel="Current"').Replace('Product ID="ProPlus2021Volume"', 'Product ID="ProPlus2021Retail"')
    [System.IO.File]::WriteAllText($configFilePath, $retailConfig, (New-Object System.Text.UTF8Encoding($false)))
    $proc = Start-Process -FilePath $setupExe -ArgumentList "/configure `"$configFilePath`"" -WorkingDirectory $workDir -Wait -PassThru -WindowStyle Hidden
    $exitCode = $proc.ExitCode
}

Remove-Item -LiteralPath $workDir -Recurse -Force -ErrorAction SilentlyContinue
if ($exitCode -ne 0 -and $exitCode -ne 3010) { exit $exitCode }
