$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
$dirs = Invoke-RestMethod -Uri "https://api.github.com/repos/microsoft/winget-pkgs/contents/manifests/t/TeamSpeakSystems/TeamSpeakClient" -Headers @{ "User-Agent" = "PS-Installers" }
$latestDir = ($dirs | Where-Object { $_.type -eq "dir" -and $_.name -match '^3\.' } | Sort-Object { [version]$_.name } | Select-Object -Last 1).name
if (-not $latestDir) { $latestDir = "3.6.2" }
$file = "TeamSpeak3-Client-win64-$latestDir.exe"
$dlLink = "https://files.teamspeak-services.com/releases/client/$latestDir/$file"
$InstallerPath = Join-Path $env:TEMP $file
(New-Object System.Net.WebClient).DownloadFile($dlLink, $InstallerPath)
Start-Process $InstallerPath -Wait -ArgumentList "/S" -Verb RunAs
Remove-Item $InstallerPath -Force -ErrorAction SilentlyContinue