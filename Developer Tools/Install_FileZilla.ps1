$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
$ua = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36"
$html = (Invoke-WebRequest -UseBasicParsing -Uri "https://filezilla-project.org/download.php?show_all=1" -UserAgent $ua).Content
$dlLink = [regex]::Match($html, 'https://[^"''\s>]+FileZilla_[^"''\s>]+win64-setup\.exe[^"''\s>]*').Value
if ($dlLink) {
    $file = "FileZilla_win64-setup.exe"
    $InstallerPath = Join-Path $env:TEMP $file
    $wc = New-Object System.Net.WebClient
    $wc.Headers["User-Agent"] = $ua
    $wc.DownloadFile($dlLink, $InstallerPath)
    Start-Process $InstallerPath -Wait -ArgumentList "/S" -Verb RunAs
    Remove-Item $InstallerPath -Force -ErrorAction SilentlyContinue
} elseif (Get-Command winget.exe -ErrorAction SilentlyContinue) {
    Start-Process winget.exe -Wait -ArgumentList "install --id TimKosse.FileZilla.Client --exact --silent --accept-package-agreements --accept-source-agreements --disable-interactivity" -WindowStyle Hidden
}