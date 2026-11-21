$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$rel = Invoke-RestMethod -Uri "https://api.github.com/repos/paintdotnet/release/releases/latest" -Headers @{ "User-Agent" = "PS-Installers" }
$asset = $rel.assets | Where-Object { $_.name -like "*winmsi.x64.zip" } | Select-Object -First 1
$dlLink = $asset.browser_download_url
$zipFile = $asset.name
$zipPath = Join-Path $env:TEMP $zipFile
$outDir = Join-Path $env:TEMP ($zipFile -replace '\.zip$', '')
(New-Object System.Net.WebClient).DownloadFile($dlLink, $zipPath)
Expand-Archive -Path $zipPath -DestinationPath $outDir -Force
$msiFile = Get-ChildItem -Path $outDir -Filter "*.msi" | Select-Object -First 1
if ($msiFile) {
    Start-Process msiexec.exe -Wait -ArgumentList "/i `"$($msiFile.FullName)`" /qn /norestart" -Verb RunAs
}
Remove-Item $outDir -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item $zipPath -Force -ErrorAction SilentlyContinue