$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor 3072
} catch {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
}

$file         = "Acrobat_DC_Web_x64_WWMUI.zip"
$dlLink       = "https://trials.adobe.com/AdobeProducts/APRO/Acrobat_HelpX/win32/$file"
$zipPath      = Join-Path $env:TEMP $file
$outputFolder = "Acrobat_DC_Web_x64_WWMUI"
$outputPath   = Join-Path $env:TEMP $outputFolder
$logDir       = Join-Path $env:TEMP "HKM_Logs"
if (-not (Test-Path -LiteralPath $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}
$msiLogDirect = Join-Path $logDir "AcrobatPro_Error_MSI.log"
$userAgent    = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"

$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# Tamponsuz doğrudan stdout yazıcı (PowerShell fonksiyon dönüş değerlerine asla karışmaz ve anında arayüze ulaşır)
function Emit-Line {
    param([string]$Text)
    try {
        [Console]::WriteLine($Text)
        [Console]::Out.Flush()
    } catch {
        Write-Output $Text
    }
}

function Test-ValidZipFile {
    param([string]$Path, [long]$ExpectedBytes = -1)
    if (-not (Test-Path -LiteralPath $Path)) { return $false }
    $fs = $null
    try {
        $fi = Get-Item -LiteralPath $Path -ErrorAction Stop
        if ($fi.Length -lt 50MB) { return $false }
        if ($ExpectedBytes -gt 0 -and $fi.Length -ne $ExpectedBytes) { return $false }

        $fs = New-Object System.IO.FileStream($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
        # ZIP başlık imzası: PK\x03\x04
        $hdr = New-Object byte[] 4
        if ($fs.Read($hdr, 0, 4) -lt 4) { return $false }
        if ($hdr[0] -ne 0x50 -or $hdr[1] -ne 0x4B -or $hdr[2] -ne 0x03 -or $hdr[3] -ne 0x04) { return $false }

        # ZIP sonu (End of Central Directory imzası: PK\x05\x06) son 64 KB içinde olmalı
        $tailSize = [int][Math]::Min(65536, $fi.Length)
        $fs.Seek($fi.Length - $tailSize, [System.IO.SeekOrigin]::Begin) | Out-Null
        $tail = New-Object byte[] $tailSize
        $readTail = $fs.Read($tail, 0, $tailSize)
        $foundEocd = $false
        for ($i = $readTail - 4; $i -ge 0; $i--) {
            if ($tail[$i] -eq 0x50 -and $tail[$i + 1] -eq 0x4B -and $tail[$i + 2] -eq 0x05 -and $tail[$i + 3] -eq 0x06) {
                $foundEocd = $true
                break
            }
        }
        return $foundEocd
    } catch {
        return $false
    } finally {
        if ($fs) { try { $fs.Close() } catch {} }
    }
}

function Test-ZipHeaderOnly {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $false }
    $fs = $null
    try {
        $fs = New-Object System.IO.FileStream($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
        $hdr = New-Object byte[] 4
        if ($fs.Read($hdr, 0, 4) -lt 4) { return $false }
        return ($hdr[0] -eq 0x50 -and $hdr[1] -eq 0x4B -and $hdr[2] -eq 0x03 -and $hdr[3] -eq 0x04)
    } catch {
        return $false
    } finally {
        if ($fs) { try { $fs.Close() } catch {} }
    }
}

function Find-InstalledAcrobatExe {
    $candidates = @(
        (Join-Path $env:ProgramFiles "Adobe\Acrobat DC\Acrobat\Acrobat.exe"),
        (Join-Path ${env:ProgramFiles(x86)} "Adobe\Acrobat DC\Acrobat\Acrobat.exe"),
        (Join-Path $env:ProgramFiles "Adobe\Acrobat\Acrobat\Acrobat.exe"),
        (Join-Path ${env:ProgramFiles(x86)} "Adobe\Acrobat\Acrobat\Acrobat.exe")
    )
    foreach ($c in $candidates) {
        if ($c -and (Test-Path -LiteralPath $c)) {
            return $c
        }
    }

    try {
        $appPathKey = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\Acrobat.exe" -ErrorAction SilentlyContinue
        if ($appPathKey) {
            $defVal = $appPathKey.'(default)'
            if ($defVal) {
                $clean = $defVal.Trim('"')
                if (Test-Path -LiteralPath $clean) { return $clean }
            }
            if ($appPathKey.Path) {
                $joined = Join-Path $appPathKey.Path "Acrobat.exe"
                if (Test-Path -LiteralPath $joined) { return $joined }
            }
        }
    } catch {}

    return $null
}

function Get-FolderSizeMB {
    param([string]$Path)
    if (-not $Path -or -not (Test-Path -LiteralPath $Path)) { return 0 }
    try {
        $sum = (Get-ChildItem -LiteralPath $Path -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
        if ($sum) { return [int][Math]::Round($sum / 1MB) }
    } catch {}
    return 0
}

function Get-RemoteContentLength {
    param([string]$Url, [string]$CurlPath)

    if ($CurlPath) {
        try {
            $hdrs = & $CurlPath -s -I -L --connect-timeout 15 --max-time 25 -A $userAgent $Url 2>$null
            $lenMatch = ($hdrs | Select-String -Pattern '^Content-Length:\s*(\d+)' | Select-Object -Last 1)
            if ($lenMatch -and $lenMatch.Matches.Count -gt 0) {
                return [long]$lenMatch.Matches[0].Groups[1].Value
            }
        } catch {}
    }

    try {
        $req = [System.Net.HttpWebRequest]::Create($Url)
        $req.Method = "HEAD"
        $req.UserAgent = $userAgent
        $req.AllowAutoRedirect = $true
        $req.Timeout = 20000
        $resp = $req.GetResponse()
        $len = [long]$resp.ContentLength
        $resp.Close()
        return $len
    } catch {
        return [long]-1
    }
}

function Invoke-CurlFastDownload {
    param(
        [string]$Url,
        [string]$DestinationPath,
        [long]$ExpectedBytes,
        [string]$CurlPath
    )

    $useResume = $false
    if (Test-Path -LiteralPath $DestinationPath) {
        if (Test-ValidZipFile -Path $DestinationPath -ExpectedBytes $ExpectedBytes) {
            $mb = [Math]::Round((Get-Item -LiteralPath $DestinationPath).Length / 1MB, 1)
            Emit-Line "@@LOG@@Önbellekte doğrulanmış tam paket bulundu, indirme atlandı ($mb MB): $DestinationPath"
            Emit-Line ("@@DL_PROGRESS@@100|{0}|{0}|0" -f $mb.ToString([System.Globalization.CultureInfo]::InvariantCulture))
            return $true
        }

        $existingLen = (Get-Item -LiteralPath $DestinationPath).Length
        if ($ExpectedBytes -gt 0 -and $existingLen -gt 4096 -and $existingLen -lt $ExpectedBytes -and (Test-ZipHeaderOnly -Path $DestinationPath)) {
            $useResume = $true
            $exMB = [Math]::Round($existingLen / 1MB, 1)
            Emit-Line "@@LOG@@Yarım kalan geçerli indirme bulundu ($exMB MB), kaldığı yerden devam ediliyor..."
        } else {
            Emit-Line "@@LOG@@Önceki eksik/bozuk geçici dosya temizleniyor..."
            Remove-Item -LiteralPath $DestinationPath -Force -ErrorAction SilentlyContinue
        }
    }

    $resumeArg = if ($useResume) { "-C -" } else { "" }
    $curlArgs = "-L --fail --silent --show-error --retry 4 --retry-delay 2 --connect-timeout 25 $resumeArg -A `"$userAgent`" -o `"$DestinationPath`" `"$Url`""

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $CurlPath
    $psi.Arguments = $curlArgs
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true

    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo = $psi
    [void]$proc.Start()
    $outTask = $proc.StandardOutput.ReadToEndAsync()
    $errTask = $proc.StandardError.ReadToEndAsync()

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $startBytes = if ($useResume -and (Test-Path -LiteralPath $DestinationPath)) { (Get-Item -LiteralPath $DestinationPath).Length } else { [long]0 }
    $lastPct = -1
    $lastEmitMs = [long]0

    while (-not $proc.HasExited) {
        Start-Sleep -Milliseconds 350
        if (Test-Path -LiteralPath $DestinationPath) {
            try {
                $curBytes = (Get-Item -LiteralPath $DestinationPath -ErrorAction Stop).Length
                $elapsedSec = [Math]::Max(0.2, $sw.Elapsed.TotalSeconds)
                $deltaBytes = [Math]::Max([long]0, $curBytes - $startBytes)
                $spd = [Math]::Round(($deltaBytes / 1MB) / $elapsedSec, 1)
                $dlMB = [Math]::Round($curBytes / 1MB, 1)
                $ms = $sw.ElapsedMilliseconds

                if ($ExpectedBytes -gt 0) {
                    $pct = [int][Math]::Min(99, [Math]::Floor(($curBytes * 100.0) / $ExpectedBytes))
                    if ($pct -ne $lastPct -or ($ms - $lastEmitMs) -ge 900) {
                        $lastPct = $pct
                        $lastEmitMs = $ms
                        $totMB = [Math]::Round($ExpectedBytes / 1MB, 1)
                        Emit-Line ("@@DL_PROGRESS@@{0}|{1}|{2}|{3}" -f $pct, $dlMB.ToString([System.Globalization.CultureInfo]::InvariantCulture), $totMB.ToString([System.Globalization.CultureInfo]::InvariantCulture), $spd.ToString([System.Globalization.CultureInfo]::InvariantCulture))
                    }
                } elseif (($ms - $lastEmitMs) -ge 800) {
                    $lastEmitMs = $ms
                    Emit-Line ("@@DL_PROGRESS@@-1|{0}|0|{1}" -f $dlMB.ToString([System.Globalization.CultureInfo]::InvariantCulture), $spd.ToString([System.Globalization.CultureInfo]::InvariantCulture))
                }
            } catch {}
        }
    }

    $proc.WaitForExit()
    $code = $proc.ExitCode
    $errText = ""
    try { $null = $outTask.GetAwaiter().GetResult() } catch {}
    try { $errText = $errTask.GetAwaiter().GetResult() } catch {}
    $proc.Dispose()

    if ($code -ne 0) {
        if (-not [string]::IsNullOrWhiteSpace($errText)) {
            Emit-Line "@@LOG@@curl.exe hatası (Kod $code): $($errText.Trim())"
        } else {
            Emit-Line "@@LOG@@curl.exe hatası (Kod $code)."
        }
        return $false
    }

    if (-not (Test-ValidZipFile -Path $DestinationPath -ExpectedBytes $ExpectedBytes)) {
        Emit-Line "@@LOG@@İndirilen ZIP dosyası bütünlük kontrolünden geçemedi."
        return $false
    }

    $finalLen = (Get-Item -LiteralPath $DestinationPath).Length
    $finalMB = [Math]::Round($finalLen / 1MB, 1)
    $avgSpd = [Math]::Round(([Math]::Max([long]0, $finalLen - $startBytes) / 1MB) / [Math]::Max(0.2, $sw.Elapsed.TotalSeconds), 1)
    Emit-Line ("@@DL_PROGRESS@@100|{0}|{0}|{1}" -f $finalMB.ToString([System.Globalization.CultureInfo]::InvariantCulture), $avgSpd.ToString([System.Globalization.CultureInfo]::InvariantCulture))
    return $true
}

function Invoke-FallbackHttpDownload {
    param([string]$Url, [string]$DestinationPath)

    Emit-Line "@@LOG@@Yedek indirme motoru (HttpWebRequest) başlatılıyor..."
    if (Test-Path -LiteralPath $DestinationPath) {
        Remove-Item -LiteralPath $DestinationPath -Force -ErrorAction SilentlyContinue
    }

    $response   = $null
    $respStream = $null
    $fileStream = $null
    try {
        $req = [System.Net.HttpWebRequest]::Create($Url)
        $req.Method = "GET"
        $req.UserAgent = $userAgent
        $req.Accept = "*/*"
        $req.AllowAutoRedirect = $true
        $req.Timeout = 60000
        $req.ReadWriteTimeout = 120000

        $response = $req.GetResponse()
        $totalBytes = [long]$response.ContentLength
        $respStream = $response.GetResponseStream()
        $fileStream = New-Object System.IO.FileStream($DestinationPath, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None, 262144)

        $buffer = New-Object byte[] 262144
        $totalRead = [long]0
        $lastPct = -1
        $lastMs = [long]0
        $sw = [System.Diagnostics.Stopwatch]::StartNew()

        while (($read = $respStream.Read($buffer, 0, $buffer.Length)) -gt 0) {
            $fileStream.Write($buffer, 0, $read)
            $totalRead += $read
            $ms = $sw.ElapsedMilliseconds
            if ($totalBytes -gt 0) {
                $pct = [int][Math]::Min(100, [Math]::Floor(($totalRead * 100.0) / $totalBytes))
                if ($pct -ne $lastPct -or ($ms - $lastMs) -ge 800) {
                    $lastPct = $pct
                    $lastMs = $ms
                    $dlMB = [Math]::Round($totalRead / 1MB, 1)
                    $totMB = [Math]::Round($totalBytes / 1MB, 1)
                    $spd = [Math]::Round(($totalRead / 1MB) / [Math]::Max(0.2, $sw.Elapsed.TotalSeconds), 1)
                    Emit-Line ("@@DL_PROGRESS@@{0}|{1}|{2}|{3}" -f $pct, $dlMB.ToString([System.Globalization.CultureInfo]::InvariantCulture), $totMB.ToString([System.Globalization.CultureInfo]::InvariantCulture), $spd.ToString([System.Globalization.CultureInfo]::InvariantCulture))
                }
            }
        }
        $fileStream.Flush()
        $fileStream.Close(); $fileStream = $null
        $respStream.Close(); $respStream = $null
        $response.Close(); $response = $null

        if (-not (Test-ValidZipFile -Path $DestinationPath)) {
            throw "İndirilen ZIP dosyası geçersiz veya eksik."
        }
        $finalMB = [Math]::Round((Get-Item -LiteralPath $DestinationPath).Length / 1MB, 1)
        Emit-Line ("@@DL_PROGRESS@@100|{0}|{0}|0" -f $finalMB.ToString([System.Globalization.CultureInfo]::InvariantCulture))
    } finally {
        if ($fileStream) { try { $fileStream.Close() } catch {} }
        if ($respStream) { try { $respStream.Close() } catch {} }
        if ($response)   { try { $response.Close() } catch {} }
    }
}

function Expand-AcrobatArchive {
    param([string]$ZipFile, [string]$DestDir)

    if (Test-Path -LiteralPath $DestDir) {
        Remove-Item -LiteralPath $DestDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    New-Item -ItemType Directory -Path $DestDir -Force | Out-Null

    Emit-Line "@@STAGE@@EXTRACT|Arşiv çıkarılıyor: $DestDir"
    Emit-Line "@@LOG@@Arşiv çıkarma klasörü: $DestDir"

    $tarCmd = Get-Command tar.exe -ErrorAction SilentlyContinue
    if ($tarCmd) {
        $tarProc = Start-Process -FilePath $tarCmd.Source -ArgumentList "-xf `"$ZipFile`" -C `"$DestDir`"" -PassThru -WindowStyle Hidden
        $exSw = [System.Diagnostics.Stopwatch]::StartNew()
        $lastBeat = 0
        while (-not $tarProc.HasExited) {
            Start-Sleep -Seconds 2
            $s = [int]$exSw.Elapsed.TotalSeconds
            if ($s -ge ($lastBeat + 4)) {
                $lastBeat = $s
                $exMB = Get-FolderSizeMB -Path $DestDir
                Emit-Line "@@STAGE@@EXTRACT|Arşiv çıkarılıyor ($exMB MB açıldı • $s sn)..."
            }
        }
        $tarProc.WaitForExit()
        if ($tarProc.ExitCode -eq 0) {
            Emit-Line "@@LOG@@Arşiv çıkarma tamamlandı (tar.exe • $([int]$exSw.Elapsed.TotalSeconds) sn)."
            return
        }
        Emit-Line "@@LOG@@tar.exe çıkış kodu $($tarProc.ExitCode), .NET ZipFile yöntemi deneniyor..."
    }

    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction Stop
        [System.IO.Compression.ZipFile]::ExtractToDirectory($ZipFile, $DestDir)
        Emit-Line "@@LOG@@Arşiv çıkarma tamamlandı (.NET ZipFile)."
    } catch {
        Expand-Archive -LiteralPath $ZipFile -DestinationPath $DestDir -Force
        Emit-Line "@@LOG@@Arşiv çıkarma tamamlandı (Expand-Archive)."
    }
}

$exitCode = 1
$usingLocalZip = $false
try {
    # 1. Yerel klasörde hazır ve geçerli zip varsa anında kullan
    $localZipCandidates = @()
    if ($PSScriptRoot) {
        $localZipCandidates += (Join-Path $PSScriptRoot $file)
        $parentDir = Split-Path -Parent $PSScriptRoot
        if ($parentDir) { $localZipCandidates += (Join-Path $parentDir $file) }
    }
    $foundLocalZip = $localZipCandidates | Where-Object { Test-ValidZipFile -Path $_ } | Select-Object -First 1

    if ($foundLocalZip) {
        $zipPath = $foundLocalZip
        $usingLocalZip = $true
        $localMB = [Math]::Round((Get-Item -LiteralPath $zipPath).Length / 1MB, 1)
        Emit-Line "@@LOG@@Yerel Adobe Acrobat Pro arşivi bulundu (indirme atlandı): $zipPath ($localMB MB)"
        Emit-Line ("@@DL_PROGRESS@@100|{0}|{0}|0" -f $localMB.ToString([System.Globalization.CultureInfo]::InvariantCulture))
    } else {
        Emit-Line "@@STAGE@@DOWNLOAD|Adobe Acrobat Pro 64-bit paketi indiriliyor..."
        Emit-Line "@@URL@@$dlLink"
        Emit-Line "@@TEMPFILE@@$zipPath"

        $curlPath = Join-Path $env:SystemRoot "System32\curl.exe"
        if (-not (Test-Path -LiteralPath $curlPath)) {
            $curlCmd = Get-Command curl.exe -ErrorAction SilentlyContinue
            $curlPath = if ($curlCmd) { $curlCmd.Source } else { $null }
        }

        $expectedBytes = Get-RemoteContentLength -Url $dlLink -CurlPath $curlPath
        if ($expectedBytes -gt 0) {
            $expMB = [Math]::Round($expectedBytes / 1MB, 1)
            Emit-Line "@@LOG@@Sunucu doğrulandı: $expMB MB (Adobe Resmi 64-Bit Paket)"
        }

        $dlOk = $false
        if ($curlPath) {
            Emit-Line "@@LOG@@Yerleşik yüksek hızlı curl.exe ile indiriliyor..."
            $dlOk = Invoke-CurlFastDownload -Url $dlLink -DestinationPath $zipPath -ExpectedBytes $expectedBytes -CurlPath $curlPath
            if (-not $dlOk) {
                Remove-Item -LiteralPath $zipPath -Force -ErrorAction SilentlyContinue
                Emit-Line "@@LOG@@Temiz yeniden indirme deneniyor (curl.exe)..."
                $dlOk = Invoke-CurlFastDownload -Url $dlLink -DestinationPath $zipPath -ExpectedBytes $expectedBytes -CurlPath $curlPath
            }
        }

        if (-not $dlOk) {
            Invoke-FallbackHttpDownload -Url $dlLink -DestinationPath $zipPath
        }

        $finalInfo = Get-Item -LiteralPath $zipPath -ErrorAction Stop
        $finalMB = [Math]::Round($finalInfo.Length / 1MB, 1)
        Emit-Line ("@@DL_DONE@@{0}|{1}" -f $zipPath, $finalMB.ToString([System.Globalization.CultureInfo]::InvariantCulture))
    }

    # 2. Çıkar
    Expand-AcrobatArchive -ZipFile $zipPath -DestDir $outputPath

    # 3. setup.exe, AcroPro.msi ve .msp yama dosyalarını bul
    $setupFile = Get-ChildItem -LiteralPath $outputPath -Filter "setup.exe" -Recurse -File -ErrorAction SilentlyContinue | Select-Object -First 1
    $msiFile   = Get-ChildItem -LiteralPath $outputPath -Filter "AcroPro.msi" -Recurse -File -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $msiFile) {
        $msiFile = Get-ChildItem -LiteralPath $outputPath -Filter "*.msi" -Recurse -File -ErrorAction SilentlyContinue | Select-Object -First 1
    }
    $mspFile   = Get-ChildItem -LiteralPath $outputPath -Filter "*.msp" -Recurse -File -ErrorAction SilentlyContinue | Sort-Object Length -Descending | Select-Object -First 1

    if (-not $setupFile -and -not $msiFile) {
        throw "Çıkarılan arşiv içinde setup.exe veya AcroPro.msi bulunamadı ($outputPath)."
    }

    # Çakışan Adobe süreçlerini kapat
    foreach ($procName in @("Acrobat", "AcroRd32", "AdobeCollabSync", "AcroTray")) {
        Get-Process -Name $procName -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    }

    $installSucceeded = $false
    $lastCode = -1

    # 4. Hızlı sessiz setup.exe kurulumu (verbose /L*v log yok -> çok daha hızlı)
    if ($setupFile) {
        Emit-Line "@@STAGE@@INSTALL|Adobe Acrobat Pro hızlı sessiz kuruluyor (setup.exe)...|5"
        Emit-Line "@@LOG@@Kurulum dosyası: $($setupFile.FullName)"

        $setupArgs = "/sAll /rs /rps /msi EULA_ACCEPT=YES UPDATE_MODE=0 DISABLE_ARM_SERVICE_INSTALL=1 DISABLE_FIU_CHECK=1 REBOOT=ReallySuppress"
        $spParams = @{
            FilePath         = $setupFile.FullName
            WorkingDirectory = $setupFile.DirectoryName
            ArgumentList     = $setupArgs
            PassThru         = $true
            WindowStyle      = "Hidden"
        }
        if (-not $isAdmin) {
            $spParams["Verb"] = "RunAs"
        }

        $p = Start-Process @spParams
        $instSw = [System.Diagnostics.Stopwatch]::StartNew()
        $lastBeat = 0

        while (-not $p.HasExited) {
            Start-Sleep -Seconds 2
            $secNow = [int]$instSw.Elapsed.TotalSeconds
            if ($secNow -ge ($lastBeat + 6)) {
                $lastBeat = $secNow
                $curMB = Get-FolderSizeMB -Path (Join-Path $env:ProgramFiles "Adobe\Acrobat DC")
                $approxPct = [Math]::Min(95, [Math]::Max(8, [int](($curMB / 1450.0) * 100)))
                if ($curMB -gt 0) {
                    Emit-Line "@@STAGE@@INSTALL|Kuruluyor... $curMB MB kopyalandı ($secNow sn)|$approxPct"
                } else {
                    Emit-Line "@@STAGE@@INSTALL|Windows Installer bileşenleri hazırlanıyor ($secNow sn)...|10"
                }
            }
        }
        $p.WaitForExit()
        $lastCode = $p.ExitCode
        Emit-Line "@@LOG@@setup.exe çıkış kodu: $lastCode ($([int]$instSw.Elapsed.TotalSeconds) sn)"

        Start-Sleep -Seconds 1
        $acroExe = Find-InstalledAcrobatExe
        if (($lastCode -eq 0 -or $lastCode -eq 3010) -and $acroExe) {
            $installSucceeded = $true
        }
    }

    # 5. Yalnızca setup.exe başarısız olduysa doğrudan AcroPro.msi + PATCH ile kur
    if (-not $installSucceeded -and $msiFile) {
        Emit-Line "@@STAGE@@INSTALL|Alternatif: AcroPro.msi ile doğrudan sessiz kurulum deneniyor...|20"
        Emit-Line "@@LOG@@setup.exe sonrası Acrobat.exe doğrulanamadı (Kod: $lastCode). Doğrudan MSI kurulumu başlatılıyor: $($msiFile.FullName)"

        $msiArgs = "/i `"$($msiFile.FullName)`""
        if ($mspFile) {
            $msiArgs += " PATCH=`"$($mspFile.FullName)`""
            Emit-Line "@@LOG@@Güncelleme yaması (MSP) eklendi: $($mspFile.Name)"
        }
        $msiArgs += " /qn /norestart EULA_ACCEPT=YES UPDATE_MODE=0 DISABLE_ARM_SERVICE_INSTALL=1 ALLUSERS=1 /le `"$msiLogDirect`""

        $mpParams = @{
            FilePath         = "msiexec.exe"
            WorkingDirectory = $msiFile.DirectoryName
            ArgumentList     = $msiArgs
            Wait             = $true
            PassThru         = $true
            WindowStyle      = "Hidden"
        }
        if (-not $isAdmin) {
            $mpParams["Verb"] = "RunAs"
        }

        $mp = Start-Process @mpParams
        $lastCode = $mp.ExitCode
        Emit-Line "@@LOG@@msiexec.exe çıkış kodu: $lastCode"

        Start-Sleep -Seconds 1
        $acroExe = Find-InstalledAcrobatExe
        if (($lastCode -eq 0 -or $lastCode -eq 3010) -and $acroExe) {
            $installSucceeded = $true
        }
    }

    # 6. Son doğrulama
    $finalExe = Find-InstalledAcrobatExe
    if ($finalExe) {
        $installDir = Split-Path -Parent $finalExe
        Emit-Line "@@INSTALL_DIR@@$installDir"
        Emit-Line "@@APP_EXE@@$finalExe"
        Emit-Line "@@LOG@@Adobe Acrobat Pro doğrulandı -> Kurulum Klasörü: $installDir"
        $exitCode = if ($lastCode -eq 3010) { 3010 } else { 0 }
    } else {
        Emit-Line "@@LOG@@HATA: Adobe Acrobat Pro kurulumu sonrasında Acrobat.exe bulunamadı (Son Çıkış Kodu: $lastCode)."
        if (Test-Path -LiteralPath $msiLogDirect) {
            $errLines = Get-Content -LiteralPath $msiLogDirect -ErrorAction SilentlyContinue | Select-Object -Last 5
            foreach ($el in $errLines) {
                if (-not [string]::IsNullOrWhiteSpace($el)) {
                    Emit-Line "@@LOG@@MSI Hata: $($el.Trim())"
                }
            }
        }
        $exitCode = if ($lastCode -ne 0 -and $lastCode -ne -1) { $lastCode } else { 1 }
    }
} catch {
    Emit-Line "@@LOG@@HATA: $($_.Exception.Message)"
    $exitCode = 1
} finally {
    if (Test-Path -LiteralPath $outputPath) {
        Remove-Item -LiteralPath $outputPath -Recurse -Force -ErrorAction SilentlyContinue
    }
    if ($exitCode -eq 0 -or $exitCode -eq 3010) {
        if (-not $usingLocalZip -and (Test-Path -LiteralPath $zipPath)) {
            Remove-Item -LiteralPath $zipPath -Force -ErrorAction SilentlyContinue
        }
    }
}

exit $exitCode
