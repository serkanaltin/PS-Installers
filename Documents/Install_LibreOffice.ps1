$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$loIndex = Invoke-WebRequest -UseBasicParsing -Uri "https://download.documentfoundation.org/libreoffice/stable/"
$loVer = ($loIndex.Links | Where-Object { $_.href -match '^\d+\.\d+\.\d+/$' } | Select-Object -Last 1 -ExpandProperty href).TrimEnd('/')
$loFiles = Invoke-WebRequest -UseBasicParsing -Uri "https://download.documentfoundation.org/libreoffice/stable/$loVer/win/x86_64/"
$file = ($loFiles.Links | Where-Object { $_.href -like "LibreOffice_*_Win_x86-64.msi" -or $_.href -like "LibreOffice_*_Win_x64.msi" } | Select-Object -First 1 -ExpandProperty href)
$dlLink = "https://download.documentfoundation.org/libreoffice/stable/$loVer/win/x86_64/$file"
$InstallerPath = Join-Path $env:TEMP $file
(New-Object System.Net.WebClient).DownloadFile($dlLink, $InstallerPath)
Start-Process msiexec.exe -Wait -ArgumentList "/i `"$InstallerPath`" /qn /norestart" -Verb RunAs
Remove-Item $InstallerPath -Force -ErrorAction SilentlyContinue