$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$rel = Invoke-RestMethod -Uri "https://api.github.com/repos/windirstat/windirstat/releases/latest" -Headers @{ "User-Agent" = "PS-Installers" }
$dlLink = ($rel.assets | Where-Object { $_.name -like "*x64.msi" } | Select-Object -First 1).browser_download_url
$file = "WinDirStat-x64.msi"
$InstallerPath = Join-Path $env:TEMP $file
(New-Object System.Net.WebClient).DownloadFile($dlLink, $InstallerPath)
Start-Process msiexec.exe -Wait -ArgumentList "/i `"$InstallerPath`" /qn /norestart" -Verb RunAs
Remove-Item $InstallerPath -Force -ErrorAction SilentlyContinue