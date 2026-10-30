# Kayıtlı adres, randevu ve yeni iş fırsatı düzeltmeleri — 30 Ekim 2026

Değişiklikler ana kaynak klasörüne uygulandı: `C:\Projeler\TARAK-APP-FINAL-KAYNAK`.
Çalışma dalı: `codex/mobile-stability-pixel9`. Canlı sunucuya dağıtım yapılmadı.

## Düzeltilen davranışlar

- Mobilde planlı randevu sırası: **kayıtlı adres → hizmet → hizmet veren → tarih/saat → ödeme → onay**. Adres otomatik seçilmiyor.
- Webde mevcut adres kartı formun başına taşındı. İşletmeler seçilen kayıtlı adrese göre sorgulanıyor. Yeni adres ekleme mevcut profil ekranını açıyor.
- Seçilen adresin ID'si API'ye gönderiliyor; sunucu adresin müşteriye ait olduğunu doğruluyor ve koordinatları kayıtlı adresten alıyor. Cihaz konumu veya istemcinin farklı koordinat göndermesi seçilen adresi geçersiz kılamıyor.
- Konumu eksik eski kayıtlı adres mevcut coğrafi çözümleme servisiyle tamamlanıyor; çözülemiyorsa kullanıcı harita konumunu kaydetmeye yönlendiriliyor. Başka bir adrese sessiz geçiş yok.
- Randevu listesinde varsayılan sıralama mesafe. İşletmenin hizmet yarıçapı ve en fazla 50 km keşif sınırı uygulanıyor. Konumu olmayan işletme yakın önerisine alınmıyor. Randevu kaydederken de yarıçap tekrar kontrol ediliyor.
- Adres değişince önceki işletme, paket ve saat seçimleri temizleniyor. Eski adres için geciken liste yanıtı yeni seçimi ezemiyor.
- Ana sayfa varsayılan adres değişimini izliyor. Kadın müşteri için **Size Yakın Kuaförler**, erkek müşteri için **Size Yakın Berberler** ve ilgili işletme türü filtresi kullanılıyor. Cinsiyet belirtilmemişse genel kuaför başlığıyla tür sınırlaması olmadan listeleniyor.
- Hemen Çağır talebi yalnız seçilen konuma hizmet verebilen, aktif, belgeleri onaylı, çevrimiçi, yeni müşteri kabul eden ve istenen hizmetlerin tamamını sunan işletmelere gösteriliyor.
- Uygun işletmelere **Yeni iş fırsatı** uygulama içi bildirimi oluşturuluyor; mevcut Firebase FCM iş kuyruğuna gönderiliyor. Aynı talep/işletme için tekrar bildirim oluşturulmuyor. Bildirimde açık adres veya koordinat yok. Kuyruk gönderiminde talebin hâlâ açık ve işletmenin uygun olduğu yeniden kontrol ediliyor.
- Ana sayfa altındaki **Randevu Oluştur** butonu mobilde ve webde planlı randevu açıyor. Hemen Çağır kendi akışını koruyor.
- Web modül önbellek sürümü bütün import zincirinde `20261030-address-rules1` olarak eşitlendi.

Renkler, CSS, kart ve buton tasarımları korunmuştur. Adres bölümünün sırası ve işlevsel yönlendirmeler bu istek kapsamında değişmiştir. Uygulama sürümü `1.1.1+6` olarak korunmuştur. Kullanıcı/işletme verileri, üretim veritabanı, Firebase ayarları ve API anahtarları değiştirilmemiştir.

## Doğrulama

- Flutter analiz: hata/uyarı yok.
- Flutter tam test çalışması: **460 test geçti**; varsayılan adres yenileme kontrolü dahil ilgili dosyanın **6 testi geçti**.
- Backend tam test çalışması: **47 geçti, 3 eski DemoIntegrityTest kontrolü başarısız, 294 assertion**. Önceden belgelenen bu üç kontrol demo/yorum beklentileriyle ilgilidir; bu değişiklikler için gerçek kayıtlar veya demo sınıflandırması değiştirilmedi.
- Yeni backend adres/bildirim testleri: **9 geçti, 50 assertion**. Adres sahipliği, farklı şehir/yanıltıcı koordinat, yarıçap dışı randevu engeli, profil adresinin koordinat yenilemesi, eski adresin çözülmesi, uygun işletme bildirimi ve iptal edilen talebin kuyruktan gönderilmemesi test edildi.
- Firebase HTTP isteği sahte test uç noktasıyla doğrulandı: doğru bildirim başlığı ve `INSTANT_REQUEST` hedefi, aynı iş iki kez çalışsa bile tek FCM gönderimi. Gerçek işletmeye push veya hizmet talebi gönderilmedi.
- Web: **5 davranış kontrolü geçti**; derlenmiş gerçek bileşenlerin callback ve form çıktıları çalıştırıldı. Bütün JavaScript dosyalarında sözdizimi ve modül sürüm tutarlılığı kontrol edildi.
- Pixel 9 emülatörüne yeni debug APK kuruldu. Ana sayfanın altındaki gerçek **Randevu Oluştur** butonuna basıldığında **1. Adres Seçimi** ekranı açıldı; mevcut kayıtlı adresler listelendi ve seçim yapılmadan **Devam Et** pasif kaldı. Oturum korundu. Flutter başlatma komutu emülatörden 255 döndürmesine rağmen uygulamanın çalıştığı ve bu yönlendirme ekranda doğrulandı.

Loglar: `.tools/address-final-analyze.log`, `.tools/address-final-flutter.log`, `.tools/selected-address-widget.log`, `.tools/address-final-backend.log`, `.tools/address-rules-tests.log`, `.tools/address-web-tests.log`.

## Elle dağıtım

`.tools/tarak-address-opportunity-web-backend-2026-10-30.zip` backend ve web dosyalarını ayrı köklerde içerir. Kurulum adımları ve SHA-256 dosya manifesti paket içindedir. Backend tarafında yeni migration veya seed yoktur; mevcut veritabanını koruyun. Mevcut push worker'ın `push` kuyruğunu tüketmesi gerekir.

Mobil uygulama yeni kodla yeniden derlenmelidir. Sunucu paketi uygulanmadan canlı `tarak.app` üzerinde yeni adres kurallarının ve iş bildiriminin etkin olduğu iddia edilmemiştir. Gerçek cihaz Firebase teslimi ve iOS çalışması bu yerel testlerin kapsamı dışındadır.
