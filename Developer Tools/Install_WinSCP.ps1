$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
$wscpIndex = Invoke-WebRequest -UseBasicParsing -Uri "https://sourceforge.net/projects/winscp/files/WinSCP/"
$ver = ($wscpIndex.Links | Where-Object { $_.href -match '/projects/winscp/files/WinSCP/\d+\.\d+(\.\d+)?/$' } | Select-Object -First 1 -ExpandProperty href) -replace '.*/WinSCP/([^/]+)/.*', '$1'
$file = "WinSCP-$ver-Setup.exe"
$dlLink = "https://downloads.sourceforge.net/project/winscp/WinSCP/$ver/$file"
$InstallerPath = Join-Path $env:TEMP $file
$wc = New-Object System.Net.WebClient
$wc.Headers["User-Agent"] = "Wget/1.21.4"
$wc.DownloadFile($dlLink, $InstallerPath)
Start-Process $InstallerPath -Wait -ArgumentList "/VERYSILENT /NORESTART /ALLUSERS" -Verb RunAs
Remove-Item $InstallerPath -Force -ErrorAction SilentlyContinue