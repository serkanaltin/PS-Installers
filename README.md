# Hızlı Kurulum Merkezi — Katılımsız Yazılım ve Paket Dağıtım Paneli

![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B%20%7C%207.x-2563EB?style=for-the-badge&logo=powershell&logoColor=white)
![Platform](https://img.shields.io/badge/Platform-Windows%2010%20%7C%2011-059669?style=for-the-badge&logo=windows&logoColor=white)
![Arayüz](https://img.shields.io/badge/Aray%C3%BCz-Modern%20WPF%20Dashboard-38BDF8?style=for-the-badge)
![Lisans](https://img.shields.io/badge/Lisans-MIT-F59E0B?style=for-the-badge)

**Hızlı Kurulum Merkezi**, Bilgi İşlem (BT / IT) ekiplerinin ve sistem yöneticilerinin yeni kurulan veya formatlanan Windows bilgisayarlara ihtiyaç duyulan yazılımları **kullanıcı onayı beklemeden (`/qn`, `/S`, `--silent`)**, tek bir modern **WPF Dashboard** arayüzü üzerinden topluca indirip kurmasını sağlayan açık kaynaklı bir otomasyon aracıdır.

> **Geliştirici:** **Serkan Altın**  
> **Açık Kaynak Altyapı ve Atıf:** Bu proje, [Tyler Lurie](https://github.com/tylerlurie) tarafından geliştirilen açık kaynaklı [**tylerlurie/PS-Installers**](https://github.com/tylerlurie/PS-Installers) betik koleksiyonu temel alınarak geliştirilmiş; üzerine modern Türkçe WPF Dashboard arayüzü, canlı uygulama logoları, adım adım süreç takip motoru, `winget` yedekleme mekanizması ve kurumsal E-İmza / Hazır Teslimat profilleri eklenerek modernize edilmiştir.

---

## Öne Çıkan Özellikler

* **Modern Koyu Tema (Dark Slate) Dashboard Arayüzü:**
  * Toplam katalog sayısını, seçilen programları, kurulumu tamamlanan paketleri ve otomasyon durumunu canlı gösteren **4'lü üst istatistik kartı**.
  * Her uygulama kartında uygulamanın **resmi logosu** (arka planda otomatik indirilir ve `.icons/` klasöründe önbelleklenir; çevrimdışı ortamlar için kurumsal marka renkli rozet desteği bulunur).
  * Windows `Segoe MDL2 Assets` vektörel ikonlarıyla zenginleştirilmiş, anlaşılır Türkçe kategori menüsü.
* **Sıfır Onay / Tamamen Katılımsız (Silent) Kurulum:**
  * Başlangıçta tek seferde Yönetici (Administrator) yetkisi alır. Seçilen onlarca program kurulurken tekrar UAC penceresi veya *"İleri > İleri"* kurulum sihirbazı açılmaz.
* **Adım Adım Canlı Kurulum Süreci Takibi:**
  * Hem program kartlarının sağ üst köşesinde hem de alt sol kısımdaki **"Adım Adım Kurulum Süreci"** tablosunda her programın hangi aşamada olduğu (**`SIRADA BEKLİYOR`** -> **`İNDİRİLİYOR...`** -> **`SESSİZ KURULUYOR...`** -> **`KURULDU`**) renkli rozetlerle ve kurulum süresiyle (sn) canlı gösterilir.
  * Alt sağdaki **"Canlı İşlem Günlüğü"** konsolunda arka planda gerçekleşen tüm indirme ve kurulum adımları saat damgalı olarak listelenir.
* **Çift Kademeli Kurulum Motoru (Yerel Betik + Winget Yedeği):**
  * Öncelikle ilgili yazılımın `Install_*.ps1` betiğini çalıştırarak resmi sunucusundan en güncel 64-bit MSI/EXE paketini indirip kurar. Herhangi bir indirme veya bağlantı hatası yaşanması durumunda otomatik olarak Windows Paket Yöneticisi (`winget`) üzerinden sessiz kuruluma geçer.
* **Tek Tıkla Hazır Teslimat Paketleri:**
  * **Hemen Teslim Et Paketi (8 Program):** Kullanıcıya teslim edilecek bilgisayarlar için *Microsoft 365 (Bireysel / Ev), WinRAR, AnyDesk, Google Chrome (Kurumsal), Adobe Acrobat Pro* ve *3 E-İmza bileşenini (Dtxgate Signer, SafeNet Authentication Client 10.4, Java JRE 8u513)* tek tıkla seçer.
  * **BT Teknik Destek Paketi (10 Program):** *7-Zip, AnyDesk, Everything, Notepad++, PuTTY, WinSCP, VLC Media Player, WinDirStat, .NET 6/8 Desktop Runtime* ve *Visual C++ 2015-2022* paketlerini tek tıkla seçer.

---

## Hızlı Başlangıç ve Kullanım

### 1. Depoyu İndirin veya Klonlayın

```powershell
git clone https://github.com/serkanaltin/PS-Installers.git
cd PS-Installers
```

### 2. Arayüzü Başlatın

Klasör içerisindeki **`Baslat.bat`** dosyasına çift tıklayarak veya PowerShell üzerinden aşağıdaki komutu çalıştırarak arayüzü açabilirsiniz:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Baslat-KurulumMerkezi.ps1
```

---

## Kategori Yapısı ve Desteklenen Yazılımlar (90 Paket)

Arayüz içerisinde tüm yazılımlar aşağıdaki Türkçe kategoriler altında gruplanmıştır:

| Kategori | İçerdiği Başlıca Yazılımlar |
| :--- | :--- |
| **E-İmza ve Akıllı Kart (3)** | Dtxgate Signer, SafeNet Authentication Client (SAC 10.4), Java JRE 8u513 |
| **Ofis ve PDF Araçları (10)** | Microsoft 365 (Bireysel / İş / Kurumsal), Adobe Acrobat Pro, Adobe Acrobat Reader DC, LibreOffice, FreeOffice, OpenOffice, Foxit PDF Reader, Sumatra PDF |
| **İnternet Tarayıcıları (6)** | Google Chrome (Enterprise MSI), Mozilla Firefox, Microsoft Edge, Brave, Opera, Vivaldi |
| **Arşiv ve Dosya Sıkıştırma (3)** | WinRAR (64-Bit), 7-Zip, PeaZip |
| **Uzak Masaüstü ve Sistem (8)** | AnyDesk, TeamViewer, OpenVPN Connect, Everything Search, Revo Uninstaller, WinDirStat, ImgBurn, NVDA Ekran Okuyucu |
| **İletişim ve Toplantı (8)** | Microsoft Teams, Zoom Workplace, Discord, Telegram, Signal, Mozilla Thunderbird, eM Client, TeamSpeak |
| **Ses, Video ve Ekran Kaydı (8)** | VLC Media Player, K-Lite Codec Pack Full, OBS Studio, Bandicam, Audacity, Spotify, Apple iTunes, foobar2000 |
| **Görsel ve Ekran Görüntüsü (5)** | ShareX, Greenshot, Paint.NET, GIMP, Blender |
| **Bulut Depolama (3)** | Google Drive Masaüstü, Microsoft OneDrive, Dropbox |
| **Yazılım ve Sunucu Araçları (10)** | Visual Studio Code, Visual Studio Community, Notepad++, Sublime Text, PuTTY, WinSCP, FileZilla, Python 3, Python 2.7, Java SE JDK |
| **Sistem Bileşenleri (.NET / C++) (13)** | .NET Desktop Runtime (3.1, 5, 6, 7, 8), .NET Framework 4.8, Visual C++ Redistributable (2005, 2008, 2010, 2012, 2013, 2015-2022), DirectX Runtime |
| **Antivirüs ve Güvenlik (5)** | Malwarebytes, Avast Free Antivirus, AVG AntiVirus Free, Avira Security, Spybot |
| **Sanal Makine Araçları (2)** | Oracle VM VirtualBox, VMware Workstation Player |
| **Dosya Paylaşımı ve Harita (2)** | Google Earth Pro, qBittorrent |
| **Oyun Platformları (4)** | Steam, Epic Games Launcher, Ubisoft Connect, EA App (Origin) |

---

## E-İmza Klasörü (`E İMZA/`) Hakkında Not

`E İMZA` klasörü içerisinde yerel MSI/EXE kurulum paketlerini sessiz parametrelerle (`/qn /norestart` ve `/s`) kuran üç betik yer alır:
* `Install_DtxgateSigner.ps1` -> `DtxgateSigner-1.0.23.msi`
* `Install_SafeNet_SAC.ps1` -> `SAC-x64-10.4.msi`
* `Install_Java_JRE_8.ps1` -> `jre-8u513-windows-i586-iftw.exe`

*(İlgili kurulum dosyaları aynı klasörde bulunduğunda internetten indirme yapmadan doğrudan yerel disk üzerinden saniyeler içinde sessiz kurulum gerçekleştirir.)*

---

## Açık Kaynak Atıf ve Teşekkür (Credits & Attribution)

* **Orijinal Betik Koleksiyonu:** Bu projedeki temel uygulama indirme ve sessiz kurulum betikleri, **[Tyler Lurie](https://github.com/tylerlurie)** tarafından geliştirilen [**PS-Installers**](https://github.com/tylerlurie/PS-Installers) projesinden alınmıştır. Açık kaynak topluluğuna sağladığı bu değerli temel için kendisine teşekkür ederiz.
* **Modernizasyon ve WPF Dashboard Geliştirmesi:** **[Serkan Altın](https://github.com/serkanaltin)** tarafından Bilgi İşlem operasyonlarını hızlandırmak amacıyla WPF grafik arayüzü, canlı süreç izleme mimarisi, Türkçe yerelleştirme, otomatik ikon önbellekleme, Winget yedekleme motoru ve E-İmza/Hazır Teslimat paketleriyle yeniden tasarlanmış ve geliştirilmiştir.

---

## Lisans

Bu proje [MIT Lisansı](LICENSE) altında lisanslanmıştır.
