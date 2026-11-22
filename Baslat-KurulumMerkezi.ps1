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

$ScriptRoot       = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
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

# 4. Modern Dashboard WPF XAML Arayüzü
[xml]$Xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Hızlı Kurulum Merkezi | Geliştirici: Serkan Altın"
        Width="1300" Height="850" MinWidth="1060" MinHeight="700"
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
    </Window.Resources>

    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <!-- ÜST DASHBOARD BAR: BAŞLIK, HIZLI ARAMA VE DİNAMİK PAKETLER -->
        <Border Grid.Row="0" Background="#0F172A" BorderBrush="#1E293B" BorderThickness="0,0,0,1" Padding="22,14">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="340"/>
                    <ColumnDefinition Width="*"/>
                </Grid.ColumnDefinitions>

                <!-- Sol: Sade ve Güçlü Başlık -->
                <StackPanel Grid.Column="0" VerticalAlignment="Center">
                    <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                        <TextBlock Text="Hızlı Kurulum Merkezi" FontSize="20" FontWeight="Bold" Foreground="#F8FAFC" VerticalAlignment="Center"/>
                        <Border x:Name="AdminBadge" Background="#064E3B" BorderBrush="#059669" BorderThickness="1" CornerRadius="6" Padding="8,2" Margin="10,0,0,0" VerticalAlignment="Center">
                            <TextBlock x:Name="AdminBadgeText" Text="YÖNETİCİ YETKİLİ" FontSize="10" FontWeight="Bold" Foreground="#A7F3D0"/>
                        </Border>
                    </StackPanel>
                    <StackPanel Orientation="Horizontal" Margin="0,3,0,0" VerticalAlignment="Center">
                        <TextBlock Text="Geliştirici: " FontSize="11.5" Foreground="#94A3B8"/>
                        <TextBlock Text="Serkan Altın" FontSize="11.5" FontWeight="Bold" Foreground="#38BDF8"/>
                        <TextBlock Text="  •  Katılımsız Kurulum Paneli" FontSize="11.5" Foreground="#64748B"/>
                    </StackPanel>
                </StackPanel>

                <!-- Orta: Modern Arama Kutusu -->
                <Border Grid.Column="1" Background="#090D16" BorderBrush="#334155" BorderThickness="1" CornerRadius="9" Margin="20,0,16,0" Height="40" VerticalAlignment="Center">
                    <Grid>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="36"/>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>
                        <TextBlock Grid.Column="0" Text="&#xE721;" FontFamily="Segoe MDL2 Assets" FontSize="13.5" Foreground="#38BDF8" VerticalAlignment="Center" HorizontalAlignment="Center"/>
                        <TextBox x:Name="SearchBox" Grid.Column="1" Background="Transparent" Foreground="#F8FAFC" BorderThickness="0"
                                 VerticalContentAlignment="Center" FontSize="13" CaretBrush="#38BDF8" Padding="2,0,8,0"/>
                        <TextBlock x:Name="SearchPlaceholder" Grid.Column="1" Text="Program veya kategori ara (Chrome, E-İmza, Office)..."
                                   Foreground="#64748B" FontSize="12" VerticalAlignment="Center" Margin="2,0,0,0" IsHitTestVisible="False"/>
                        <Button x:Name="BtnClearSearch" Grid.Column="2" Content="Temizle" Visibility="Collapsed" Background="Transparent" Foreground="#38BDF8"
                                BorderThickness="0" Padding="10,0" Cursor="Hand" FontSize="11" FontWeight="SemiBold"/>
                    </Grid>
                </Border>

                <!-- Sağ: Dinamik Hazır Paketler Barı + Yeni Paket Oluştur Butonu -->
                <WrapPanel x:Name="PackagesTopBarPanel" Grid.Column="2" Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Center"/>
            </Grid>
        </Border>

        <!-- ANA DASHBOARD GÖVDESİ -->
        <Grid Grid.Row="1">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="265"/>
                <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>

            <!-- Sol Menü: İkonlu Kategoriler + Geliştirici Kartı -->
            <Border Grid.Column="0" Background="#0F172A" BorderBrush="#1E293B" BorderThickness="0,0,1,0" Padding="12,14">
                <DockPanel>
                    <TextBlock DockPanel.Dock="Top" Text="KATEGORİLER" FontSize="11" FontWeight="Bold" Foreground="#64748B" Margin="10,0,0,8"/>

                    <!-- Sol Alt: Geliştirici İmza ve Açık Kaynak Atıf Kartı -->
                    <Border DockPanel.Dock="Bottom" Background="#090D16" BorderBrush="#1E293B" BorderThickness="1" CornerRadius="9" Padding="14,11" Margin="2,12,2,0">
                        <Grid>
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="36"/>
                                <ColumnDefinition Width="*"/>
                            </Grid.ColumnDefinitions>
                            <Border Grid.Column="0" Width="32" Height="32" CornerRadius="8" Background="#1E3A8A" VerticalAlignment="Center" HorizontalAlignment="Left">
                                <TextBlock Text="SA" FontSize="12" FontWeight="Bold" Foreground="#93C5FD" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                            </Border>
                            <StackPanel Grid.Column="1" VerticalAlignment="Center" Margin="6,0,0,0">
                                <TextBlock Text="Serkan Altın" FontSize="13" FontWeight="Bold" Foreground="#F8FAFC"/>
                                <TextBlock Text="Sistem &amp; Bilgi İşlem Otomasyonu" FontSize="11" Foreground="#38BDF8"/>
                                <TextBlock Text="Altyapı: tylerlurie/PS-Installers" FontSize="9.5" Foreground="#64748B" Margin="0,2,0,0"/>
                            </StackPanel>
                        </Grid>
                    </Border>

                    <ScrollViewer VerticalScrollBarVisibility="Auto">
                        <StackPanel x:Name="CategoryListPanel"/>
                    </ScrollViewer>
                </DockPanel>
            </Border>

            <!-- Sağ Ana Alan: Dashboard Özet Kartları + Uygulama Izgarası + Alt Süreç Takip Paneli -->
            <Grid Grid.Column="1">
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="*"/>
                    <RowDefinition Height="215"/>
                </Grid.RowDefinitions>

                <!-- 1. Satır: Dashboard Özet Metrik Kartları (4'lü Bilgi Kartı) -->
                <Border Grid.Row="0" Background="#0B1120" BorderBrush="#1E293B" BorderThickness="0,0,0,1" Padding="20,12">
                    <UniformGrid Columns="4">
                        <!-- Kart 1: Katalogdaki Toplam Program -->
                        <Border Background="#111827" BorderBrush="#1E293B" BorderThickness="1" CornerRadius="8" Padding="14,9" Margin="0,0,10,0">
                            <Grid>
                                <StackPanel>
                                    <TextBlock Text="TOPLAM KATALOG" FontSize="10" FontWeight="Bold" Foreground="#64748B"/>
                                    <TextBlock x:Name="MetricTotalText" Text="90 Program" FontSize="17" FontWeight="Bold" Foreground="#F8FAFC" Margin="0,2,0,0"/>
                                </StackPanel>
                                <TextBlock Text="&#xE71D;" FontFamily="Segoe MDL2 Assets" FontSize="22" Foreground="#334155" HorizontalAlignment="Right" VerticalAlignment="Center"/>
                            </Grid>
                        </Border>

                        <!-- Kart 2: Seçilen / Kurulacak Program -->
                        <Border Background="#111827" BorderBrush="#1E3A8A" BorderThickness="1" CornerRadius="8" Padding="14,9" Margin="5,0,5,0">
                            <Grid>
                                <StackPanel>
                                    <TextBlock Text="KURULACAK SEÇİM" FontSize="10" FontWeight="Bold" Foreground="#60A5FA"/>
                                    <TextBlock x:Name="MetricSelectedText" Text="0 Seçili" FontSize="17" FontWeight="Bold" Foreground="#38BDF8" Margin="0,2,0,0"/>
                                </StackPanel>
                                <TextBlock Text="&#xE762;" FontFamily="Segoe MDL2 Assets" FontSize="22" Foreground="#1D4ED8" HorizontalAlignment="Right" VerticalAlignment="Center"/>
                            </Grid>
                        </Border>

                        <!-- Kart 3: Bilgisayarda Yüklü & Kurulan Program -->
                        <Border Background="#111827" BorderBrush="#064E3B" BorderThickness="1" CornerRadius="8" Padding="14,9" Margin="5,0,5,0">
                            <Grid>
                                <StackPanel>
                                    <TextBlock Text="SİSTEMDE YÜKLÜ" FontSize="10" FontWeight="Bold" Foreground="#34D399"/>
                                    <TextBlock x:Name="MetricInstalledText" Text="0 Yüklü" FontSize="17" FontWeight="Bold" Foreground="#10B981" Margin="0,2,0,0"/>
                                </StackPanel>
                                <TextBlock Text="&#xE73E;" FontFamily="Segoe MDL2 Assets" FontSize="22" Foreground="#059669" HorizontalAlignment="Right" VerticalAlignment="Center"/>
                            </Grid>
                        </Border>

                        <!-- Kart 4: Sistem / Kurulum Durumu -->
                        <Border Background="#111827" BorderBrush="#1E293B" BorderThickness="1" CornerRadius="8" Padding="14,9" Margin="10,0,0,0">
                            <Grid>
                                <StackPanel>
                                    <TextBlock Text="OTOMASYON DURUMU" FontSize="10" FontWeight="Bold" Foreground="#94A3B8"/>
                                    <TextBlock x:Name="MetricStateText" Text="Seçim Bekleniyor" FontSize="15" FontWeight="Bold" Foreground="#E2E8F0" Margin="0,4,0,0" TextTrimming="CharacterEllipsis"/>
                                </StackPanel>
                                <TextBlock Text="&#xE945;" FontFamily="Segoe MDL2 Assets" FontSize="22" Foreground="#475569" HorizontalAlignment="Right" VerticalAlignment="Center"/>
                            </Grid>
                        </Border>
                    </UniformGrid>
                </Border>

                <!-- 2. Satır: Aktif Kategori Başlığı ve Hızlı Seçim + Yenile/Tara Kontrolleri -->
                <Border Grid.Row="1" Background="#090D16" Padding="22,12,22,6">
                    <Grid>
                        <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                            <TextBlock x:Name="CurrentCategoryTitle" Text="Tüm Programlar" FontSize="17" FontWeight="Bold" Foreground="#F8FAFC" VerticalAlignment="Center"/>
                            <Border Background="#1E293B" BorderBrush="#334155" BorderThickness="1" CornerRadius="12" Padding="10,3" Margin="12,0,0,0" VerticalAlignment="Center">
                                <TextBlock x:Name="CurrentCategoryCount" Text="0 program" FontSize="12" Foreground="#38BDF8" FontWeight="SemiBold"/>
                            </Border>
                        </StackPanel>

                        <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Center">
                            <Button x:Name="BtnRescanInstalled" Style="{StaticResource ActionButtonStyle}" Margin="0,0,8,0" Padding="12,6" FontSize="12"
                                    ToolTip="Windows Kayıt Defteri üzerinden bilgisayarda yüklü olan programları yeniden tarar">
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock Text="&#xE72C;" FontFamily="Segoe MDL2 Assets" FontSize="11.5" Foreground="#34D399" Margin="0,0,6,0" VerticalAlignment="Center"/>
                                    <TextBlock Text="Yenile / Tara" VerticalAlignment="Center"/>
                                </StackPanel>
                            </Button>
                            <Button x:Name="BtnShowSelectedOnly" Style="{StaticResource ActionButtonStyle}" Content="Seçilenleri Göster (0)" Margin="0,0,8,0" Padding="12,6" FontSize="12"/>
                            <Button x:Name="BtnSelectCategory" Style="{StaticResource ActionButtonStyle}" Content="Bu Kategoridekileri Seç" Margin="0,0,8,0" Padding="12,6" FontSize="12"/>
                            <Button x:Name="BtnClearAll" Style="{StaticResource ActionButtonStyle}" Content="Seçimleri Temizle" Padding="12,6" FontSize="12"/>
                        </StackPanel>
                    </Grid>
                </Border>

                <!-- 3. Satır: Logolu Uygulama Kartları Izgarası -->
                <ScrollViewer Grid.Row="2" VerticalScrollBarVisibility="Auto" Padding="16,4,16,14">
                    <WrapPanel x:Name="AppsWrapPanel" Orientation="Horizontal"/>
                </ScrollViewer>

                <!-- 4. Satır: ALT ADIM ADIM SÜREÇ TAKİP PANELİ -->
                <Border Grid.Row="3" Background="#070A12" BorderBrush="#1E293B" BorderThickness="0,1,0,0" Padding="16,10">
                    <Grid>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="440"/>
                            <ColumnDefinition Width="14"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>

                        <!-- Sol Sütun: Seçilen Programların Adım Adım Durum Tablosu -->
                        <Border Grid.Column="0" Background="#0F172A" BorderBrush="#1E293B" BorderThickness="1" CornerRadius="8" Padding="12,8">
                            <DockPanel>
                                <Grid DockPanel.Dock="Top" Margin="0,0,0,6">
                                    <TextBlock Text="ADIM ADIM KURULUM SÜRECİ" FontSize="11" FontWeight="Bold" Foreground="#38BDF8"/>
                                    <TextBlock x:Name="StepCounterBadge" Text="0 / 0 Tamamlandı" FontSize="11" FontWeight="SemiBold" Foreground="#94A3B8" HorizontalAlignment="Right"/>
                                </Grid>
                                <ScrollViewer VerticalScrollBarVisibility="Auto">
                                    <StackPanel x:Name="StepProgressPanel"/>
                                </ScrollViewer>
                            </DockPanel>
                        </Border>

                        <!-- Sağ Sütun: Detaylı Canlı Kurulum Günlüğü -->
                        <Border Grid.Column="2" Background="#0F172A" BorderBrush="#1E293B" BorderThickness="1" CornerRadius="8" Padding="12,8">
                            <DockPanel>
                                <Grid DockPanel.Dock="Top" Margin="0,0,0,6">
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="Auto"/>
                                        <ColumnDefinition Width="*"/>
                                    </Grid.ColumnDefinitions>
                                    <TextBlock Grid.Column="0" Text="CANLI İŞLEM GÜNLÜĞÜ" FontSize="11" FontWeight="Bold" Foreground="#64748B" VerticalAlignment="Center"/>
                                    <TextBlock x:Name="ProgressStepText" Grid.Column="1" Text="Kurulum için program seçin" FontSize="11.5" FontWeight="Bold" Foreground="#38BDF8" HorizontalAlignment="Right" Margin="12,0,0,0" TextTrimming="CharacterEllipsis" VerticalAlignment="Center"/>
                                </Grid>
                                <TextBox x:Name="LogTextBox" Background="Transparent" Foreground="#A7F3D0" BorderThickness="0"
                                         FontFamily="Consolas" FontSize="12" IsReadOnly="True" TextWrapping="Wrap"
                                         VerticalScrollBarVisibility="Auto" AcceptsReturn="True"/>
                            </DockPanel>
                        </Border>
                    </Grid>
                </Border>
            </Grid>
        </Grid>

        <!-- ALT DURUM, SEÇİLEN ÖZETİ VE KURULUM BAŞLATMA ÇUBUĞU -->
        <Border Grid.Row="2" Background="#0F172A" BorderBrush="#1E293B" BorderThickness="0,1,0,0" Padding="24,13">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>

                <!-- Seçili Uygulama Sayısı -->
                <Border Grid.Column="0" Background="#090D16" BorderBrush="#334155" BorderThickness="1" CornerRadius="8" Padding="14,9" VerticalAlignment="Center">
                    <StackPanel Orientation="Horizontal">
                        <TextBlock Text="Seçilen Program: " Foreground="#94A3B8" FontSize="13.5" VerticalAlignment="Center"/>
                        <TextBlock x:Name="SelectedCountText" Text="0" Foreground="#38BDF8" FontSize="15" FontWeight="Bold" VerticalAlignment="Center"/>
                    </StackPanel>
                </Border>

                <!-- Orta: Canlı Aşama Özeti + İlerleme Çubuğu -->
                <StackPanel Grid.Column="1" Margin="20,0" VerticalAlignment="Center">
                    <TextBlock x:Name="SelectedSummaryText" Text="Henüz program seçilmedi. Kartlara tıklayarak veya üstteki hazır paketlerden seçim yapabilirsiniz."
                               Foreground="#94A3B8" FontSize="12" TextTrimming="CharacterEllipsis" Margin="0,0,0,6"/>
                    <ProgressBar x:Name="InstallProgressBar" Height="10" Minimum="0" Maximum="100" Value="0"
                                 Background="#090D16" Foreground="#2563EB" BorderBrush="#334155" BorderThickness="1"/>
                </StackPanel>

                <!-- Sağ: Kurulumu Başlat Butonu -->
                <StackPanel Grid.Column="2" Orientation="Horizontal" VerticalAlignment="Center">
                    <Button x:Name="BtnStartInstall" Style="{StaticResource PrimaryButtonStyle}" Content="Seçilenleri Onaysız Kur (0)" IsEnabled="False"/>
                </StackPanel>
            </Grid>
        </Border>
    </Grid>
</Window>
"@

# 5. XAML Okuma ve Kontrolleri Bağlama
$Reader = New-Object System.Xml.XmlNodeReader $Xaml
$Window = [Windows.Markup.XamlReader]::Load($Reader)

$AdminBadge           = $Window.FindName("AdminBadge")
$AdminBadgeText       = $Window.FindName("AdminBadgeText")
$SearchBox            = $Window.FindName("SearchBox")
$SearchPlaceholder    = $Window.FindName("SearchPlaceholder")
$BtnClearSearch       = $Window.FindName("BtnClearSearch")
$PackagesTopBarPanel  = $Window.FindName("PackagesTopBarPanel")
$CategoryListPanel    = $Window.FindName("CategoryListPanel")
$MetricTotalText      = $Window.FindName("MetricTotalText")
$MetricSelectedText   = $Window.FindName("MetricSelectedText")
$MetricInstalledText  = $Window.FindName("MetricInstalledText")
$MetricStateText      = $Window.FindName("MetricStateText")
$BtnRescanInstalled   = $Window.FindName("BtnRescanInstalled")
$BtnShowSelectedOnly  = $Window.FindName("BtnShowSelectedOnly")
$BtnSelectCategory    = $Window.FindName("BtnSelectCategory")
$BtnClearAll          = $Window.FindName("BtnClearAll")
$CurrentCategoryTitle = $Window.FindName("CurrentCategoryTitle")
$CurrentCategoryCount = $Window.FindName("CurrentCategoryCount")
$AppsWrapPanel        = $Window.FindName("AppsWrapPanel")
$StepProgressPanel    = $Window.FindName("StepProgressPanel")
$StepCounterBadge     = $Window.FindName("StepCounterBadge")
$LogTextBox           = $Window.FindName("LogTextBox")
$ProgressStepText     = $Window.FindName("ProgressStepText")
$SelectedCountText    = $Window.FindName("SelectedCountText")
$SelectedSummaryText  = $Window.FindName("SelectedSummaryText")
$InstallProgressBar   = $Window.FindName("InstallProgressBar")
$BtnStartInstall      = $Window.FindName("BtnStartInstall")

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
$script:ActiveCategory   = "Tümü"
$script:ShowSelectedOnly = $false
$script:IsInstalling     = $false
$BrushConverter          = New-Object Windows.Media.BrushConverter
$script:StepRowMap       = @{}

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

# Kart Üzerindeki ve Alt Süreç Listesindeki Durum Rozetini Güncelleme
function Set-AppInstallState {
    param(
        [string]$AppId,
        [string]$State,
        [string]$DetailText
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
                    $app.StatusBadgeText.Text         = "İNDİRİLİYOR..."
                    $app.CardRef.BorderBrush          = $BrushConverter.ConvertFrom("#F59E0B")
                }
                "Installing" {
                    $app.StatusBadgeBorder.Visibility = [Windows.Visibility]::Visible
                    $app.StatusBadgeBorder.Background = $BrushConverter.ConvertFrom("#1E3A8A")
                    $app.StatusBadgeText.Foreground   = $BrushConverter.ConvertFrom("#93C5FD")
                    $app.StatusBadgeText.Text         = "KURULUYOR..."
                    $app.CardRef.BorderBrush          = $BrushConverter.ConvertFrom("#38BDF8")
                }
                "Fallback" {
                    $app.StatusBadgeBorder.Visibility = [Windows.Visibility]::Visible
                    $app.StatusBadgeBorder.Background = $BrushConverter.ConvertFrom("#7C2D12")
                    $app.StatusBadgeText.Foreground   = $BrushConverter.ConvertFrom("#FED7AA")
                    $app.StatusBadgeText.Text         = "WINGET İLE..."
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
        switch ($State) {
            "Pending" {
                $rowInfo.BadgeBorder.Background = $BrushConverter.ConvertFrom("#1E293B")
                $rowInfo.BadgeText.Foreground   = $BrushConverter.ConvertFrom("#94A3B8")
                $rowInfo.BadgeText.Text         = "SIRADA BEKLİYOR"
                $rowInfo.RowBorder.BorderBrush  = $BrushConverter.ConvertFrom("#1E293B")
            }
            "Downloading" {
                $rowInfo.BadgeBorder.Background = $BrushConverter.ConvertFrom("#78350F")
                $rowInfo.BadgeText.Foreground   = $BrushConverter.ConvertFrom("#FDE68A")
                $rowInfo.BadgeText.Text         = "İNDİRİLİYOR..."
                $rowInfo.RowBorder.BorderBrush  = $BrushConverter.ConvertFrom("#F59E0B")
                $rowInfo.RowBorder.Background   = $BrushConverter.ConvertFrom("#1C1917")
            }
            "Installing" {
                $rowInfo.BadgeBorder.Background = $BrushConverter.ConvertFrom("#1E3A8A")
                $rowInfo.BadgeText.Foreground   = $BrushConverter.ConvertFrom("#93C5FD")
                $rowInfo.BadgeText.Text         = "SESSİZ KURULUYOR..."
                $rowInfo.RowBorder.BorderBrush  = $BrushConverter.ConvertFrom("#3B82F6")
                $rowInfo.RowBorder.Background   = $BrushConverter.ConvertFrom("#172554")
            }
            "Fallback" {
                $rowInfo.BadgeBorder.Background = $BrushConverter.ConvertFrom("#7C2D12")
                $rowInfo.BadgeText.Foreground   = $BrushConverter.ConvertFrom("#FED7AA")
                $rowInfo.BadgeText.Text         = "YEDEK MOTOR..."
                $rowInfo.RowBorder.BorderBrush  = $BrushConverter.ConvertFrom("#F97316")
            }
            "Success" {
                $rowInfo.BadgeBorder.Background = $BrushConverter.ConvertFrom("#065F46")
                $rowInfo.BadgeText.Foreground   = $BrushConverter.ConvertFrom("#A7F3D0")
                $rowInfo.BadgeText.Text         = "KURULDU"
                $rowInfo.RowBorder.BorderBrush  = $BrushConverter.ConvertFrom("#059669")
                $rowInfo.RowBorder.Background   = $BrushConverter.ConvertFrom("#064E3B")
            }
            "Failed" {
                $rowInfo.BadgeBorder.Background = $BrushConverter.ConvertFrom("#7F1D1D")
                $rowInfo.BadgeText.Foreground   = $BrushConverter.ConvertFrom("#FECACA")
                $rowInfo.BadgeText.Text         = "BAŞARISIZ"
                $rowInfo.RowBorder.BorderBrush  = $BrushConverter.ConvertFrom("#DC2626")
                $rowInfo.RowBorder.Background   = $BrushConverter.ConvertFrom("#450A0A")
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
        $emptyText.Text = "Henüz program seçilmedi. Seçtiğiniz programlar kurulum sırasıyla burada adım adım (Sırada -> İndiriliyor -> Kuruluyor -> Kuruldu) listelenir."
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
        $detailBlock.Text = if ($app.IsLocal) { "Yerel paket hazır (İndirme gerekmez)" } else { "Kurulum başlatıldığında otomatik indirilecek" }
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
        $rowBorder.Child = $grid

        $StepProgressPanel.Children.Add($rowBorder) | Out-Null
        $script:StepRowMap[$app.Id] = @{
            RowBorder   = $rowBorder
            NameBlock   = $nameBlock
            DetailBlock = $detailBlock
            BadgeBorder = $badgeBorder
            BadgeText   = $badgeText
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
})

# 9. Özel Paket Oluşturma / Düzenleme / Ad Değiştirme / Silme Penceresi ve Üst Paket Barı
function Show-PackageEditorDialog {
    param(
        [PSCustomObject]$ExistingPackage = $null,
        [switch]$CreateFromCurrentSelection
    )

    [xml]$dlgXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Paket Oluştur / Düzenle"
        Width="560" Height="640"
        WindowStartupLocation="CenterOwner"
        ResizeMode="NoResize"
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

        <!-- Program Arama ve Sayaç -->
        <Grid Grid.Row="2" Margin="0,0,0,8">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>
            <Border Grid.Column="0" Background="#090D16" BorderBrush="#334155" BorderThickness="1" CornerRadius="7" Padding="8,5">
                <TextBox x:Name="TxtDlgSearch" Background="Transparent" Foreground="#F8FAFC" BorderThickness="0" FontSize="12.5" CaretBrush="#38BDF8" Tag="Program ara..."/>
            </Border>
            <TextBlock x:Name="TxtDlgSelectedCount" Grid.Column="1" Text="0 program seçili" FontSize="12" FontWeight="Bold" Foreground="#34D399" VerticalAlignment="Center" Margin="12,0,0,0"/>
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

    $DlgHeaderTitle      = $dlgWin.FindName("DlgHeaderTitle")
    $TxtPackageName      = $dlgWin.FindName("TxtPackageName")
    $TxtDlgSearch        = $dlgWin.FindName("TxtDlgSearch")
    $TxtDlgSelectedCount = $dlgWin.FindName("TxtDlgSelectedCount")
    $DlgAppsStackPanel   = $dlgWin.FindName("DlgAppsStackPanel")
    $BtnDlgDelete        = $dlgWin.FindName("BtnDlgDelete")
    $BtnDlgCancel        = $dlgWin.FindName("BtnDlgCancel")
    $BtnDlgSave          = $dlgWin.FindName("BtnDlgSave")

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
        foreach ($cb in $dlgCheckBoxes) {
            $a = $cb.Tag
            $vis = [string]::IsNullOrEmpty($q) -or $a.Name.ToLower().Contains($q) -or $a.Category.ToLower().Contains($q)
            $cb.Visibility = if ($vis) { [Windows.Visibility]::Visible } else { [Windows.Visibility]::Collapsed }
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

        # Paket Kapsayıcı (Sol: Paket Seçim Butonu | Sağ: Düzenle/Sil Mini Butonu + Sağ Tık Menüsü)
        $btn = New-Object Windows.Controls.Button
        $btn.Style = if ($pkg.Style -eq "Green") { $Window.FindResource("HemenTeslimButtonStyle") } else { $Window.FindResource("ActionButtonStyle") }
        $btn.Margin = New-Object Windows.Thickness(0, 2, 8, 2)
        $btn.Tag = $pkg

        $appNamesPreview = ($AllApps | Where-Object { $pkg.AppIds -contains $_.Id } | Select-Object -ExpandProperty Name) -join ", "
        $btn.ToolTip = "$($pkg.Name) ($pkgCount Program): $appNamesPreview`r`n`r`n• Sol Tık: Paketi Seç (Yüklü olanları otomatik atlar)`r`n• Sağ Tık veya ⚙ İkonu: Paketi Düzenle / Program Ekle-Çıkar / Ad Değiştir / Sil"

        $sp = New-Object Windows.Controls.StackPanel
        $sp.Orientation = [Windows.Controls.Orientation]::Horizontal
        $sp.VerticalAlignment = [Windows.VerticalAlignment]::Center

        $iconGlyph = if ($pkg.Style -eq "Green") { [string][char]0xE73E } elseif ($pkg.Style -eq "Default") { [string][char]0xE90F } else { [string][char]0xE7B8 }
        $ic = New-Object Windows.Controls.TextBlock
        $ic.Text = $iconGlyph
        $ic.FontFamily = New-Object Windows.Media.FontFamily("Segoe MDL2 Assets")
        $ic.FontSize = 12.5
        $ic.Margin = New-Object Windows.Thickness(0, 0, 7, 0)
        $ic.VerticalAlignment = [Windows.VerticalAlignment]::Center
        if ($pkg.Style -ne "Green") {
            $ic.Foreground = $BrushConverter.ConvertFrom("#38BDF8")
        }

        $txt = New-Object Windows.Controls.TextBlock
        $txt.Text = "$($pkg.Name) ($pkgCount)"
        $txt.VerticalAlignment = [Windows.VerticalAlignment]::Center

        # Yanındaki küçük düzenle/yönet butonu (⚙)
        $editGear = New-Object Windows.Controls.TextBlock
        $editGear.Text = [string][char]0xE713
        $editGear.FontFamily = New-Object Windows.Media.FontFamily("Segoe MDL2 Assets")
        $editGear.FontSize = 11.5
        $editGear.Opacity = 0.8
        $editGear.Margin = New-Object Windows.Thickness(8, 0, 0, 0)
        $editGear.VerticalAlignment = [Windows.VerticalAlignment]::Center
        $editGear.ToolTip = "Paketi Düzenle / Ad Değiştir / Sil"
        $editGear.Tag = $pkg

        $editGear.Add_MouseLeftButtonDown({
            param($sender, $e)
            $e.Handled = $true
            if ($script:IsInstalling) { return }
            Show-PackageEditorDialog -ExistingPackage $sender.Tag
        })

        $sp.Children.Add($ic) | Out-Null
        $sp.Children.Add($txt) | Out-Null
        $sp.Children.Add($editGear) | Out-Null
        $btn.Content = $sp

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
        $btn.ContextMenu = $ctxMenu

        $btn.Add_Click({
            param($sender, $e)
            Apply-SavedPackage -PackageObj $sender.Tag
        })

        $PackagesTopBarPanel.Children.Add($btn) | Out-Null
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
        if ($script:ShowSelectedOnly) {
            $match = $app.IsSelected -and (
                [string]::IsNullOrEmpty($query) -or
                $app.Name.ToLower().Contains($query) -or
                $app.Description.ToLower().Contains($query) -or
                $app.Category.ToLower().Contains($query)
            )
        } else {
            $catMatch = ($script:ActiveCategory -eq "Tümü") -or ($app.Category -eq $script:ActiveCategory)
            $searchMatch = [string]::IsNullOrEmpty($query) -or
                           ($app.Name.ToLower().Contains($query)) -or
                           ($app.Description.ToLower().Contains($query)) -or
                           ($app.Category.ToLower().Contains($query))
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
    } else {
        $CurrentCategoryTitle.Text = if ($script:ActiveCategory -eq "Tümü") { "Tüm Programlar" } else { $script:ActiveCategory }
    }
    $CurrentCategoryCount.Text = "$visibleCount program"

    foreach ($catName in $CategoryButtons.Keys) {
        $btn = $CategoryButtons[$catName]
        if (-not $script:ShowSelectedOnly -and $catName -eq $script:ActiveCategory) {
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

    $rowGrid = New-Object Windows.Controls.Grid
    $rc0 = New-Object Windows.Controls.ColumnDefinition
    $rc0.Width = New-Object Windows.GridLength(24)
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
    [Windows.Controls.Grid]::SetColumn($lblBlock, 1)

    $cntBlock = New-Object Windows.Controls.TextBlock
    $cntBlock.Text = "$count"
    $cntBlock.FontSize = 11.5
    $cntBlock.Opacity = 0.75
    $cntBlock.Margin = New-Object Windows.Thickness(6, 0, 0, 0)
    $cntBlock.VerticalAlignment = [Windows.VerticalAlignment]::Center
    [Windows.Controls.Grid]::SetColumn($cntBlock, 2)

    $rowGrid.Children.Add($iconBlock) | Out-Null
    $rowGrid.Children.Add($lblBlock) | Out-Null
    $rowGrid.Children.Add($cntBlock) | Out-Null
    $btn.Content = $rowGrid

    $btn.Add_Click({
        param($sender, $e)
        $script:ShowSelectedOnly = $false
        $script:ActiveCategory = $sender.Tag
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
    $script:ShowSelectedOnly = -not $script:ShowSelectedOnly
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
    $script:ShowSelectedOnly = $false
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

# 13. Asenkron (Arayüzü Dondurmayan) Adım Adım Katılımsız Kurulum Motoru
$BtnStartInstall.Add_Click({
    if ($script:IsInstalling) { return }
    $selectedApps = @($AllApps | Where-Object { $_.IsSelected })
    if ($selectedApps.Count -eq 0) { return }

    $script:ShowSelectedOnly = $true
    Update-AppFilter
    Rebuild-StepTrackerPreview

    $script:IsInstalling = $true
    $BtnStartInstall.IsEnabled     = $false
    $BtnSelectCategory.IsEnabled   = $false
    $BtnClearAll.IsEnabled         = $false
    $BtnRescanInstalled.IsEnabled  = $false
    $PackagesTopBarPanel.IsEnabled = $false

    $InstallProgressBar.Maximum = $selectedApps.Count
    $InstallProgressBar.Value   = 0
    $MetricStateText.Text       = "Kurulum Yapılıyor..."

    foreach ($app in $selectedApps) {
        Set-AppInstallState -AppId $app.Id -State "Pending" -DetailText "Kurulum sırası bekleniyor..."
    }

    Write-GuiLog "=================================================================="
    Write-GuiLog "KATILIMSIZ KURULUM SÜRECİ BAŞLATILDI ($($selectedApps.Count) program)"
    Write-GuiLog "=================================================================="

    $syncHash = [hashtable]::Synchronized(@{
        LogQueue     = [System.Collections.Concurrent.ConcurrentQueue[string]]::new()
        StateQueue   = [System.Collections.Concurrent.ConcurrentQueue[PSCustomObject]]::new()
        CurrentStep  = "Kurulum hazırlığı yapılıyor..."
        SummaryLine  = "Kurulum başlatıldı..."
        Completed    = 0
        Total        = $selectedApps.Count
        IsFinished   = $false
        SuccessCount = 0
        FailCount    = 0
    })

    $appsPayload = $selectedApps | ForEach-Object {
        [PSCustomObject]@{
            Id         = $_.Id
            Name       = $_.Name
            ScriptPath = $_.ScriptPath
            WingetId   = $_.WingetId
            IsLocal    = $_.IsLocal
        }
    }

    $runspace = [runspacefactory]::CreateRunspace()
    $runspace.ApartmentState = "STA"
    $runspace.ThreadOptions  = "ReuseThread"
    $runspace.Open()
    $runspace.SessionStateProxy.SetVariable("syncHash", $syncHash)
    $runspace.SessionStateProxy.SetVariable("appsPayload", $appsPayload)
    $runspace.SessionStateProxy.SetVariable("ScriptRoot", $ScriptRoot)

    $psCmd = [powershell]::Create().AddScript({
        $ProgressPreference = 'SilentlyContinue'
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

        $hasWinget = $null -ne (Get-Command winget.exe -ErrorAction SilentlyContinue)

        function Send-AppState {
            param([string]$AppId, [string]$State, [string]$Detail)
            $syncHash.StateQueue.Enqueue([PSCustomObject]@{
                AppId  = $AppId
                State  = $State
                Detail = $Detail
            })
        }

        function Invoke-WingetSilent {
            param([string]$PackageId)
            if (-not $hasWinget -or [string]::IsNullOrWhiteSpace($PackageId)) { return $false }
            $wingetArgs = "install --id `"$PackageId`" --exact --silent --accept-package-agreements --accept-source-agreements --disable-interactivity"
            $proc = Start-Process -FilePath "winget.exe" -ArgumentList $wingetArgs -Wait -PassThru -WindowStyle Hidden
            return ($proc.ExitCode -eq 0 -or $proc.ExitCode -eq -1978335189)
        }

        $index = 0
        foreach ($app in $appsPayload) {
            $index++
            $sw = [System.Diagnostics.Stopwatch]::StartNew()

            $syncHash.CurrentStep = "Adım $index / $($syncHash.Total): $($app.Name) işleniyor..."
            $syncHash.SummaryLine = "Şu an kurulan ($index/$($syncHash.Total)): $($app.Name)"
            $syncHash.LogQueue.Enqueue("------------------------------------------------------------------")
            $syncHash.LogQueue.Enqueue("[ADIM $index/$($syncHash.Total)] $($app.Name) süreci başlatıldı.")

            $installed = $false
            try {
                if ($app.IsLocal) {
                    Send-AppState -AppId $app.Id -State "Installing" -Detail "Adım 1/2: Yerel kurulum paketi sessiz kuruluyor..."
                    $syncHash.LogQueue.Enqueue("   [1/2] Yerel kurulum dosyası doğrulandı, sessiz kurulum başlatılıyor...")
                } else {
                    Send-AppState -AppId $app.Id -State "Downloading" -Detail "Adım 1/2: Kurulum dosyası indiriliyor ve sessiz kuruluyor..."
                    $syncHash.LogQueue.Enqueue("   [1/2] Resmi sunucudan güncel 64-bit kurulum paketi indiriliyor...")
                }

                $isOfficeApp = ($app.Id -like "*Office365*")

                if ($isOfficeApp) {
                    $officeExe = Join-Path $ScriptRoot "office_setup.exe"
                    $officeXml = Join-Path $ScriptRoot "configuration.xml"
                    Send-AppState -AppId $app.Id -State "Installing" -Detail "office_setup.exe /configure configuration.xml ile Office 2021 kuruluyor..."
                    $syncHash.LogQueue.Enqueue("   [1/2] Yerel office_setup.exe ve configuration.xml (ProPlus2021Volume tr-tr) başlatılıyor...")
                    $proc = Start-Process -FilePath $officeExe -ArgumentList "/configure `"$officeXml`"" -PassThru -WindowStyle Hidden
                    $lastOfficeNoticeSec = 0
                    while (-not $proc.HasExited) {
                        Start-Sleep -Milliseconds 500
                        $elapsedNow = [int]$sw.Elapsed.TotalSeconds
                        if ($elapsedNow -ge ($lastOfficeNoticeSec + 20)) {
                            $lastOfficeNoticeSec = $elapsedNow
                            Send-AppState -AppId $app.Id -State "Installing" -Detail "Microsoft Office 2021 kuruluyor ($elapsedNow sn geçti, lütfen bekleyin)..."
                        }
                    }
                    $proc.WaitForExit()
                    $installed = ($proc.ExitCode -eq 0 -or $proc.ExitCode -eq 3010)
                }
                elseif (Test-Path -LiteralPath $app.ScriptPath) {
                    $proc = Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$($app.ScriptPath)`"" -PassThru -WindowStyle Hidden

                    $switchedToInstalling = $app.IsLocal
                    while (-not $proc.HasExited) {
                        Start-Sleep -Milliseconds 500
                        $elapsedNow = [int]$sw.Elapsed.TotalSeconds
                        if (-not $switchedToInstalling -and $elapsedNow -ge 3) {
                            $switchedToInstalling = $true
                            Send-AppState -AppId $app.Id -State "Installing" -Detail "Adım 2/2: İndirildi, onay beklemeden sessiz kuruluyor..."
                            $syncHash.LogQueue.Enqueue("   [2/2] Kurulum paketi arka planda sessiz parametrelerle (/qn /S) kuruluyor...")
                        }
                    }
                    $proc.WaitForExit()
                    $installed = ($proc.ExitCode -eq 0 -or $proc.ExitCode -eq 3010)
                }

                if (-not $installed -and -not $isOfficeApp -and $hasWinget -and $app.WingetId) {
                    Send-AppState -AppId $app.Id -State "Fallback" -Detail "Alternatif: Windows Paket Yöneticisi (Winget) ile kuruluyor..."
                    $syncHash.LogQueue.Enqueue("   [YEDEK ADIM] Yerel betik tamamlanamadı, Winget üzerinden sessiz kuruluyor ($($app.WingetId))...")
                    $installed = Invoke-WingetSilent -PackageId $app.WingetId
                }
            } catch {
                $syncHash.LogQueue.Enqueue("   [HATA] $($_.Exception.Message)")
                $installed = $false
            }

            $sw.Stop()
            $elapsedSec = [Math]::Max(1, [int]$sw.Elapsed.TotalSeconds)

            if ($installed) {
                $syncHash.SuccessCount++
                Send-AppState -AppId $app.Id -State "Success" -Detail "Tamamlandı: Başarıyla kuruldu ($elapsedSec sn)"
                $syncHash.LogQueue.Enqueue("   [KURULDU] $($app.Name) kurulumu $elapsedSec saniyede tamamlandı.")
            } else {
                $syncHash.FailCount++
                Send-AppState -AppId $app.Id -State "Failed" -Detail "Hata: Kurulum tamamlanamadı ($elapsedSec sn)"
                $syncHash.LogQueue.Enqueue("   [BAŞARISIZ] $($app.Name) kurulumu tamamlanamadı veya iptal edildi.")
            }

            $syncHash.Completed = $index
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
            Set-AppInstallState -AppId $stateUpdate.AppId -State $stateUpdate.State -DetailText $stateUpdate.Detail
        }

        $msg = $null
        while ($sh.LogQueue.TryDequeue([ref]$msg)) {
            Write-GuiLog $msg
        }

        $ProgressStepText.Text    = $sh.CurrentStep
        $SelectedSummaryText.Text = $sh.SummaryLine
        $InstallProgressBar.Value = $sh.Completed
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
            Scan-InstalledApplications -SilentLog
        }
    })

    $timer.Start()
})

# Pencereyi Göster
$Window.ShowDialog() | Out-Null
