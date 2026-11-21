$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$rel = Invoke-RestMethod -Uri "https://api.github.com/repos/ShareX/ShareX/releases/latest" -Headers @{ "User-Agent" = "PS-Installers" }
$asset = $rel.assets | Where-Object { $_.name -like "*setup*.exe" } | Select-Object -First 1
$dlLink = $asset.browser_download_url
$file = $asset.name
$InstallerPath = Join-Path $env:TEMP $file
(New-Object System.Net.WebClient).DownloadFile($dlLink, $InstallerPath)
Start-Process $InstallerPath -Wait -ArgumentList "/VERYSILENT /NORESTART /NORUN" -Verb RunAs
Remove-Item $InstallerPath -Force -ErrorAction SilentlyContinue