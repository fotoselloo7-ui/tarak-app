<?php

namespace App\Support;

/**
 * Default, launch-ready values for the single SiteContent JSON blob (id=1).
 *
 * These are merged UNDER the admin-managed content in SiteContentController::show
 * so public pages (legal texts, store links) are never empty before an admin
 * customises them. Legal templates below are standard Turkish boilerplate and
 * MUST be reviewed by the operator's legal counsel before production launch.
 */
class SiteContentDefaults
{
    public static function all(): array
    {
        return [
            'general' => self::general(),
            'branding' => self::branding(),
            'social' => self::social(),
            'seo' => self::seo(),
            'legal' => self::legal(),
            'config' => self::config(),
            'home' => self::home(),
            'landing' => self::landing(),
        ];
    }

    /**
     * Hero copy + CTA labels. Values mirror the approved design exactly, so
     * serving them from the API changes nothing visually until an admin edits.
     */
    public static function landing(): array
    {
        return [
            'hero' => [
                'badge' => 'Berber ve kuaför platformu',
                'title_prefix' => 'Doğrulanmış berber ve kuaförler,',
                'title_highlight' => 'adresinizde.',
                'description' => 'Belgeleri ve kimliği kontrol edilmiş uzmanları karşılaştırın; fiyatı, süreyi ve gerçek müşteri değerlendirmelerini önceden görün, randevunuzu dakikalar içinde oluşturun.',
                'cta_primary' => 'Randevu Oluştur',
                'cta_primary_desc' => 'Doğrulanmış uzmanlar arasından seçin',
                'cta_secondary' => 'Hizmet Veren Olarak Katıl',
                'cta_secondary_desc' => 'Başvurunuz ekibimizce incelenir',
            ],
            // "real": the public sees measured platform numbers (rows with a metric);
            // "manual": the values typed by the admin. See HomeStatsService.
            'stats_mode' => 'real',
            // Demo (pre-launch preview) accounts in the measured numbers: "auto" = counted
            // everywhere except production, "yes" = always, "no" = never.
            'stats_count_demo' => 'auto',
            'stats' => [
                ['metric' => 'providers', 'label' => 'Doğrulanmış Hizmet Veren', 'desc' => 'Belge ve kimlik kontrolünden geçti', 'value' => '', 'audience' => 'all', 'is_active' => true, 'order' => 1],
                ['metric' => 'customers', 'label' => 'Hizmet Alan Müşteri', 'desc' => 'Tarak ile bakım yaptıran', 'value' => '', 'audience' => 'all', 'is_active' => true, 'order' => 2],
                ['metric' => 'weekly_services', 'label' => 'Haftalık Hizmet', 'desc' => 'Son 7 günde tamamlanan', 'value' => '', 'audience' => 'all', 'is_active' => true, 'order' => 3],
                ['metric' => 'avg_rating', 'label' => 'Ortalama Tarak Puanı', 'desc' => 'Gerçek müşteri değerlendirmeleri', 'value' => '', 'audience' => 'all', 'is_active' => true, 'order' => 4],
            ],
        ];
    }

    /**
     * General identity / contact / footer copy. Reused across navbar, footer,
     * public pages and the admin "Genel Ayarlar" panel.
     */
    public static function general(): array
    {
        return [
            'site_name' => 'Tarak',
            'brand_name' => 'Tarak',
            'slogan' => 'Güvenli, Profesyonel, Evinde',
            'description' => "Tarak, berber ve kuaför hizmetlerini güvenli, kolay ve erişilebilir hale getiren Türkiye'nin öncü platformudur.",
            'footer_description' => "Tarak, berber ve kuaför hizmetlerini güvenli, kolay ve erişilebilir hale getiren Türkiye'nin öncü platformudur.",
            'company_name' => '',
            'address' => '',
            'city' => '',
            'district' => '',
            'working_hours' => '09:00 - 22:00',
            'support_hours' => '09:00 - 22:00',
        ];
    }

    /**
     * Uploaded brand assets (public disk, managed prefix "branding/").
     * Empty => callers fall back to the built-in icon+text mark.
     */
    public static function branding(): array
    {
        return [
            // Empty => the bundled official Tarak asset is used by the clients.
            'logo_url' => '',
            // Optional light mark for dark surfaces (footer, dark hero).
            'logo_dark_url' => '',
            'favicon_url' => '',
            // Homepage hero visual; empty => the bundled default asset is used.
            'hero_image_url' => '',
        ];
    }

    /** Social profile links. Empty entries are hidden by the UI, not rendered as dead links. */
    public static function social(): array
    {
        return [
            'instagram' => '',
            'facebook' => '',
            'x' => '',
            'youtube' => '',
            'linkedin' => '',
            'tiktok' => '',
        ];
    }

    /** Homepage + core-branding SEO only — not a site-wide SEO engine. */
    public static function seo(): array
    {
        return [
            'site_title' => 'Tarak',
            'meta_description' => "Türkiye'nin güvenilir berber ve kuaför platformu. Doğrulanmış uzmanlar kapına gelsin.",
            'og_title' => '',
            'og_description' => '',
            'og_image_url' => '',
            'canonical_url' => 'https://tarak.app',
            'robots_index' => true,
            'robots_follow' => true,
        ];
    }

    /**
     * Shared home-page content (verification / trust section, section
     * visibility+order, provider CTA, app download banner) consumed by BOTH
     * the web homepage and the Flutter mobile home — single source of truth.
     */
    public static function home(): array
    {
        return [
            // Every real homepage section, in default order. Admin can toggle
            // visibility and reorder; web + mobile both honour this list.
            'sections' => [
                ['key' => 'hero', 'is_active' => true, 'order' => 1],
                ['key' => 'stats', 'is_active' => true, 'order' => 2],
                ['key' => 'how_it_works', 'is_active' => true, 'order' => 3],
                ['key' => 'categories', 'is_active' => true, 'order' => 4],
                ['key' => 'spotlight', 'is_active' => true, 'order' => 5],
                ['key' => 'providers', 'is_active' => true, 'order' => 6],
                ['key' => 'newest', 'is_active' => true, 'order' => 7],
                ['key' => 'verification', 'is_active' => true, 'order' => 8],
                ['key' => 'provider_cta', 'is_active' => true, 'order' => 9],
                ['key' => 'app_download', 'is_active' => true, 'order' => 10],
            ],
            'verification' => [
                'eyebrow' => 'Güven, Bizim Standartımız',
                'title' => 'Doğrulanmış ve Güvenilir Hizmet Verenler',
                'subtitle' => 'Sadece yetkin, belgeli ve deneyimli profesyoneller platformumuzda yer alır. Tüm hizmet verenlerimiz, ekibimiz tarafından titizlikle incelenir ve doğrulanır.',
                'cards' => [
                    ['icon' => 'diploma', 'title' => 'Diploma Kontrolü', 'desc' => 'Mesleki diploma ve sertifikalar doğrulanır.'],
                    ['icon' => 'certificate', 'title' => 'Kalfalık / Ustalık Belgesi', 'desc' => 'Resmi belgeler kontrol edilir.'],
                    ['icon' => 'identity', 'title' => 'Kimlik Doğrulama', 'desc' => 'Nüfus ve kimlik bilgileri teyit edilir.'],
                    ['icon' => 'team', 'title' => 'Uzman Ekibimiz İnceler', 'desc' => 'Başvuru, uzman ekibimiz tarafından manuel olarak incelenir.'],
                ],
            ],
            // "Nasıl Çalışır?" — same copy drives web and mobile.
            'how_it_works' => [
                'eyebrow' => 'Sadece 4 Adımda',
                'title' => 'Nasıl Çalışır?',
                'subtitle' => 'Tarak ile profesyonel bakım hizmetine ulaşmak çok kolay.',
                'steps' => [
                    ['title' => 'Hizmetini Seç', 'desc' => 'Berber veya kuaför hizmetleri arasından ihtiyacını seç.'],
                    ['title' => 'Zamanını Belirle', 'desc' => 'Uygun tarih ve saati seç, adresini (güvenli şekilde) paylaş.'],
                    ['title' => 'Doğrulanmış Uzman Gelsin', 'desc' => 'Sana en yakın, doğrulanmış uzman belirtilen saatte kapında olsun.'],
                    ['title' => 'Güvenle Hizmet Al', 'desc' => 'Rahatına bak, profesyonel hizmetin keyfini çıkar. Sonrasında değerlendir.'],
                ],
            ],
            // Presentation ONLY. Category records themselves stay canonical
            // domain data served by /api/service-categories.
            'categories' => [
                'eyebrow' => 'Popüler Hizmetler',
                'title' => 'Hizmet Kategorileri',
                'subtitle' => 'İhtiyacına en uygun hizmeti seç, doğrulanmış profesyoneller kapına gelsin.',
                'limit' => 4,
            ],
            // Featured provider strategy: 'auto' = real verified providers from
            // /api/providers/featured; 'selected' = the admin-curated list in
            // landing.featured_providers. Never demo data in either mode.
            'providers' => [
                'eyebrow' => 'Öne Çıkan Uzmanlar',
                'title' => 'Doğrulanmış Hizmet Verenler',
                'subtitle' => 'Alanında uzman, doğrulanmış ve yüksek puanlı profesyonellerle tanışın.',
                'mode' => 'auto',
                'limit' => 8,
            ],
            // Paid "öne çıkarma" section right under the categories. Cards rotate every
            // rotate_seconds (the apps show 6 at a time: 2 columns x 3 rows on a phone).
            'spotlight' => [
                'eyebrow' => 'Vitrindeki Uzmanlar',
                'title' => 'Öne Çıkan Profesyoneller',
                'subtitle' => 'Bu hafta vitrinde yer alan, işini severek yapan uzmanlarla tanışın.',
                'rotate_seconds' => 8,
            ],
            // The most recently approved providers.
            'newest' => [
                'eyebrow' => 'Aramıza Yeni Katıldı',
                'title' => 'Yeni Katılan Profesyoneller',
                'subtitle' => 'Platforma yeni katılan doğrulanmış berber ve kuaförler.',
                'limit' => 8,
            ],
            'provider_cta' => [
                'eyebrow' => 'Uzman mısın?',
                'title' => 'Berber veya Kuaför olarak Aramıza Katıl',
                'subtitle' => 'Esnek çalışma saatleri, kendi müşterilerin ve ek gelir fırsatı seni bekliyor. Binlerce kişinin bakımına dokun, güvenilir bir platformda yer al.',
                'cta_label' => 'Hemen Başvur',
            ],
            'app_download' => [
                'eyebrow' => 'Her Zaman Yanında',
                'title' => 'Tarak',
                'title_highlight' => 'Cebinde!',
                'subtitle' => 'Dilediğin yerde, dilediğin zaman. iOS ve Android uygulamalarımızla hizmetlere daha hızlı ulaş.',
            ],
        ];
    }

    public static function config(): array
    {
        return [
            // Empty => the app shows "Çok Yakında"; fill with a real store URL to enable.
            'app_store_url' => '',
            'play_store_url' => '',
            'support_email' => 'destek@tarak.app',
            'support_phone' => '',
            'whatsapp_number' => '',
        ];
    }

    public static function legal(): array
    {
        return [
            'privacy' => [
                'title' => 'Gizlilik Politikası',
                'updated_at' => '2026-09-24',
                'body' => self::privacyBody(),
            ],
            'kvkk' => [
                'title' => 'KVKK Aydınlatma Metni',
                'updated_at' => '2026-09-24',
                'body' => self::kvkkBody(),
            ],
            'terms' => [
                'title' => 'Kullanım Koşulları',
                'updated_at' => '2026-09-24',
                'body' => self::termsBody(),
            ],
            'cookies' => [
                'title' => 'Çerez Politikası',
                'updated_at' => '2026-09-24',
                'body' => self::cookiesBody(),
            ],
        ];
    }

    private static function privacyBody(): string
    {
        return <<<'MD'
## Gizlilik Politikası

Tarak ("Platform") olarak kişisel verilerinizin gizliliğine önem veriyoruz. Bu politika, Platform'u kullanırken hangi verilerin toplandığını, nasıl işlendiğini ve haklarınızı açıklar.

### 1. Toplanan Veriler
- Hesap bilgileri (ad, soyad, e-posta, telefon)
- Hizmet talebi ve randevu bilgileri
- Konum bilgisi (yalnızca hizmet eşleştirmesi ve onaylı talep sonrası, açık adres gizliliği korunarak)
- Ödeme işlemleri (ödemeler güvenli PayTR altyapısı üzerinden alınır; kart bilgileri Platform'da saklanmaz)

### 2. Verilerin Kullanım Amacı
Verileriniz; hizmet eşleştirmesi, randevu yönetimi, ödeme ve iade süreçleri, güvenlik ve yasal yükümlülüklerin yerine getirilmesi amacıyla işlenir.

### 3. Verilerin Paylaşımı
Verileriniz, hizmetin gerçekleştirilmesi için gerekli olduğu ölçüde hizmet veren ile paylaşılır. Açık adresiniz yalnızca talebiniz onaylandıktan sonra ilgili hizmet verene iletilir.

### 4. Veri Güvenliği
Verileriniz endüstri standardı güvenlik önlemleriyle korunur. Ödeme verileri PayTR tarafından işlenir.

### 5. Haklarınız
KVKK kapsamındaki haklarınızı kullanmak için destek@tarak.app adresine başvurabilirsiniz.
MD;
    }

    private static function kvkkBody(): string
    {
        return <<<'MD'
## KVKK Aydınlatma Metni

6698 sayılı Kişisel Verilerin Korunması Kanunu ("KVKK") uyarınca, veri sorumlusu sıfatıyla Tarak tarafından kişisel verilerinizin işlenmesine ilişkin aşağıdaki hususlarda sizi bilgilendiririz.

### 1. Veri Sorumlusu
Tarak, kişisel verilerinizi KVKK kapsamında veri sorumlusu sıfatıyla işlemektedir.

### 2. İşlenen Veriler ve Amaçları
Kimlik, iletişim, işlem güvenliği, konum ve müşteri işlem verileriniz; hizmet sunumu, sözleşmenin ifası, yasal yükümlülükler ve meşru menfaat kapsamında işlenir.

### 3. Verilerin Aktarımı
Verileriniz, hizmetin ifası için gerekli iş ortaklarına (ör. ödeme kuruluşu PayTR) ve yasal olarak yetkili kamu kurumlarına aktarılabilir.

### 4. Veri Sahibinin Hakları
KVKK md. 11 uyarınca; verilerinizin işlenip işlenmediğini öğrenme, düzeltilmesini/silinmesini isteme ve işlemeye itiraz etme haklarına sahipsiniz.

### 5. Başvuru
Haklarınızı kullanmak için destek@tarak.app adresine yazılı başvuruda bulunabilirsiniz.
MD;
    }

    private static function termsBody(): string
    {
        return <<<'MD'
## Kullanım Koşulları

Tarak'a hoş geldiniz. Platform'u kullanarak aşağıdaki koşulları kabul etmiş olursunuz.

### 1. Hizmet Tanımı
Tarak, müşteriler ile berber/kuaför hizmeti veren profesyonelleri buluşturan bir aracı platformdur. Hizmetler ilgili hizmet veren tarafından sunulur.

### 2. Hesap ve Kullanım
Kayıt sırasında verdiğiniz bilgilerin doğruluğundan siz sorumlusunuz. Hesabınızın güvenliğini korumak sizin sorumluluğunuzdadır.

### 3. Ödeme ve İade
Ödemeler güvenli PayTR ekranı üzerinden alınır. İade süreçleri, ilgili randevu ve platform kuralları çerçevesinde yürütülür.

### 4. Sorumluluk
Platform, hizmet verenler tarafından sunulan hizmetlerin kalitesine ilişkin aracı konumundadır. Uyuşmazlıklar Platform'un uyuşmazlık çözüm mekanizması üzerinden değerlendirilir.

### 5. Değişiklikler
Bu koşullar zaman zaman güncellenebilir. Güncel sürüm bu sayfada yayımlanır.
MD;
    }

    private static function cookiesBody(): string
    {
        return <<<'MD'
## Çerez Politikası

Tarak, deneyiminizi iyileştirmek için çerezler ve benzeri teknolojiler kullanır.

### 1. Çerez Nedir?
Çerezler, ziyaret ettiğiniz siteler tarafından cihazınıza kaydedilen küçük metin dosyalarıdır.

### 2. Kullandığımız Çerezler
- **Zorunlu çerezler:** Oturum yönetimi ve güvenlik için gereklidir.
- **İşlevsel çerezler:** Tercihlerinizi (ör. dil, oturum) hatırlar.

### 3. Çerez Yönetimi
Tarayıcı ayarlarınızdan çerezleri yönetebilir veya silebilirsiniz. Zorunlu çerezlerin devre dışı bırakılması bazı özelliklerin çalışmamasına yol açabilir.

### 4. İletişim
Sorularınız için destek@tarak.app adresine ulaşabilirsiniz.
MD;
    }
}
