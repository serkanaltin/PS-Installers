$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
$dirs = Invoke-RestMethod -Uri "https://api.github.com/repos/microsoft/winget-pkgs/contents/manifests/d/Discord/Discord" -Headers @{ "User-Agent" = "PS-Installers" }
$latestDir = ($dirs | Where-Object { $_.type -eq "dir" -and $_.name -match '^\d' } | Sort-Object { [version]$_.name } | Select-Object -Last 1).name
if (-not $latestDir) { $latestDir = "1.0.9269" }
$dlLink = "https://stable.dl2.discordapp.net/distro/app/stable/win/x64/$latestDir/DiscordSetup.exe"
$file = "DiscordSetup.exe"
$InstallerPath = Join-Path $env:TEMP $file
(New-Object System.Net.WebClient).DownloadFile($dlLink, $InstallerPath)
Start-Process $InstallerPath -Wait -ArgumentList "-s"
Get-Process Discord -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Remove-Item $InstallerPath -Force -ErrorAction SilentlyContinue