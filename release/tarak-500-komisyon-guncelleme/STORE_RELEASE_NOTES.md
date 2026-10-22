# Tarak — Mağaza sürüm notları ve inceleme notları

Sürüm: **1.1.0 (build / versionCode 2)** — `mobile/pubspec.yaml` `version: 1.1.0+2`. Bundle ID / applicationId: `app.tarak.mobile` (değişmedi).
Mağazada bu sürüm numarası veya build numarası zaten yüklüyse `build-aab.ps1 -BuildNumber <daha büyük>` / `BUILD_NUMBER=<daha büyük> bash build-ipa-on-mac.sh` ile üstüne çıkın.

---

## 1. "Yeni neler var" (kısa sürüm notları)

### Türkçe (Google Play ≤ 500 karakter · App Store)
```
• İlk 500 TL komisyon Tarak.app'ten! Onaylanan işletmelere tanımlanan hoş geldin hakkı yalnızca Tarak komisyonunu karşılar; çekilebilir nakit değildir.
• Yeni İşletme Finans Hesabı: hediye hakkı, yüklenen ve rezerve bakiye ile komisyon takibi tek ekranda.
• Komisyon ve bakiye hareketleri daha net görünür.
• Hediye hakkı bittiğinde otomatik e-posta bilgilendirmesi; ödeme bilgilerinizi isteğe bağlı olarak kayıtlı e-postanıza gönderebilirsiniz.
• Genel iyileştirmeler ve hata düzeltmeleri.
```

### English (Google Play ≤ 500 characters · App Store)
```
• First 500 TL of commission on Tarak.app! The welcome allowance granted to approved businesses covers Tarak's platform commission only; it is not withdrawable cash.
• New Business Finance account: gift allowance, deposited and reserved balance, and commission tracking on one screen.
• Clearer commission and balance history.
• Automatic e-mail notice when the allowance is used up; you can also send your payment details to your registered e-mail.
• General improvements and bug fixes.
```

---

## 2. Gerçek ödeme modeli (App Review / Play inceleme notları için — kısaca doğru olan)

- **Müşteri → işletme:** Müşteriler gerçek dünyadaki berber/kuaför hizmetinin bedelini hizmet sırasında **doğrudan işletmeye** öder (nakit veya işletmenin kendi POS cihazı). Uygulama bu ödemeyi tahsil etmez. İsteğe bağlı kartlı ödeme, fiziksel hizmet için üçüncü taraf ödeme kuruluşu (PayTR) üzerinden yapılır; hizmet uygulama dışında, fiziksel olarak tüketilir.
- **500 TL hediye hak:** Yeni onaylanan **işletmelere** tanımlanan bir komisyon hakkıdır; **yalnızca Tarak platform komisyonlarını** karşılar. Nakit değeri yoktur, çekilemez, devredilemez; müşterilere sunulmaz ve uygulama içi satın alma değildir.
- **Banka havalesi:** İşletmeler, hediye hakkı bittikten sonra Tarak'a olan **platform hizmet bedelini (komisyon bakiyesi)** Tarak şirketinin banka hesabına havale/EFT ile öder. Bu, işletme ↔ Tarak arasındaki platform borcunun ödemesidir (B2B), dijital içerik satışı değildir. Ödeme uygulama içinden toplanmaz; kart bilgisi alınmaz. Tutar, Tarak banka kaydında doğrulandıktan sonra işletmenin bakiyesine yazılır (bildirim veya dekont tek başına bakiye eklemez).
- **IBAN uygulamada gösterilmez.** Banka bilgileri yalnızca giriş yapmış onaylı işletmeye web "İşletme Finans Merkezi"nde görünür; mobilde "Ödeme Bilgilerimi E-postama Gönder" ile yalnızca hesaba kayıtlı e-postaya gönderilir (saatte en fazla 3).
- **Platformdaki isteğe bağlı işletme hizmetleri** (öne çıkarma, bildirim kampanyası) işletmenin ön yüklemeli bakiyesinden veya kartla ödenir; bunlar da Tarak'ın işletmelere sunduğu platform hizmetleridir.
- Abonelik, uygulama içi dijital içerik veya kripto/kumar özelliği **yoktur**.

### App Review Notes (English — paste into App Store Connect → App Review Information → Notes)
```
Tarak is a marketplace that connects customers with barbers/hair salons for REAL-WORLD, in-person services.

PAYMENTS
• Customers pay the business directly for the physical service (cash or the business's own POS). The app does not collect this fee. Optional card payment for the physical service is processed by a third-party gateway (PayTR); the service is consumed outside the app (Guideline 3.1.3(e)).
• "First 500 TL commission on Tarak.app" is a one-time ALLOWANCE for newly approved BUSINESSES that offsets only Tarak's own platform commission. It has no cash value, cannot be withdrawn or transferred, is not offered to customers and is not an in-app purchase.
• After the allowance is used, a business settles its platform fee (commission balance) with Tarak by bank transfer to Tarak's company account. This is a business-to-business payment of platform service fees, not a purchase of digital content. The app does not collect or display bank details: it only offers "Email my payment details", which sends them to the business's registered e-mail. Transfers are verified against Tarak's bank statement before any balance is credited.
• No subscriptions, no digital goods or content sold in the app, no external purchase links for digital content.

ACCOUNT & SAFETY
• In-app account deletion: Settings → Delete account (customers) / Profile → Delete account (businesses).
• User-generated content: report and block tools for chat messages and reviews; moderation in the admin panel.

SIGN-IN
• Demo accounts (customer and approved business) are provided in the "Sign-in required" fields.
```

### Google Play — App access / Payments notes (English)
```
Tarak is a marketplace for real-world, in-person barber and hair-salon services. Customers pay the business directly for the physical service (cash or the business's own POS); optional card payment for the physical service goes through a third-party gateway. No digital goods or in-app content are sold, and Google Play billing is not required.
The one-time "First 500 TL commission" is an allowance for newly approved businesses that offsets only Tarak's platform commission (no cash value, not withdrawable, not offered to customers). Businesses settle the platform commission balance by bank transfer to Tarak's company account; this is a B2B payment for platform service fees, verified against Tarak's bank statement before crediting. Bank details are not shown in the app (they are e-mailed to the business's registered address on request).
```

### Google Play — açıklama (Türkçe, aynı içerik)
```
Tarak, gerçek dünyadaki berber/kuaför hizmetleri için bir pazar yeridir. Müşteri, fiziksel hizmetin bedelini doğrudan işletmeye öder (nakit veya işletmenin kendi POS cihazı). Uygulamada dijital ürün/içerik satılmaz. "İlk 500 TL komisyon", yeni onaylanan işletmelere tanımlanan ve yalnızca Tarak platform komisyonunu karşılayan tek seferlik bir haktır (nakit değeri yok, çekilemez, müşterilere sunulmaz). Hak bittiğinde işletme, platform komisyon bakiyesini Tarak şirketinin banka hesabına havale/EFT ile öder; bu bir işletmeden işletmeye platform hizmet bedeli ödemesidir ve banka kaydında doğrulanmadan bakiyeye yazılmaz. Banka bilgileri uygulamada gösterilmez; işletmenin kayıtlı e-postasına gönderilir.
```

---

## 3. Yüklemeden önce hatırlatma (inceleme formları)
- **Demo hesap:** incelemeciye bir müşteri ve **onaylı, banka hesabı tanımlı** bir işletme hesabı verin. Üretim veritabanındaki 3 isimli hesap (`customer@`/`provider@`/`admin@berberimgelsin.com`) geliştirme parolasını kullanıyor; **incelemeye vermeden önce özel inceleme hesapları açın / parolaları değiştirin.** Parolaları bu dosyaya yazmayın.
- Admin panelinde banka hesabı ve SMTP tanımlı olmalı (aksi halde incelemeci "Ödeme Bilgilerimi E-postama Gönder" düğmesinde hata görür).
- Mağaza ekran görüntüleri / öne çıkan grafik / herkese açık hesap silme sayfası ayrı eksiklerdir (bkz. `STORE_UPLOAD_FILES.md`).
