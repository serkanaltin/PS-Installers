$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$rel = Invoke-RestMethod -Uri "https://api.github.com/repos/audacity/audacity/releases/latest" -Headers @{ "User-Agent" = "PS-Installers" }
$asset = $rel.assets | Where-Object { $_.name -like "*win*x86_64.msi" -or $_.name -like "*win*64*.exe" } | Select-Object -First 1
$dlLink = $asset.browser_download_url
$file = $asset.name
$InstallerPath = Join-Path $env:TEMP $file
(New-Object System.Net.WebClient).DownloadFile($dlLink, $InstallerPath)
if ($file -like "*.msi") {
    Start-Process msiexec.exe -Wait -ArgumentList "/i `"$InstallerPath`" /qn /norestart" -Verb RunAs
} else {
    Start-Process $InstallerPath -Wait -ArgumentList "/VERYSILENT /NORESTART" -Verb RunAs
}
Remove-Item $InstallerPath -Force -ErrorAction SilentlyContinue