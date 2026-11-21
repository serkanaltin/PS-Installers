$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ooIndex = Invoke-WebRequest -UseBasicParsing -Uri "https://archive.apache.org/dist/openoffice/"
$ooVer = ($ooIndex.Links | Where-Object { $_.href -match '^4\.\d+\.\d+/$' } | Select-Object -Last 1 -ExpandProperty href).TrimEnd('/')
$ooFiles = Invoke-WebRequest -UseBasicParsing -Uri "https://archive.apache.org/dist/openoffice/$ooVer/binaries/en-US/"
$file = ($ooFiles.Links | Where-Object { $_.href -like "Apache_OpenOffice_*_Win_x86_install_en-US.exe" } | Select-Object -First 1 -ExpandProperty href)
$dlLink = "https://archive.apache.org/dist/openoffice/$ooVer/binaries/en-US/$file"
$InstallerPath = Join-Path $env:TEMP $file
(New-Object System.Net.WebClient).DownloadFile($dlLink, $InstallerPath)
Start-Process $InstallerPath -Wait -ArgumentList "/S /v /qb RebootYesNo=No" -Verb RunAs
Remove-Item $InstallerPath -Force -ErrorAction SilentlyContinue