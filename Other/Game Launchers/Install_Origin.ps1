$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$file = "EAappInstaller.exe"
$dlLink = "https://origin-a.akamaihd.net/EA-Desktop-Client-Download/installer-releases/$file"
$InstallerPath = Join-Path $env:TEMP $file
(New-Object System.Net.WebClient).DownloadFile($dlLink, $InstallerPath)
Start-Process $InstallerPath -Wait -ArgumentList "/quiet" -Verb RunAs
Remove-Item $InstallerPath -Force -ErrorAction SilentlyContinue