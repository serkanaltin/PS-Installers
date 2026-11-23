# Hızlı Kurulum Merkezi — Katılımsız Yazılım ve Paket Dağıtım Paneli

![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B%20%7C%207.x-2563EB?style=for-the-badge&logo=powershell&logoColor=white)
![Platform](https://img.shields.io/badge/Platform-Windows%2010%20%7C%2011-059669?style=for-the-badge&logo=windows&logoColor=white)
![Arayüz](https://img.shields.io/badge/Aray%C3%BCz-Modern%20WPF%20Dashboard-38BDF8?style=for-the-badge)
![Paket](https://img.shields.io/badge/Katalog-91%20Kat%C4%B1l%C4%B1ms%C4%B1z%20Paket-10B981?style=for-the-badge)
![Lisans](https://img.shields.io/badge/Lisans-MIT-F59E0B?style=for-the-badge)

**Hızlı Kurulum Merkezi**, Bilgi İşlem (BT / IT) ekiplerinin ve sistem yöneticilerinin yeni kurulan veya formatlanan Windows bilgisayarlara ihtiyaç duyulan yazılımları **kullanıcı onayı beklemeden (`/qn`, `/S`, `--silent`)**, tek bir modern **WPF Dashboard** arayüzü üzerinden topluca indirip kurmasını sağlayan açık kaynaklı bir otomasyon aracıdır.

> **Geliştirici:** [**Serkan Altın**](https://github.com/serkanaltin) • [LinkedIn](https://www.linkedin.com/in/serkanaltin/)  
> **Açık Kaynak Altyapı ve Atıf:** Bu proje, [Tyler Lurie](https://github.com/tylerlurie) tarafından geliştirilen açık kaynaklı [**tylerlurie/PS-Installers**](https://github.com/tylerlurie/PS-Installers) betik koleksiyonu temel alınarak geliştirilmiş; üzerine modern Türkçe WPF Dashboard arayüzü, yüklü programları otomatik algılama (`YÜKLÜ` rozeti), özel departman paketleri oluşturma/düzenleme (`ozel_paketler.json`), canlı uygulama logoları, adım adım süreç takip motoru, `winget` yedekleme mekanizması ve kurumsal E-İmza / Office 2021 / Santral (Yeastar Linkus) entegrasyonları eklenerek modernize edilmiştir.

---

## Ekran Görüntüleri (Screenshots)

### 1. Ana Dashboard & Otomatik Yüklü Program Algılama (`YÜKLÜ` Rozeti)
![Ana Dashboard](screenshots/1-ana-dashboard.png)

### 2. "Hemen Teslim Et Paketi" & Adım Adım Canlı Kurulum Süreci Takibi
![Adım Adım Kurulum Süreci](screenshots/2-hemen-teslim-paketi-kurulum-sureci.png)

### 3. Sistemde Yüklü Programlar Filtresi & Daraltılmış (`☰`) Kompakt Görünüm
![Yüklü Programlar ve Kompakt Görünüm](screenshots/3-yuklu-programlar-ve-kompakt-gorunum.png)

### 4. Departmanlara Özel Paket Oluşturma & Düzenleme (`ozel_paketler.json`)
![Özel Paket Oluşturma](screenshots/4-ozel-paket-olusturma-penceresi.png)

---

## Öne Çıkan Özellikler

### 1. Modern ve Duyarlı (Responsive) Koyu Tema (Dark Slate) Dashboard Arayüzü
* **Tam Duyarlı (Responsive) Yerleşim:** Ekran çözünürlüğüne ve DPI ölçeğine otomatik sığar; pencere büyütülüp küçültüldüğünde uygulama kartları (`1`–`5` sütun), üst arama çubuğu, metrik kartları (`4`'lü / `2×2`) ve sol kategori menüsü akıllı kırılımlarla kendini yeniden düzenler.
* **Açılır-Kapanır (Daraltılabilir) Sol Kategori Menüsü (`☰`):** Sol üstteki `☰` butonuyla kategori menüsünü tek tıkla kompakt ikon moduna daraltarak orta katalog alanına maksimum genişlik kazandırır.
* **Etkileşimli 4'lü Üst İstatistik Kartı:**
  * **TOPLAM KATALOG (`91 Program`):** Tıklandığında tüm filtreleri sıfırlar ve tüm kataloğu listeler.
  * **KURULACAK SEÇİM (`X Seçili`):** Tıklandığında yalnızca kurulmak üzere işaretlenen programları filtreler.
  * **SİSTEMDE YÜKLÜ (`XX Yüklü`):** Tıklandığında yalnızca bu bilgisayarda halihazırda kurulu olan programları filtreler.
  * **OTOMASYON DURUMU:** Seçim ve kurulum durumunu canlı olarak gösterir.
* **Canlı Uygulama Logoları ve Marka Rozetleri:** Her uygulama kartında uygulamanın resmi logosu arka planda otomatik indirilir ve `.icons/` klasöründe önbelleklenir (çevrimdışı ortamlar için kurumsal marka renkli rozet desteği bulunur).
* **Sürüklenebilir ve Katlanabilir Canlı İşlem Günlüğü:** Alt süreç/günlük paneli sürüklenebilir yatay/dikey ayırıcılarla (`GridSplitter`) büyütülüp küçültülebilir, **`Gizle ▼ / Göster ▲`** ve **`Temizle`** butonlarıyla kontrol edilebilir; yeni kurulum başlatıldığında otomatik olarak açılır.

### 2. Yüklü Programları Otomatik Algılama ve `YÜKLÜ` Rozeti
* Uygulama açıldığında Windows Kayıt Defteri'ndeki (`HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*`, `WOW6432Node` ve `HKCU`) kurulu yazılımları otomatik tarar.
* Bilgisayarda zaten kurulu olan programların kartında belirgin yeşil **`YÜKLÜ`** rozeti gösterir.
* Hazır paketlere (*Hemen Teslim Et Paketi*, *BT Teknik Destek Paketi* vb.) veya *Bu Kategoridekileri Seç* butonuna basıldığında **sistemde zaten `YÜKLÜ` olan programları otomatik olarak atlar**; böylece yeniden kurulumla vakit kaybedilmez.
* Üst şeritteki **`Yenile / Tara`** butonuyla her an kayıt defteri taraması yenilenebilir.

### 3. Özel Paket Oluşturma, Düzenleme, Ad Değiştirme ve Silme (`ozel_paketler.json`)
* Sağ üstteki **`+ Yeni Paket Oluştur`** butonuyla departmanlara özel paketler (*İK Paketi*, *Muhasebe Paketi*, *Çağrı Merkezi Paketi* vb.) oluşturabilirsiniz.
* Oluşturulan tüm paketler proje klasöründeki **[`ozel_paketler.json`](ozel_paketler.json)** dosyasına kaydedilir; USB bellekte veya ortak ağ paylaşımında taşındığında diğer bilgisayarlarda da otomatik görünür.
* Mevcut ve yeni oluşturulan her paket butonunun sağındaki **`⚙` (Düzenle)** butonuna veya **Sağ Tık Menüsüne** basarak:
  * Pakete yeni program ekleyebilir veya mevcut programları çıkarabilirsiniz,
  * Paketin adını değiştirebilirsiniz,
  * Ana ekranda seçili olan programları tek tıkla o paketin üzerine kaydedebilirsiniz,
  * Paketi tamamen silebilirsiniz.

### 4. Sıfır Onay (Katılımsız) Kurulum, Adım Adım Yüzdelik İndirme ve Otomatik Masaüstü Kısayolu
* Başlangıçta tek seferde Yönetici (Administrator) yetkisi alır. Seçilen onlarca program kurulurken tekrar UAC penceresi veya *"İleri > İleri"* kurulum sihirbazı açılmaz.
* **Canlı Yüzdelik İndirme ve Süreç Takibi:** Hem program kartlarında hem de alt sol **"Adım Adım Kurulum Süreci"** tablosunda her program için satır içi ilerleme çubuğu, indirilen/toplam MB, indirme hızı (`MB/sn`) ve aşama rozetleri (**`SIRADA`** -> **`İNDİRİLİYOR %XX`** -> **`ARŞİV AÇILIYOR`** -> **`KURULUYOR`** -> **`KURULDU`**) canlı olarak gösterilir; Canlı İşlem Günlüğü `%1` ve ardından her `%5` adımda ilerlemeyi satır satır yazar.
* **Detaylı Canlı Günlük & Gerçek Kurulum Doğrulaması:** Kurulum öncesi ve sonrası Kayıt Defteri / dosya sistemi karşılaştırmasıyla programın gerçekten kurulduğu doğrulanır; canlı işlem günlüğüne **indirme adresi**, **geçici dosya yolu**, **çıkış kodu**, **kurulum klasörü (`[KURULUM KLASÖRÜ]`)**, **ana çalıştırılabilir (`[ANA UYGULAMA]`)** ve **sürüm (`[SÜRÜM]`)** bilgileri yazılır.
* **Otomatik Masaüstü Kısayolu:** Kurulan her masaüstü uygulaması için (Microsoft Office 2021'de Word, Excel, PowerPoint ve Outlook dahil) kurulum sırasında kısayol oluşmadıysa Ortak Masaüstü (`C:\Users\Public\Desktop`) üzerinde otomatik `.lnk` kısayolu oluşturulur ve günlüğe işlenir.
* **Yüksek Hızlı Adobe Acrobat Pro & Çift Kademeli Kurulum Motoru:** Adobe Acrobat Pro, yerleşik `curl.exe` + ZIP bütünlük kontrolü + `tar.exe` arşiv açma + hızlı kurumsal MSI parametreleri (`setup.exe` + doğrudan `AcroPro.msi` yedeği) ile güvenilir ve hızlı şekilde kurulur. Herhangi bir betik tamamlanamazsa Windows Paket Yöneticisi (`winget`) yedeği otomatik devreye girer.

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

## Varsayılan Hazır Teslimat Paketleri

1. **Hemen Teslim Et Paketi (8 Program):**
   * **Microsoft Office 2021 Pro Plus (64-Bit Türkçe)** (`office_setup.exe` + `configuration.xml` ile Word, Excel, PowerPoint, Outlook)
   * **Google Chrome (Kurumsal 64-Bit MSI)**
   * **WinRAR (64-Bit)**
   * **Adobe Acrobat Pro (64-Bit)**
   * **AnyDesk**
   * **Dtxgate Signer (E-İmza İstemcisi)** (`DtxgateSigner-1.0.23.msi`)
   * **SafeNet Authentication Client 10.4** (`SAC-x64-10.4.msi`)
   * **Java JRE 8u513 (E-İmza Uyumlu)** (`jre-8u513-windows-i586-iftw.exe`)

2. **BT Teknik Destek Paketi (11 Program):**
   * *7-Zip, AnyDesk, Everything (Anında Dosya Arama), Notepad++, PuTTY, WinSCP, VLC Media Player, WinDirStat, .NET 6 Desktop Runtime, .NET 8 Desktop Runtime, Visual C++ 2015-2022 (64-Bit).*

---

## Kategori Yapısı ve Desteklenen Yazılımlar (91 Paket)

| Kategori | İçerdiği Başlıca Yazılımlar |
| :--- | :--- |
| **E-İmza ve Akıllı Kart (3)** | Dtxgate Signer, SafeNet Authentication Client (SAC 10.4), Java JRE 8u513 |
| **Ofis ve PDF Araçları (10)** | Microsoft Office 2021 Pro Plus (Türkçe / İş / Kurumsal), Adobe Acrobat Pro, Adobe Acrobat Reader DC, LibreOffice, FreeOffice, OpenOffice, Foxit PDF Reader, Sumatra PDF |
| **İnternet Tarayıcıları (6)** | Google Chrome (Enterprise MSI), Mozilla Firefox, Microsoft Edge, Brave, Opera, Vivaldi |
| **Arşiv ve Dosya Sıkıştırma (3)** | WinRAR (64-Bit), 7-Zip, PeaZip |
| **Uzak Masaüstü ve Sistem (8)** | AnyDesk, TeamViewer, OpenVPN Connect, Everything Search, Revo Uninstaller, WinDirStat, ImgBurn, NVDA Ekran Okuyucu |
| **İletişim ve Toplantı (9)** | Yeastar Linkus (Dahili Santral & Çağrı), Microsoft Teams, Zoom Workplace, Discord, Telegram, Signal, Mozilla Thunderbird, eM Client, TeamSpeak |
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

## Proje Dosya Yapısı

* **`Baslat-KurulumMerkezi.ps1`**: Modern WPF Dashboard arayüzünü, kayıt defteri tarayıcısını, özel paket yöneticisini ve çoklu iş parçacıklı (`Runspace`) kurulum motorunu barındıran ana uygulama.
* **`Baslat.bat`**: PowerShell ExecutionPolicy kısıtlamasına takılmadan çift tıklamayla arayüzü başlatan kısayol.
* **`ozel_paketler.json`**: Hazır ve kullanıcı tarafından oluşturulan özel kurulum paketlerinin tutulduğu taşınabilir JSON yapılandırma dosyası.
* **`office_setup.exe` & `configuration.xml`**: Microsoft Office 2021 Pro Plus (`ProPlus2021Volume`, 64-Bit, Türkçe `tr-tr`) katılımsız kurulum motoru ve yapılandırması.
* **`E İMZA/`**: Yerel E-İmza kurulum paketleri (`DtxgateSigner-1.0.23.msi`, `SAC-x64-10.4.msi`, `jre-8u513-windows-i586-iftw.exe`) ve sessiz kurulum betikleri.

---

## Açık Kaynak Atıf ve Teşekkür (Credits & Attribution)

* **Orijinal Betik Koleksiyonu:** Bu projedeki temel uygulama indirme ve sessiz kurulum betikleri, **[Tyler Lurie](https://github.com/tylerlurie)** tarafından geliştirilen [**PS-Installers**](https://github.com/tylerlurie/PS-Installers) projesinden alınmıştır. Açık kaynak topluluğuna sağladığı bu değerli temel için kendisine teşekkür ederiz.
* **Modernizasyon ve WPF Dashboard Geliştirmesi:** **[Serkan Altın](https://github.com/serkanaltin)** ([LinkedIn](https://www.linkedin.com/in/serkanaltin/)) tarafından Bilgi İşlem operasyonlarını hızlandırmak amacıyla WPF grafik arayüzü, yüklü uygulama algılama motoru, dinamik özel paket yönetimi (`ozel_paketler.json`), canlı süreç izleme mimarisi, Türkçe yerelleştirme, otomatik ikon önbellekleme, Winget yedekleme motoru ve E-İmza / Office 2021 / Yeastar Linkus entegrasyonlarıyla yeniden tasarlanmış ve geliştirilmiştir.

---

## Lisans

Bu proje [MIT Lisansı](LICENSE) altında lisanslanmıştır.
