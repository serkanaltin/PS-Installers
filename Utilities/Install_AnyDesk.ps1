$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$file = "AnyDesk.exe"
$dlLink = "https://download.anydesk.com/$file"
$InstallerPath = Join-Path $env:TEMP $file
(New-Object System.Net.WebClient).DownloadFile($dlLink, $InstallerPath)
Start-Process $InstallerPath -Wait -ArgumentList "--install `"C:\Program Files (x86)\AnyDesk`" --start-with-win --create-shortcuts --create-desktop-icon --silent" -Verb RunAs
Remove-Item $InstallerPath -Force -ErrorAction SilentlyContinue