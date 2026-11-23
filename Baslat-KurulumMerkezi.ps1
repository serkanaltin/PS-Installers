<#
.SYNOPSIS
    Hızlı Kurulum Merkezi (Modern Dashboard Arayüzlü Katılımsız Yazılım Kurulum Aracı)
.DESCRIPTION
    Bilgi İşlem (BT) ekipleri için tasarlanmış, gerçek uygulama logolu, kategorize edilmiş,
    yüklü programları otomatik algılayan ("YÜKLÜ" rozetli), özel paket oluşturma/düzenleme/silme
    (`ozel_paketler.json`) ve adım adım canlı kurulum takip destekli modern kurulum paneli (Dashboard).
    Geliştirici: Serkan Altın
    Açık Kaynak Altyapı & Atıf: Tyler Lurie - PS-Installers (https://github.com/tylerlurie/PS-Installers)
.LINK
    https://github.com/tylerlurie/PS-Installers
#>

[CmdletBinding()]
param(
    [switch]$NoElevate
)

# 1. Yönetici (Administrator) Yetkisi Kontrolü ve Otomatik Yükseltme (UAC onaylarını tek seferde geçmek için)
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin -and -not $NoElevate) {
    try {
        $scriptPath = $MyInvocation.MyCommand.Definition
        if ($scriptPath) {
            Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`"" -Verb RunAs
            exit
        }
    } catch {
        Write-Warning "Yönetici yetkisi alınamadı. Kurulumlar sırasında UAC onayı istenebilir."
    }
}

# WPF Kütüphanelerini Yükle
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Drawing

$ScriptRoot       = if ($MyInvocation.MyCommand.Path -and (Test-Path -LiteralPath (Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "Documents"))) {
    Split-Path -Parent $MyInvocation.MyCommand.Path
} elseif ($PSScriptRoot -and (Test-Path -LiteralPath (Join-Path $PSScriptRoot "Documents"))) {
    $PSScriptRoot
} else {
    (Get-Location).Path
}
$IconsCacheDir    = Join-Path $ScriptRoot ".icons"
$PackagesJsonPath = Join-Path $ScriptRoot "ozel_paketler.json"

if (-not (Test-Path -LiteralPath $IconsCacheDir)) {
    New-Item -ItemType Directory -Path $IconsCacheDir -Force | Out-Null
}

# 2. Doğal ve Anlaşılır Türkçe Kategori Eşleştirmesi, İkonlar ve Sıralama Önceliği
$CategoryTranslations = @{
    "E İMZA"                              = "E-İmza ve Akıllı Kart"
    "Documents"                           = "Ofis ve PDF Araçları"
    "Web Browsers"                        = "İnternet Tarayıcıları"
    "Compression"                         = "Arşiv ve Dosya Sıkıştırma"
    "Utilities"                           = "Uzak Masaüstü ve Sistem"
    "Other\File System Tools"             = "Uzak Masaüstü ve Sistem"
    "Messaging"                           = "İletişim ve Toplantı"
    "Media"                               = "Ses, Video ve Ekran Kaydı"
    "Other\Screen Recorders"              = "Ses, Video ve Ekran Kaydı"
    "Imaging"                             = "Görsel ve Ekran Görüntüsü"
    "Online Storage"                      = "Bulut Depolama"
    "Developer Tools"                     = "Yazılım ve Sunucu Araçları"
    "Runtimes"                            = "Sistem Bileşenleri (.NET / C++)"
    "Security"                            = "Antivirüs ve Güvenlik"
    "Other\Virtualization Software"       = "Sanal Makine Araçları"
    "File Sharing"                        = "Dosya Paylaşımı ve Harita"
    "Other\Geographic Information System" = "Dosya Paylaşımı ve Harita"
    "Other\Accessibility"                 = "Uzak Masaüstü ve Sistem"
    "Other\Game Launchers"                = "Oyun Platformları"
}

$CategoryOrder = @(
    "E-İmza ve Akıllı Kart",
    "Ofis ve PDF Araçları",
    "İnternet Tarayıcıları",
    "Arşiv ve Dosya Sıkıştırma",
    "Uzak Masaüstü ve Sistem",
    "İletişim ve Toplantı",
    "Ses, Video ve Ekran Kaydı",
    "Görsel ve Ekran Görüntüsü",
    "Bulut Depolama",
    "Yazılım ve Sunucu Araçları",
    "Sistem Bileşenleri (.NET / C++)",
    "Antivirüs ve Güvenlik",
    "Sanal Makine Araçları",
    "Dosya Paylaşımı ve Harita",
    "Oyun Platformları"
)

# Segoe MDL2 Assets Kategori İkon Kodları
$CategoryGlyphs = @{
    "Tümü"                            = [string][char]0xE71D
    "E-İmza ve Akıllı Kart"           = [string][char]0xE8D7
    "Ofis ve PDF Araçları"            = [string][char]0xE8A5
    "İnternet Tarayıcıları"           = [string][char]0xE774
    "Arşiv ve Dosya Sıkıştırma"       = [string][char]0xF012
    "Uzak Masaüstü ve Sistem"         = [string][char]0xE7F4
    "İletişim ve Toplantı"            = [string][char]0xE8BD
    "Ses, Video ve Ekran Kaydı"       = [string][char]0xE714
    "Görsel ve Ekran Görüntüsü"       = [string][char]0xEB9F
    "Bulut Depolama"                  = [string][char]0xE753
    "Yazılım ve Sunucu Araçları"      = [string][char]0xE943
    "Sistem Bileşenleri (.NET / C++)" = [string][char]0xE950
    "Antivirüs ve Güvenlik"           = [string][char]0xEA18
    "Sanal Makine Araçları"           = [string][char]0xE7F8
    "Dosya Paylaşımı ve Harita"       = [string][char]0xE707
    "Oyun Platformları"               = [string][char]0xE7FC
}

# Uygulama Kataloğu: Marka Rengi (Color), Logo Kısaltması (Mono), Resmi Logo Alan Adı (Domain), Kayıt Defteri Algılama Deseni (DetectPattern)
$AppMetadata = @{
    "Install_DtxgateSigner.ps1"            = @{ Name = "Dtxgate Signer (E-İmza İstemcisi)"; Winget = ""; Desc = "Yerel MSI paketi (DtxgateSigner-1.0.23.msi) ile sessiz kurulum"; Preset = @("HemenTeslim"); IsLocal = $true; Domain = "arksigner.com"; Color = "#0284C7"; Mono = "DTX"; Detect = "Dtxgate|ArkSigner" }
    "Install_SafeNet_SAC.ps1"              = @{ Name = "SafeNet Authentication Client 10.4"; Winget = ""; Desc = "Akıllı kart ve E-İmza token sürücüsü (SAC-x64-10.4.msi)"; Preset = @("HemenTeslim"); IsLocal = $true; Domain = "thalesgroup.com"; Color = "#4F46E5"; Mono = "SAC"; Detect = "SafeNet Authentication Client" }
    "Install_Java_JRE_8.ps1"               = @{ Name = "Java JRE 8u513 (E-İmza Uyumlu)"; Winget = "Oracle.JavaRuntimeEnvironment"; Desc = "E-İmza uygulamaları için Java 8 çalışma zamanı (jre-8u513)"; Preset = @("HemenTeslim"); IsLocal = $true; Domain = "java.com"; Color = "#EA580C"; Mono = "JRE"; Detect = "^Java 8 Update|Java\(TM\) SE Runtime" }

    "Install_Google_Chrome.ps1"            = @{ Name = "Google Chrome (Kurumsal)"; Winget = "Google.Chrome"; Desc = "Tüm kullanıcılar için 64-bit kurumsal MSI sürümü"; Preset = @("HemenTeslim"); Domain = "google.com/chrome"; Color = "#2563EB"; Mono = "GC"; Detect = "^Google Chrome$" }
    "Install_Firefox.ps1"                  = @{ Name = "Mozilla Firefox"; Winget = "Mozilla.Firefox"; Desc = "Hızlı ve gizlilik odaklı internet tarayıcısı"; Preset = @(); Domain = "mozilla.org"; Color = "#EA580C"; Mono = "FF"; Detect = "^Mozilla Firefox" }
    "Install_Brave.ps1"                    = @{ Name = "Brave Tarayıcı"; Winget = "Brave.Brave"; Desc = "Dahili reklam engelleyicili Chromium tarayıcı"; Preset = @(); Domain = "brave.com"; Color = "#F97316"; Mono = "BR"; Detect = "^Brave$" }
    "Install_Microsoft_Edge.ps1"           = @{ Name = "Microsoft Edge"; Winget = "Microsoft.Edge"; Desc = "Microsoft kurumsal internet tarayıcısı"; Preset = @(); Domain = "microsoft.com/edge"; Color = "#0284C7"; Mono = "EDG"; Detect = "^Microsoft Edge$" }
    "Install_Opera.ps1"                    = @{ Name = "Opera Tarayıcı"; Winget = "Opera.Opera"; Desc = "Dahili araçlara sahip hızlı internet tarayıcısı"; Preset = @(); Domain = "opera.com"; Color = "#DC2626"; Mono = "OP"; Detect = "^Opera Stable" }
    "Install_Vivaldi.ps1"                  = @{ Name = "Vivaldi"; Winget = "Vivaldi.Vivaldi"; Desc = "Gelişmiş sekme yönetimli internet tarayıcısı"; Preset = @(); Domain = "vivaldi.com"; Color = "#E11D48"; Mono = "VV"; Detect = "^Vivaldi$" }

    "Install_7-Zip.ps1"                    = @{ Name = "7-Zip"; Winget = "7zip.7zip"; Desc = "Ücretsiz ve yüksek hızlı ZIP/7Z arşiv yöneticisi"; Preset = @("Temel"); Domain = "7-zip.org"; Color = "#475569"; Mono = "7Z"; Detect = "^7-Zip" }
    "Install_WinRAR.ps1"                   = @{ Name = "WinRAR (64-Bit)"; Winget = "RARLab.WinRAR"; Desc = "RAR ve ZIP arşiv dosyalarını açma ve sıkıştırma aracı"; Preset = @("HemenTeslim"); Domain = "win-rar.com"; Color = "#7C3AED"; Mono = "RAR"; Detect = "^WinRAR" }
    "Install_PeaZip.ps1"                   = @{ Name = "PeaZip"; Winget = "Giorgiotani.Peazip"; Desc = "Açık kaynaklı çoklu format arşiv yöneticisi"; Preset = @(); Domain = "peazip.github.io"; Color = "#16A34A"; Mono = "PZ"; Detect = "^PeaZip" }

    "Install_Adobe_Acrobat_Reader.ps1"     = @{ Name = "Adobe Acrobat Reader DC"; Winget = "Adobe.Acrobat.Reader.64-bit"; Desc = "Ücretsiz standart PDF görüntüleme ve yazdırma aracı"; Preset = @(); Domain = "adobe.com"; Color = "#DC2626"; Mono = "PDF"; Detect = "Adobe Acrobat Reader" }
    "Install_Adobe_Acrobat_Pro.ps1"        = @{ Name = "Adobe Acrobat Pro"; Winget = "Adobe.Acrobat.Pro"; Desc = "Kapsamlı PDF düzenleme, dönüştürme ve imzalama paketi"; Preset = @("HemenTeslim"); Domain = "adobe.com"; Color = "#B91C1C"; Mono = "PRO"; Detect = "^Adobe Acrobat \(64-bit\)|Adobe Acrobat DC|Adobe Acrobat Pro" }
    "Install_Foxit_Reader.ps1"             = @{ Name = "Foxit PDF Reader"; Winget = "Foxit.FoxitReader"; Desc = "Hızlı açılan hafif PDF görüntüleme programı"; Preset = @(); Domain = "foxit.com"; Color = "#EA580C"; Mono = "FX"; Detect = "Foxit PDF Reader|Foxit Reader" }
    "Install_Sumatra_PDF.ps1"              = @{ Name = "Sumatra PDF"; Winget = "SumatraPDF.SumatraPDF"; Desc = "Çok hafif ve hızlı PDF, ePub ve çizgi roman okuyucu"; Preset = @(); Domain = "sumatrapdfreader.org"; Color = "#CA8A04"; Mono = "SUM"; Detect = "^SumatraPDF$" }
    "Install_LibreOffice.ps1"              = @{ Name = "LibreOffice"; Winget = "TheDocumentFoundation.LibreOffice"; Desc = "Ücretsiz ve açık kaynaklı tam kapsamlı ofis paketi"; Preset = @(); Domain = "libreoffice.org"; Color = "#16A34A"; Mono = "LO"; Detect = "^LibreOffice" }
    "Install_FreeOffice.ps1"               = @{ Name = "SoftMaker FreeOffice"; Winget = "SoftMaker.FreeOffice.2021"; Desc = "Word, Excel ve PowerPoint uyumlu ücretsiz ofis paketi"; Preset = @(); Domain = "freeoffice.com"; Color = "#E11D48"; Mono = "FO"; Detect = "SoftMaker FreeOffice" }
    "Install_OpenOffice.ps1"               = @{ Name = "Apache OpenOffice"; Winget = "Apache.OpenOffice"; Desc = "Açık kaynaklı klasik belge ve tablo paketi"; Preset = @(); Domain = "openoffice.org"; Color = "#0284C7"; Mono = "OO"; Detect = "^OpenOffice" }
    "Install_Office365_Enterprise.ps1"     = @{ Name = "Microsoft Office 2021 Pro Plus (Kurumsal)"; Winget = ""; Desc = "Yerel office_setup.exe + configuration.xml ile 64-Bit Türkçe Office 2021"; Preset = @(); IsLocal = $true; Domain = "office.com"; Color = "#D97706"; Mono = "2021"; Detect = "Microsoft Office LTSC Professional Plus 2021|Microsoft Office Professional Plus 2021|Microsoft 365 Apps for enterprise|O365ProPlusRetail" }
    "Install_Office365_Business.ps1"       = @{ Name = "Microsoft Office 2021 Pro Plus (İş)"; Winget = ""; Desc = "Yerel office_setup.exe + configuration.xml ile 64-Bit Türkçe Office 2021"; Preset = @(); IsLocal = $true; Domain = "office.com"; Color = "#EA580C"; Mono = "2021"; Detect = "Microsoft Office LTSC Professional Plus 2021|Microsoft Office Professional Plus 2021|Microsoft 365 Apps for business|O365BusinessRetail" }
    "Install_Office365_HomePrem.ps1"       = @{ Name = "Microsoft Office 2021 Pro Plus (Türkçe)"; Winget = ""; Desc = "Word, Excel, PowerPoint, Outlook 2021 (office_setup.exe + configuration.xml)"; Preset = @("HemenTeslim"); IsLocal = $true; Domain = "office.com"; Color = "#EA580C"; Mono = "2021"; Detect = "Microsoft Office LTSC Professional Plus 2021|Microsoft Office Professional Plus 2021|ProPlus2021Volume|ProPlus2021Retail|Microsoft 365" }

    "Install_Yeastar_Linkus.ps1"           = @{ Name = "Yeastar Linkus (Dahili Santral & Çağrı)"; Winget = ""; Desc = "Şirket içi dahili telefon hattı ve çağrı merkezi (Softphone) MSI istemcisi"; Preset = @(); Domain = "yeastar.com"; Color = "#0284C7"; Mono = "PBX"; Detect = "Linkus|Yeastar" }
    "Install_Microsoft_Teams.ps1"          = @{ Name = "Microsoft Teams"; Winget = "Microsoft.Teams"; Desc = "Şirket içi yazışma ve görüntülü toplantı programı"; Preset = @(); Domain = "teams.microsoft.com"; Color = "#4F46E5"; Mono = "TMS"; Detect = "Microsoft Teams|MSTeams" }
    "Install_Zoom.ps1"                     = @{ Name = "Zoom Workplace"; Winget = "Zoom.Zoom"; Desc = "Kurumsal MSI tabanlı görüntülü toplantı programı"; Preset = @(); Domain = "zoom.us"; Color = "#2563EB"; Mono = "ZM"; Detect = "^Zoom" }
    "Install_Discord.ps1"                  = @{ Name = "Discord"; Winget = "Discord.Discord"; Desc = "Sesli, görüntülü ve yazılı iletişim platformu"; Preset = @(); Domain = "discord.com"; Color = "#4F46E5"; Mono = "DC"; Detect = "^Discord$" }
    "Install_Telegram.ps1"                 = @{ Name = "Telegram Masaüstü"; Winget = "Telegram.TelegramDesktop"; Desc = "Hızlı ve bulut tabanlı mesajlaşma uygulaması"; Preset = @(); Domain = "telegram.org"; Color = "#0284C7"; Mono = "TG"; Detect = "^Telegram Desktop$" }
    "Install_Signal.ps1"                   = @{ Name = "Signal Masaüstü"; Winget = "OpenWhisperSystems.Signal"; Desc = "Uçtan uca şifreli güvenli mesajlaşma uygulaması"; Preset = @(); Domain = "signal.org"; Color = "#2563EB"; Mono = "SIG"; Detect = "^Signal " }
    "Install_Thunderbird.ps1"              = @{ Name = "Mozilla Thunderbird"; Winget = "Mozilla.Thunderbird"; Desc = "Ücretsiz gelişmiş e-posta ve takvim istemcisi"; Preset = @(); Domain = "thunderbird.net"; Color = "#0284C7"; Mono = "TB"; Detect = "^Mozilla Thunderbird" }
    "Install_eM_Client.ps1"                = @{ Name = "eM Client"; Winget = "eMClient.eMClient"; Desc = "Modern arayüzlü kurumsal e-posta istemcisi"; Preset = @(); Domain = "emclient.com"; Color = "#F97316"; Mono = "eM"; Detect = "^eM Client$" }
    "Install_TeamSpeak.ps1"                = @{ Name = "TeamSpeak"; Winget = "TeamSpeakSystems.TeamSpeakClient"; Desc = "Düşük gecikmeli sesli iletişim istemcisi"; Preset = @(); Domain = "teamspeak.com"; Color = "#1E40AF"; Mono = "TS"; Detect = "^TeamSpeak 3 Client$" }

    "Install_AnyDesk.ps1"                  = @{ Name = "AnyDesk"; Winget = "AnyDeskSoftwareGmbH.AnyDesk"; Desc = "Bilgi işlem uzaktan bağlantı ve teknik destek aracı"; Preset = @("HemenTeslim", "Temel"); Domain = "anydesk.com"; Color = "#EF4444"; Mono = "AD"; Detect = "^AnyDesk$" }
    "Install_TeamViewer.ps1"               = @{ Name = "TeamViewer"; Winget = "TeamViewer.TeamViewer"; Desc = "Uzaktan masaüstü bağlantısı ve teknik destek yazılımı"; Preset = @(); Domain = "teamviewer.com"; Color = "#2563EB"; Mono = "TV"; Detect = "^TeamViewer$" }
    "Install_OpenVPN.ps1"                  = @{ Name = "OpenVPN Connect"; Winget = "OpenVPNTechnologies.OpenVPN"; Desc = "Şirket ağına uzaktan güvenli bağlantı (VPN) istemcisi"; Preset = @(); Domain = "openvpn.net"; Color = "#EA580C"; Mono = "VPN"; Detect = "^OpenVPN" }
    "Install_Revo_Uninstaller.ps1"         = @{ Name = "Revo Uninstaller"; Winget = "RevoUninstaller.RevoUninstaller"; Desc = "Programları kayıt defteri kalıntısı bırakmadan kaldırma aracı"; Preset = @(); Domain = "revouninstaller.com"; Color = "#0284C7"; Mono = "REV"; Detect = "^Revo Uninstaller" }
    "Install_WinDirStat.ps1"               = @{ Name = "WinDirStat"; Winget = "WinDirStat.WinDirStat"; Desc = "Diskte yer kaplayan klasörleri görsel olarak analiz etme aracı"; Preset = @("Temel"); Domain = "windirstat.net"; Color = "#059669"; Mono = "WDS"; Detect = "^WinDirStat$" }
    "Install_ImgBurn.ps1"                  = @{ Name = "ImgBurn"; Winget = "LIGHTNINGUK.ImgBurn"; Desc = "CD/DVD ve ISO kalıp dosyası yazdırma aracı"; Preset = @(); Domain = "imgburn.com"; Color = "#EA580C"; Mono = "ISO"; Detect = "^ImgBurn$" }
    "Install_Everything.ps1"               = @{ Name = "Everything (Anında Dosya Arama)"; Winget = "voidtools.Everything"; Desc = "Bilgisayardaki milyonlarca dosyayı saniyede bulan arama aracı"; Preset = @("Temel"); Domain = "voidtools.com"; Color = "#D97706"; Mono = "EV"; Detect = "^Everything " }
    "Install_NV_Access.ps1"                = @{ Name = "NVDA Ekran Okuyucu"; Winget = "NVAccess.NVDA"; Desc = "Görme engelli kullanıcılar için Türkçe sesli ekran okuyucu"; Preset = @(); Domain = "nvaccess.org"; Color = "#7C3AED"; Mono = "NV"; Detect = "^NVDA" }

    "Install_Visual_Studio_Code.ps1"       = @{ Name = "Visual Studio Code"; Winget = "Microsoft.VisualStudioCode"; Desc = "Modern ve eklenti destekli kaynak kod düzenleyicisi"; Preset = @(); Domain = "code.visualstudio.com"; Color = "#0284C7"; Mono = "VSC"; Detect = "Microsoft Visual Studio Code" }
    "Install_Notepad-Plus-Plus.ps1"        = @{ Name = "Notepad++"; Winget = "Notepad++.Notepad++"; Desc = "Sistem yöneticileri için gelişmiş metin ve kod editörü"; Preset = @("Temel"); Domain = "notepad-plus-plus.org"; Color = "#16A34A"; Mono = "N++"; Detect = "^Notepad\+\+" }
    "Install_Sublime_Text.ps1"             = @{ Name = "Sublime Text"; Winget = "SublimeHQ.SublimeText.4"; Desc = "Çok hızlı açılan hafif kod ve metin düzenleyici"; Preset = @(); Domain = "sublimetext.com"; Color = "#D97706"; Mono = "ST"; Detect = "^Sublime Text" }
    "Install_PuTTY.ps1"                    = @{ Name = "PuTTY"; Winget = "PuTTY.PuTTY"; Desc = "Sunucu ve ağ cihazları yönetimi için SSH / Telnet istemcisi"; Preset = @("Temel"); Domain = "putty.org"; Color = "#2563EB"; Mono = "SSH"; Detect = "^PuTTY release" }
    "Install_WinSCP.ps1"                   = @{ Name = "WinSCP"; Winget = "WinSCP.WinSCP"; Desc = "Sunuculara güvenli SFTP, SCP ve FTP dosya aktarım aracı"; Preset = @("Temel"); Domain = "winscp.net"; Color = "#0284C7"; Mono = "SCP"; Detect = "^WinSCP " }
    "Install_FileZilla.ps1"                = @{ Name = "FileZilla Client"; Winget = "TimKosse.FileZilla.Client"; Desc = "Hızlı FTP / FTPS / SFTP dosya transfer istemcisi"; Preset = @(); Domain = "filezilla-project.org"; Color = "#DC2626"; Mono = "FZ"; Detect = "^FileZilla" }
    "Install_Python_3.ps1"                 = @{ Name = "Python 3 (64-Bit)"; Winget = "Python.Python.3.12"; Desc = "Güncel Python 3 programlama dili çalışma ortamı"; Preset = @(); Domain = "python.org"; Color = "#0284C7"; Mono = "PY3"; Detect = "^Python 3\." }
    "Install_Python_2.7.ps1"               = @{ Name = "Python 2.7 (Eski Sistem)"; Winget = "Python.Python.2"; Desc = "Eski yazılımlar için Python 2.7 sürümü"; Preset = @(); Domain = "python.org"; Color = "#475569"; Mono = "PY2"; Detect = "^Python 2\.7" }
    "Install_Java_JDK.ps1"                 = @{ Name = "Java SE Development Kit (JDK)"; Winget = "Oracle.JDK.21"; Desc = "Java tabanlı kurumsal uygulamalar için geliştirme kiti"; Preset = @(); Domain = "oracle.com"; Color = "#DC2626"; Mono = "JDK"; Detect = "Java\(TM\) SE Development Kit" }
    "Install_Visual_Studio_Community.ps1"  = @{ Name = "Visual Studio Community"; Winget = "Microsoft.VisualStudio.2022.Community"; Desc = "Microsoft .NET ve C++ yazılım geliştirme ortamı (IDE)"; Preset = @(); Domain = "visualstudio.microsoft.com"; Color = "#7C3AED"; Mono = "VS"; Detect = "Visual Studio Community" }

    "Install_VLC_Media_Player.ps1"         = @{ Name = "VLC Media Player"; Winget = "VideoLAN.VLC"; Desc = "Tüm ses ve video formatlarını sorunsuz açan oynatıcı"; Preset = @("Temel"); Domain = "videolan.org"; Color = "#EA580C"; Mono = "VLC"; Detect = "^VLC media player$" }
    "Install_K-Lite_Codec_Pack_Full.ps1"   = @{ Name = "K-Lite Codec Pack Full"; Winget = "CodecGuide.K-LiteCodecPack.Full"; Desc = "Açılmayan video ve ses formatları için tam çözücü paketi"; Preset = @(); Domain = "codecguide.com"; Color = "#0284C7"; Mono = "KLC"; Detect = "^K-Lite Codec Pack" }
    "Install_Audacity.ps1"                 = @{ Name = "Audacity"; Winget = "Audacity.Audacity"; Desc = "Ücretsiz ses kaydetme, kesme ve düzenleme programı"; Preset = @(); Domain = "audacityteam.org"; Color = "#2563EB"; Mono = "AUD"; Detect = "^Audacity" }
    "Install_Spotify.ps1"                  = @{ Name = "Spotify"; Winget = "Spotify.Spotify"; Desc = "Masaüstü müzik ve podcast dinleme uygulaması"; Preset = @(); Domain = "spotify.com"; Color = "#16A34A"; Mono = "SP"; Detect = "^Spotify$" }
    "Install_iTunes.ps1"                   = @{ Name = "Apple iTunes"; Winget = "Apple.iTunes"; Desc = "iPhone/iPad yedekleme ve medya yönetim programı"; Preset = @(); Domain = "apple.com"; Color = "#E11D48"; Mono = "iT"; Detect = "^iTunes$" }
    "Install_foobar2000.ps1"               = @{ Name = "foobar2000"; Winget = "PeterPawlowski.foobar2000"; Desc = "Düşük bellek tüketen gelişmiş müzik oynatıcısı"; Preset = @(); Domain = "foobar2000.org"; Color = "#475569"; Mono = "FB"; Detect = "^foobar2000" }
    "Install_OBS_Studio.ps1"               = @{ Name = "OBS Studio"; Winget = "OBSProject.OBSStudio"; Desc = "Ücretsiz profesyonel ekran kaydı ve canlı yayın programı"; Preset = @(); Domain = "obsproject.com"; Color = "#334155"; Mono = "OBS"; Detect = "^OBS Studio$" }
    "Install_Bandicam.ps1"                 = @{ Name = "Bandicam"; Winget = "BandicamCompany.Bandicam"; Desc = "Yüksek kaliteli ekran ve uygulama videosu kaydetme aracı"; Preset = @(); Domain = "bandicam.com"; Color = "#DC2626"; Mono = "BDC"; Detect = "^Bandicam$" }

    "Install_ShareX.ps1"                   = @{ Name = "ShareX"; Winget = "ShareX.ShareX"; Desc = "Gelişmiş ekran görüntüsü alma, GIF kaydetme ve çizim aracı"; Preset = @(); Domain = "getsharex.com"; Color = "#0284C7"; Mono = "SX"; Detect = "^ShareX$" }
    "Install_Greenshot.ps1"                = @{ Name = "Greenshot"; Winget = "Greenshot.Greenshot"; Desc = "Ofis kullanıcıları için pratik ekran görüntüsü alma aracı"; Preset = @(); Domain = "getgreenshot.org"; Color = "#16A34A"; Mono = "GS"; Detect = "^Greenshot" }
    "Install_Paint.NET.ps1"                = @{ Name = "Paint.NET"; Winget = "dotPDN.PaintDotNet"; Desc = "Katman destekli, hızlı fotoğraf ve görsel düzenleme aracı"; Preset = @(); Domain = "getpaint.net"; Color = "#2563EB"; Mono = "PDN"; Detect = "^paint\.net$" }
    "Install_GIMP.ps1"                     = @{ Name = "GIMP"; Winget = "GIMP.GIMP"; Desc = "Ücretsiz profesyonel fotoğraf ve grafik tasarım programı"; Preset = @(); Domain = "gimp.org"; Color = "#78350F"; Mono = "GMP"; Detect = "^GIMP " }
    "Install_Blender.ps1"                  = @{ Name = "Blender"; Winget = "BlenderFoundation.Blender"; Desc = "3 boyutlu modelleme, animasyon ve tasarım yazılımı"; Preset = @(); Domain = "blender.org"; Color = "#EA580C"; Mono = "BLD"; Detect = "^Blender" }

    "Install_Google_Drive_for_Desktop.ps1" = @{ Name = "Google Drive Masaüstü"; Winget = "Google.GoogleDrive"; Desc = "Google Drive dosyalarını bilgisayarla eşitleme programı"; Preset = @(); Domain = "drive.google.com"; Color = "#16A34A"; Mono = "DRV"; Detect = "^Google Drive$" }
    "Install_OneDrive.ps1"                 = @{ Name = "Microsoft OneDrive"; Winget = "Microsoft.OneDrive"; Desc = "Microsoft 365 bulut yedekleme ve dosya senkronizasyonu"; Preset = @(); Domain = "onedrive.live.com"; Color = "#0284C7"; Mono = "OD"; Detect = "^Microsoft OneDrive$" }
    "Install_Dropbox.ps1"                  = @{ Name = "Dropbox"; Winget = "Dropbox.Dropbox"; Desc = "Dropbox bulut klasör eşitleme ve paylaşım uygulaması"; Preset = @(); Domain = "dropbox.com"; Color = "#2563EB"; Mono = "DBX"; Detect = "^Dropbox$" }

    "Install_.NET_8_Desktop_Runtime.ps1"   = @{ Name = ".NET 8 Masaüstü Çalışma Zamanı"; Winget = "Microsoft.DotNet.DesktopRuntime.8"; Desc = "Güncel .NET 8 masaüstü programlarını çalıştıran bileşen"; Preset = @("Temel"); Domain = "dotnet.microsoft.com"; Color = "#6D28D9"; Mono = ".N8"; Detect = "Microsoft Windows Desktop Runtime - 8\." }
    "Install_.NET_7_Desktop_Runtime.ps1"   = @{ Name = ".NET 7 Masaüstü Çalışma Zamanı"; Winget = "Microsoft.DotNet.DesktopRuntime.7"; Desc = ".NET 7 tabanlı Windows uygulamaları için çalışma zamanı"; Preset = @(); Domain = "dotnet.microsoft.com"; Color = "#6D28D9"; Mono = ".N7"; Detect = "Microsoft Windows Desktop Runtime - 7\." }
    "Install_.NET_6_Desktop_Runtime.ps1"   = @{ Name = ".NET 6 Masaüstü Çalışma Zamanı"; Winget = "Microsoft.DotNet.DesktopRuntime.6"; Desc = ".NET 6 LTS tabanlı programlar için çalışma zamanı"; Preset = @("Temel"); Domain = "dotnet.microsoft.com"; Color = "#6D28D9"; Mono = ".N6"; Detect = "Microsoft Windows Desktop Runtime - 6\." }
    "Install_.NET_5_Desktop_Runtime.ps1"   = @{ Name = ".NET 5 Masaüstü Çalışma Zamanı"; Winget = "Microsoft.DotNet.DesktopRuntime.5"; Desc = ".NET 5 tabanlı programlar için çalışma zamanı"; Preset = @(); Domain = "dotnet.microsoft.com"; Color = "#6D28D9"; Mono = ".N5"; Detect = "Microsoft Windows Desktop Runtime - 5\." }
    "Install_.NET_3.1_Desktop_Runtime.ps1" = @{ Name = ".NET Core 3.1 Çalışma Zamanı"; Winget = "Microsoft.DotNet.DesktopRuntime.3_1"; Desc = ".NET Core 3.1 masaüstü programları için çalışma zamanı"; Preset = @(); Domain = "dotnet.microsoft.com"; Color = "#6D28D9"; Mono = ".N3"; Detect = "Microsoft Windows Desktop Runtime - 3\.1" }
    "Install_.NET_Framework_4.8.ps1"       = @{ Name = ".NET Framework 4.8"; Winget = "Microsoft.DotNet.Framework.DeveloperPack_4"; Desc = "Klasik Windows ve muhasebe/ERP yazılımları için .NET 4.8"; Preset = @(); Domain = "dotnet.microsoft.com"; Color = "#4F46E5"; Mono = "4.8"; Detect = "Microsoft \.NET Framework 4\.8" }
    "Install_VCRedist_2015-2022-x64.ps1"   = @{ Name = "Visual C++ 2015-2022 (64-Bit)"; Winget = "Microsoft.VCRedist.2015+.x64"; Desc = "Programlardaki DLL hatalarını önleyen temel C++ paketi"; Preset = @("Temel"); Domain = "visualstudio.microsoft.com"; Color = "#0284C7"; Mono = "C++"; Detect = "Microsoft Visual C\+\+ 2015-2022 Redistributable \(x64\)" }
    "Install_VCRedist_2013-x64.ps1"        = @{ Name = "Visual C++ 2013 (64-Bit)"; Winget = "Microsoft.VCRedist.2013.x64"; Desc = "2013 C++ tabanlı yazılımlar için sistem kütüphanesi"; Preset = @(); Domain = "visualstudio.microsoft.com"; Color = "#0369A1"; Mono = "C13"; Detect = "Microsoft Visual C\+\+ 2013 Redistributable \(x64\)" }
    "Install_VCRedist_2012-x64.ps1"        = @{ Name = "Visual C++ 2012 (64-Bit)"; Winget = "Microsoft.VCRedist.2012.x64"; Desc = "2012 C++ tabanlı yazılımlar için sistem kütüphanesi"; Preset = @(); Domain = "visualstudio.microsoft.com"; Color = "#0369A1"; Mono = "C12"; Detect = "Microsoft Visual C\+\+ 2012 Redistributable \(x64\)" }
    "Install_VCRedist_2010-x64.ps1"        = @{ Name = "Visual C++ 2010 (64-Bit)"; Winget = "Microsoft.VCRedist.2010.x64"; Desc = "2010 C++ tabanlı yazılımlar için sistem kütüphanesi"; Preset = @(); Domain = "visualstudio.microsoft.com"; Color = "#0369A1"; Mono = "C10"; Detect = "Microsoft Visual C\+\+ 2010  x64 Redistributable" }
    "Install_VCRedist_2008-x64.ps1"        = @{ Name = "Visual C++ 2008 (64-Bit)"; Winget = "Microsoft.VCRedist.2008.x64"; Desc = "2008 C++ tabanlı yazılımlar için sistem kütüphanesi"; Preset = @(); Domain = "visualstudio.microsoft.com"; Color = "#0369A1"; Mono = "C08"; Detect = "Microsoft Visual C\+\+ 2008 Redistributable - x64" }
    "Install_VCRedist_2005-x64.ps1"        = @{ Name = "Visual C++ 2005 (64-Bit)"; Winget = "Microsoft.VCRedist.2005.x64"; Desc = "2005 C++ tabanlı eski yazılımlar için sistem kütüphanesi"; Preset = @(); Domain = "visualstudio.microsoft.com"; Color = "#0369A1"; Mono = "C05"; Detect = "Microsoft Visual C\+\+ 2005 Redistributable \(x64\)" }
    "Install_DirectX_Runtime.ps1"          = @{ Name = "DirectX End-User Runtime"; Winget = "Microsoft.DirectX"; Desc = "Grafik, çizim ve multimedya programları için DirectX"; Preset = @(); Domain = "microsoft.com"; Color = "#16A34A"; Mono = "DX"; Detect = "^DirectX_NeverMatch$" }

    "Install_Malwarebytes.ps1"             = @{ Name = "Malwarebytes"; Winget = "Malwarebytes.Malwarebytes"; Desc = "Reklam virüslerini ve zararlı yazılımları temizleme aracı"; Preset = @(); Domain = "malwarebytes.com"; Color = "#2563EB"; Mono = "MB"; Detect = "^Malwarebytes version" }
    "Install_Avast.ps1"                    = @{ Name = "Avast Free Antivirus"; Winget = "Avast.AvastFreeAntivirus"; Desc = "Ücretsiz gerçek zamanlı antivirüs koruması"; Preset = @(); Domain = "avast.com"; Color = "#EA580C"; Mono = "AVS"; Detect = "^Avast Free Antivirus$" }
    "Install_AVG.ps1"                      = @{ Name = "AVG AntiVirus Free"; Winget = "AVG.AntiVirusFree"; Desc = "Temel sistem ve internet antivirüs koruması"; Preset = @(); Domain = "avg.com"; Color = "#16A34A"; Mono = "AVG"; Detect = "^AVG AntiVirus" }
    "Install_Avira.ps1"                    = @{ Name = "Avira Security"; Winget = "Avira.Security"; Desc = "Bulut tabanlı antivirüs ve güvenlik yazılımı"; Preset = @(); Domain = "avira.com"; Color = "#DC2626"; Mono = "AVR"; Detect = "^Avira " }
    "Install_Spybot.ps1"                   = @{ Name = "Spybot - Search & Destroy"; Winget = "SaferNetworking.SpybotSearchAndDestroy"; Desc = "Casus yazılım ve izleyici tarama/temizleme aracı"; Preset = @(); Domain = "safer-networking.org"; Color = "#0284C7"; Mono = "SPY"; Detect = "^Spybot - Search & Destroy" }

    "Install_Oracle_VM_VirtualBox.ps1"     = @{ Name = "Oracle VM VirtualBox"; Winget = "Oracle.VirtualBox"; Desc = "Ücretsiz sanal bilgisayar oluşturma ve çalıştırma programı"; Preset = @(); Domain = "virtualbox.org"; Color = "#0284C7"; Mono = "VBX"; Detect = "Oracle .* VirtualBox" }
    "Install_VMware_Player.ps1"            = @{ Name = "VMware Workstation Player"; Winget = "VMware.WorkstationPlayer"; Desc = "Masaüstü sanal makine çalıştırma platformu"; Preset = @(); Domain = "vmware.com"; Color = "#D97706"; Mono = "VMW"; Detect = "^VMware Player|^VMware Workstation" }
    "Install_qBittorrent.ps1"              = @{ Name = "qBittorrent"; Winget = "qBittorrent.qBittorrent"; Desc = "Reklamsız ve açık kaynaklı Torrent indirme istemcisi"; Preset = @(); Domain = "qbittorrent.org"; Color = "#0284C7"; Mono = "qB"; Detect = "^qBittorrent" }
    "Install_Google_Earth.ps1"             = @{ Name = "Google Earth Pro"; Winget = "Google.EarthPro"; Desc = "3 boyutlu uydu görüntüsü, parsel ve harita inceleme aracı"; Preset = @(); Domain = "earth.google.com"; Color = "#2563EB"; Mono = "GEO"; Detect = "^Google Earth Pro" }
    "Install_Steam.ps1"                    = @{ Name = "Steam"; Winget = "Valve.Steam"; Desc = "Steam masaüstü istemcisi"; Preset = @(); Domain = "steampowered.com"; Color = "#1E3A8A"; Mono = "STM"; Detect = "^Steam$" }
    "Install_Epic_Games_Launcher.ps1"      = @{ Name = "Epic Games Launcher"; Winget = "EpicGames.EpicGamesLauncher"; Desc = "Unreal Engine ve Epic Games başlatıcısı"; Preset = @(); Domain = "epicgames.com"; Color = "#334155"; Mono = "EPC"; Detect = "^Epic Games Launcher$" }
    "Install_Ubisoft_Connect.ps1"          = @{ Name = "Ubisoft Connect"; Winget = "Ubisoft.Connect"; Desc = "Ubisoft masaüstü istemcisi"; Preset = @(); Domain = "ubisoft.com"; Color = "#2563EB"; Mono = "UBI"; Detect = "^Ubisoft Connect$" }
    "Install_Origin.ps1"                   = @{ Name = "EA App (Origin)"; Winget = "ElectronicArts.EADesktop"; Desc = "Electronic Arts masaüstü platformu"; Preset = @(); Domain = "ea.com"; Color = "#EA580C"; Mono = "EA"; Detect = "^EA app$|^Origin$" }
}

# Klasörlerdeki tüm yalnızca yasal Install_*.ps1 dosyalarını tara ve listeyi oluştur
$AllApps = New-Object System.Collections.Generic.List[PSCustomObject]
$scriptFiles = Get-ChildItem -Path $ScriptRoot -Recurse -Filter "Install_*.ps1" -ErrorAction SilentlyContinue

foreach ($file in $scriptFiles) {
    $relDir = $file.Directory.FullName.Replace($ScriptRoot + "\", "")
    if ($relDir -like "*disable-windows-defender*" -or $relDir -like "*Microsoft-Activation-Scripts*") {
        continue
    }

    $catTr = if ($CategoryTranslations.ContainsKey($relDir)) {
        $CategoryTranslations[$relDir]
    } elseif ($relDir -like "E*MZA*") {
        "E-İmza ve Akıllı Kart"
    } else {
        $relDir
    }
    $meta = $AppMetadata[$file.Name]

    $displayName = if ($meta -and $meta.Name) {
        $meta.Name
    } else {
        ($file.BaseName -replace '^Install_', '' -replace '_', ' ')
    }

    $wingetId      = if ($meta -and $meta.Winget) { $meta.Winget } else { "" }
    $desc          = if ($meta -and $meta.Desc) { $meta.Desc } else { "64-bit katılımsız kurulum paketi ($($file.Name))" }
    $presets       = if ($meta -and $meta.Preset) { $meta.Preset } else { @() }
    $isLocal       = if ($meta -and $meta.IsLocal) { $true } else { $false }
    $domain        = if ($meta -and $meta.Domain) { $meta.Domain } else { "" }
    $color         = if ($meta -and $meta.Color) { $meta.Color } else { "#2563EB" }
    $mono          = if ($meta -and $meta.Mono) { $meta.Mono } else { $displayName.Substring(0, [Math]::Min(2, $displayName.Length)).ToUpper() }
    $detectPattern = if ($meta -and $meta.Detect) { $meta.Detect } else { [regex]::Escape($displayName) }

    $catIndex = $CategoryOrder.IndexOf($catTr)
    if ($catIndex -lt 0) { $catIndex = 99 }

    $iconFile = Join-Path $IconsCacheDir ($file.BaseName + ".png")

    $AllApps.Add([PSCustomObject]@{
        Id                = $file.Name
        Name              = $displayName
        Category          = $catTr
        CategoryIndex     = $catIndex
        Description       = $desc
        ScriptPath        = $file.FullName
        WingetId          = $wingetId
        Presets           = $presets
        IsLocal           = $isLocal
        Domain            = $domain
        BrandColor        = $color
        Monogram          = $mono
        DetectPattern     = $detectPattern
        IconCachePath     = $iconFile
        IsSelected        = $false
        IsInstalled       = $false
        InstallState      = "Idle"
        CheckBoxRef       = $null
        CardRef           = $null
        IconImageRef      = $null
        IconFallbackRef   = $null
        StatusBadgeBorder = $null
        StatusBadgeText   = $null
    })
}

$AllApps = $AllApps | Sort-Object CategoryIndex, Name

# 3. Özel ve Varsayılan Paket Yönetimi (ozel_paketler.json)
$script:SavedPackages = New-Object System.Collections.Generic.List[PSCustomObject]

function Save-PackagesToJson {
    $exportList = @($script:SavedPackages | ForEach-Object {
        [PSCustomObject]@{
            Name   = $_.Name
            Style  = $_.Style
            AppIds = @($_.AppIds)
        }
    })
    $json = ConvertTo-Json -InputObject $exportList -Depth 5
    [System.IO.File]::WriteAllText($PackagesJsonPath, $json, (New-Object System.Text.UTF8Encoding($true)))
}

function Load-PackagesFromJson {
    $script:SavedPackages.Clear()
    $loaded = $false
    if (Test-Path -LiteralPath $PackagesJsonPath) {
        try {
            $raw = [System.IO.File]::ReadAllText($PackagesJsonPath, [System.Text.Encoding]::UTF8)
            $parsed = ConvertFrom-Json -InputObject $raw
            if ($parsed) {
                foreach ($pkg in @($parsed)) {
                    if ($pkg.Name) {
                        $script:SavedPackages.Add([PSCustomObject]@{
                            Name   = [string]$pkg.Name
                            Style  = if ($pkg.Style) { [string]$pkg.Style } else { "Custom" }
                            AppIds = @($pkg.AppIds | ForEach-Object { [string]$_ })
                        })
                    }
                }
                $loaded = $true
            }
        } catch {
            $loaded = $false
        }
    }

    if (-not $loaded) {
        # İlk çalıştırmada varsayılan 2 paketi oluştur ve ozel_paketler.json'a kaydet
        $hemenTeslimIds = @($AllApps | Where-Object { $_.Presets -contains "HemenTeslim" } | Select-Object -ExpandProperty Id)
        $temelIds       = @($AllApps | Where-Object { $_.Presets -contains "Temel" } | Select-Object -ExpandProperty Id)

        $script:SavedPackages.Add([PSCustomObject]@{
            Name   = "Hemen Teslim Et Paketi"
            Style  = "Green"
            AppIds = $hemenTeslimIds
        })
        $script:SavedPackages.Add([PSCustomObject]@{
            Name   = "BT Teknik Destek Paketi"
            Style  = "Default"
            AppIds = $temelIds
        })
        Save-PackagesToJson
    }
}

Load-PackagesFromJson

# 4. Modern ve Duyarlı (Responsive) Dashboard WPF XAML Arayüzü
[xml]$Xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Hızlı Kurulum Merkezi | Geliştirici: Serkan Altın"
        Width="1280" Height="820" MinWidth="760" MinHeight="560"
        WindowStartupLocation="CenterScreen"
        Background="#090D16" Foreground="#F8FAFC"
        FontFamily="Segoe UI">

    <Window.Resources>
        <Style TargetType="ScrollBar">
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="Width" Value="8"/>
        </Style>

        <!-- Sol Menü Kategori Butonu Stili -->
        <Style x:Key="CategoryButtonStyle" TargetType="Button">
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="Foreground" Value="#CBD5E1"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Padding" Value="12,9"/>
            <Setter Property="Margin" Value="0,2"/>
            <Setter Property="HorizontalContentAlignment" Value="Stretch"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="border" Background="{TemplateBinding Background}" CornerRadius="8" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="{TemplateBinding HorizontalContentAlignment}" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="border" Property="Background" Value="#1E293B"/>
                                <Setter Property="Foreground" Value="#FFFFFF"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- İkincil Aksiyon Butonu Stili -->
        <Style x:Key="ActionButtonStyle" TargetType="Button">
            <Setter Property="Background" Value="#1E293B"/>
            <Setter Property="Foreground" Value="#E2E8F0"/>
            <Setter Property="BorderBrush" Value="#334155"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="13,8"/>
            <Setter Property="FontSize" Value="12.5"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="border" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="8" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="border" Property="Background" Value="#334155"/>
                                <Setter TargetName="border" Property="BorderBrush" Value="#475569"/>
                                <Setter Property="Foreground" Value="#FFFFFF"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter Property="Opacity" Value="0.45"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- + Yeni Paket Oluştur Buton Stili -->
        <Style x:Key="NewPackageButtonStyle" TargetType="Button">
            <Setter Property="Background" Value="#1E3A8A"/>
            <Setter Property="Foreground" Value="#93C5FD"/>
            <Setter Property="BorderBrush" Value="#3B82F6"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="13,8"/>
            <Setter Property="FontSize" Value="12.5"/>
            <Setter Property="FontWeight" Value="Bold"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="border" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="8" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="border" Property="Background" Value="#2563EB"/>
                                <Setter Property="Foreground" Value="#FFFFFF"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter Property="Opacity" Value="0.45"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- Yeşil Vurgulu Paket Buton Stili -->
        <Style x:Key="HemenTeslimButtonStyle" TargetType="Button">
            <Setter Property="Background" Value="#059669"/>
            <Setter Property="Foreground" Value="#FFFFFF"/>
            <Setter Property="BorderBrush" Value="#10B981"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="15,8"/>
            <Setter Property="FontSize" Value="12.5"/>
            <Setter Property="FontWeight" Value="Bold"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="border" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="8" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="border" Property="Background" Value="#047857"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter Property="Opacity" Value="0.45"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- Birincil Kurulum Butonu Stili -->
        <Style x:Key="PrimaryButtonStyle" TargetType="Button">
            <Setter Property="Background" Value="#2563EB"/>
            <Setter Property="Foreground" Value="#FFFFFF"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Padding" Value="28,12"/>
            <Setter Property="FontSize" Value="14"/>
            <Setter Property="FontWeight" Value="Bold"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="border" Background="{TemplateBinding Background}" CornerRadius="8" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="border" Property="Background" Value="#1D4ED8"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter TargetName="border" Property="Background" Value="#1E293B"/>
                                <Setter Property="Foreground" Value="#64748B"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <!-- Hazır Paket İç Buton Stili (Devre dışı bırakıldığında asla beyaza dönmez) -->
        <Style x:Key="PillInnerButtonStyle" TargetType="Button">
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="Foreground" Value="#FFFFFF"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="border" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="border" Property="Background" Value="#26FFFFFF"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter TargetName="border" Property="Background" Value="Transparent"/>
                                <Setter Property="Foreground" Value="#CBD5E1"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>

    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <!-- ÜST DASHBOARD BAR: DUYARLI (RESPONSIVE) BAŞLIK, ARAMA VE DİNAMİK PAKETLER ŞERİDİ -->
        <Border Grid.Row="0" Background="#0F172A" BorderBrush="#1E293B" BorderThickness="0,0,0,1" Padding="18,11,18,10">
            <StackPanel>
                <!-- 1. Satır: Sol Başlık + Sağ Duyarlı Arama Kutusu (Dar ekranda otomatik 2. satıra iner) -->
                <Grid x:Name="HeaderTopGrid">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="Auto"/>
                    </Grid.RowDefinitions>
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="Auto"/>
                        <ColumnDefinition Width="*"/>
                    </Grid.ColumnDefinitions>

                    <!-- Sol: Hamburger Menü (☰) + Sade ve Güçlü Başlık -->
                    <StackPanel Grid.Row="0" Grid.Column="0" Orientation="Horizontal" VerticalAlignment="Center" Margin="0,0,14,0">
                        <Button x:Name="BtnToggleSidebar" Style="{StaticResource ActionButtonStyle}" Width="36" Height="36" Padding="0" Margin="0,0,11,0"
                                ToolTip="Sol Kategori Menüsünü Daralt / Genişlet (☰)">
                            <TextBlock Text="&#xE700;" FontFamily="Segoe MDL2 Assets" FontSize="15" Foreground="#F8FAFC" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Button>
                        <StackPanel VerticalAlignment="Center">
                            <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                                <TextBlock x:Name="AppMainTitle" Text="Hızlı Kurulum Merkezi" FontSize="19" FontWeight="Bold" Foreground="#F8FAFC" VerticalAlignment="Center"/>
                                <Border x:Name="AdminBadge" Background="#064E3B" BorderBrush="#059669" BorderThickness="1" CornerRadius="6" Padding="7,2" Margin="9,0,0,0" VerticalAlignment="Center">
                                    <TextBlock x:Name="AdminBadgeText" Text="YÖNETİCİ YETKİLİ" FontSize="9.5" FontWeight="Bold" Foreground="#A7F3D0"/>
                                </Border>
                            </StackPanel>
                            <StackPanel Orientation="Horizontal" Margin="0,2,0,0" VerticalAlignment="Center">
                                <TextBlock Text="Geliştirici: " FontSize="11" Foreground="#94A3B8"/>
                                <TextBlock Text="Serkan Altın" FontSize="11" FontWeight="Bold" Foreground="#38BDF8"/>
                                <TextBlock Text="  •  Katılımsız Kurulum Paneli" FontSize="11" Foreground="#64748B"/>
                            </StackPanel>
                        </StackPanel>
                    </StackPanel>

                    <!-- Sağ: Duyarlı Modern Arama Kutusu -->
                    <Border x:Name="SearchBorder" Grid.Row="0" Grid.Column="1" Background="#090D16" BorderBrush="#334155" BorderThickness="1" CornerRadius="9"
                            Height="38" MinWidth="210" MaxWidth="520" HorizontalAlignment="Right" Width="420" VerticalAlignment="Center">
                        <Grid>
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="34"/>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>
                            <TextBlock Grid.Column="0" Text="&#xE721;" FontFamily="Segoe MDL2 Assets" FontSize="13.5" Foreground="#38BDF8" VerticalAlignment="Center" HorizontalAlignment="Center"/>
                            <TextBox x:Name="SearchBox" Grid.Column="1" Background="Transparent" Foreground="#F8FAFC" BorderThickness="0"
                                     VerticalContentAlignment="Center" FontSize="13" CaretBrush="#38BDF8" Padding="2,0,8,0"/>
                            <TextBlock x:Name="SearchPlaceholder" Grid.Column="1" Text="Program veya kategori ara (Chrome, Acrobat, Office)..."
                                       Foreground="#64748B" FontSize="12" VerticalAlignment="Center" Margin="2,0,6,0" TextTrimming="CharacterEllipsis" IsHitTestVisible="False"/>
                            <Button x:Name="BtnClearSearch" Grid.Column="2" Content="Temizle" Visibility="Collapsed" Background="Transparent" Foreground="#38BDF8"
                                    BorderThickness="0" Padding="10,0" Cursor="Hand" FontSize="11" FontWeight="SemiBold"/>
                        </Grid>
                    </Border>
                </Grid>

                <!-- 2. Satır: Dinamik Hazır Paketler Şeridi (Ekran genişliğine göre taşmadan satır atlar) -->
                <Border BorderBrush="#1E293B" BorderThickness="0,1,0,0" Margin="0,9,0,0" Padding="0,8,0,0">
                    <DockPanel LastChildFill="True">
                        <TextBlock DockPanel.Dock="Left" Text="HAZIR PAKETLER" FontSize="10.5" FontWeight="Bold" Foreground="#64748B" VerticalAlignment="Center" Margin="0,0,12,0"/>
                        <WrapPanel x:Name="PackagesTopBarPanel" Orientation="Horizontal" HorizontalAlignment="Left" VerticalAlignment="Center"/>
                    </DockPanel>
                </Border>
            </StackPanel>
        </Border>

        <!-- ANA DASHBOARD GÖVDESİ -->
        <Grid Grid.Row="1">
            <Grid.ColumnDefinitions>
                <ColumnDefinition x:Name="SidebarColumn" Width="255"/>
                <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>

            <!-- Sol Menü: İkonlu Kategoriler + Tıklanabilir Geliştirici Kartı -->
            <Border x:Name="SidebarBorder" Grid.Column="0" Background="#0F172A" BorderBrush="#1E293B" BorderThickness="0,0,1,0" Padding="10,12">
                <DockPanel>
                    <TextBlock x:Name="SidebarHeaderTitle" DockPanel.Dock="Top" Text="KATEGORİLER" FontSize="11" FontWeight="Bold" Foreground="#64748B" Margin="10,0,0,8"/>

                    <!-- Sol Alt: Doğrudan GitHub ve LinkedIn Butonlu Geliştirici Kartı (Ekstra Pencere Açmaz) -->
                    <Border x:Name="DeveloperCardBorder" DockPanel.Dock="Bottom" Background="#090D16" BorderBrush="#1E293B" BorderThickness="1" CornerRadius="9" Padding="10,9" Margin="2,10,2,0">
                        <StackPanel>
                            <Grid>
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="Auto"/>
                                    <ColumnDefinition Width="*"/>
                                </Grid.ColumnDefinitions>
                                <Border Grid.Column="0" Width="32" Height="32" CornerRadius="8" Background="#1E3A8A" BorderBrush="#3B82F6" BorderThickness="1" VerticalAlignment="Center" HorizontalAlignment="Center">
                                    <TextBlock Text="SA" FontSize="12" FontWeight="Bold" Foreground="#93C5FD" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                </Border>
                                <StackPanel x:Name="DeveloperCardTextStack" Grid.Column="1" VerticalAlignment="Center" Margin="10,0,0,0">
                                    <TextBlock Text="Serkan Altın" FontSize="13" FontWeight="Bold" Foreground="#F8FAFC"/>
                                    <TextBlock Text="Sistem &amp; Bilgi İşlem Otomasyonu" FontSize="10.5" Foreground="#38BDF8" TextTrimming="CharacterEllipsis"/>
                                    <TextBlock Text="Altyapı: tylerlurie/PS-Installers" FontSize="9.5" Foreground="#64748B" Margin="0,1,0,0" TextTrimming="CharacterEllipsis"/>
                                </StackPanel>
                            </Grid>

                            <!-- Doğrudan Altında Yer Alan GitHub ve LinkedIn Butonları -->
                            <Grid x:Name="DeveloperLinksGrid" Margin="0,8,0,0">
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="*"/>
                                    <ColumnDefinition Width="6"/>
                                    <ColumnDefinition Width="*"/>
                                </Grid.ColumnDefinitions>
                                <Button x:Name="BtnDevGitHub" Grid.Column="0" Style="{StaticResource ActionButtonStyle}" Padding="6,5" FontSize="11"
                                        ToolTip="GitHub Profilini Aç (https://github.com/serkanaltin)">
                                    <StackPanel Orientation="Horizontal" HorizontalAlignment="Center">
                                        <TextBlock Text="&#xE774;" FontFamily="Segoe MDL2 Assets" FontSize="11.5" Foreground="#38BDF8" Margin="0,0,5,0" VerticalAlignment="Center"/>
                                        <TextBlock Text="GitHub" VerticalAlignment="Center"/>
                                    </StackPanel>
                                </Button>
                                <Button x:Name="BtnDevLinkedIn" Grid.Column="2" Style="{StaticResource NewPackageButtonStyle}" Padding="6,5" FontSize="11"
                                        ToolTip="LinkedIn Profilini Aç (https://www.linkedin.com/in/serkanaltin/)">
                                    <StackPanel Orientation="Horizontal" HorizontalAlignment="Center">
                                        <TextBlock Text="&#xE71B;" FontFamily="Segoe MDL2 Assets" FontSize="11.5" Foreground="#93C5FD" Margin="0,0,5,0" VerticalAlignment="Center"/>
                                        <TextBlock Text="LinkedIn" VerticalAlignment="Center"/>
                                    </StackPanel>
                                </Button>
                            </Grid>
                        </StackPanel>
                    </Border>

                    <ScrollViewer VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled">
                        <StackPanel x:Name="CategoryListPanel"/>
                    </ScrollViewer>
                </DockPanel>
            </Border>

            <!-- Sağ Ana Alan: Duyarlı Özet Kartları + Uygulama Izgarası + Sürüklenebilir Süreç Takip Paneli -->
            <Grid Grid.Column="1">
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="*" MinHeight="140"/>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition x:Name="BottomPanelRow" Height="225" MinHeight="42"/>
                </Grid.RowDefinitions>

                <!-- 1. Satır: Duyarlı Dashboard Özet Metrik Kartları (Geniş ekranda 4'lü, dar ekranda 2x2) -->
                <Border Grid.Row="0" Background="#0B1120" BorderBrush="#1E293B" BorderThickness="0,0,0,1" Padding="14,9">
                    <UniformGrid x:Name="MetricsUniformGrid" Columns="4">
                        <!-- Kart 1: Katalogdaki Toplam Program -->
                        <Border x:Name="CardMetricTotal" Background="#111827" BorderBrush="#1E293B" BorderThickness="1" CornerRadius="8" Padding="12,8" Margin="4" Cursor="Hand"
                                ToolTip="Tüm program kataloğunu göstermek için tıklayın">
                            <Grid>
                                <StackPanel Margin="0,0,26,0">
                                    <TextBlock Text="TOPLAM KATALOG" FontSize="10" FontWeight="Bold" Foreground="#64748B" TextTrimming="CharacterEllipsis"/>
                                    <TextBlock x:Name="MetricTotalText" Text="91 Program" FontSize="16" FontWeight="Bold" Foreground="#F8FAFC" Margin="0,2,0,0" TextTrimming="CharacterEllipsis"/>
                                </StackPanel>
                                <TextBlock Text="&#xE71D;" FontFamily="Segoe MDL2 Assets" FontSize="20" Foreground="#334155" HorizontalAlignment="Right" VerticalAlignment="Center"/>
                            </Grid>
                        </Border>

                        <!-- Kart 2: Seçilen / Kurulacak Program -->
                        <Border x:Name="CardMetricSelected" Background="#111827" BorderBrush="#1E3A8A" BorderThickness="1" CornerRadius="8" Padding="12,8" Margin="4" Cursor="Hand"
                                ToolTip="Yalnızca kurulmak üzere seçilen programları filtrelemek için tıklayın">
                            <Grid>
                                <StackPanel Margin="0,0,26,0">
                                    <TextBlock Text="KURULACAK SEÇİM" FontSize="10" FontWeight="Bold" Foreground="#60A5FA" TextTrimming="CharacterEllipsis"/>
                                    <TextBlock x:Name="MetricSelectedText" Text="0 Seçili" FontSize="16" FontWeight="Bold" Foreground="#38BDF8" Margin="0,2,0,0" TextTrimming="CharacterEllipsis"/>
                                </StackPanel>
                                <TextBlock Text="&#xE762;" FontFamily="Segoe MDL2 Assets" FontSize="20" Foreground="#1D4ED8" HorizontalAlignment="Right" VerticalAlignment="Center"/>
                            </Grid>
                        </Border>

                        <!-- Kart 3: Bilgisayarda Yüklü & Kurulan Program -->
                        <Border x:Name="CardMetricInstalled" Background="#111827" BorderBrush="#064E3B" BorderThickness="1" CornerRadius="8" Padding="12,8" Margin="4" Cursor="Hand"
                                ToolTip="Yalnızca bu bilgisayarda yüklü olan programları filtrelemek için tıklayın">
                            <Grid>
                                <StackPanel Margin="0,0,26,0">
                                    <TextBlock Text="SİSTEMDE YÜKLÜ" FontSize="10" FontWeight="Bold" Foreground="#34D399" TextTrimming="CharacterEllipsis"/>
                                    <TextBlock x:Name="MetricInstalledText" Text="0 Yüklü" FontSize="16" FontWeight="Bold" Foreground="#10B981" Margin="0,2,0,0" TextTrimming="CharacterEllipsis"/>
                                </StackPanel>
                                <TextBlock Text="&#xE73E;" FontFamily="Segoe MDL2 Assets" FontSize="20" Foreground="#059669" HorizontalAlignment="Right" VerticalAlignment="Center"/>
                            </Grid>
                        </Border>

                        <!-- Kart 4: Sistem / Kurulum Durumu -->
                        <Border Background="#111827" BorderBrush="#1E293B" BorderThickness="1" CornerRadius="8" Padding="12,8" Margin="4">
                            <Grid>
                                <StackPanel Margin="0,0,26,0">
                                    <TextBlock Text="OTOMASYON DURUMU" FontSize="10" FontWeight="Bold" Foreground="#94A3B8" TextTrimming="CharacterEllipsis"/>
                                    <TextBlock x:Name="MetricStateText" Text="Seçim Bekleniyor" FontSize="14.5" FontWeight="Bold" Foreground="#E2E8F0" Margin="0,3,0,0" TextTrimming="CharacterEllipsis"/>
                                </StackPanel>
                                <TextBlock Text="&#xE945;" FontFamily="Segoe MDL2 Assets" FontSize="20" Foreground="#475569" HorizontalAlignment="Right" VerticalAlignment="Center"/>
                            </Grid>
                        </Border>
                    </UniformGrid>
                </Border>

                <!-- 2. Satır: Duyarlı Aktif Kategori Başlığı ve Hızlı Seçim Kontrolleri (Çakışmadan satır atlar) -->
                <Border Grid.Row="1" Background="#090D16" Padding="18,10,18,6">
                    <Grid>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="Auto"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>

                        <StackPanel Grid.Column="0" Orientation="Horizontal" VerticalAlignment="Center" Margin="0,2,12,2">
                            <TextBlock x:Name="CurrentCategoryTitle" Text="Tüm Programlar" FontSize="16.5" FontWeight="Bold" Foreground="#F8FAFC" VerticalAlignment="Center"/>
                            <Border Background="#1E293B" BorderBrush="#334155" BorderThickness="1" CornerRadius="12" Padding="9,2" Margin="10,0,0,0" VerticalAlignment="Center">
                                <TextBlock x:Name="CurrentCategoryCount" Text="0 program" FontSize="11.5" Foreground="#38BDF8" FontWeight="SemiBold"/>
                            </Border>
                        </StackPanel>

                        <WrapPanel Grid.Column="1" Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Center">
                            <Button x:Name="BtnRescanInstalled" Style="{StaticResource ActionButtonStyle}" Margin="0,2,6,2" Padding="10,5" FontSize="11.5"
                                    ToolTip="Windows Kayıt Defteri üzerinden bilgisayarda yüklü olan programları yeniden tarar">
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock Text="&#xE72C;" FontFamily="Segoe MDL2 Assets" FontSize="11" Foreground="#34D399" Margin="0,0,5,0" VerticalAlignment="Center"/>
                                    <TextBlock Text="Yenile / Tara" VerticalAlignment="Center"/>
                                </StackPanel>
                            </Button>
                            <Button x:Name="BtnShowSelectedOnly" Style="{StaticResource ActionButtonStyle}" Content="Seçilenleri Göster (0)" Margin="0,2,6,2" Padding="10,5" FontSize="11.5"/>
                            <Button x:Name="BtnSelectCategory" Style="{StaticResource ActionButtonStyle}" Content="Bu Kategoridekileri Seç" Margin="0,2,6,2" Padding="10,5" FontSize="11.5"/>
                            <Button x:Name="BtnClearAll" Style="{StaticResource ActionButtonStyle}" Content="Seçimleri Temizle" Margin="0,2,0,2" Padding="10,5" FontSize="11.5"/>
                        </WrapPanel>
                    </Grid>
                </Border>

                <!-- 3. Satır: Duyarlı Logolu Uygulama Kartları Izgarası -->
                <ScrollViewer x:Name="AppsScrollViewer" Grid.Row="2" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" Padding="12,4,12,12">
                    <WrapPanel x:Name="AppsWrapPanel" Orientation="Horizontal"/>
                </ScrollViewer>

                <!-- 4. Satır: Sürüklenebilir Yatay Ayırıcı (Alt panel yüksekliği ayarlanabilir) -->
                <GridSplitter x:Name="BottomPanelSplitter" Grid.Row="3" Height="5" HorizontalAlignment="Stretch" VerticalAlignment="Center"
                              Background="#1E293B" ShowsPreview="False" Cursor="SizeNS"
                              ToolTip="Sürükleyerek alt günlük panelini büyütüp küçültebilirsiniz"/>

                <!-- 5. Satır: ALT ADIM ADIM SÜREÇ TAKİP VE KATLANABİLİR CANLI GÜNLÜK PANELİ -->
                <Border x:Name="BottomPanelOuterBorder" Grid.Row="4" Background="#070A12" Padding="14,7">
                    <Grid x:Name="BottomSplitGrid">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition x:Name="StepColDef" Width="0.42*" MinWidth="200"/>
                            <ColumnDefinition Width="8"/>
                            <ColumnDefinition x:Name="LogColDef" Width="0.58*" MinWidth="240"/>
                        </Grid.ColumnDefinitions>

                        <!-- Sol Sütun: Seçilen Programların Adım Adım Yüzdelik Durum Tablosu -->
                        <Border x:Name="StepTrackerInnerBorder" Grid.Column="0" Background="#0F172A" BorderBrush="#1E293B" BorderThickness="1" CornerRadius="8" Padding="11,7">
                            <DockPanel>
                                <Grid DockPanel.Dock="Top" Margin="0,0,0,5">
                                    <TextBlock Text="ADIM ADIM KURULUM SÜRECİ" FontSize="11" FontWeight="Bold" Foreground="#38BDF8" VerticalAlignment="Center"/>
                                    <TextBlock x:Name="StepCounterBadge" Text="0 / 0 Tamamlandı" FontSize="11" FontWeight="SemiBold" Foreground="#94A3B8" HorizontalAlignment="Right" VerticalAlignment="Center"/>
                                </Grid>
                                <ScrollViewer x:Name="StepProgressScrollViewer" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled">
                                    <StackPanel x:Name="StepProgressPanel"/>
                                </ScrollViewer>
                            </DockPanel>
                        </Border>

                        <!-- Dikey Ayırıcı -->
                        <GridSplitter Grid.Column="1" Width="4" HorizontalAlignment="Center" VerticalAlignment="Stretch"
                                      Background="#1E293B" ShowsPreview="False" Cursor="SizeWE"
                                      ToolTip="Sürükleyerek süreç ve günlük genişliğini ayarlayabilirsiniz"/>

                        <!-- Sağ Sütun: Katlanabilir ve Temizlenebilir Detaylı Canlı Kurulum Günlüğü -->
                        <Border x:Name="LogPanelInnerBorder" Grid.Column="2" Background="#0F172A" BorderBrush="#1E293B" BorderThickness="1" CornerRadius="8" Padding="11,7">
                            <DockPanel>
                                <Grid DockPanel.Dock="Top" Margin="0,0,0,5">
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="Auto"/>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="Auto"/>
                                    </Grid.ColumnDefinitions>
                                    <TextBlock Grid.Column="0" Text="CANLI İŞLEM GÜNLÜĞÜ" FontSize="11" FontWeight="Bold" Foreground="#64748B" VerticalAlignment="Center"/>
                                    <TextBlock x:Name="ProgressStepText" Grid.Column="1" Text="Kurulum için program seçin" FontSize="11" FontWeight="Bold" Foreground="#38BDF8" HorizontalAlignment="Right" Margin="8,0,8,0" TextTrimming="CharacterEllipsis" VerticalAlignment="Center"/>
                                    <StackPanel Grid.Column="2" Orientation="Horizontal" VerticalAlignment="Center">
                                        <Button x:Name="BtnClearLog" Style="{StaticResource ActionButtonStyle}" Content="Temizle" Padding="8,3" FontSize="11" Margin="0,0,5,0" ToolTip="Günlük kayıtlarını temizler"/>
                                        <Button x:Name="BtnToggleLogPanel" Style="{StaticResource ActionButtonStyle}" Content="Gizle ▼" Padding="8,3" FontSize="11" ToolTip="Alt günlük panelini daraltır veya genişletir"/>
                                    </StackPanel>
                                </Grid>
                                <TextBox x:Name="LogTextBox" Background="Transparent" Foreground="#A7F3D0" BorderThickness="0"
                                         FontFamily="Consolas" FontSize="11.8" IsReadOnly="True" TextWrapping="Wrap"
                                         VerticalScrollBarVisibility="Auto" AcceptsReturn="True"/>
                            </DockPanel>
                        </Border>
                    </Grid>
                </Border>
            </Grid>
        </Grid>

        <!-- ALT DURUM, SEÇİLEN ÖZETİ, CANLI YÜZDELİK İLERLEME VE KURULUM BAŞLATMA ÇUBUĞU -->
        <Border Grid.Row="2" Background="#0F172A" BorderBrush="#1E293B" BorderThickness="0,1,0,0" Padding="18,11">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>

                <!-- Seçili Uygulama Sayısı -->
                <Border Grid.Column="0" Background="#090D16" BorderBrush="#334155" BorderThickness="1" CornerRadius="8" Padding="12,8" VerticalAlignment="Center">
                    <StackPanel Orientation="Horizontal">
                        <TextBlock Text="Seçilen: " Foreground="#94A3B8" FontSize="13" VerticalAlignment="Center"/>
                        <TextBlock x:Name="SelectedCountText" Text="0" Foreground="#38BDF8" FontSize="14.5" FontWeight="Bold" VerticalAlignment="Center"/>
                    </StackPanel>
                </Border>

                <!-- Orta: Canlı Aşama Özeti + Yüzdelikli İlerleme Çubuğu -->
                <StackPanel Grid.Column="1" Margin="16,0" VerticalAlignment="Center">
                    <Grid Margin="0,0,0,5">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>
                        <TextBlock x:Name="SelectedSummaryText" Grid.Column="0" Text="Henüz program seçilmedi. Kartlara tıklayarak veya üstteki hazır paketlerden seçim yapabilirsiniz."
                                   Foreground="#94A3B8" FontSize="12" TextTrimming="CharacterEllipsis" VerticalAlignment="Center"/>
                        <TextBlock x:Name="ProgressPercentText" Grid.Column="1" Text="%0" Foreground="#38BDF8" FontSize="12" FontWeight="Bold" Margin="10,0,0,0" VerticalAlignment="Center"/>
                    </Grid>
                    <ProgressBar x:Name="InstallProgressBar" Height="10" Minimum="0" Maximum="100" Value="0"
                                 Background="#090D16" Foreground="#2563EB" BorderBrush="#334155" BorderThickness="1"/>
                </StackPanel>

                <!-- Sağ: Kurulumu Başlat Butonu -->
                <StackPanel Grid.Column="2" Orientation="Horizontal" VerticalAlignment="Center">
                    <Button x:Name="BtnStartInstall" Style="{StaticResource PrimaryButtonStyle}" Padding="20,10" FontSize="13.5" Content="Seçilenleri Onaysız Kur (0)" IsEnabled="False"/>
                </StackPanel>
            </Grid>
        </Border>
    </Grid>
</Window>
"@

# 5. XAML Okuma ve Kontrolleri Bağlama
$Reader = New-Object System.Xml.XmlNodeReader $Xaml
$Window = [Windows.Markup.XamlReader]::Load($Reader)

# Pencere boyutunu mevcut ekran çalışma alanına (DPI / çözünürlük) göre otomatik sığdır
$workArea = [System.Windows.SystemParameters]::WorkArea
if ($workArea.Width -gt 0 -and $workArea.Height -gt 0) {
    $Window.Width  = [Math]::Max($Window.MinWidth,  [Math]::Min(1340, [Math]::Floor($workArea.Width  * 0.92)))
    $Window.Height = [Math]::Max($Window.MinHeight, [Math]::Min(860,  [Math]::Floor($workArea.Height * 0.90)))
}

$BtnToggleSidebar         = $Window.FindName("BtnToggleSidebar")
$AdminBadge               = $Window.FindName("AdminBadge")
$AdminBadgeText           = $Window.FindName("AdminBadgeText")
$SearchBorder             = $Window.FindName("SearchBorder")
$SearchBox                = $Window.FindName("SearchBox")
$SearchPlaceholder        = $Window.FindName("SearchPlaceholder")
$BtnClearSearch           = $Window.FindName("BtnClearSearch")
$PackagesTopBarPanel      = $Window.FindName("PackagesTopBarPanel")
$SidebarColumn            = $Window.FindName("SidebarColumn")
$SidebarBorder            = $Window.FindName("SidebarBorder")
$SidebarHeaderTitle       = $Window.FindName("SidebarHeaderTitle")
$DeveloperCardBorder      = $Window.FindName("DeveloperCardBorder")
$DeveloperCardTextStack   = $Window.FindName("DeveloperCardTextStack")
$DeveloperLinksGrid       = $Window.FindName("DeveloperLinksGrid")
$BtnDevGitHub             = $Window.FindName("BtnDevGitHub")
$BtnDevLinkedIn           = $Window.FindName("BtnDevLinkedIn")
$CategoryListPanel        = $Window.FindName("CategoryListPanel")
$MetricsUniformGrid       = $Window.FindName("MetricsUniformGrid")
$CardMetricTotal          = $Window.FindName("CardMetricTotal")
$CardMetricSelected       = $Window.FindName("CardMetricSelected")
$CardMetricInstalled      = $Window.FindName("CardMetricInstalled")
$MetricTotalText          = $Window.FindName("MetricTotalText")
$MetricSelectedText       = $Window.FindName("MetricSelectedText")
$MetricInstalledText      = $Window.FindName("MetricInstalledText")
$MetricStateText          = $Window.FindName("MetricStateText")
$BtnRescanInstalled       = $Window.FindName("BtnRescanInstalled")
$BtnShowSelectedOnly      = $Window.FindName("BtnShowSelectedOnly")
$BtnSelectCategory        = $Window.FindName("BtnSelectCategory")
$BtnClearAll              = $Window.FindName("BtnClearAll")
$CurrentCategoryTitle     = $Window.FindName("CurrentCategoryTitle")
$CurrentCategoryCount     = $Window.FindName("CurrentCategoryCount")
$AppsScrollViewer         = $Window.FindName("AppsScrollViewer")
$AppsWrapPanel            = $Window.FindName("AppsWrapPanel")
$BottomPanelSplitter      = $Window.FindName("BottomPanelSplitter")
$BottomPanelRow           = $Window.FindName("BottomPanelRow")
$BottomPanelOuterBorder   = $Window.FindName("BottomPanelOuterBorder")
$StepTrackerInnerBorder   = $Window.FindName("StepTrackerInnerBorder")
$LogPanelInnerBorder      = $Window.FindName("LogPanelInnerBorder")
$StepProgressScrollViewer = $Window.FindName("StepProgressScrollViewer")
$StepProgressPanel        = $Window.FindName("StepProgressPanel")
$StepCounterBadge         = $Window.FindName("StepCounterBadge")
$BtnClearLog              = $Window.FindName("BtnClearLog")
$BtnToggleLogPanel        = $Window.FindName("BtnToggleLogPanel")
$LogTextBox               = $Window.FindName("LogTextBox")
$ProgressStepText         = $Window.FindName("ProgressStepText")
$SelectedCountText        = $Window.FindName("SelectedCountText")
$SelectedSummaryText      = $Window.FindName("SelectedSummaryText")
$ProgressPercentText      = $Window.FindName("ProgressPercentText")
$InstallProgressBar       = $Window.FindName("InstallProgressBar")
$BtnStartInstall          = $Window.FindName("BtnStartInstall")

$MetricTotalText.Text = "$($AllApps.Count) Program"

if (-not $isAdmin) {
    $AdminBadge.Background     = [Windows.Media.BrushConverter]::new().ConvertFrom("#78350F")
    $AdminBadge.BorderBrush    = [Windows.Media.BrushConverter]::new().ConvertFrom("#D97706")
    $AdminBadgeText.Foreground = [Windows.Media.BrushConverter]::new().ConvertFrom("#FDE68A")
    $AdminBadgeText.Text       = "STANDART KULLANICI"
}

function Write-GuiLog {
    param([string]$Message)
    $timestamp = (Get-Date).ToString("HH:mm:ss")
    $LogTextBox.AppendText("[$timestamp] $Message`r`n")
    $LogTextBox.ScrollToEnd()
}

# 6. Durum Değişkenleri ve Görsel Yardımcı Fonksiyonlar
$script:ActiveCategory    = "Tümü"
$script:ShowSelectedOnly  = $false
$script:ShowInstalledOnly = $false
$script:IsSidebarCollapsed = $false
$script:IsLogCollapsed    = $false
$script:IsInstalling      = $false
$BrushConverter           = New-Object Windows.Media.BrushConverter
$script:StepRowMap        = @{}
$script:CategoryTextBlocks = New-Object System.Collections.Generic.List[Windows.Controls.TextBlock]

function Set-AppCardLogoFromFile {
    param($AppItem, [string]$FilePath)
    if (-not (Test-Path -LiteralPath $FilePath)) { return $false }
    try {
        $bytes = [System.IO.File]::ReadAllBytes($FilePath)
        if ($bytes.Length -lt 64) { return $false }
        $ms = New-Object System.IO.MemoryStream(,$bytes)
        $bmp = New-Object System.Windows.Media.Imaging.BitmapImage
        $bmp.BeginInit()
        $bmp.StreamSource = $ms
        $bmp.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
        $bmp.EndInit()
        $bmp.Freeze()
        $ms.Close()

        $AppItem.IconImageRef.Source = $bmp
        $AppItem.IconImageRef.Visibility = [Windows.Visibility]::Visible
        $AppItem.IconFallbackRef.Visibility = [Windows.Visibility]::Collapsed
        return $true
    } catch {
        return $false
    }
}

function Set-CardVisualState {
    param($AppItem)
    if (-not $AppItem.CardRef) { return }
    if ($AppItem.IsSelected) {
        $AppItem.CardRef.Background  = $BrushConverter.ConvertFrom("#172554")
        $AppItem.CardRef.BorderBrush = $BrushConverter.ConvertFrom("#3B82F6")
    } elseif ($AppItem.IsInstalled) {
        $AppItem.CardRef.Background  = $BrushConverter.ConvertFrom("#0D1F1C")
        $AppItem.CardRef.BorderBrush = $BrushConverter.ConvertFrom("#065F46")
    } else {
        $AppItem.CardRef.Background  = $BrushConverter.ConvertFrom("#111827")
        $AppItem.CardRef.BorderBrush = $BrushConverter.ConvertFrom("#1E293B")
    }

    if (-not $script:IsInstalling -and $AppItem.StatusBadgeBorder) {
        if ($AppItem.IsInstalled) {
            $AppItem.StatusBadgeBorder.Visibility = [Windows.Visibility]::Visible
            $AppItem.StatusBadgeBorder.Background = $BrushConverter.ConvertFrom("#065F46")
            $AppItem.StatusBadgeText.Foreground   = $BrushConverter.ConvertFrom("#A7F3D0")
            $AppItem.StatusBadgeText.Text         = "YÜKLÜ"
        } else {
            $AppItem.StatusBadgeBorder.Visibility = [Windows.Visibility]::Collapsed
        }
    }
}

# 7. Windows Kayıt Defteri Üzerinden Yüklü Programları Otomatik Algılama Motoru
function Scan-InstalledApplications {
    param([switch]$SilentLog)

    $regPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )

    $installedNames = New-Object System.Collections.Generic.List[string]
    foreach ($rp in $regPaths) {
        try {
            $items = Get-ItemProperty -Path $rp -Name DisplayName, ReleaseTypeIds -ErrorAction SilentlyContinue
            foreach ($it in $items) {
                if ($it.DisplayName) {
                    $installedNames.Add([string]$it.DisplayName)
                }
                if ($it.ReleaseTypeIds) {
                    $installedNames.Add([string]$it.ReleaseTypeIds)
                }
            }
        } catch {}
    }

    $detectedCount = 0
    foreach ($app in $AllApps) {
        $found = $false
        if ($app.DetectPattern) {
            foreach ($dispName in $installedNames) {
                if ($dispName -match $app.DetectPattern) {
                    $found = $true
                    break
                }
            }
        }
        $app.IsInstalled = $found
        if ($found) {
            $detectedCount++
        }
        if ($app.CardRef) {
            Set-CardVisualState -AppItem $app
        }
    }

    $MetricInstalledText.Text = "$detectedCount Yüklü"
    if (-not $SilentLog) {
        Write-GuiLog "Sistem taraması tamamlandı: Katalogdaki $($AllApps.Count) programdan $detectedCount tanesi bu bilgisayarda zaten YÜKLÜ olarak algılandı."
    }
}

# Kart Üzerindeki ve Alt Süreç Listesindeki Durum Rozetini + Yüzdelik İlerlemeyi Güncelleme
function Set-AppInstallState {
    param(
        [string]$AppId,
        [string]$State,
        [string]$DetailText,
        [string]$BadgeOverride = "",
        [int]$Percent = -1
    )
    $app = $AllApps | Where-Object { $_.Id -eq $AppId } | Select-Object -First 1
    if ($app) {
        $app.InstallState = $State
        if ($app.StatusBadgeBorder -and $app.StatusBadgeText) {
            switch ($State) {
                "Idle" {
                    Set-CardVisualState -AppItem $app
                }
                "Pending" {
                    $app.StatusBadgeBorder.Visibility = [Windows.Visibility]::Visible
                    $app.StatusBadgeBorder.Background = $BrushConverter.ConvertFrom("#1E293B")
                    $app.StatusBadgeText.Foreground   = $BrushConverter.ConvertFrom("#94A3B8")
                    $app.StatusBadgeText.Text         = "SIRADA"
                }
                "Downloading" {
                    $app.StatusBadgeBorder.Visibility = [Windows.Visibility]::Visible
                    $app.StatusBadgeBorder.Background = $BrushConverter.ConvertFrom("#78350F")
                    $app.StatusBadgeText.Foreground   = $BrushConverter.ConvertFrom("#FDE68A")
                    $app.StatusBadgeText.Text         = if ($BadgeOverride) { $BadgeOverride } else { "İNDİRİLİYOR..." }
                    $app.CardRef.BorderBrush          = $BrushConverter.ConvertFrom("#F59E0B")
                }
                "Extracting" {
                    $app.StatusBadgeBorder.Visibility = [Windows.Visibility]::Visible
                    $app.StatusBadgeBorder.Background = $BrushConverter.ConvertFrom("#4C1D95")
                    $app.StatusBadgeText.Foreground   = $BrushConverter.ConvertFrom("#DDD6FE")
                    $app.StatusBadgeText.Text         = if ($BadgeOverride) { $BadgeOverride } else { "ARŞİV AÇILIYOR..." }
                    $app.CardRef.BorderBrush          = $BrushConverter.ConvertFrom("#8B5CF6")
                }
                "Installing" {
                    $app.StatusBadgeBorder.Visibility = [Windows.Visibility]::Visible
                    $app.StatusBadgeBorder.Background = $BrushConverter.ConvertFrom("#1E3A8A")
                    $app.StatusBadgeText.Foreground   = $BrushConverter.ConvertFrom("#93C5FD")
                    $app.StatusBadgeText.Text         = if ($BadgeOverride) { $BadgeOverride } else { "KURULUYOR..." }
                    $app.CardRef.BorderBrush          = $BrushConverter.ConvertFrom("#38BDF8")
                }
                "Fallback" {
                    $app.StatusBadgeBorder.Visibility = [Windows.Visibility]::Visible
                    $app.StatusBadgeBorder.Background = $BrushConverter.ConvertFrom("#7C2D12")
                    $app.StatusBadgeText.Foreground   = $BrushConverter.ConvertFrom("#FED7AA")
                    $app.StatusBadgeText.Text         = if ($BadgeOverride) { $BadgeOverride } else { "WINGET İLE..." }
                }
                "Success" {
                    $app.IsInstalled                  = $true
                    $app.StatusBadgeBorder.Visibility = [Windows.Visibility]::Visible
                    $app.StatusBadgeBorder.Background = $BrushConverter.ConvertFrom("#065F46")
                    $app.StatusBadgeText.Foreground   = $BrushConverter.ConvertFrom("#A7F3D0")
                    $app.StatusBadgeText.Text         = "KURULDU"
                    $app.CardRef.Background           = $BrushConverter.ConvertFrom("#064E3B")
                    $app.CardRef.BorderBrush          = $BrushConverter.ConvertFrom("#10B981")
                }
                "Failed" {
                    $app.StatusBadgeBorder.Visibility = [Windows.Visibility]::Visible
                    $app.StatusBadgeBorder.Background = $BrushConverter.ConvertFrom("#7F1D1D")
                    $app.StatusBadgeText.Foreground   = $BrushConverter.ConvertFrom("#FECACA")
                    $app.StatusBadgeText.Text         = "HATA"
                    $app.CardRef.Background           = $BrushConverter.ConvertFrom("#450A0A")
                    $app.CardRef.BorderBrush          = $BrushConverter.ConvertFrom("#EF4444")
                }
            }
        }
    }

    if ($script:StepRowMap.ContainsKey($AppId)) {
        $rowInfo = $script:StepRowMap[$AppId]
        $rowInfo.DetailBlock.Text = $DetailText
        if ($rowInfo.ProgressBar) {
            if ($Percent -ge 0) {
                $rowInfo.ProgressBar.Visibility = [Windows.Visibility]::Visible
                $rowInfo.ProgressBar.IsIndeterminate = $false
                $rowInfo.ProgressBar.Value = [Math]::Min(100, [Math]::Max(0, $Percent))
            }
        }
        switch ($State) {
            "Pending" {
                $rowInfo.BadgeBorder.Background = $BrushConverter.ConvertFrom("#1E293B")
                $rowInfo.BadgeText.Foreground   = $BrushConverter.ConvertFrom("#94A3B8")
                $rowInfo.BadgeText.Text         = "SIRADA BEKLİYOR"
                $rowInfo.RowBorder.BorderBrush  = $BrushConverter.ConvertFrom("#1E293B")
                if ($rowInfo.ProgressBar) {
                    $rowInfo.ProgressBar.Visibility = [Windows.Visibility]::Collapsed
                    $rowInfo.ProgressBar.Value = 0
                }
            }
            "Downloading" {
                $rowInfo.BadgeBorder.Background = $BrushConverter.ConvertFrom("#78350F")
                $rowInfo.BadgeText.Foreground   = $BrushConverter.ConvertFrom("#FDE68A")
                $rowInfo.BadgeText.Text         = if ($BadgeOverride) { $BadgeOverride } else { "İNDİRİLİYOR..." }
                $rowInfo.RowBorder.BorderBrush  = $BrushConverter.ConvertFrom("#F59E0B")
                $rowInfo.RowBorder.Background   = $BrushConverter.ConvertFrom("#1C1917")
                if ($rowInfo.ProgressBar) {
                    $rowInfo.ProgressBar.Visibility = [Windows.Visibility]::Visible
                    $rowInfo.ProgressBar.Foreground = $BrushConverter.ConvertFrom("#F59E0B")
                    if ($Percent -lt 0) { $rowInfo.ProgressBar.IsIndeterminate = $true }
                }
            }
            "Extracting" {
                $rowInfo.BadgeBorder.Background = $BrushConverter.ConvertFrom("#4C1D95")
                $rowInfo.BadgeText.Foreground   = $BrushConverter.ConvertFrom("#DDD6FE")
                $rowInfo.BadgeText.Text         = if ($BadgeOverride) { $BadgeOverride } else { "ARŞİV AÇILIYOR..." }
                $rowInfo.RowBorder.BorderBrush  = $BrushConverter.ConvertFrom("#8B5CF6")
                $rowInfo.RowBorder.Background   = $BrushConverter.ConvertFrom("#1E1B4B")
                if ($rowInfo.ProgressBar) {
                    $rowInfo.ProgressBar.Visibility = [Windows.Visibility]::Visible
                    $rowInfo.ProgressBar.Foreground = $BrushConverter.ConvertFrom("#8B5CF6")
                    $rowInfo.ProgressBar.IsIndeterminate = $true
                }
            }
            "Installing" {
                $rowInfo.BadgeBorder.Background = $BrushConverter.ConvertFrom("#1E3A8A")
                $rowInfo.BadgeText.Foreground   = $BrushConverter.ConvertFrom("#93C5FD")
                $rowInfo.BadgeText.Text         = if ($BadgeOverride) { $BadgeOverride } else { "SESSİZ KURULUYOR..." }
                $rowInfo.RowBorder.BorderBrush  = $BrushConverter.ConvertFrom("#3B82F6")
                $rowInfo.RowBorder.Background   = $BrushConverter.ConvertFrom("#172554")
                if ($rowInfo.ProgressBar) {
                    $rowInfo.ProgressBar.Visibility = [Windows.Visibility]::Visible
                    $rowInfo.ProgressBar.Foreground = $BrushConverter.ConvertFrom("#38BDF8")
                    if ($Percent -lt 0) { $rowInfo.ProgressBar.IsIndeterminate = $true }
                }
            }
            "Fallback" {
                $rowInfo.BadgeBorder.Background = $BrushConverter.ConvertFrom("#7C2D12")
                $rowInfo.BadgeText.Foreground   = $BrushConverter.ConvertFrom("#FED7AA")
                $rowInfo.BadgeText.Text         = if ($BadgeOverride) { $BadgeOverride } else { "YEDEK MOTOR..." }
                $rowInfo.RowBorder.BorderBrush  = $BrushConverter.ConvertFrom("#F97316")
                if ($rowInfo.ProgressBar) {
                    $rowInfo.ProgressBar.Visibility = [Windows.Visibility]::Visible
                    $rowInfo.ProgressBar.Foreground = $BrushConverter.ConvertFrom("#F97316")
                    if ($Percent -lt 0) { $rowInfo.ProgressBar.IsIndeterminate = $true }
                }
            }
            "Success" {
                $rowInfo.BadgeBorder.Background = $BrushConverter.ConvertFrom("#065F46")
                $rowInfo.BadgeText.Foreground   = $BrushConverter.ConvertFrom("#A7F3D0")
                $rowInfo.BadgeText.Text         = "KURULDU"
                $rowInfo.RowBorder.BorderBrush  = $BrushConverter.ConvertFrom("#059669")
                $rowInfo.RowBorder.Background   = $BrushConverter.ConvertFrom("#064E3B")
                if ($rowInfo.ProgressBar) {
                    $rowInfo.ProgressBar.Visibility = [Windows.Visibility]::Visible
                    $rowInfo.ProgressBar.IsIndeterminate = $false
                    $rowInfo.ProgressBar.Foreground = $BrushConverter.ConvertFrom("#10B981")
                    $rowInfo.ProgressBar.Value = 100
                }
            }
            "Failed" {
                $rowInfo.BadgeBorder.Background = $BrushConverter.ConvertFrom("#7F1D1D")
                $rowInfo.BadgeText.Foreground   = $BrushConverter.ConvertFrom("#FECACA")
                $rowInfo.BadgeText.Text         = "BAŞARISIZ"
                $rowInfo.RowBorder.BorderBrush  = $BrushConverter.ConvertFrom("#DC2626")
                $rowInfo.RowBorder.Background   = $BrushConverter.ConvertFrom("#450A0A")
                if ($rowInfo.ProgressBar) {
                    $rowInfo.ProgressBar.Visibility = [Windows.Visibility]::Collapsed
                    $rowInfo.ProgressBar.IsIndeterminate = $false
                }
            }
        }
    }
}

# Seçimler değiştikçe alt sol "Adım Adım Kurulum Süreci" listesini canlı oluştur
function Rebuild-StepTrackerPreview {
    if ($script:IsInstalling) { return }
    $StepProgressPanel.Children.Clear()
    $script:StepRowMap.Clear()

    $selectedApps = @($AllApps | Where-Object { $_.IsSelected })
    $StepCounterBadge.Text = "0 / $($selectedApps.Count) Tamamlandı"

    if ($selectedApps.Count -eq 0) {
        $emptyText = New-Object Windows.Controls.TextBlock
        $emptyText.Text = "Henüz program seçilmedi. Seçtiğiniz programlar kurulum sırasıyla burada adım adım (Sırada -> % İndirme -> Kuruluyor -> Kuruldu) listelenir."
        $emptyText.Foreground = $BrushConverter.ConvertFrom("#64748B")
        $emptyText.FontSize = 11.5
        $emptyText.TextWrapping = [Windows.TextWrapping]::Wrap
        $emptyText.Margin = New-Object Windows.Thickness(4, 12, 4, 0)
        $StepProgressPanel.Children.Add($emptyText) | Out-Null
        return
    }

    $idx = 0
    foreach ($app in $selectedApps) {
        $idx++
        $rowBorder = New-Object Windows.Controls.Border
        $rowBorder.Background = $BrushConverter.ConvertFrom("#111827")
        $rowBorder.BorderBrush = $BrushConverter.ConvertFrom("#1E293B")
        $rowBorder.BorderThickness = New-Object Windows.Thickness(1)
        $rowBorder.CornerRadius = New-Object Windows.CornerRadius(6)
        $rowBorder.Padding = New-Object Windows.Thickness(8, 5, 8, 5)
        $rowBorder.Margin = New-Object Windows.Thickness(0, 0, 0, 4)

        $outerStack = New-Object Windows.Controls.StackPanel

        $grid = New-Object Windows.Controls.Grid
        $c0 = New-Object Windows.Controls.ColumnDefinition
        $c0.Width = New-Object Windows.GridLength(1, [Windows.GridUnitType]::Star)
        $c1 = New-Object Windows.Controls.ColumnDefinition
        $c1.Width = [Windows.GridLength]::Auto
        $grid.ColumnDefinitions.Add($c0)
        $grid.ColumnDefinitions.Add($c1)

        $leftStack = New-Object Windows.Controls.StackPanel
        [Windows.Controls.Grid]::SetColumn($leftStack, 0)

        $nameBlock = New-Object Windows.Controls.TextBlock
        $nameBlock.Text = "$idx. $($app.Name)"
        $nameBlock.FontSize = 12
        $nameBlock.FontWeight = [Windows.FontWeights]::SemiBold
        $nameBlock.Foreground = $BrushConverter.ConvertFrom("#F8FAFC")
        $nameBlock.TextTrimming = [Windows.TextTrimming]::CharacterEllipsis

        $detailBlock = New-Object Windows.Controls.TextBlock
        $detailBlock.Text = if ($app.IsLocal) { "Yerel paket hazır (İndirme gerekmez)" } else { "Kurulum başlatıldığında adım adım % ile indirilecek" }
        $detailBlock.FontSize = 10.5
        $detailBlock.Foreground = $BrushConverter.ConvertFrom("#94A3B8")
        $detailBlock.TextTrimming = [Windows.TextTrimming]::CharacterEllipsis

        $leftStack.Children.Add($nameBlock) | Out-Null
        $leftStack.Children.Add($detailBlock) | Out-Null

        $badgeBorder = New-Object Windows.Controls.Border
        $badgeBorder.Background = $BrushConverter.ConvertFrom("#1E293B")
        $badgeBorder.CornerRadius = New-Object Windows.CornerRadius(4)
        $badgeBorder.Padding = New-Object Windows.Thickness(7, 2, 7, 2)
        $badgeBorder.VerticalAlignment = [Windows.VerticalAlignment]::Center
        $badgeBorder.Margin = New-Object Windows.Thickness(8, 0, 0, 0)
        [Windows.Controls.Grid]::SetColumn($badgeBorder, 1)

        $badgeText = New-Object Windows.Controls.TextBlock
        $badgeText.Text = "HAZIR"
        $badgeText.FontSize = 10
        $badgeText.FontWeight = [Windows.FontWeights]::Bold
        $badgeText.Foreground = $BrushConverter.ConvertFrom("#38BDF8")
        $badgeBorder.Child = $badgeText

        $grid.Children.Add($leftStack) | Out-Null
        $grid.Children.Add($badgeBorder) | Out-Null

        $miniPb = New-Object Windows.Controls.ProgressBar
        $miniPb.Height = 4
        $miniPb.Minimum = 0
        $miniPb.Maximum = 100
        $miniPb.Value = 0
        $miniPb.Margin = New-Object Windows.Thickness(0, 4, 0, 0)
        $miniPb.Background = $BrushConverter.ConvertFrom("#090D16")
        $miniPb.Foreground = $BrushConverter.ConvertFrom("#F59E0B")
        $miniPb.BorderThickness = New-Object Windows.Thickness(0)
        $miniPb.Visibility = [Windows.Visibility]::Collapsed

        $outerStack.Children.Add($grid) | Out-Null
        $outerStack.Children.Add($miniPb) | Out-Null
        $rowBorder.Child = $outerStack

        $StepProgressPanel.Children.Add($rowBorder) | Out-Null
        $script:StepRowMap[$app.Id] = @{
            RowBorder   = $rowBorder
            NameBlock   = $nameBlock
            DetailBlock = $detailBlock
            BadgeBorder = $badgeBorder
            BadgeText   = $badgeText
            ProgressBar = $miniPb
        }
    }
}

function Update-SelectionCounter {
    $selectedApps = @($AllApps | Where-Object { $_.IsSelected })
    $count = $selectedApps.Count
    $SelectedCountText.Text = "$count"
    $MetricSelectedText.Text = "$count Seçili"
    $BtnStartInstall.Content = "Seçilenleri Onaysız Kur ($count)"
    $BtnShowSelectedOnly.Content = if ($script:ShowSelectedOnly) { "Tümünü Göster" } else { "Seçilenleri Göster ($count)" }
    $BtnStartInstall.IsEnabled = ($count -gt 0 -and -not $script:IsInstalling)

    if (-not $script:IsInstalling) {
        if ($count -eq 0) {
            $SelectedSummaryText.Text = "Henüz program seçilmedi. Kartlara tıklayarak veya üstteki hazır paket butonlarından seçim yapabilirsiniz."
            $SelectedSummaryText.Foreground = $BrushConverter.ConvertFrom("#94A3B8")
            $ProgressStepText.Text = "Kurulum için program seçin"
            $MetricStateText.Text = "Seçim Bekleniyor"
        } else {
            $names = ($selectedApps | Select-Object -ExpandProperty Name) -join ", "
            $SelectedSummaryText.Text = "Kurulacaklar ($count): $names"
            $SelectedSummaryText.Foreground = $BrushConverter.ConvertFrom("#E2E8F0")
            $ProgressStepText.Text = "$count program kuruluma hazır"
            $MetricStateText.Text = "$count Program Hazır"
        }
        Rebuild-StepTrackerPreview
    }
}

# 8. Logolu Uygulama Kartlarını Oluşturma
foreach ($app in $AllApps) {
    $card = New-Object Windows.Controls.Border
    $card.Width = 308
    $card.Height = 108
    $card.Margin = New-Object Windows.Thickness(6)
    $card.Padding = New-Object Windows.Thickness(12, 10, 12, 10)
    $card.CornerRadius = New-Object Windows.CornerRadius(10)
    $card.Background = $BrushConverter.ConvertFrom("#111827")
    $card.BorderBrush = $BrushConverter.ConvertFrom("#1E293B")
    $card.BorderThickness = New-Object Windows.Thickness(1.5)
    $card.Cursor = [Windows.Input.Cursors]::Hand

    $grid = New-Object Windows.Controls.Grid
    $col0 = New-Object Windows.Controls.ColumnDefinition
    $col0.Width = New-Object Windows.GridLength(52)
    $col1 = New-Object Windows.Controls.ColumnDefinition
    $col1.Width = New-Object Windows.GridLength(1, [Windows.GridUnitType]::Star)
    $col2 = New-Object Windows.Controls.ColumnDefinition
    $col2.Width = New-Object Windows.GridLength(24)
    $grid.ColumnDefinitions.Add($col0)
    $grid.ColumnDefinitions.Add($col1)
    $grid.ColumnDefinitions.Add($col2)

    $logoContainer = New-Object Windows.Controls.Grid
    $logoContainer.Width = 42
    $logoContainer.Height = 42
    $logoContainer.VerticalAlignment = [Windows.VerticalAlignment]::Top
    $logoContainer.HorizontalAlignment = [Windows.HorizontalAlignment]::Left
    $logoContainer.Margin = New-Object Windows.Thickness(0, 2, 0, 0)
    [Windows.Controls.Grid]::SetColumn($logoContainer, 0)

    $fallbackBorder = New-Object Windows.Controls.Border
    $fallbackBorder.CornerRadius = New-Object Windows.CornerRadius(10)
    $fallbackBorder.Background = $BrushConverter.ConvertFrom($app.BrandColor)
    $fallbackText = New-Object Windows.Controls.TextBlock
    $fallbackText.Text = $app.Monogram
    $fallbackText.FontSize = 13
    $fallbackText.FontWeight = [Windows.FontWeights]::Bold
    $fallbackText.Foreground = [Windows.Media.Brushes]::White
    $fallbackText.HorizontalAlignment = [Windows.HorizontalAlignment]::Center
    $fallbackText.VerticalAlignment = [Windows.VerticalAlignment]::Center
    $fallbackBorder.Child = $fallbackText

    $imgBorder = New-Object Windows.Controls.Border
    $imgBorder.CornerRadius = New-Object Windows.CornerRadius(10)
    $imgBorder.Background = $BrushConverter.ConvertFrom("#1E293B")
    $imgBorder.Padding = New-Object Windows.Thickness(5)
    $imgBorder.Visibility = [Windows.Visibility]::Collapsed

    $iconImg = New-Object Windows.Controls.Image
    $iconImg.Stretch = [Windows.Media.Stretch]::Uniform
    [Windows.Media.RenderOptions]::SetBitmapScalingMode($iconImg, [Windows.Media.BitmapScalingMode]::HighQuality)
    $imgBorder.Child = $iconImg

    $logoContainer.Children.Add($fallbackBorder) | Out-Null
    $logoContainer.Children.Add($imgBorder) | Out-Null

    $stack = New-Object Windows.Controls.StackPanel
    $stack.Margin = New-Object Windows.Thickness(2, 0, 4, 0)
    [Windows.Controls.Grid]::SetColumn($stack, 1)

    $titleBlock = New-Object Windows.Controls.TextBlock
    $titleBlock.Text = $app.Name
    $titleBlock.FontSize = 13.5
    $titleBlock.FontWeight = [Windows.FontWeights]::Bold
    $titleBlock.Foreground = $BrushConverter.ConvertFrom("#F8FAFC")
    $titleBlock.TextTrimming = [Windows.TextTrimming]::CharacterEllipsis

    $metaGrid = New-Object Windows.Controls.Grid
    $metaGrid.Margin = New-Object Windows.Thickness(0, 2, 0, 3)
    $mc0 = New-Object Windows.Controls.ColumnDefinition
    $mc0.Width = New-Object Windows.GridLength(1, [Windows.GridUnitType]::Star)
    $mc1 = New-Object Windows.Controls.ColumnDefinition
    $mc1.Width = [Windows.GridLength]::Auto
    $metaGrid.ColumnDefinitions.Add($mc0)
    $metaGrid.ColumnDefinitions.Add($mc1)

    $catBlock = New-Object Windows.Controls.TextBlock
    $catBlock.Text = $app.Category
    $catBlock.FontSize = 10.5
    $catBlock.FontWeight = [Windows.FontWeights]::SemiBold
    $catBlock.Foreground = $BrushConverter.ConvertFrom("#38BDF8")
    $catBlock.VerticalAlignment = [Windows.VerticalAlignment]::Center
    $catBlock.TextTrimming = [Windows.TextTrimming]::CharacterEllipsis
    [Windows.Controls.Grid]::SetColumn($catBlock, 0)

    $statusBadgeBorder = New-Object Windows.Controls.Border
    $statusBadgeBorder.CornerRadius = New-Object Windows.CornerRadius(4)
    $statusBadgeBorder.Padding = New-Object Windows.Thickness(6, 1, 6, 1)
    $statusBadgeBorder.Background = $BrushConverter.ConvertFrom("#1E293B")
    $statusBadgeBorder.Visibility = [Windows.Visibility]::Collapsed
    [Windows.Controls.Grid]::SetColumn($statusBadgeBorder, 1)

    $statusBadgeText = New-Object Windows.Controls.TextBlock
    $statusBadgeText.FontSize = 9.5
    $statusBadgeText.FontWeight = [Windows.FontWeights]::Bold
    $statusBadgeText.Foreground = $BrushConverter.ConvertFrom("#94A3B8")
    $statusBadgeText.Text = "SIRADA"
    $statusBadgeBorder.Child = $statusBadgeText

    $metaGrid.Children.Add($catBlock) | Out-Null
    $metaGrid.Children.Add($statusBadgeBorder) | Out-Null

    $descBlock = New-Object Windows.Controls.TextBlock
    $descBlock.Text = $app.Description
    $descBlock.FontSize = 11.2
    $descBlock.Foreground = $BrushConverter.ConvertFrom("#94A3B8")
    $descBlock.TextWrapping = [Windows.TextWrapping]::Wrap
    $descBlock.MaxHeight = 33
    $descBlock.TextTrimming = [Windows.TextTrimming]::CharacterEllipsis

    $stack.Children.Add($titleBlock) | Out-Null
    $stack.Children.Add($metaGrid) | Out-Null
    $stack.Children.Add($descBlock) | Out-Null

    $cb = New-Object Windows.Controls.CheckBox
    $cb.VerticalAlignment = [Windows.VerticalAlignment]::Top
    $cb.HorizontalAlignment = [Windows.HorizontalAlignment]::Right
    $cb.Margin = New-Object Windows.Thickness(0, 3, 0, 0)
    $cb.IsChecked = $false
    [Windows.Controls.Grid]::SetColumn($cb, 2)

    $grid.Children.Add($logoContainer) | Out-Null
    $grid.Children.Add($stack) | Out-Null
    $grid.Children.Add($cb) | Out-Null
    $card.Child = $grid

    $app.CheckBoxRef       = $cb
    $app.CardRef           = $card
    $app.IconImageRef      = $iconImg
    $app.IconFallbackRef   = $fallbackBorder
    $app.StatusBadgeBorder = $statusBadgeBorder
    $app.StatusBadgeText   = $statusBadgeText

    if (Test-Path -LiteralPath $app.IconCachePath) {
        if (Set-AppCardLogoFromFile -AppItem $app -FilePath $app.IconCachePath) {
            $imgBorder.Visibility = [Windows.Visibility]::Visible
        }
    }

    $cb.Tag = $app
    $cb.Add_Checked({
        param($sender, $e)
        $item = $sender.Tag
        $item.IsSelected = $true
        Set-CardVisualState -AppItem $item
        Update-SelectionCounter
    })
    $cb.Add_Unchecked({
        param($sender, $e)
        $item = $sender.Tag
        $item.IsSelected = $false
        Set-CardVisualState -AppItem $item
        Update-SelectionCounter
        if ($script:ShowSelectedOnly) { Update-AppFilter }
    })

    $card.Tag = $app
    $card.Add_MouseLeftButtonUp({
        param($sender, $e)
        if ($script:IsInstalling) { return }
        if ($e.OriginalSource -is [Windows.Controls.Primitives.ToggleButton]) { return }
        $item = $sender.Tag
        $item.CheckBoxRef.IsChecked = -not $item.CheckBoxRef.IsChecked
    })

    $AppsWrapPanel.Children.Add($card) | Out-Null
}

# Form açılışında sistemde yüklü programları tara ve yeşil "YÜKLÜ" rozetlerini göster
Write-GuiLog "Hızlı Kurulum Merkezi hazır (Geliştirici: Serkan Altın). Toplam $($AllApps.Count) katılımsız paket yüklendi."
Scan-InstalledApplications

$BtnRescanInstalled.Add_Click({
    if ($script:IsInstalling) { return }
    Scan-InstalledApplications
    if ($script:ShowInstalledOnly) { Update-AppFilter }
})

# Sol Alt Geliştirici Kartındaki Doğrudan GitHub ve LinkedIn Butonları
$BtnDevGitHub.Add_Click({
    Start-Process "https://github.com/serkanaltin"
})

$BtnDevLinkedIn.Add_Click({
    Start-Process "https://www.linkedin.com/in/serkanaltin/"
})

# Katlanabilir ve Temizlenebilir Canlı İşlem Günlüğü Kontrolleri
function Set-LogPanelExpanded {
    param([bool]$Expanded)
    if ($Expanded) {
        $script:IsLogCollapsed = $false
        $BottomPanelRow.MinHeight = 140
        $BottomPanelRow.Height = New-Object Windows.GridLength(225)
        $BottomPanelSplitter.Visibility = [Windows.Visibility]::Visible
        $BottomPanelOuterBorder.Padding = New-Object Windows.Thickness(14, 7, 14, 7)
        $StepTrackerInnerBorder.Padding = New-Object Windows.Thickness(11, 7, 11, 7)
        $LogPanelInnerBorder.Padding    = New-Object Windows.Thickness(11, 7, 11, 7)
        $LogTextBox.Visibility = [Windows.Visibility]::Visible
        $StepProgressScrollViewer.Visibility = [Windows.Visibility]::Visible
        $BtnToggleLogPanel.Content = "Gizle ▼"
    } else {
        $script:IsLogCollapsed = $true
        $BottomPanelRow.MinHeight = 40
        $BottomPanelRow.Height = [Windows.GridLength]::Auto
        $BottomPanelSplitter.Visibility = [Windows.Visibility]::Collapsed
        $BottomPanelOuterBorder.Padding = New-Object Windows.Thickness(14, 4, 14, 4)
        $StepTrackerInnerBorder.Padding = New-Object Windows.Thickness(11, 5, 11, 5)
        $LogPanelInnerBorder.Padding    = New-Object Windows.Thickness(11, 5, 11, 5)
        $LogTextBox.Visibility = [Windows.Visibility]::Collapsed
        $StepProgressScrollViewer.Visibility = [Windows.Visibility]::Collapsed
        $BtnToggleLogPanel.Content = "Göster ▲"
    }
}

$BtnClearLog.Add_Click({
    $LogTextBox.Clear()
    Write-GuiLog "Günlük ekranı temizlendi."
})

$BtnToggleLogPanel.Add_Click({
    Set-LogPanelExpanded -Expanded $script:IsLogCollapsed
})

# Açılır-Kapanır (Daraltılabilir) Sol Kategori Menüsü (☰) ve Tam Duyarlı (Responsive) Yerleşim Motoru
$script:UserPinnedSidebar = $false

function Set-SidebarCollapsed {
    param([bool]$Collapsed)
    $script:IsSidebarCollapsed = $Collapsed
    if ($Collapsed) {
        $SidebarColumn.Width = New-Object Windows.GridLength(72)
        $SidebarBorder.Padding = New-Object Windows.Thickness(4, 12, 4, 12)
        $SidebarHeaderTitle.Visibility = [Windows.Visibility]::Collapsed
        $DeveloperCardTextStack.Visibility = [Windows.Visibility]::Collapsed
        $DeveloperLinksGrid.Visibility = [Windows.Visibility]::Collapsed
        $DeveloperCardBorder.Padding = New-Object Windows.Thickness(6, 8, 6, 8)
        foreach ($tb in $script:CategoryTextBlocks) {
            $tb.Visibility = [Windows.Visibility]::Collapsed
        }
        if ($CategoryButtons) {
            foreach ($btn in $CategoryButtons.Values) {
                $btn.Padding = New-Object Windows.Thickness(6, 9, 6, 9)
            }
        }
    } else {
        $SidebarColumn.Width = New-Object Windows.GridLength(255)
        $SidebarBorder.Padding = New-Object Windows.Thickness(10, 12, 10, 12)
        $SidebarHeaderTitle.Visibility = [Windows.Visibility]::Visible
        $DeveloperCardTextStack.Visibility = [Windows.Visibility]::Visible
        $DeveloperLinksGrid.Visibility = [Windows.Visibility]::Visible
        $DeveloperCardBorder.Padding = New-Object Windows.Thickness(10, 9, 10, 9)
        foreach ($tb in $script:CategoryTextBlocks) {
            $tb.Visibility = [Windows.Visibility]::Visible
        }
        if ($CategoryButtons) {
            foreach ($btn in $CategoryButtons.Values) {
                $btn.Padding = New-Object Windows.Thickness(12, 9, 12, 9)
            }
        }
    }
}

$script:UserResizedBottomPanel = $false
$BottomPanelSplitter.Add_DragCompleted({
    $script:UserResizedBottomPanel = $true
})

function Update-ResponsiveLayout {
    $winW = $Window.ActualWidth
    $winH = $Window.ActualHeight
    if ($winW -le 0) { $winW = $Window.Width }
    if ($winH -le 0) { $winH = $Window.Height }

    # 1. Dar pencerede sol menüyü otomatik kompakt moda al, genişleyince geri aç (kullanıcı elle kilitlemediyse)
    if (-not $script:UserPinnedSidebar) {
        if ($winW -lt 980 -and -not $script:IsSidebarCollapsed) {
            Set-SidebarCollapsed -Collapsed $true
        } elseif ($winW -ge 1060 -and $script:IsSidebarCollapsed) {
            Set-SidebarCollapsed -Collapsed $false
        }
    }

    # 2. Üst arama kutusunu dar ekranda 2. satıra tam genişlikte indir, geniş ekranda sağda orantılı tut
    if ($SearchBorder) {
        if ($winW -lt 900) {
            [Windows.Controls.Grid]::SetRow($SearchBorder, 1)
            [Windows.Controls.Grid]::SetColumn($SearchBorder, 0)
            [Windows.Controls.Grid]::SetColumnSpan($SearchBorder, 2)
            $SearchBorder.HorizontalAlignment = [Windows.HorizontalAlignment]::Stretch
            $SearchBorder.Width = [double]::NaN
            $SearchBorder.MaxWidth = [double]::PositiveInfinity
            $SearchBorder.Margin = New-Object Windows.Thickness(0, 8, 0, 0)
        } else {
            [Windows.Controls.Grid]::SetRow($SearchBorder, 0)
            [Windows.Controls.Grid]::SetColumn($SearchBorder, 1)
            [Windows.Controls.Grid]::SetColumnSpan($SearchBorder, 1)
            $SearchBorder.HorizontalAlignment = [Windows.HorizontalAlignment]::Right
            $SearchBorder.MaxWidth = 540
            $SearchBorder.Width = [Math]::Max(260, [Math]::Min(520, [Math]::Floor($winW * 0.31)))
            $SearchBorder.Margin = New-Object Windows.Thickness(0)
        }
    }

    # 3. Üst metrik kartlarını dar ekranda 2x2, geniş ekranda 4'lü diz
    if ($MetricsUniformGrid) {
        $targetCols = if ($winW -lt 980) { 2 } else { 4 }
        if ($MetricsUniformGrid.Columns -ne $targetCols) {
            $MetricsUniformGrid.Columns = $targetCols
        }
    }

    # 4. Alt süreç/günlük paneli yüksekliğini ekran yüksekliğine orantılı ayarla (kullanıcı sürüklemediyse)
    if (-not $script:IsLogCollapsed -and -not $script:UserResizedBottomPanel -and $BottomPanelRow) {
        $ratio = if ($script:IsInstalling) { 0.31 } else { 0.27 }
        $targetBottomH = [Math]::Max(185, [Math]::Min(360, [Math]::Floor($winH * $ratio)))
        if ([Math]::Abs($BottomPanelRow.Height.Value - $targetBottomH) -ge 8) {
            $BottomPanelRow.Height = New-Object Windows.GridLength($targetBottomH)
        }
    }

    # 5. Uygulama kartlarının genişliğini mevcut görünüm alanını eşit ve boşluksuz dolduracak şekilde hesapla
    if ($AppsScrollViewer) {
        $vpW = $AppsScrollViewer.ViewportWidth
        if ($vpW -le 100) {
            $sideW = if ($script:IsSidebarCollapsed) { 72 } else { 255 }
            $vpW = $winW - $sideW - 44
        }
        $usableW = [Math]::Max(260, $vpW - 28)

        # Akıllı kırılım noktaları (1 - 5 sütun)
        if ($usableW -lt 590)      { $cols = 1 }
        elseif ($usableW -lt 920)  { $cols = 2 }
        elseif ($usableW -lt 1280) { $cols = 3 }
        elseif ($usableW -lt 1680) { $cols = 4 }
        else                       { $cols = 5 }

        $cardW = [Math]::Floor(($usableW - ($cols * 12) - 4) / $cols)
        $cardW = [Math]::Max(240, [Math]::Min(460, $cardW))

        foreach ($app in $AllApps) {
            if ($app.CardRef -and [Math]::Abs($app.CardRef.Width - $cardW) -ge 2) {
                $app.CardRef.Width = $cardW
            }
        }
    }
}

$ScheduleResponsiveUpdate = {
    $Window.Dispatcher.BeginInvoke([Action]{ Update-ResponsiveLayout }, [Windows.Threading.DispatcherPriority]::Loaded) | Out-Null
}

$BtnToggleSidebar.Add_Click({
    $script:UserPinnedSidebar = $true
    Set-SidebarCollapsed -Collapsed (-not $script:IsSidebarCollapsed)
    & $ScheduleResponsiveUpdate
})

$Window.Add_SizeChanged({
    & $ScheduleResponsiveUpdate
})

$Window.Add_StateChanged({
    & $ScheduleResponsiveUpdate
})

$AppsScrollViewer.Add_SizeChanged({
    & $ScheduleResponsiveUpdate
})

$Window.Add_Loaded({
    & $ScheduleResponsiveUpdate
})

# Etkileşimli Üst Özet Kartları (Toplam Katalog / Kurulacak Seçim / Sistemde Yüklü)
$CardMetricTotal.Add_MouseLeftButtonUp({
    $script:ShowSelectedOnly  = $false
    $script:ShowInstalledOnly = $false
    $script:ActiveCategory    = "Tümü"
    Update-SelectionCounter
    Update-AppFilter
})

$CardMetricSelected.Add_MouseLeftButtonUp({
    $script:ShowInstalledOnly = $false
    $script:ShowSelectedOnly  = -not $script:ShowSelectedOnly
    Update-SelectionCounter
    Update-AppFilter
})

$CardMetricInstalled.Add_MouseLeftButtonUp({
    $script:ShowSelectedOnly  = $false
    $script:ShowInstalledOnly = -not $script:ShowInstalledOnly
    Update-SelectionCounter
    Update-AppFilter
})

# 9. Özel Paket Oluşturma / Düzenleme / Ad Değiştirme / Silme Penceresi ve Üst Paket Barı
function Show-PackageEditorDialog {
    param(
        [PSCustomObject]$ExistingPackage = $null,
        [switch]$CreateFromCurrentSelection
    )

    $dlgMaxH = [Math]::Max(500, [Math]::Min(650, [Math]::Floor([System.Windows.SystemParameters]::WorkArea.Height * 0.86)))

    [xml]$dlgXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Paket Oluştur / Düzenle"
        Width="560" Height="$dlgMaxH" MinWidth="460" MinHeight="460"
        WindowStartupLocation="CenterOwner"
        ResizeMode="CanResize"
        Background="#0F172A" Foreground="#F8FAFC"
        FontFamily="Segoe UI">
    <Grid Margin="20">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <StackPanel Grid.Row="0" Margin="0,0,0,14">
            <TextBlock x:Name="DlgHeaderTitle" Text="Yeni Kurulum Paketi Oluştur" FontSize="18" FontWeight="Bold" Foreground="#F8FAFC"/>
            <TextBlock Text="Paket adını belirleyin ve bu pakete dahil edilecek programları işaretleyin (ozel_paketler.json dosyasına kaydedilir)." FontSize="11.5" Foreground="#94A3B8" Margin="0,3,0,0" TextWrapping="Wrap"/>
        </StackPanel>

        <!-- Paket Adı Girişi -->
        <StackPanel Grid.Row="1" Margin="0,0,0,12">
            <TextBlock Text="PAKET ADI (Örn: İK Paketi, Muhasebe Paketi, Hemen Teslim Et)" FontSize="11" FontWeight="Bold" Foreground="#38BDF8" Margin="0,0,0,5"/>
            <Border Background="#090D16" BorderBrush="#334155" BorderThickness="1" CornerRadius="7" Padding="10,6">
                <TextBox x:Name="TxtPackageName" Background="Transparent" Foreground="#F8FAFC" BorderThickness="0" FontSize="14" CaretBrush="#38BDF8"/>
            </Border>
        </StackPanel>

        <!-- Program Arama ve Hızlı Seçim / Sayaç -->
        <Grid Grid.Row="2" Margin="0,0,0,8">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>
            <Grid Grid.Column="0">
                <Border Background="#090D16" BorderBrush="#334155" BorderThickness="1" CornerRadius="7" Padding="8,5">
                    <TextBox x:Name="TxtDlgSearch" Background="Transparent" Foreground="#F8FAFC" BorderThickness="0" FontSize="12.5" CaretBrush="#38BDF8"/>
                </Border>
                <TextBlock x:Name="TxtDlgSearchPlaceholder" Text="Program veya kategori ara..." Foreground="#64748B" FontSize="12" VerticalAlignment="Center" Margin="10,0,0,0" IsHitTestVisible="False"/>
            </Grid>
            <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center" Margin="10,0,0,0">
                <Button x:Name="BtnDlgClearSelection" Content="Seçimi Temizle" Background="#1E293B" Foreground="#CBD5E1" BorderBrush="#334155" BorderThickness="1" Padding="8,4" FontSize="11" Margin="0,0,8,0" Cursor="Hand"/>
                <TextBlock x:Name="TxtDlgSelectedCount" Text="0 program seçili" FontSize="12" FontWeight="Bold" Foreground="#34D399" VerticalAlignment="Center"/>
            </StackPanel>
        </Grid>

        <!-- Program Seçim Listesi -->
        <Border Grid.Row="3" Background="#090D16" BorderBrush="#1E293B" BorderThickness="1" CornerRadius="8" Padding="10">
            <ScrollViewer VerticalScrollBarVisibility="Auto">
                <StackPanel x:Name="DlgAppsStackPanel"/>
            </ScrollViewer>
        </Border>

        <!-- Alt Butonlar: Sil, İptal, Kaydet -->
        <Grid Grid.Row="4" Margin="0,16,0,0">
            <Button x:Name="BtnDlgDelete" Content="Paketi Sil" HorizontalAlignment="Left" Visibility="Collapsed"
                    Background="#7F1D1D" Foreground="#FECACA" BorderBrush="#EF4444" BorderThickness="1" Padding="14,8" FontWeight="Bold" Cursor="Hand"/>
            <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
                <Button x:Name="BtnDlgCancel" Content="İptal" Background="#1E293B" Foreground="#CBD5E1" BorderBrush="#334155" BorderThickness="1" Padding="16,8" Margin="0,0,10,0" FontWeight="SemiBold" Cursor="Hand"/>
                <Button x:Name="BtnDlgSave" Content="Paketi Kaydet" Background="#059669" Foreground="#FFFFFF" BorderBrush="#10B981" BorderThickness="1" Padding="20,8" FontWeight="Bold" Cursor="Hand"/>
            </StackPanel>
        </Grid>
    </Grid>
</Window>
"@

    $dlgReader = New-Object System.Xml.XmlNodeReader $dlgXaml
    $dlgWin = [Windows.Markup.XamlReader]::Load($dlgReader)
    $dlgWin.Owner = $Window

    $DlgHeaderTitle          = $dlgWin.FindName("DlgHeaderTitle")
    $TxtPackageName          = $dlgWin.FindName("TxtPackageName")
    $TxtDlgSearch            = $dlgWin.FindName("TxtDlgSearch")
    $TxtDlgSearchPlaceholder = $dlgWin.FindName("TxtDlgSearchPlaceholder")
    $BtnDlgClearSelection    = $dlgWin.FindName("BtnDlgClearSelection")
    $TxtDlgSelectedCount     = $dlgWin.FindName("TxtDlgSelectedCount")
    $DlgAppsStackPanel       = $dlgWin.FindName("DlgAppsStackPanel")
    $BtnDlgDelete            = $dlgWin.FindName("BtnDlgDelete")
    $BtnDlgCancel            = $dlgWin.FindName("BtnDlgCancel")
    $BtnDlgSave              = $dlgWin.FindName("BtnDlgSave")

    $initialAppIds = @()
    if ($ExistingPackage) {
        $DlgHeaderTitle.Text = "Paketi Düzenle: $($ExistingPackage.Name)"
        $TxtPackageName.Text = $ExistingPackage.Name
        $initialAppIds       = @($ExistingPackage.AppIds)
        $BtnDlgDelete.Visibility = [Windows.Visibility]::Visible
    } elseif ($CreateFromCurrentSelection) {
        $initialAppIds = @($AllApps | Where-Object { $_.IsSelected } | Select-Object -ExpandProperty Id)
    }

    $dlgCheckBoxes = New-Object System.Collections.Generic.List[Windows.Controls.CheckBox]

    $updateDlgCount = {
        $c = @($dlgCheckBoxes | Where-Object { $_.IsChecked }).Count
        $TxtDlgSelectedCount.Text = "$c program seçili"
    }

    foreach ($app in $AllApps) {
        $cb = New-Object Windows.Controls.CheckBox
        $cb.Margin = New-Object Windows.Thickness(4, 5, 4, 5)
        $cb.Foreground = $BrushConverter.ConvertFrom("#F8FAFC")
        $cb.FontSize = 12.5
        $cb.IsChecked = ($initialAppIds -contains $app.Id)
        $cb.Tag = $app

        $statusSuffix = if ($app.IsInstalled) { "  [Sistemde Yüklü]" } else { "" }
        $cb.Content = "$($app.Name)  ($($app.Category))$statusSuffix"

        $cb.Add_Checked($updateDlgCount)
        $cb.Add_Unchecked($updateDlgCount)

        $dlgCheckBoxes.Add($cb)
        $DlgAppsStackPanel.Children.Add($cb) | Out-Null
    }

    & $updateDlgCount

    $TxtDlgSearch.Add_TextChanged({
        $q = $TxtDlgSearch.Text.Trim().ToLower()
        $TxtDlgSearchPlaceholder.Visibility = if ([string]::IsNullOrEmpty($q)) { [Windows.Visibility]::Visible } else { [Windows.Visibility]::Collapsed }
        foreach ($cb in $dlgCheckBoxes) {
            $a = $cb.Tag
            $vis = [string]::IsNullOrEmpty($q) -or $a.Name.ToLower().Contains($q) -or $a.Category.ToLower().Contains($q)
            $cb.Visibility = if ($vis) { [Windows.Visibility]::Visible } else { [Windows.Visibility]::Collapsed }
        }
    })

    $BtnDlgClearSelection.Add_Click({
        foreach ($cb in $dlgCheckBoxes) {
            $cb.IsChecked = $false
        }
    })

    $BtnDlgCancel.Add_Click({
        $dlgWin.Close()
    })

    $BtnDlgDelete.Add_Click({
        if (-not $ExistingPackage) { return }
        $confirm = [System.Windows.MessageBox]::Show(
            "'$($ExistingPackage.Name)' paketini kalıcı olarak silmek istediğinize emin misiniz?",
            "Paketi Sil",
            [System.Windows.MessageBoxButton]::YesNo,
            [System.Windows.MessageBoxImage]::Warning
        )
        if ($confirm -eq [System.Windows.MessageBoxResult]::Yes) {
            [void]$script:SavedPackages.Remove($ExistingPackage)
            Save-PackagesToJson
            Rebuild-PackageButtonsBar
            Write-GuiLog "'$($ExistingPackage.Name)' paketi silindi."
            $dlgWin.Close()
        }
    })

    $BtnDlgSave.Add_Click({
        $newName = $TxtPackageName.Text.Trim()
        if ([string]::IsNullOrWhiteSpace($newName)) {
            [System.Windows.MessageBox]::Show("Lütfen paket için bir isim girin (Örn: İK Paketi, Muhasebe Paketi).", "Paket Adı Gerekli", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information) | Out-Null
            return
        }

        $chosenIds = @($dlgCheckBoxes | Where-Object { $_.IsChecked } | ForEach-Object { $_.Tag.Id })
        if ($chosenIds.Count -eq 0) {
            [System.Windows.MessageBox]::Show("Lütfen pakete dahil edilecek en az 1 program seçin.", "Program Seçilmedi", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information) | Out-Null
            return
        }

        if ($ExistingPackage) {
            $ExistingPackage.Name   = $newName
            $ExistingPackage.AppIds = $chosenIds
            Write-GuiLog "'$newName' paketi güncellendi ($($chosenIds.Count) program)."
        } else {
            # Aynı isimde paket varsa üzerine yaz, yoksa yeni ekle
            $sameNamePkg = $script:SavedPackages | Where-Object { $_.Name.ToLower() -eq $newName.ToLower() } | Select-Object -First 1
            if ($sameNamePkg) {
                $sameNamePkg.Name   = $newName
                $sameNamePkg.AppIds = $chosenIds
                Write-GuiLog "'$newName' paketi güncellendi ($($chosenIds.Count) program)."
            } else {
                $script:SavedPackages.Add([PSCustomObject]@{
                    Name   = $newName
                    Style  = "Custom"
                    AppIds = $chosenIds
                })
                Write-GuiLog "Yeni paket oluşturuldu ve ozel_paketler.json dosyasına kaydedildi: '$newName' ($($chosenIds.Count) program)."
            }
        }

        Save-PackagesToJson
        Rebuild-PackageButtonsBar
        $dlgWin.Close()
    })

    $TxtPackageName.Focus()
    $dlgWin.ShowDialog() | Out-Null
}

function Apply-SavedPackage {
    param([PSCustomObject]$PackageObj)
    if ($script:IsInstalling) { return }

    # Önce sistemde yüklü olanları güncel olarak kontrol et
    Scan-InstalledApplications -SilentLog

    $skippedInstalled = New-Object System.Collections.Generic.List[string]
    $selectedForInstall = 0

    foreach ($app in $AllApps) {
        if ($PackageObj.AppIds -contains $app.Id) {
            if ($app.IsInstalled) {
                # Sistemde zaten YÜKLÜ olan programları otomatik atla
                $app.CheckBoxRef.IsChecked = $false
                $skippedInstalled.Add($app.Name)
            } else {
                $app.CheckBoxRef.IsChecked = $true
                $selectedForInstall++
            }
        } else {
            $app.CheckBoxRef.IsChecked = $false
        }
        Set-CardVisualState -AppItem $app
    }

    $SearchBox.Text = ""
    $script:ShowInstalledOnly = $false
    # Eğer kurulu olmayan program seçildiyse Seçilenleri Göster görünümüne geç; hepsi zaten yüklüyse tümünü göster
    $script:ShowSelectedOnly = ($selectedForInstall -gt 0)
    Update-SelectionCounter
    Update-AppFilter

    if ($skippedInstalled.Count -gt 0) {
        Write-GuiLog "'$($PackageObj.Name)' seçildi: $selectedForInstall program kuruluma hazır. Sistemde zaten YÜKLÜ olduğu için atlanan ($($skippedInstalled.Count)): $($skippedInstalled -join ', ')"
    } else {
        Write-GuiLog "'$($PackageObj.Name)' seçildi ($selectedForInstall program kuruluma hazır)."
    }
}

function Rebuild-PackageButtonsBar {
    $PackagesTopBarPanel.Children.Clear()

    foreach ($pkg in $script:SavedPackages) {
        $pkgCount = @($pkg.AppIds).Count
        $isGreen  = ($pkg.Style -eq "Green")

        # Paket Kapsayıcı Çerçeve (Sol: Paket Seçim Butonu | Sağ: Bağımsız ⚙ Düzenle Butonu)
        $pillBorder = New-Object Windows.Controls.Border
        $pillBorder.CornerRadius = New-Object Windows.CornerRadius(8)
        $pillBorder.BorderThickness = New-Object Windows.Thickness(1)
        $pillBorder.Margin = New-Object Windows.Thickness(0, 2, 8, 2)
        $pillBorder.Background  = if ($isGreen) { $BrushConverter.ConvertFrom("#059669") } else { $BrushConverter.ConvertFrom("#1E293B") }
        $pillBorder.BorderBrush = if ($isGreen) { $BrushConverter.ConvertFrom("#10B981") } else { $BrushConverter.ConvertFrom("#334155") }

        $pillGrid = New-Object Windows.Controls.Grid
        $pc0 = New-Object Windows.Controls.ColumnDefinition
        $pc0.Width = [Windows.GridLength]::Auto
        $pc1 = New-Object Windows.Controls.ColumnDefinition
        $pc1.Width = [Windows.GridLength]::Auto
        $pillGrid.ColumnDefinitions.Add($pc0)
        $pillGrid.ColumnDefinitions.Add($pc1)

        # Sol: Paket Seçim Butonu (Koyu tema uyumlu şablon -> devre dışı bırakıldığında asla beyaza dönmez)
        $btn = New-Object Windows.Controls.Button
        $btn.Style = $Window.FindResource("PillInnerButtonStyle")
        $btn.Background = [Windows.Media.Brushes]::Transparent
        $btn.BorderThickness = New-Object Windows.Thickness(0)
        $btn.Foreground = $BrushConverter.ConvertFrom("#FFFFFF")
        $btn.Padding = New-Object Windows.Thickness(12, 7, 8, 7)
        $btn.FontSize = 12.5
        $btn.FontWeight = if ($isGreen) { [Windows.FontWeights]::Bold } else { [Windows.FontWeights]::SemiBold }
        $btn.Cursor = [Windows.Input.Cursors]::Hand
        $btn.Tag = $pkg
        [Windows.Controls.Grid]::SetColumn($btn, 0)

        $appNamesPreview = ($AllApps | Where-Object { $pkg.AppIds -contains $_.Id } | Select-Object -ExpandProperty Name) -join ", "
        $btn.ToolTip = "$($pkg.Name) ($pkgCount Program): $appNamesPreview`r`n`r`n• Sol Tık: Paketi Seç (Yüklü olanları otomatik atlar)`r`n• Sağ Tık veya ⚙ Butonu: Paketi Düzenle / Program Ekle-Çıkar / Ad Değiştir / Sil"

        $sp = New-Object Windows.Controls.StackPanel
        $sp.Orientation = [Windows.Controls.Orientation]::Horizontal
        $sp.VerticalAlignment = [Windows.VerticalAlignment]::Center

        $iconGlyph = if ($isGreen) { [string][char]0xE73E } elseif ($pkg.Style -eq "Default") { [string][char]0xE90F } else { [string][char]0xE7B8 }
        $ic = New-Object Windows.Controls.TextBlock
        $ic.Text = $iconGlyph
        $ic.FontFamily = New-Object Windows.Media.FontFamily("Segoe MDL2 Assets")
        $ic.FontSize = 12.5
        $ic.Margin = New-Object Windows.Thickness(0, 0, 7, 0)
        $ic.VerticalAlignment = [Windows.VerticalAlignment]::Center
        if (-not $isGreen) {
            $ic.Foreground = $BrushConverter.ConvertFrom("#38BDF8")
        }

        $txt = New-Object Windows.Controls.TextBlock
        $txt.Text = "$($pkg.Name) ($pkgCount)"
        $txt.VerticalAlignment = [Windows.VerticalAlignment]::Center

        $sp.Children.Add($ic) | Out-Null
        $sp.Children.Add($txt) | Out-Null
        $btn.Content = $sp

        # Sağ: Bağımsız ⚙ Düzenle / Yönet Butonu (Click çakışmasını %100 önler ve devre dışı iken koyu kalır)
        $btnGear = New-Object Windows.Controls.Button
        $btnGear.Style = $Window.FindResource("PillInnerButtonStyle")
        $btnGear.Background = [Windows.Media.Brushes]::Transparent
        $btnGear.BorderThickness = New-Object Windows.Thickness(1, 0, 0, 0)
        $btnGear.BorderBrush = if ($isGreen) { $BrushConverter.ConvertFrom("#047857") } else { $BrushConverter.ConvertFrom("#334155") }
        $btnGear.Foreground = $BrushConverter.ConvertFrom("#E2E8F0")
        $btnGear.Padding = New-Object Windows.Thickness(8, 7, 9, 7)
        $btnGear.Cursor = [Windows.Input.Cursors]::Hand
        $btnGear.ToolTip = "'$($pkg.Name)' Paketini Düzenle / Program Ekle-Çıkar / Ad Değiştir / Sil"
        $btnGear.Tag = $pkg
        [Windows.Controls.Grid]::SetColumn($btnGear, 1)

        $gearIcon = New-Object Windows.Controls.TextBlock
        $gearIcon.Text = [string][char]0xE713
        $gearIcon.FontFamily = New-Object Windows.Media.FontFamily("Segoe MDL2 Assets")
        $gearIcon.FontSize = 12
        $gearIcon.VerticalAlignment = [Windows.VerticalAlignment]::Center
        $btnGear.Content = $gearIcon

        $btnGear.Add_Click({
            param($sender, $e)
            if ($script:IsInstalling) { return }
            Show-PackageEditorDialog -ExistingPackage $sender.Tag
        })

        # Sağ Tık Menüsü (ContextMenu): Paketi Düzenle, Seçili Programlarla Güncelle, Paketi Sil
        $ctxMenu = New-Object Windows.Controls.ContextMenu

        $miEdit = New-Object Windows.Controls.MenuItem
        $miEdit.Header = "Paketi Düzenle (Program Ekle/Çıkar veya Ad Değiştir)..."
        $miEdit.Tag = $pkg
        $miEdit.Add_Click({
            param($sender, $e)
            if ($script:IsInstalling) { return }
            Show-PackageEditorDialog -ExistingPackage $sender.Tag
        })

        $miUpdateFromSel = New-Object Windows.Controls.MenuItem
        $miUpdateFromSel.Header = "Ekranda Seçili Olan Programları Bu Pakete Kaydet"
        $miUpdateFromSel.Tag = $pkg
        $miUpdateFromSel.Add_Click({
            param($sender, $e)
            if ($script:IsInstalling) { return }
            $targetPkg = $sender.Tag
            $curSel = @($AllApps | Where-Object { $_.IsSelected } | Select-Object -ExpandProperty Id)
            if ($curSel.Count -eq 0) {
                [System.Windows.MessageBox]::Show("Önce ekrandan pakete kaydetmek istediğiniz programları işaretleyin.", "Seçili Program Yok", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information) | Out-Null
                return
            }
            $targetPkg.AppIds = $curSel
            Save-PackagesToJson
            Rebuild-PackageButtonsBar
            Write-GuiLog "'$($targetPkg.Name)' paketi ekranda seçili olan $($curSel.Count) programla güncellendi."
        })

        $miDelete = New-Object Windows.Controls.MenuItem
        $miDelete.Header = "Paketi Sil"
        $miDelete.Tag = $pkg
        $miDelete.Add_Click({
            param($sender, $e)
            if ($script:IsInstalling) { return }
            $targetPkg = $sender.Tag
            $confirm = [System.Windows.MessageBox]::Show(
                "'$($targetPkg.Name)' paketini silmek istediğinize emin misiniz?",
                "Paketi Sil",
                [System.Windows.MessageBoxButton]::YesNo,
                [System.Windows.MessageBoxImage]::Warning
            )
            if ($confirm -eq [System.Windows.MessageBoxResult]::Yes) {
                [void]$script:SavedPackages.Remove($targetPkg)
                Save-PackagesToJson
                Rebuild-PackageButtonsBar
                Write-GuiLog "'$($targetPkg.Name)' paketi silindi."
            }
        })

        $ctxMenu.Items.Add($miEdit) | Out-Null
        $ctxMenu.Items.Add($miUpdateFromSel) | Out-Null
        $ctxMenu.Items.Add((New-Object Windows.Controls.Separator)) | Out-Null
        $ctxMenu.Items.Add($miDelete) | Out-Null
        $pillBorder.ContextMenu = $ctxMenu

        $btn.Add_Click({
            param($sender, $e)
            Apply-SavedPackage -PackageObj $sender.Tag
        })

        $pillGrid.Children.Add($btn) | Out-Null
        $pillGrid.Children.Add($btnGear) | Out-Null
        $pillBorder.Child = $pillGrid

        $PackagesTopBarPanel.Children.Add($pillBorder) | Out-Null
    }

    # "+ Yeni Paket Oluştur" Butonu
    $btnNewPkg = New-Object Windows.Controls.Button
    $btnNewPkg.Style = $Window.FindResource("NewPackageButtonStyle")
    $btnNewPkg.Margin = New-Object Windows.Thickness(0, 2, 0, 2)
    $btnNewPkg.Content = "+ Yeni Paket Oluştur"
    $btnNewPkg.ToolTip = "Seçtiğiniz programlardan yeni bir kurulum paketi (Örn: İK Paketi, Muhasebe Paketi) oluşturur ve ozel_paketler.json dosyasına kaydeder"
    $btnNewPkg.Add_Click({
        if ($script:IsInstalling) { return }
        Show-PackageEditorDialog -CreateFromCurrentSelection
    })

    $PackagesTopBarPanel.Children.Add($btnNewPkg) | Out-Null
}

Rebuild-PackageButtonsBar

# 10. Arka Planda Gerçek Uygulama Logolarını İndirip Önbelleğe (.icons) Kaydeden Motor
$missingIconApps = @($AllApps | Where-Object { $_.Domain -and -not (Test-Path -LiteralPath $_.IconCachePath) })
if ($missingIconApps.Count -gt 0) {
    $iconSync = [hashtable]::Synchronized(@{
        CompletedQueue = [System.Collections.Concurrent.ConcurrentQueue[string]]::new()
        IsDone         = $false
    })

    $iconPayload = $missingIconApps | ForEach-Object {
        [PSCustomObject]@{
            Id        = $_.Id
            Domain    = $_.Domain
            CachePath = $_.IconCachePath
        }
    }

    $iconRunspace = [runspacefactory]::CreateRunspace()
    $iconRunspace.Open()
    $iconRunspace.SessionStateProxy.SetVariable("iconSync", $iconSync)
    $iconRunspace.SessionStateProxy.SetVariable("iconPayload", $iconPayload)

    $iconPs = [powershell]::Create().AddScript({
        $ProgressPreference = 'SilentlyContinue'
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $wc = New-Object System.Net.WebClient

        foreach ($item in $iconPayload) {
            try {
                $url = "https://www.google.com/s2/favicons?domain=$($item.Domain)&sz=64"
                $bytes = $wc.DownloadData($url)
                if ($bytes -and $bytes.Length -gt 80) {
                    [System.IO.File]::WriteAllBytes($item.CachePath, $bytes)
                    $iconSync.CompletedQueue.Enqueue($item.Id)
                }
            } catch {}
        }
        $wc.Dispose()
        $iconSync.IsDone = $true
    })

    $iconPs.Runspace = $iconRunspace
    $iconAsync = $iconPs.BeginInvoke()

    $iconTimer = New-Object Windows.Threading.DispatcherTimer
    $iconTimer.Interval = [TimeSpan]::FromMilliseconds(250)
    $iconTimer.Tag = @{
        Sync     = $iconSync
        PS       = $iconPs
        Runspace = $iconRunspace
        Async    = $iconAsync
    }
    $iconTimer.Add_Tick({
        param($sender, $e)
        $ctx = $sender.Tag
        $appId = $null
        while ($ctx.Sync.CompletedQueue.TryDequeue([ref]$appId)) {
            $appObj = $AllApps | Where-Object { $_.Id -eq $appId } | Select-Object -First 1
            if ($appObj -and (Set-AppCardLogoFromFile -AppItem $appObj -FilePath $appObj.IconCachePath)) {
                $appObj.IconImageRef.Parent.Visibility = [Windows.Visibility]::Visible
            }
        }
        if ($ctx.Sync.IsDone -and $ctx.Sync.CompletedQueue.IsEmpty) {
            $sender.Stop()
            try {
                $ctx.PS.EndInvoke($ctx.Async) | Out-Null
                $ctx.PS.Dispose()
                $ctx.Runspace.Close()
                $ctx.Runspace.Dispose()
            } catch {}
        }
    })
    $iconTimer.Start()
}

# 11. Sol Kategori Menüsünü İkonlu Olarak Oluşturma ve Filtreleme
$DistinctCategories = $AllApps | Select-Object -ExpandProperty Category -Unique
$OrderedCats = @("Tümü")
foreach ($c in $CategoryOrder) {
    if ($DistinctCategories -contains $c) { $OrderedCats += $c }
}
foreach ($c in $DistinctCategories) {
    if ($OrderedCats -notcontains $c) { $OrderedCats += $c }
}

$CategoryButtons = @{}

function Update-AppFilter {
    $query = $SearchBox.Text.Trim().ToLower()
    $SearchPlaceholder.Visibility = if ([string]::IsNullOrEmpty($query)) { [Windows.Visibility]::Visible } else { [Windows.Visibility]::Collapsed }
    $BtnClearSearch.Visibility    = if ([string]::IsNullOrEmpty($query)) { [Windows.Visibility]::Collapsed } else { [Windows.Visibility]::Visible }

    $visibleCount = 0
    foreach ($app in $AllApps) {
        $searchMatch = [string]::IsNullOrEmpty($query) -or
                       ($app.Name.ToLower().Contains($query)) -or
                       ($app.Description.ToLower().Contains($query)) -or
                       ($app.Category.ToLower().Contains($query))

        if ($script:ShowSelectedOnly) {
            $match = $app.IsSelected -and $searchMatch
        } elseif ($script:ShowInstalledOnly) {
            $match = $app.IsInstalled -and $searchMatch
        } else {
            $catMatch = ($script:ActiveCategory -eq "Tümü") -or ($app.Category -eq $script:ActiveCategory)
            $match = $catMatch -and $searchMatch
        }

        if ($match) {
            $app.CardRef.Visibility = [Windows.Visibility]::Visible
            $visibleCount++
        } else {
            $app.CardRef.Visibility = [Windows.Visibility]::Collapsed
        }
    }

    if ($script:ShowSelectedOnly) {
        $CurrentCategoryTitle.Text = "Seçilen Programlar"
    } elseif ($script:ShowInstalledOnly) {
        $CurrentCategoryTitle.Text = "Sistemde Yüklü Programlar"
    } else {
        $CurrentCategoryTitle.Text = if ($script:ActiveCategory -eq "Tümü") { "Tüm Programlar" } else { $script:ActiveCategory }
    }
    $CurrentCategoryCount.Text = "$visibleCount program"

    # Üst Özet Kartlarının Vurgu Çerçevelerini Güncelle
    $CardMetricTotal.BorderBrush     = if (-not $script:ShowSelectedOnly -and -not $script:ShowInstalledOnly -and $script:ActiveCategory -eq "Tümü") { $BrushConverter.ConvertFrom("#38BDF8") } else { $BrushConverter.ConvertFrom("#1E293B") }
    $CardMetricSelected.BorderBrush  = if ($script:ShowSelectedOnly) { $BrushConverter.ConvertFrom("#38BDF8") } else { $BrushConverter.ConvertFrom("#1E3A8A") }
    $CardMetricInstalled.BorderBrush = if ($script:ShowInstalledOnly) { $BrushConverter.ConvertFrom("#10B981") } else { $BrushConverter.ConvertFrom("#064E3B") }

    foreach ($catName in $CategoryButtons.Keys) {
        $btn = $CategoryButtons[$catName]
        if (-not $script:ShowSelectedOnly -and -not $script:ShowInstalledOnly -and $catName -eq $script:ActiveCategory) {
            $btn.Background = $BrushConverter.ConvertFrom("#2563EB")
            $btn.Foreground = $BrushConverter.ConvertFrom("#FFFFFF")
            $btn.FontWeight = [Windows.FontWeights]::Bold
        } else {
            $btn.Background = [Windows.Media.Brushes]::Transparent
            $btn.Foreground = $BrushConverter.ConvertFrom("#CBD5E1")
            $btn.FontWeight = [Windows.FontWeights]::Normal
        }
    }
}

foreach ($cat in $OrderedCats) {
    $count = if ($cat -eq "Tümü") { $AllApps.Count } else { @($AllApps | Where-Object { $_.Category -eq $cat }).Count }
    $label = if ($cat -eq "Tümü") { "Tüm Programlar" } else { $cat }
    $glyph = if ($CategoryGlyphs.ContainsKey($cat)) { $CategoryGlyphs[$cat] } else { [string][char]0xE71D }

    $btn = New-Object Windows.Controls.Button
    $btn.Style = $Window.FindResource("CategoryButtonStyle")
    $btn.Tag = $cat
    $btn.ToolTip = "$label ($count program)"

    $rowGrid = New-Object Windows.Controls.Grid
    $rc0 = New-Object Windows.Controls.ColumnDefinition
    $rc0.Width = New-Object Windows.GridLength(22)
    $rc1 = New-Object Windows.Controls.ColumnDefinition
    $rc1.Width = New-Object Windows.GridLength(1, [Windows.GridUnitType]::Star)
    $rc2 = New-Object Windows.Controls.ColumnDefinition
    $rc2.Width = [Windows.GridLength]::Auto
    $rowGrid.ColumnDefinitions.Add($rc0)
    $rowGrid.ColumnDefinitions.Add($rc1)
    $rowGrid.ColumnDefinitions.Add($rc2)

    $iconBlock = New-Object Windows.Controls.TextBlock
    $iconBlock.Text = $glyph
    $iconBlock.FontFamily = New-Object Windows.Media.FontFamily("Segoe MDL2 Assets")
    $iconBlock.FontSize = 13.5
    $iconBlock.VerticalAlignment = [Windows.VerticalAlignment]::Center
    [Windows.Controls.Grid]::SetColumn($iconBlock, 0)

    $lblBlock = New-Object Windows.Controls.TextBlock
    $lblBlock.Text = $label
    $lblBlock.VerticalAlignment = [Windows.VerticalAlignment]::Center
    $lblBlock.TextTrimming = [Windows.TextTrimming]::CharacterEllipsis
    $lblBlock.Margin = New-Object Windows.Thickness(2, 0, 4, 0)
    [Windows.Controls.Grid]::SetColumn($lblBlock, 1)
    $script:CategoryTextBlocks.Add($lblBlock) | Out-Null

    $cntBlock = New-Object Windows.Controls.TextBlock
    $cntBlock.Text = "$count"
    $cntBlock.FontSize = 11.5
    $cntBlock.Opacity = 0.8
    $cntBlock.Margin = New-Object Windows.Thickness(2, 0, 0, 0)
    $cntBlock.VerticalAlignment = [Windows.VerticalAlignment]::Center
    [Windows.Controls.Grid]::SetColumn($cntBlock, 2)

    $rowGrid.Children.Add($iconBlock) | Out-Null
    $rowGrid.Children.Add($lblBlock) | Out-Null
    $rowGrid.Children.Add($cntBlock) | Out-Null
    $btn.Content = $rowGrid

    $btn.Add_Click({
        param($sender, $e)
        $script:ShowSelectedOnly  = $false
        $script:ShowInstalledOnly = $false
        $script:ActiveCategory    = $sender.Tag
        Update-SelectionCounter
        Update-AppFilter
    })

    $CategoryButtons[$cat] = $btn
    $CategoryListPanel.Children.Add($btn) | Out-Null
}

$SearchBox.Add_TextChanged({ Update-AppFilter })
$BtnClearSearch.Add_Click({
    $SearchBox.Text = ""
    $SearchBox.Focus()
})

$BtnShowSelectedOnly.Add_Click({
    $script:ShowInstalledOnly = $false
    $script:ShowSelectedOnly  = -not $script:ShowSelectedOnly
    Update-SelectionCounter
    Update-AppFilter
})

# 12. Toplu Seçim Butonları (Kategori Seçiminde de Zaten Yüklü Olanları Atlar)
$BtnSelectCategory.Add_Click({
    if ($script:IsInstalling) { return }
    foreach ($app in $AllApps) {
        if ($app.CardRef.Visibility -eq [Windows.Visibility]::Visible -and -not $app.IsInstalled) {
            $app.CheckBoxRef.IsChecked = $true
        }
    }
})

$BtnClearAll.Add_Click({
    if ($script:IsInstalling) { return }
    $script:ShowSelectedOnly  = $false
    $script:ShowInstalledOnly = $false
    foreach ($app in $AllApps) {
        $app.CheckBoxRef.IsChecked = $false
        Set-CardVisualState -AppItem $app
    }
    Update-SelectionCounter
    Update-AppFilter
    Write-GuiLog "Tüm seçimler temizlendi."
})

# İlk filtre görünümünü yükle
Update-AppFilter
Update-SelectionCounter

# 13. Asenkron (Arayüzü Dondurmayan) Yüzdelikli İndirme, Gerçek Kurulum Doğrulama ve Masaüstü Kısayolu Motoru
$BtnStartInstall.Add_Click({
    if ($script:IsInstalling) { return }
    $selectedApps = @($AllApps | Where-Object { $_.IsSelected })
    if ($selectedApps.Count -eq 0) { return }

    # Alt log paneli gizlenmişse kurulum başlarken otomatik olarak tekrar aç
    if ($script:IsLogCollapsed) {
        Set-LogPanelExpanded -Expanded $true
    }

    $script:ShowInstalledOnly = $false
    $script:ShowSelectedOnly  = $true
    Update-SelectionCounter
    Update-AppFilter
    Rebuild-StepTrackerPreview

    $script:IsInstalling = $true
    $BtnStartInstall.IsEnabled     = $false
    $BtnStartInstall.Content       = "Kurulum Devam Ediyor..."
    $BtnSelectCategory.IsEnabled   = $false
    $BtnClearAll.IsEnabled         = $false
    $BtnRescanInstalled.IsEnabled  = $false
    $PackagesTopBarPanel.IsEnabled = $false
    $PackagesTopBarPanel.Opacity   = 0.48
    Update-ResponsiveLayout

    $InstallProgressBar.Maximum = $selectedApps.Count * 100
    $InstallProgressBar.Value   = 0
    $ProgressPercentText.Text   = "%0"
    $MetricStateText.Text       = "Kurulum Yapılıyor..."

    foreach ($app in $selectedApps) {
        Set-AppInstallState -AppId $app.Id -State "Pending" -DetailText "Kurulum sırası bekleniyor..." -Percent 0
    }

    Write-GuiLog "=================================================================="
    Write-GuiLog "KATILIMSIZ KURULUM SÜRECİ BAŞLATILDI ($($selectedApps.Count) program)"
    Write-GuiLog "=================================================================="

    $syncHash = [hashtable]::Synchronized(@{
        LogQueue       = [System.Collections.Concurrent.ConcurrentQueue[string]]::new()
        StateQueue     = [System.Collections.Concurrent.ConcurrentQueue[PSCustomObject]]::new()
        CurrentStep    = "Kurulum hazırlığı yapılıyor..."
        SummaryLine    = "Kurulum başlatıldı..."
        Completed      = 0
        ProgressValue  = 0
        OverallPercent = 0
        Total          = $selectedApps.Count
        IsFinished     = $false
        SuccessCount   = 0
        FailCount      = 0
    })

    $appsPayload = $selectedApps | ForEach-Object {
        [PSCustomObject]@{
            Id            = $_.Id
            Name          = $_.Name
            Category      = $_.Category
            ScriptPath    = $_.ScriptPath
            WingetId      = $_.WingetId
            IsLocal       = $_.IsLocal
            DetectPattern = $_.DetectPattern
            WasInstalled  = $_.IsInstalled
        }
    }

    $runspace = [runspacefactory]::CreateRunspace()
    $runspace.ApartmentState = "STA"
    $runspace.ThreadOptions  = "ReuseThread"
    $runspace.Open()
    $runspace.SessionStateProxy.SetVariable("syncHash", $syncHash)
    $runspace.SessionStateProxy.SetVariable("appsPayload", $appsPayload)
    $runspace.SessionStateProxy.SetVariable("ScriptRoot", $ScriptRoot)
    $runspace.SessionStateProxy.SetVariable("IsAdminSession", $isAdmin)

    $psCmd = [powershell]::Create().AddScript({
        $ProgressPreference = 'SilentlyContinue'
        try {
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor 3072
        } catch {
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        }

        $hasWinget = $null -ne (Get-Command winget.exe -ErrorAction SilentlyContinue)

        function Send-AppState {
            param(
                [string]$AppId,
                [string]$State,
                [string]$Detail,
                [string]$Badge = "",
                [int]$Percent = -1
            )
            $syncHash.StateQueue.Enqueue([PSCustomObject]@{
                AppId   = $AppId
                State   = $State
                Detail  = $Detail
                Badge   = $Badge
                Percent = $Percent
            })
        }

        function Update-OverallProgress {
            param([int]$AppIndex, [int]$StepPct)
            $clamped = [Math]::Max(0, [Math]::Min(100, $StepPct))
            $val = (($AppIndex - 1) * 100) + $clamped
            $maxVal = [Math]::Max(1, $syncHash.Total * 100)
            $syncHash.ProgressValue  = $val
            $syncHash.OverallPercent = [int][Math]::Floor(($val * 100.0) / $maxVal)
        }

        function Get-UninstallSnapshot {
            $regPaths = @(
                "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
                "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
                "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
            )
            $list = New-Object System.Collections.Generic.List[PSCustomObject]
            foreach ($rp in $regPaths) {
                try {
                    $items = Get-ItemProperty -Path $rp -ErrorAction SilentlyContinue
                    foreach ($it in $items) {
                        if ($it.DisplayName) {
                            $list.Add([PSCustomObject]@{
                                Key             = [string]$it.PSPath
                                DisplayName     = [string]$it.DisplayName
                                DisplayVersion  = if ($it.DisplayVersion) { [string]$it.DisplayVersion } else { "" }
                                InstallLocation = if ($it.InstallLocation) { ([string]$it.InstallLocation).Trim().Trim('"') } else { "" }
                                DisplayIcon     = if ($it.DisplayIcon) { [string]$it.DisplayIcon } else { "" }
                                UninstallString = if ($it.UninstallString) { [string]$it.UninstallString } else { "" }
                            })
                        }
                    }
                } catch {}
            }
            return $list
        }

        function Get-LnkMap {
            param([string[]]$Dirs)
            $map = @{}
            foreach ($d in $Dirs) {
                if ($d -and (Test-Path -LiteralPath $d)) {
                    Get-ChildItem -LiteralPath $d -Filter "*.lnk" -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {
                        $map[$_.FullName.ToLowerInvariant()] = $_.FullName
                    }
                }
            }
            return $map
        }

        function Resolve-ExeFromRawString {
            param([string]$RawStr)
            if ([string]::IsNullOrWhiteSpace($RawStr)) { return $null }
            $s = $RawStr.Trim()
            if ($s -match '^"([^"]+\.exe)"') {
                $cand = $Matches[1]
            } elseif ($s -match '([A-Za-z]:\\[^",;\r\n]+\.exe)') {
                $cand = $Matches[1]
            } else {
                $cand = ($s -split ',')[0].Trim().Trim('"')
            }
            if ($cand -and $cand -match '\.exe$' -and (Test-Path -LiteralPath $cand)) {
                $leaf = Split-Path -Leaf $cand
                if ($leaf -notmatch '^(msiexec|unins|uninstall|setup|update|updater|helper|crash)') {
                    return $cand
                }
            }
            return $null
        }

        function Get-KnownAppExecutables {
            param([string]$AppId)
            $pf   = $env:ProgramFiles
            $pf86 = ${env:ProgramFiles(x86)}
            $lad  = $env:LOCALAPPDATA
            $ad   = $env:APPDATA
            $map = @{
                "Install_Adobe_Acrobat_Pro.ps1"        = @("$pf\Adobe\Acrobat DC\Acrobat\Acrobat.exe", "$pf86\Adobe\Acrobat DC\Acrobat\Acrobat.exe")
                "Install_Adobe_Acrobat_Reader.ps1"     = @("$pf\Adobe\Acrobat DC\Acrobat\Acrobat.exe", "$pf86\Adobe\Acrobat Reader DC\Reader\AcroRd32.exe")
                "Install_Google_Chrome.ps1"            = @("$pf\Google\Chrome\Application\chrome.exe", "$pf86\Google\Chrome\Application\chrome.exe")
                "Install_Firefox.ps1"                  = @("$pf\Mozilla Firefox\firefox.exe", "$pf86\Mozilla Firefox\firefox.exe")
                "Install_Brave.ps1"                    = @("$pf\BraveSoftware\Brave-Browser\Application\brave.exe", "$lad\BraveSoftware\Brave-Browser\Application\brave.exe")
                "Install_Microsoft_Edge.ps1"           = @("$pf86\Microsoft\Edge\Application\msedge.exe", "$pf\Microsoft\Edge\Application\msedge.exe")
                "Install_Opera.ps1"                    = @("$pf\Opera\opera.exe", "$lad\Programs\Opera\opera.exe")
                "Install_Vivaldi.ps1"                  = @("$pf\Vivaldi\Application\vivaldi.exe", "$lad\Vivaldi\Application\vivaldi.exe")
                "Install_WinRAR.ps1"                   = @("$pf\WinRAR\WinRAR.exe", "$pf86\WinRAR\WinRAR.exe")
                "Install_7-Zip.ps1"                    = @("$pf\7-Zip\7zFM.exe", "$pf86\7-Zip\7zFM.exe")
                "Install_PeaZip.ps1"                   = @("$pf\PeaZip\peazip.exe")
                "Install_AnyDesk.ps1"                  = @("$pf86\AnyDesk\AnyDesk.exe", "$pf\AnyDesk\AnyDesk.exe")
                "Install_TeamViewer.ps1"               = @("$pf\TeamViewer\TeamViewer.exe", "$pf86\TeamViewer\TeamViewer.exe")
                "Install_OpenVPN.ps1"                  = @("$pf\OpenVPN Connect\OpenVPNConnect.exe", "$pf\OpenVPN\bin\openvpn-gui.exe")
                "Install_SafeNet_SAC.ps1"              = @("$pf\SafeNet\Authentication\SAC\x64\SACTools.exe", "$pf\SafeNet\Authentication\SAC\x32\SACTools.exe")
                "Install_DtxgateSigner.ps1"            = @("$pf\Dtxgate\DtxgateSigner\DtxgateSigner.exe", "$pf86\Dtxgate\DtxgateSigner\DtxgateSigner.exe", "$pf\ArkSigner\ArkSigner.exe", "$pf86\ArkSigner\ArkSigner.exe")
                "Install_Notepad-Plus-Plus.ps1"        = @("$pf\Notepad++\notepad++.exe", "$pf86\Notepad++\notepad++.exe")
                "Install_Visual_Studio_Code.ps1"       = @("$pf\Microsoft VS Code\Code.exe", "$lad\Programs\Microsoft VS Code\Code.exe")
                "Install_Sublime_Text.ps1"             = @("$pf\Sublime Text\sublime_text.exe", "$pf\Sublime Text 3\sublime_text.exe")
                "Install_PuTTY.ps1"                    = @("$pf\PuTTY\putty.exe", "$pf86\PuTTY\putty.exe")
                "Install_WinSCP.ps1"                   = @("$pf86\WinSCP\WinSCP.exe", "$pf\WinSCP\WinSCP.exe")
                "Install_FileZilla.ps1"                = @("$pf\FileZilla FTP Client\filezilla.exe")
                "Install_VLC_Media_Player.ps1"         = @("$pf\VideoLAN\VLC\vlc.exe", "$pf86\VideoLAN\VLC\vlc.exe")
                "Install_Foxit_Reader.ps1"             = @("$pf86\Foxit Software\Foxit PDF Reader\FoxitPDFReader.exe", "$pf\Foxit Software\Foxit PDF Reader\FoxitPDFReader.exe")
                "Install_Sumatra_PDF.ps1"              = @("$pf\SumatraPDF\SumatraPDF.exe", "$lad\SumatraPDF\SumatraPDF.exe")
                "Install_LibreOffice.ps1"              = @("$pf\LibreOffice\program\soffice.exe")
                "Install_Everything.ps1"               = @("$pf\Everything\Everything.exe", "$pf86\Everything\Everything.exe")
                "Install_WinDirStat.ps1"               = @("$pf86\WinDirStat\windirstat.exe", "$pf\WinDirStat\WinDirStat.exe")
                "Install_Revo_Uninstaller.ps1"         = @("$pf\VS Revo Group\Revo Uninstaller\RevoUnin.exe", "$pf86\VS Revo Group\Revo Uninstaller\RevoUnin.exe")
                "Install_Zoom.ps1"                     = @("$pf\Zoom\bin\Zoom.exe", "$pf86\Zoom\bin\Zoom.exe", "$ad\Zoom\bin\Zoom.exe")
                "Install_Discord.ps1"                  = @("$lad\Discord\Update.exe")
                "Install_Telegram.ps1"                 = @("$ad\Telegram Desktop\Telegram.exe", "$pf\Telegram Desktop\Telegram.exe")
                "Install_Thunderbird.ps1"              = @("$pf\Mozilla Thunderbird\thunderbird.exe")
                "Install_OBS_Studio.ps1"               = @("$pf\obs-studio\bin\64bit\obs64.exe")
                "Install_ShareX.ps1"                   = @("$pf\ShareX\ShareX.exe")
                "Install_Greenshot.ps1"                = @("$pf\Greenshot\Greenshot.exe")
                "Install_Paint.NET.ps1"                = @("$pf\paint.net\paintdotnet.exe")
                "Install_Audacity.ps1"                 = @("$pf\Audacity\Audacity.exe")
                "Install_Spotify.ps1"                  = @("$ad\Spotify\Spotify.exe")
                "Install_qBittorrent.ps1"              = @("$pf\qBittorrent\qbittorrent.exe")
                "Install_Google_Earth.ps1"             = @("$pf\Google\Google Earth Pro\client\googleearth.exe")
                "Install_Oracle_VM_VirtualBox.ps1"     = @("$pf\Oracle\VirtualBox\VirtualBox.exe")
                "Install_Steam.ps1"                    = @("$pf86\Steam\steam.exe")
                "Install_Malwarebytes.ps1"             = @("$pf\Malwarebytes\Anti-Malware\mbam.exe")
            }
            if ($map.ContainsKey($AppId)) { return $map[$AppId] }
            return @()
        }

        function Resolve-InstalledAppInfo {
            param(
                $App,
                $BeforeReg,
                $AfterReg,
                [string]$ReportedDir,
                [string]$ReportedExe,
                [string[]]$NewStartLnks
            )

            $beforeKeys = @{}
            foreach ($b in $BeforeReg) { $beforeKeys[$b.Key] = $true }
            $newEntries = @($AfterReg | Where-Object { -not $beforeKeys.ContainsKey($_.Key) })

            $matchedEntry = $null
            if ($App.DetectPattern -and $App.DetectPattern -notmatch 'NeverMatch') {
                $matchedEntry = $newEntries | Where-Object { $_.DisplayName -match $App.DetectPattern } | Select-Object -First 1
                if (-not $matchedEntry) {
                    $matchedEntry = $AfterReg | Where-Object { $_.DisplayName -match $App.DetectPattern } | Select-Object -First 1
                }
            }
            if (-not $matchedEntry -and $newEntries.Count -gt 0) {
                $matchedEntry = $newEntries | Where-Object { $_.DisplayName -notmatch 'Microsoft Visual C\+\+|Windows Update|Security Update' } | Select-Object -First 1
                if (-not $matchedEntry) { $matchedEntry = $newEntries[0] }
            }

            $mainExe = $null
            if ($ReportedExe -and (Test-Path -LiteralPath $ReportedExe)) {
                $mainExe = $ReportedExe
            }
            if (-not $mainExe) {
                foreach ($cand in (Get-KnownAppExecutables -AppId $App.Id)) {
                    if ($cand -and (Test-Path -LiteralPath $cand)) {
                        $mainExe = $cand
                        break
                    }
                }
            }
            if (-not $mainExe -and $matchedEntry) {
                $mainExe = Resolve-ExeFromRawString -RawStr $matchedEntry.DisplayIcon
            }
            if (-not $mainExe -and $NewStartLnks -and $NewStartLnks.Count -gt 0) {
                try {
                    $wshTmp = New-Object -ComObject WScript.Shell
                    foreach ($lnk in $NewStartLnks) {
                        $bn = [System.IO.Path]::GetFileNameWithoutExtension($lnk)
                        if ($bn -match 'Uninstall|Kaldır|Help|Readme|Update|Website|Manual|License|Release Notes') { continue }
                        $sc = $wshTmp.CreateShortcut($lnk)
                        if ($sc.TargetPath -and $sc.TargetPath -match '\.exe$' -and (Test-Path -LiteralPath $sc.TargetPath)) {
                            $mainExe = $sc.TargetPath
                            break
                        }
                    }
                } catch {}
            }

            $installDir = ""
            if ($ReportedDir -and (Test-Path -LiteralPath $ReportedDir)) {
                $installDir = $ReportedDir
            } elseif ($matchedEntry -and $matchedEntry.InstallLocation -and (Test-Path -LiteralPath $matchedEntry.InstallLocation)) {
                $installDir = $matchedEntry.InstallLocation
            } elseif ($mainExe) {
                $installDir = Split-Path -Parent $mainExe
            } elseif ($matchedEntry -and $matchedEntry.UninstallString) {
                $uExe = Resolve-ExeFromRawString -RawStr $matchedEntry.UninstallString
                if ($uExe) { $installDir = Split-Path -Parent $uExe }
            }

            if (-not $mainExe -and $installDir -and (Test-Path -LiteralPath $installDir)) {
                $exeCand = Get-ChildItem -LiteralPath $installDir -Filter "*.exe" -File -ErrorAction SilentlyContinue |
                    Where-Object { $_.Name -notmatch '^(unins|uninstall|setup|update|updater|crash|helper|elevat|report|vcredist)' } |
                    Sort-Object Length -Descending |
                    Select-Object -First 1
                if ($exeCand) { $mainExe = $exeCand.FullName }
            }

            $verified = $false
            if ($matchedEntry -or ($mainExe -and (Test-Path -LiteralPath $mainExe)) -or ($NewStartLnks -and $NewStartLnks.Count -gt 0)) {
                $verified = $true
            } elseif ($App.Category -eq "Sistem Bileşenleri (.NET / C++)" -or $App.DetectPattern -match 'NeverMatch') {
                $verified = $true
            }

            return [PSCustomObject]@{
                Verified    = $verified
                InstallDir  = $installDir
                MainExe     = $mainExe
                Version     = if ($matchedEntry) { $matchedEntry.DisplayVersion } else { "" }
                DisplayName = if ($matchedEntry) { $matchedEntry.DisplayName } else { $App.Name }
            }
        }

        function Ensure-DesktopShortcuts {
            param(
                $App,
                $InstallInfo,
                [string[]]$NewStartLnks,
                [string[]]$NewDesktopLnks
            )

            $result = New-Object System.Collections.Generic.List[string]

            # Saf sistem çalışma zamanları (GUI uygulaması olmayanlar) için kısayol gerekmez
            if ($App.Category -eq "Sistem Bileşenleri (.NET / C++)" -or $App.Id -match 'Install_Java_JRE|Install_Java_JDK') {
                $syncHash.LogQueue.Enqueue("   [MASAÜSTÜ KISAYOLU] Sistem çalışma zamanı bileşeni olduğu için masaüstü kısayolu gerekmez.")
                return $result
            }

            $publicDesktop = [Environment]::GetFolderPath('CommonDesktopDirectory')
            $userDesktop   = [Environment]::GetFolderPath('Desktop')
            $targetDesktop = $userDesktop
            if ($IsAdminSession -and $publicDesktop -and (Test-Path -LiteralPath $publicDesktop)) {
                $targetDesktop = $publicDesktop
            }

            $wsh = New-Object -ComObject WScript.Shell

            # Mevcut tüm masaüstü kısayollarının hedeflerini topla (çift kısayol önleme)
            $existingTargets = @{}
            $existingNames   = @{}
            foreach ($dd in @($publicDesktop, $userDesktop)) {
                if ($dd -and (Test-Path -LiteralPath $dd)) {
                    Get-ChildItem -LiteralPath $dd -Filter "*.lnk" -File -ErrorAction SilentlyContinue | ForEach-Object {
                        $existingNames[$_.BaseName.ToLowerInvariant()] = $_.FullName
                        try {
                            $sc = $wsh.CreateShortcut($_.FullName)
                            if ($sc.TargetPath) {
                                $existingTargets[$sc.TargetPath.ToLowerInvariant()] = $_.FullName
                            }
                        } catch {}
                    }
                }
            }

            function New-SafeDesktopShortcut {
                param([string]$ShortcutName, [string]$TargetExe, [string]$Arguments = "", [string]$IconLoc = "", [string]$Description = "")
                if ([string]::IsNullOrWhiteSpace($TargetExe) -or -not (Test-Path -LiteralPath $TargetExe)) { return $null }
                $keyTarget = $TargetExe.ToLowerInvariant()
                if ($existingTargets.ContainsKey($keyTarget)) {
                    return "MEVCUT:" + $existingTargets[$keyTarget]
                }
                $cleanName = ($ShortcutName -replace '[\\/:*?"<>|]', ' ').Trim()
                if ([string]::IsNullOrWhiteSpace($cleanName)) { $cleanName = [System.IO.Path]::GetFileNameWithoutExtension($TargetExe) }
                if ($existingNames.ContainsKey($cleanName.ToLowerInvariant())) {
                    return "MEVCUT:" + $existingNames[$cleanName.ToLowerInvariant()]
                }
                $lnkPath = Join-Path $targetDesktop ($cleanName + ".lnk")
                try {
                    $sc = $wsh.CreateShortcut($lnkPath)
                    $sc.TargetPath = $TargetExe
                    if ($Arguments) { $sc.Arguments = $Arguments }
                    $sc.WorkingDirectory = Split-Path -Parent $TargetExe
                    $sc.IconLocation = if ($IconLoc) { $IconLoc } else { "$TargetExe,0" }
                    $sc.Description = if ($Description) { $Description } else { $cleanName }
                    $sc.Save()
                    $existingTargets[$keyTarget] = $lnkPath
                    $existingNames[$cleanName.ToLowerInvariant()] = $lnkPath
                    return "OLUSTURULDU:" + $lnkPath
                } catch {
                    return $null
                }
            }

            # Kurulum sırasında zaten masaüstüne kısayol eklendiyse raporla
            if ($NewDesktopLnks -and $NewDesktopLnks.Count -gt 0) {
                foreach ($dl in $NewDesktopLnks) {
                    $result.Add($dl)
                    $syncHash.LogQueue.Enqueue("   [MASAÜSTÜ KISAYOLU] Kurulum sırasında oluşturuldu: $dl")
                }
            }

            # Özel durum: Microsoft Office (Word, Excel, PowerPoint, Outlook kısayolları)
            if ($App.Id -like "*Office365*") {
                $officeDirs = @(
                    (Join-Path $env:ProgramFiles "Microsoft Office\root\Office16"),
                    (Join-Path ${env:ProgramFiles(x86)} "Microsoft Office\root\Office16")
                )
                $officeApps = @(
                    @{ Name = "Word";       Exe = "WINWORD.EXE" },
                    @{ Name = "Excel";      Exe = "EXCEL.EXE" },
                    @{ Name = "PowerPoint"; Exe = "POWERPNT.EXE" },
                    @{ Name = "Outlook";    Exe = "OUTLOOK.EXE" }
                )
                foreach ($oa in $officeApps) {
                    foreach ($od in $officeDirs) {
                        $exePath = Join-Path $od $oa.Exe
                        if (Test-Path -LiteralPath $exePath) {
                            $res = New-SafeDesktopShortcut -ShortcutName $oa.Name -TargetExe $exePath -Description "Microsoft $($oa.Name)"
                            if ($res) {
                                if ($res.StartsWith("OLUSTURULDU:")) {
                                    $p = $res.Substring(12)
                                    $result.Add($p)
                                    $syncHash.LogQueue.Enqueue("   [MASAÜSTÜ KISAYOLU] Oluşturuldu: $p -> $exePath")
                                } elseif ($res.StartsWith("MEVCUT:")) {
                                    $p = $res.Substring(7)
                                    $result.Add($p)
                                    $syncHash.LogQueue.Enqueue("   [MASAÜSTÜ KISAYOLU] Zaten mevcut: $p")
                                }
                            }
                            break
                        }
                    }
                }
                return $result
            }

            # Eğer kurulum sırasında yeni kısayol oluşmadıysa 4 katmanlı keşif ile mutlaka oluştur
            if ($result.Count -eq 0) {
                # Katman 1: Kurulum sırasında Başlat Menüsüne eklenen yeni ana kısayollar
                if ($NewStartLnks -and $NewStartLnks.Count -gt 0) {
                    $goodLnks = @($NewStartLnks | Where-Object {
                        $bn = [System.IO.Path]::GetFileNameWithoutExtension($_)
                        $bn -notmatch 'Uninstall|Kaldır|Help|Yardım|Readme|Update|Güncelle|Website|Web Sitesi|Manual|Kılavuz|License|Release Notes|Troubleshooting|Console|Command Prompt'
                    })
                    foreach ($sl in ($goodLnks | Select-Object -First 3)) {
                        try {
                            $srcSc = $wsh.CreateShortcut($sl)
                            if ($srcSc.TargetPath -and $srcSc.TargetPath -match '\.exe$' -and (Test-Path -LiteralPath $srcSc.TargetPath)) {
                                $bn = [System.IO.Path]::GetFileNameWithoutExtension($sl)
                                $res = New-SafeDesktopShortcut -ShortcutName $bn -TargetExe $srcSc.TargetPath -Arguments $srcSc.Arguments -IconLoc $srcSc.IconLocation -Description $App.Name
                                if ($res) {
                                    if ($res.StartsWith("OLUSTURULDU:")) {
                                        $p = $res.Substring(12)
                                        $result.Add($p)
                                        $syncHash.LogQueue.Enqueue("   [MASAÜSTÜ KISAYOLU] Oluşturuldu: $p -> $($srcSc.TargetPath)")
                                    } elseif ($res.StartsWith("MEVCUT:")) {
                                        $p = $res.Substring(7)
                                        $result.Add($p)
                                        $syncHash.LogQueue.Enqueue("   [MASAÜSTÜ KISAYOLU] Zaten mevcut: $p")
                                    }
                                }
                            }
                        } catch {}
                    }
                }

                # Katman 2: Doğrudan algılanan / bilinen ana çalıştırılabilir (.exe)
                if ($result.Count -eq 0 -and $InstallInfo.MainExe -and (Test-Path -LiteralPath $InstallInfo.MainExe)) {
                    $cleanShortcutName = ($App.Name -replace '\s*\([^)]*\)', '').Trim()
                    if ([string]::IsNullOrWhiteSpace($cleanShortcutName)) { $cleanShortcutName = $App.Name }
                    $res = New-SafeDesktopShortcut -ShortcutName $cleanShortcutName -TargetExe $InstallInfo.MainExe -Description $App.Name
                    if ($res) {
                        if ($res.StartsWith("OLUSTURULDU:")) {
                            $p = $res.Substring(12)
                            $result.Add($p)
                            $syncHash.LogQueue.Enqueue("   [MASAÜSTÜ KISAYOLU] Oluşturuldu: $p -> $($InstallInfo.MainExe)")
                        } elseif ($res.StartsWith("MEVCUT:")) {
                            $p = $res.Substring(7)
                            $result.Add($p)
                            $syncHash.LogQueue.Enqueue("   [MASAÜSTÜ KISAYOLU] Zaten mevcut: $p")
                        }
                    }
                }

                # Katman 3: Mevcut Başlat Menüsünde program adıyla eşleşen kısayol ara
                if ($result.Count -eq 0) {
                    $smDirs = @(
                        [Environment]::GetFolderPath('CommonPrograms'),
                        [Environment]::GetFolderPath('Programs')
                    )
                    $baseKeyword = ($App.Name -replace '\s*\([^)]*\)', '').Trim()
                    foreach ($sd in $smDirs) {
                        if (-not $sd -or -not (Test-Path -LiteralPath $sd)) { continue }
                        $foundLnk = Get-ChildItem -LiteralPath $sd -Filter "*.lnk" -Recurse -File -ErrorAction SilentlyContinue |
                            Where-Object {
                                ($_.BaseName -like "*$baseKeyword*" -or ($App.DetectPattern -and $_.BaseName -match $App.DetectPattern)) -and
                                $_.BaseName -notmatch 'Uninstall|Kaldır|Help|Readme|Update|Website|Manual'
                            } | Select-Object -First 1
                        if ($foundLnk) {
                            try {
                                $srcSc = $wsh.CreateShortcut($foundLnk.FullName)
                                if ($srcSc.TargetPath -and (Test-Path -LiteralPath $srcSc.TargetPath)) {
                                    $res = New-SafeDesktopShortcut -ShortcutName $foundLnk.BaseName -TargetExe $srcSc.TargetPath -Arguments $srcSc.Arguments -IconLoc $srcSc.IconLocation -Description $App.Name
                                    if ($res) {
                                        if ($res.StartsWith("OLUSTURULDU:")) {
                                            $p = $res.Substring(12)
                                            $result.Add($p)
                                            $syncHash.LogQueue.Enqueue("   [MASAÜSTÜ KISAYOLU] Oluşturuldu: $p -> $($srcSc.TargetPath)")
                                        } elseif ($res.StartsWith("MEVCUT:")) {
                                            $p = $res.Substring(7)
                                            $result.Add($p)
                                            $syncHash.LogQueue.Enqueue("   [MASAÜSTÜ KISAYOLU] Zaten mevcut: $p")
                                        }
                                        break
                                    }
                                }
                            } catch {}
                        }
                    }
                }
            }

            if ($result.Count -eq 0) {
                $syncHash.LogQueue.Enqueue("   [MASAÜSTÜ KISAYOLU] Uygun çalıştırılabilir dosya bulunamadı (uygulama arka plan aracı olabilir).")
            }

            return $result
        }

        function New-InstrumentedRunnerScript {
            param([string]$OriginalScriptPath)
            $rawContent = [System.IO.File]::ReadAllText($OriginalScriptPath, [System.Text.Encoding]::UTF8)

            # Eğer betik zaten yerel @@DL_PROGRESS@@ protokolünü destekliyorsa doğrudan çalıştır
            if ($rawContent -match '@@DL_PROGRESS@@') {
                return [PSCustomObject]@{ Path = $OriginalScriptPath; IsTemp = $false }
            }

            $origDir = (Split-Path -Parent $OriginalScriptPath).Replace("'", "''")

            $preamble = @"
`$ProgressPreference = 'SilentlyContinue'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor 3072 } catch { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 }
`$__HKM_OrigScriptDir = '$origDir'

function Invoke-HKMTrackedDownload {
    param(
        [string]`$Url,
        [string]`$OutFile,
        [object]`$ExistingWebClient = `$null
    )
    if ([string]::IsNullOrWhiteSpace(`$Url)) { throw "İndirme adresi (URL) alınamadı." }
    if ([string]::IsNullOrWhiteSpace(`$OutFile)) { throw "Hedef dosya yolu belirtilmedi." }

    Write-Output "@@STAGE@@DOWNLOAD|Kurulum paketi indiriliyor..."
    Write-Output "@@URL@@`$Url"
    Write-Output "@@TEMPFILE@@`$OutFile"

    `$response = `$null
    `$respStream = `$null
    `$fileStream = `$null
    try {
        `$req = [System.Net.HttpWebRequest]::Create(`$Url)
        `$req.Method = "GET"
        `$req.AllowAutoRedirect = `$true
        `$req.Timeout = 60000
        `$req.ReadWriteTimeout = 120000
        `$req.UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
        if (`$ExistingWebClient -and `$ExistingWebClient.Headers) {
            foreach (`$hk in `$ExistingWebClient.Headers.AllKeys) {
                if (`$hk -ieq 'User-Agent') { `$req.UserAgent = `$ExistingWebClient.Headers[`$hk] }
                elseif (`$hk -ieq 'Referer') { `$req.Referer = `$ExistingWebClient.Headers[`$hk] }
                elseif (`$hk -ieq 'Accept') { `$req.Accept = `$ExistingWebClient.Headers[`$hk] }
            }
        }

        `$response = `$req.GetResponse()
        `$totalBytes = [long]`$response.ContentLength
        `$respStream = `$response.GetResponseStream()
        `$parentDir = Split-Path -Parent `$OutFile
        if (`$parentDir -and -not (Test-Path -LiteralPath `$parentDir)) {
            New-Item -ItemType Directory -Path `$parentDir -Force | Out-Null
        }
        `$fileStream = New-Object System.IO.FileStream(`$OutFile, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)

        `$buffer = New-Object byte[] 131072
        `$totalRead = [long]0
        `$lastPct = -1
        `$sw = [System.Diagnostics.Stopwatch]::StartNew()
        `$lastTick = [long]0

        while ((`$read = `$respStream.Read(`$buffer, 0, `$buffer.Length)) -gt 0) {
            `$fileStream.Write(`$buffer, 0, `$read)
            `$totalRead += `$read
            `$ms = `$sw.ElapsedMilliseconds
            if (`$totalBytes -gt 0) {
                `$pct = [int][Math]::Floor((`$totalRead * 100.0) / `$totalBytes)
                if (`$pct -gt 100) { `$pct = 100 }
                if ((`$pct -ne `$lastPct -and (`$pct -ge (`$lastPct + 2) -or `$pct -eq 100)) -or (`$ms - `$lastTick) -ge 700) {
                    `$lastPct = `$pct
                    `$lastTick = `$ms
                    `$dlMB = [Math]::Round(`$totalRead / 1MB, 1)
                    `$totMB = [Math]::Round(`$totalBytes / 1MB, 1)
                    `$sec = [Math]::Max(0.1, `$sw.Elapsed.TotalSeconds)
                    `$spd = [Math]::Round((`$totalRead / 1MB) / `$sec, 1)
                    Write-Output ("@@DL_PROGRESS@@{0}|{1}|{2}|{3}" -f `$pct, `$dlMB.ToString([System.Globalization.CultureInfo]::InvariantCulture), `$totMB.ToString([System.Globalization.CultureInfo]::InvariantCulture), `$spd.ToString([System.Globalization.CultureInfo]::InvariantCulture))
                }
            } elseif ((`$ms - `$lastTick) -ge 800) {
                `$lastTick = `$ms
                `$dlMB = [Math]::Round(`$totalRead / 1MB, 1)
                `$sec = [Math]::Max(0.1, `$sw.Elapsed.TotalSeconds)
                `$spd = [Math]::Round((`$totalRead / 1MB) / `$sec, 1)
                Write-Output ("@@DL_PROGRESS@@-1|{0}|0|{1}" -f `$dlMB.ToString([System.Globalization.CultureInfo]::InvariantCulture), `$spd.ToString([System.Globalization.CultureInfo]::InvariantCulture))
            }
        }

        `$fileStream.Flush()
        `$fileStream.Close(); `$fileStream = `$null
        `$respStream.Close(); `$respStream = `$null
        `$response.Close(); `$response = `$null

        `$finalMB = [Math]::Round((Get-Item -LiteralPath `$OutFile).Length / 1MB, 1)
        Write-Output ("@@DL_PROGRESS@@100|{0}|{0}|0" -f `$finalMB.ToString([System.Globalization.CultureInfo]::InvariantCulture))
        Write-Output ("@@DL_DONE@@{0}|{1}" -f `$OutFile, `$finalMB.ToString([System.Globalization.CultureInfo]::InvariantCulture))
    } catch {
        if (`$fileStream) { try { `$fileStream.Close() } catch {} }
        if (`$respStream) { try { `$respStream.Close() } catch {} }
        if (`$response)   { try { `$response.Close() } catch {} }
        Write-Output "@@LOG@@İndirme hatası: `$(`$_.Exception.Message)"
        exit 1
    }
}

"@

            $transformed = $rawContent
            # $PSScriptRoot referanslarını orijinal klasöre bağla (yerel MSI/EXE betikleri için)
            $transformed = $transformed -replace '\$PSScriptRoot\b', '$__HKM_OrigScriptDir'
            # (New-Object System.Net.WebClient).DownloadFile(url, out)
            $transformed = [regex]::Replace($transformed, '\(New-Object\s+System\.Net\.WebClient\)\.DownloadFile\(([^,\r\n]+),\s*([^)\r\n]+)\)', 'Invoke-HKMTrackedDownload -Url ($1) -OutFile ($2)')
            # $wc.DownloadFile(url, out)
            $transformed = [regex]::Replace($transformed, '(\$\w+)\.DownloadFile\(([^,\r\n]+),\s*([^)\r\n]+)\)', 'Invoke-HKMTrackedDownload -Url ($2) -OutFile ($3) -ExistingWebClient $1')
            # Invoke-WebRequest ... -Uri $dlLink -OutFile $InstallerPath ...
            $transformed = [regex]::Replace($transformed, 'Invoke-WebRequest[^\r\n]*-Uri\s+(\S+)[^\r\n]*-OutFile\s+(\S+)[^\r\n]*', 'Invoke-HKMTrackedDownload -Url ($1) -OutFile ($2)')
            # Start-Process öncesi kurulum aşaması sinyali ekle
            $transformed = [regex]::Replace($transformed, '(?m)^([ \t]*)(Start-Process\b)', '$1Write-Output "@@STAGE@@INSTALL|Sessiz kurulum çalıştırılıyor..."' + "`r`n" + '$1$2')

            $tempScript = Join-Path $env:TEMP ("HKM_Run_" + [Guid]::NewGuid().ToString("N") + ".ps1")
            [System.IO.File]::WriteAllText($tempScript, ($preamble + $transformed), (New-Object System.Text.UTF8Encoding($true)))
            return [PSCustomObject]@{ Path = $tempScript; IsTemp = $true }
        }

        function Invoke-TrackedProcess {
            param(
                [string]$FilePath,
                [string]$Arguments,
                [string]$AppId,
                [string]$AppName,
                [int]$AppIndex,
                [bool]$IsWinget = $false
            )

            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName               = $FilePath
            $psi.Arguments              = $Arguments
            $psi.UseShellExecute        = $false
            $psi.CreateNoWindow         = $true
            $psi.RedirectStandardOutput = $true
            $psi.RedirectStandardError  = $true
            $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
            $psi.StandardErrorEncoding  = [System.Text.Encoding]::UTF8

            $proc = New-Object System.Diagnostics.Process
            $proc.StartInfo = $psi
            [void]$proc.Start()

            $reportedDir = ""
            $reportedExe = ""
            $stderrLines = New-Object System.Collections.Generic.List[string]
            $lastLoggedMilestone = -1
            $lastLoggedUnknownMB = 0

            $outTask = $proc.StandardOutput.ReadLineAsync()
            $errTask = $proc.StandardError.ReadLineAsync()
            $outDone = $false
            $errDone = $false

            while (-not ($outDone -and $errDone)) {
                $didWork = $false

                if (-not $outDone -and $outTask.IsCompleted) {
                    $didWork = $true
                    $line = $outTask.Result
                    if ($null -eq $line) {
                        $outDone = $true
                    } else {
                        $outTask = $proc.StandardOutput.ReadLineAsync()
                        $trimLine = $line.Trim()
                        if (-not [string]::IsNullOrEmpty($trimLine)) {
                            if ($trimLine.StartsWith("@@URL@@")) {
                                $syncHash.LogQueue.Enqueue("   [KAYNAK] İndirme adresi: $($trimLine.Substring(7))")
                            } elseif ($trimLine.StartsWith("@@TEMPFILE@@")) {
                                $syncHash.LogQueue.Enqueue("   [GEÇİCİ DOSYA] İndirme klasörü/dosyası: $($trimLine.Substring(12))")
                            } elseif ($trimLine.StartsWith("@@DL_PROGRESS@@")) {
                                $parts = $trimLine.Substring(15) -split '\|'
                                if ($parts.Length -ge 4) {
                                    $pct = [int]$parts[0]
                                    $dlMB = $parts[1]
                                    $totMB = $parts[2]
                                    $spd = $parts[3]
                                    if ($pct -ge 0) {
                                        $detailStr = if ([double]::Parse($spd, [System.Globalization.CultureInfo]::InvariantCulture) -gt 0) {
                                            "İndiriliyor: %$pct ($dlMB / $totMB MB • $spd MB/sn)"
                                        } else {
                                            "İndiriliyor: %$pct ($dlMB / $totMB MB)"
                                        }
                                        Send-AppState -AppId $AppId -State "Downloading" -Detail $detailStr -Badge "İNDİRİLİYOR %$pct" -Percent $pct
                                        $syncHash.CurrentStep = "Adım $AppIndex/$($syncHash.Total): $AppName indiriliyor (%$pct)"
                                        Update-OverallProgress -AppIndex $AppIndex -StepPct ([int]($pct * 0.55))

                                        # Canlı işlem günlüğüne %1'de hemen ve ardından her %5'te bir (%5, %10, ..., %100) adım adım yaz
                                        $milestone = if ($pct -ge 1 -and $pct -lt 5) { 1 } else { [int]([Math]::Floor($pct / 5.0) * 5) }
                                        if ($milestone -gt $lastLoggedMilestone -and $milestone -gt 0) {
                                            $lastLoggedMilestone = $milestone
                                            $spdTxt = if ([double]::Parse($spd, [System.Globalization.CultureInfo]::InvariantCulture) -gt 0) { " ($spd MB/sn)" } else { "" }
                                            $syncHash.LogQueue.Enqueue("   [İNDİRME %$pct] $dlMB MB / $totMB MB$spdTxt")
                                        }
                                    } else {
                                        $detailStr = "İndiriliyor: $dlMB MB ($spd MB/sn)"
                                        Send-AppState -AppId $AppId -State "Downloading" -Detail $detailStr -Badge "$dlMB MB" -Percent -1
                                        $dlNum = [double]::Parse($dlMB, [System.Globalization.CultureInfo]::InvariantCulture)
                                        if ($dlNum -ge ($lastLoggedUnknownMB + 10)) {
                                            $lastLoggedUnknownMB = [int]$dlNum
                                            $syncHash.LogQueue.Enqueue("   [İNDİRME] $dlMB MB indirildi ($spd MB/sn)...")
                                        }
                                    }
                                }
                            } elseif ($trimLine.StartsWith("@@DL_DONE@@")) {
                                $parts = $trimLine.Substring(11) -split '\|'
                                if ($parts.Length -ge 2) {
                                    $syncHash.LogQueue.Enqueue("   [İNDİRME TAMAMLANDI] %100 ($($parts[1]) MB) -> $($parts[0])")
                                }
                            } elseif ($trimLine.StartsWith("@@STAGE@@")) {
                                $payload = $trimLine.Substring(9)
                                $sp = $payload -split '\|', 3
                                $st = $sp[0]
                                $msg = if ($sp.Length -gt 1) { $sp[1] } else { "" }
                                $stagePct = -1
                                if ($sp.Length -gt 2 -and $sp[2] -match '^\d+$') {
                                    $stagePct = [int]$sp[2]
                                }
                                if ($st -eq "EXTRACT") {
                                    Send-AppState -AppId $AppId -State "Extracting" -Detail $msg -Badge "ARŞİV AÇILIYOR" -Percent -1
                                    $syncHash.CurrentStep = "Adım $AppIndex/$($syncHash.Total): $AppName arşivi açılıyor..."
                                    Update-OverallProgress -AppIndex $AppIndex -StepPct 60
                                    $syncHash.LogQueue.Enqueue("   [ARŞİV] $msg")
                                } elseif ($st -eq "INSTALL") {
                                    if ($stagePct -ge 0) {
                                        Send-AppState -AppId $AppId -State "Installing" -Detail $msg -Badge "KURULUYOR %$stagePct" -Percent $stagePct
                                        $syncHash.CurrentStep = "Adım $AppIndex/$($syncHash.Total): $AppName kuruluyor (%$stagePct)"
                                        Update-OverallProgress -AppIndex $AppIndex -StepPct ([int](62 + ($stagePct * 0.34)))
                                    } else {
                                        Send-AppState -AppId $AppId -State "Installing" -Detail $msg -Badge "KURULUYOR..." -Percent -1
                                        $syncHash.CurrentStep = "Adım $AppIndex/$($syncHash.Total): $AppName sessiz kuruluyor..."
                                        Update-OverallProgress -AppIndex $AppIndex -StepPct 72
                                    }
                                    $syncHash.LogQueue.Enqueue("   [KURULUM] $msg")
                                } elseif ($st -eq "DOWNLOAD") {
                                    Send-AppState -AppId $AppId -State "Downloading" -Detail $msg -Badge "İNDİRİLİYOR %0" -Percent 0
                                }
                            } elseif ($trimLine.StartsWith("@@INSTALL_DIR@@")) {
                                $reportedDir = $trimLine.Substring(15).Trim()
                            } elseif ($trimLine.StartsWith("@@APP_EXE@@")) {
                                $reportedExe = $trimLine.Substring(11).Trim()
                            } elseif ($trimLine.StartsWith("@@LOG@@")) {
                                $syncHash.LogQueue.Enqueue("   [BİLGİ] $($trimLine.Substring(7))")
                            } elseif ($IsWinget) {
                                # Winget canlı yüzdelik ve durum satırlarını yakala
                                if ($trimLine -match '(\d{1,3})%') {
                                    $wpct = [int]$Matches[1]
                                    if ($wpct -ge 0 -and $wpct -le 100) {
                                        Send-AppState -AppId $AppId -State "Fallback" -Detail "Winget indiriyor/kuruyor: %$wpct" -Badge "WINGET %$wpct" -Percent $wpct
                                        Update-OverallProgress -AppIndex $AppIndex -StepPct ([int](50 + ($wpct * 0.4)))
                                        $wMile = [int]([Math]::Floor($wpct / 20.0) * 20)
                                        if ($wMile -gt $lastLoggedMilestone -and $wMile -gt 0) {
                                            $lastLoggedMilestone = $wMile
                                            $syncHash.LogQueue.Enqueue("   [WINGET %$wpct] İndirme/kurulum ilerliyor...")
                                        }
                                    }
                                } elseif ($trimLine -match 'Successfully installed|Başarıyla yüklendi|Installer hash does not match|Found |Starting package install|Downloading ') {
                                    $syncHash.LogQueue.Enqueue("   [WINGET] $trimLine")
                                }
                            }
                        }
                    }
                }

                if (-not $errDone -and $errTask.IsCompleted) {
                    $didWork = $true
                    $eLine = $errTask.Result
                    if ($null -eq $eLine) {
                        $errDone = $true
                    } else {
                        $errTask = $proc.StandardError.ReadLineAsync()
                        $et = $eLine.Trim()
                        if (-not [string]::IsNullOrEmpty($et)) {
                            $stderrLines.Add($et)
                        }
                    }
                }

                if (-not $didWork) {
                    Start-Sleep -Milliseconds 60
                }
            }

            $proc.WaitForExit()
            $code = $proc.ExitCode
            $proc.Dispose()

            return [PSCustomObject]@{
                ExitCode    = $code
                ReportedDir = $reportedDir
                ReportedExe = $reportedExe
                StderrLines = $stderrLines
            }
        }

        function Invoke-WingetSilent {
            param([string]$PackageId, [string]$AppId, [string]$AppName, [int]$AppIndex)
            if (-not $hasWinget -or [string]::IsNullOrWhiteSpace($PackageId)) { return $false }
            $wingetArgs = "install --id `"$PackageId`" --exact --silent --accept-package-agreements --accept-source-agreements --disable-interactivity"
            $res = Invoke-TrackedProcess -FilePath "winget.exe" -Arguments $wingetArgs -AppId $AppId -AppName $AppName -AppIndex $AppIndex -IsWinget $true
            $syncHash.LogQueue.Enqueue("   [WINGET ÇIKIŞ KODU] $($res.ExitCode)")
            return ($res.ExitCode -eq 0 -or $res.ExitCode -eq -1978335189)
        }

        $startMenuDirs = @(
            [Environment]::GetFolderPath('CommonPrograms'),
            [Environment]::GetFolderPath('Programs')
        )
        $desktopDirs = @(
            [Environment]::GetFolderPath('CommonDesktopDirectory'),
            [Environment]::GetFolderPath('Desktop')
        )

        $index = 0
        foreach ($app in $appsPayload) {
            $index++
            $sw = [System.Diagnostics.Stopwatch]::StartNew()

            $syncHash.CurrentStep = "Adım $index / $($syncHash.Total): $($app.Name) işleniyor..."
            $syncHash.SummaryLine = "Şu an kurulan ($index/$($syncHash.Total)): $($app.Name)"
            Update-OverallProgress -AppIndex $index -StepPct 2
            $syncHash.LogQueue.Enqueue("------------------------------------------------------------------")
            $syncHash.LogQueue.Enqueue("[ADIM $index/$($syncHash.Total)] $($app.Name) süreci başlatıldı.")

            # Kurulum öncesi sistem anlık görüntüsü (Kayıt Defteri + Başlat Menüsü + Masaüstü)
            $beforeReg     = Get-UninstallSnapshot
            $beforeSmLnks  = Get-LnkMap -Dirs $startMenuDirs
            $beforeDtLnks  = Get-LnkMap -Dirs $desktopDirs

            $installed   = $false
            $reportedDir = ""
            $reportedExe = ""
            $lastExitCode = -1
            $tempWrapper  = $null

            try {
                if ($app.IsLocal) {
                    Send-AppState -AppId $app.Id -State "Installing" -Detail "Yerel kurulum paketi sessiz kuruluyor..." -Badge "KURULUYOR..." -Percent -1
                    $syncHash.LogQueue.Enqueue("   [KAYNAK] Yerel kurulum paketi: $($app.ScriptPath)")
                } else {
                    Send-AppState -AppId $app.Id -State "Downloading" -Detail "İndirme bağlantısı hazırlanıyor (%0)..." -Badge "İNDİRİLİYOR %0" -Percent 0
                    $syncHash.LogQueue.Enqueue("   [1/2] Resmi sunucudan güncel kurulum paketi sorgulanıyor ve indiriliyor...")
                }

                $isOfficeApp = ($app.Id -like "*Office365*")

                if ($isOfficeApp) {
                    $officeExe = Join-Path $ScriptRoot "office_setup.exe"
                    $officeXml = Join-Path $ScriptRoot "configuration.xml"
                    $officeTargetDir = Join-Path $env:ProgramFiles "Microsoft Office"
                    Send-AppState -AppId $app.Id -State "Installing" -Detail "Microsoft Office 2021 kuruluyor (office_setup.exe)..." -Badge "KURULUYOR..." -Percent -1
                    $syncHash.LogQueue.Enqueue("   [KAYNAK] Yerel dosya: $officeExe + $officeXml")
                    $syncHash.LogQueue.Enqueue("   [HEDEF KLASÖR] $officeTargetDir")
                    $proc = Start-Process -FilePath $officeExe -ArgumentList "/configure `"$officeXml`"" -PassThru -WindowStyle Hidden
                    $lastOfficeNoticeSec = 0
                    while (-not $proc.HasExited) {
                        Start-Sleep -Milliseconds 500
                        $elapsedNow = [int]$sw.Elapsed.TotalSeconds
                        if ($elapsedNow -ge ($lastOfficeNoticeSec + 15)) {
                            $lastOfficeNoticeSec = $elapsedNow
                            $approxPct = [Math]::Min(92, [int](($elapsedNow / 240.0) * 100))
                            Send-AppState -AppId $app.Id -State "Installing" -Detail "Microsoft Office 2021 kuruluyor (~%$approxPct • $elapsedNow sn geçti)..." -Badge "KURULUYOR ~%$approxPct" -Percent $approxPct
                            Update-OverallProgress -AppIndex $index -StepPct $approxPct
                            $syncHash.LogQueue.Enqueue("   [OFFICE %$approxPct] Kurulum devam ediyor ($elapsedNow sn)...")
                        }
                    }
                    $proc.WaitForExit()
                    $lastExitCode = $proc.ExitCode
                    $syncHash.LogQueue.Enqueue("   [ÇIKIŞ KODU] office_setup.exe: $lastExitCode")
                    $installed = ($lastExitCode -eq 0 -or $lastExitCode -eq 3010)
                    if (Test-Path -LiteralPath (Join-Path $officeTargetDir "root\Office16")) {
                        $reportedDir = Join-Path $officeTargetDir "root\Office16"
                    }
                }
                elseif (Test-Path -LiteralPath $app.ScriptPath) {
                    $runner = New-InstrumentedRunnerScript -OriginalScriptPath $app.ScriptPath
                    if ($runner.IsTemp) { $tempWrapper = $runner.Path }

                    $psArgs = "-NoProfile -ExecutionPolicy Bypass -File `"$($runner.Path)`""
                    $procRes = Invoke-TrackedProcess -FilePath "powershell.exe" -Arguments $psArgs -AppId $app.Id -AppName $app.Name -AppIndex $index
                    $lastExitCode = $procRes.ExitCode
                    if ($procRes.ReportedDir) { $reportedDir = $procRes.ReportedDir }
                    if ($procRes.ReportedExe) { $reportedExe = $procRes.ReportedExe }
                    $syncHash.LogQueue.Enqueue("   [ÇIKIŞ KODU] Kurulum betiği çıkış kodu: $lastExitCode")

                    $installed = ($lastExitCode -eq 0 -or $lastExitCode -eq 3010)
                    if (-not $installed -and $procRes.StderrLines.Count -gt 0) {
                        $errPreview = ($procRes.StderrLines | Select-Object -First 2) -join " | "
                        $syncHash.LogQueue.Enqueue("   [HATA DETAYI] $errPreview")
                    }
                }

                # Kurulum sonrası gerçek doğrulama anlık görüntüsü
                $afterReg    = Get-UninstallSnapshot
                $afterSmLnks = Get-LnkMap -Dirs $startMenuDirs
                $afterDtLnks = Get-LnkMap -Dirs $desktopDirs
                $newSmLnks   = @($afterSmLnks.Keys | Where-Object { -not $beforeSmLnks.ContainsKey($_) } | ForEach-Object { $afterSmLnks[$_] })
                $newDtLnks   = @($afterDtLnks.Keys | Where-Object { -not $beforeDtLnks.ContainsKey($_) } | ForEach-Object { $afterDtLnks[$_] })

                $installInfo = Resolve-InstalledAppInfo -App $app -BeforeReg $beforeReg -AfterReg $afterReg -ReportedDir $reportedDir -ReportedExe $reportedExe -NewStartLnks $newSmLnks

                # Eğer betik çıkış kodu 0 döndüyse ama program gerçekte kurulmadıysa (örn. sessiz hata), sahte "Kuruldu" demeyi engelle!
                if ($installed -and -not $installInfo.Verified -and -not $app.WasInstalled -and -not $isOfficeApp) {
                    $syncHash.LogQueue.Enqueue("   [DOĞRULAMA UYARISI] Betik hata vermeden kapandı ancak program sistemde doğrulanamadı!")
                    $installed = $false
                }

                # Yedek Winget kurulumu
                if (-not $installed -and -not $isOfficeApp -and $hasWinget -and $app.WingetId) {
                    Send-AppState -AppId $app.Id -State "Fallback" -Detail "Alternatif: Winget ile sessiz kuruluyor ($($app.WingetId))..." -Badge "WINGET..." -Percent -1
                    $syncHash.LogQueue.Enqueue("   [YEDEK ADIM] Yerel betik tamamlanamadı, Winget üzerinden kuruluyor ($($app.WingetId))...")
                    $wingetOk = Invoke-WingetSilent -PackageId $app.WingetId -AppId $app.Id -AppName $app.Name -AppIndex $index

                    $afterReg    = Get-UninstallSnapshot
                    $afterSmLnks = Get-LnkMap -Dirs $startMenuDirs
                    $afterDtLnks = Get-LnkMap -Dirs $desktopDirs
                    $newSmLnks   = @($afterSmLnks.Keys | Where-Object { -not $beforeSmLnks.ContainsKey($_) } | ForEach-Object { $afterSmLnks[$_] })
                    $newDtLnks   = @($afterDtLnks.Keys | Where-Object { -not $beforeDtLnks.ContainsKey($_) } | ForEach-Object { $afterDtLnks[$_] })
                    $installInfo = Resolve-InstalledAppInfo -App $app -BeforeReg $beforeReg -AfterReg $afterReg -ReportedDir $reportedDir -ReportedExe $reportedExe -NewStartLnks $newSmLnks

                    $installed = $wingetOk -or $installInfo.Verified
                }
            } catch {
                $syncHash.LogQueue.Enqueue("   [HATA] $($_.Exception.Message)")
                $installed = $false
            } finally {
                if ($tempWrapper -and (Test-Path -LiteralPath $tempWrapper)) {
                    Remove-Item -LiteralPath $tempWrapper -Force -ErrorAction SilentlyContinue
                }
            }

            $sw.Stop()
            $elapsedSec = [Math]::Max(1, [int]$sw.Elapsed.TotalSeconds)

            if ($installed) {
                # Kurulum klasörü, sürüm, ana dosya ve masaüstü kısayolu bilgilerini canlı günlüğe yaz
                if ($installInfo.InstallDir) {
                    $syncHash.LogQueue.Enqueue("   [KURULUM KLASÖRÜ] $($installInfo.InstallDir)")
                } else {
                    $syncHash.LogQueue.Enqueue("   [KURULUM KLASÖRÜ] Sistem varsayılan dizini (Windows / Program Files)")
                }
                if ($installInfo.MainExe) {
                    $syncHash.LogQueue.Enqueue("   [ANA UYGULAMA] $($installInfo.MainExe)")
                }
                if ($installInfo.Version) {
                    $syncHash.LogQueue.Enqueue("   [SÜRÜM] $($installInfo.Version)")
                }

                # Kurulan her program için Masaüstü Kısayolu oluştur / doğrula
                $createdShortcuts = Ensure-DesktopShortcuts -App $app -InstallInfo $installInfo -NewStartLnks $newSmLnks -NewDesktopLnks $newDtLnks

                $syncHash.SuccessCount++
                $folderNote = if ($installInfo.InstallDir) { " • $($installInfo.InstallDir)" } else { "" }
                Send-AppState -AppId $app.Id -State "Success" -Detail "Kuruldu ($elapsedSec sn)$folderNote" -Badge "KURULDU" -Percent 100
                $syncHash.LogQueue.Enqueue("   [KURULDU] $($app.Name) kurulumu $elapsedSec saniyede başarıyla tamamlandı.")
            } else {
                $syncHash.FailCount++
                Send-AppState -AppId $app.Id -State "Failed" -Detail "Hata: Kurulum doğrulanamadı veya başarısız oldu ($elapsedSec sn)" -Badge "BAŞARISIZ" -Percent -1
                $syncHash.LogQueue.Enqueue("   [BAŞARISIZ] $($app.Name) kurulumu tamamlanamadı veya sistemde doğrulanamadı (Çıkış Kodu: $lastExitCode).")
            }

            $syncHash.Completed = $index
            Update-OverallProgress -AppIndex $index -StepPct 100
        }

        $syncHash.CurrentStep = "Tüm Süreç Tamamlandı ($($syncHash.SuccessCount) Kuruldu, $($syncHash.FailCount) Hatalı)"
        $syncHash.SummaryLine = "Kurulum tamamlandı: $($syncHash.SuccessCount) program başarıyla kuruldu, $($syncHash.FailCount) hata."
        $syncHash.LogQueue.Enqueue("==================================================================")
        $syncHash.LogQueue.Enqueue("TÜM KURULUMLAR BİTTİ: $($syncHash.SuccessCount) Başarılı (Kuruldu), $($syncHash.FailCount) Başarısız.")
        $syncHash.LogQueue.Enqueue("==================================================================")
        $syncHash.IsFinished = $true
    })

    $psCmd.Runspace = $runspace
    $asyncHandle = $psCmd.BeginInvoke()

    $timer = New-Object Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromMilliseconds(150)
    $timer.Tag = @{
        SyncHash    = $syncHash
        PSCmd       = $psCmd
        Runspace    = $runspace
        AsyncHandle = $asyncHandle
    }

    $timer.Add_Tick({
        param($sender, $e)
        $ctx = $sender.Tag
        $sh  = $ctx.SyncHash

        $stateUpdate = $null
        while ($sh.StateQueue.TryDequeue([ref]$stateUpdate)) {
            Set-AppInstallState -AppId $stateUpdate.AppId -State $stateUpdate.State -DetailText $stateUpdate.Detail -BadgeOverride $stateUpdate.Badge -Percent $stateUpdate.Percent
        }

        $msg = $null
        while ($sh.LogQueue.TryDequeue([ref]$msg)) {
            Write-GuiLog $msg
        }

        $ProgressStepText.Text    = $sh.CurrentStep
        $SelectedSummaryText.Text = $sh.SummaryLine
        $InstallProgressBar.Value = $sh.ProgressValue
        $ProgressPercentText.Text = "%$($sh.OverallPercent)"
        $StepCounterBadge.Text    = "$($sh.Completed) / $($sh.Total) Tamamlandı"

        if ($sh.IsFinished) {
            $sender.Stop()
            try {
                $ctx.PSCmd.EndInvoke($ctx.AsyncHandle) | Out-Null
                $ctx.PSCmd.Dispose()
                $ctx.Runspace.Close()
                $ctx.Runspace.Dispose()
            } catch {}

            $script:IsInstalling           = $false
            $MetricStateText.Text          = "Kurulum Tamamlandı"
            $BtnStartInstall.IsEnabled     = $true
            $BtnSelectCategory.IsEnabled   = $true
            $BtnClearAll.IsEnabled         = $true
            $BtnRescanInstalled.IsEnabled  = $true
            $PackagesTopBarPanel.IsEnabled = $true
            $PackagesTopBarPanel.Opacity   = 1.0
            $selCnt = @($AllApps | Where-Object { $_.IsSelected }).Count
            $BtnStartInstall.Content       = "Seçilenleri Onaysız Kur ($selCnt)"
            Scan-InstalledApplications -SilentLog
            Update-ResponsiveLayout
        }
    })

    $timer.Start()
})

# Pencere kapatılırken arka plandaki zamanlayıcıları ve Runspace'leri güvenli şekilde sonlandır
$Window.Add_Closed({
    try {
        if ($iconTimer -and $iconTimer.IsEnabled) { $iconTimer.Stop() }
        if ($iconRunspace) { $iconRunspace.Close(); $iconRunspace.Dispose() }
    } catch {}
})

# Pencereyi Göster
$Window.ShowDialog() | Out-Null
