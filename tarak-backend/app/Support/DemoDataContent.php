<?php

namespace App\Support;

/**
 * Turkish content pools for the demo/preview data set (see DemoDataService).
 * Everything here is fictional; names, places and texts are only combined to
 * make the app look lived-in during pre-launch demos.
 */
final class DemoDataContent
{
    public const FEMALE_NAMES = [
        'Elif', 'Zeynep', 'Ayşe', 'Merve', 'Esra', 'Selin', 'Büşra', 'Derya', 'Gizem', 'Hande',
        'İpek', 'Melis', 'Naz', 'Defne', 'Ceren', 'Burcu', 'Pınar', 'Yasemin', 'Sevgi', 'Tuğba',
        'Aslı', 'Ebru', 'Seda', 'Dilara', 'Nehir', 'Ecem', 'Sude', 'Beyza', 'Cansu', 'Damla',
        'Fulya', 'Gamze', 'Hatice', 'İrem', 'Kübra', 'Lale', 'Meltem', 'Nazlı', 'Özge', 'Rabia',
        'Sibel', 'Şule', 'Tülin', 'Ülkü', 'Vildan', 'Yeliz', 'Zehra', 'Asya', 'Bahar', 'Cemre',
    ];

    public const MALE_NAMES = [
        'Emre', 'Burak', 'Can', 'Mert', 'Oğuz', 'Kaan', 'Serkan', 'Hakan', 'Murat', 'Ahmet',
        'Mehmet', 'Yusuf', 'Eren', 'Berk', 'Onur', 'Tolga', 'Barış', 'Cem', 'Deniz', 'Efe',
        'Furkan', 'Görkem', 'Halil', 'İbrahim', 'Kemal', 'Levent', 'Mustafa', 'Necati', 'Orhan', 'Polat',
        'Rıza', 'Selim', 'Taner', 'Uğur', 'Volkan', 'Yiğit', 'Zafer', 'Alper', 'Batuhan', 'Cihan',
        'Doruk', 'Ege', 'Fatih', 'Gökhan', 'Hüseyin', 'Ilker', 'Kerem', 'Metin', 'Nihat', 'Ozan',
    ];

    public const SURNAMES = [
        'Yılmaz', 'Kaya', 'Demir', 'Şahin', 'Çelik', 'Yıldız', 'Yıldırım', 'Öztürk', 'Aydın', 'Özdemir',
        'Arslan', 'Doğan', 'Kılıç', 'Aslan', 'Çetin', 'Kara', 'Koç', 'Kurt', 'Özkan', 'Şimşek',
        'Polat', 'Erdoğan', 'Acar', 'Güneş', 'Aksoy', 'Tekin', 'Bulut', 'Korkmaz', 'Avcı', 'Uçar',
        'Taş', 'Karataş', 'Özer', 'Bozkurt', 'Çakır', 'Yavuz', 'Keskin', 'Sönmez', 'Ateş', 'Duman',
        'Aktaş', 'Güler', 'Işık', 'Erdem', 'Tunç', 'Kaplan', 'Bayram', 'Turan', 'Sezer', 'Çiftçi',
        'Eroğlu', 'Soylu', 'Başaran', 'Ergün', 'Yalçın', 'Güven', 'Altun', 'Karaca', 'Toprak', 'Gündüz',
    ];

    /**
     * Cities (weighted) with districts and approximate centre coordinates [lat, lng].
     *
     * @var array<string, array{weight:int, districts:array<string, array{0:float,1:float}>}>
     */
    public const PLACES = [
        'İstanbul' => ['weight' => 38, 'districts' => [
            'Kadıköy' => [40.9903, 29.0290], 'Beşiktaş' => [41.0430, 29.0094], 'Şişli' => [41.0602, 28.9877],
            'Üsküdar' => [41.0226, 29.0153], 'Bakırköy' => [40.9819, 28.8772], 'Ataşehir' => [40.9923, 29.1244],
            'Maltepe' => [40.9358, 29.1311], 'Sarıyer' => [41.1670, 29.0570], 'Beylikdüzü' => [40.9902, 28.6426],
            'Fatih' => [41.0186, 28.9397],
        ]],
        'Ankara' => ['weight' => 14, 'districts' => [
            'Çankaya' => [39.9179, 32.8628], 'Yenimahalle' => [39.9655, 32.8120], 'Keçiören' => [39.9856, 32.8640],
            'Etimesgut' => [39.9535, 32.6370],
        ]],
        'İzmir' => ['weight' => 14, 'districts' => [
            'Konak' => [38.4192, 27.1287], 'Karşıyaka' => [38.4560, 27.1100], 'Bornova' => [38.4620, 27.2200],
            'Buca' => [38.3880, 27.1760],
        ]],
        'Bursa' => ['weight' => 7, 'districts' => ['Nilüfer' => [40.2140, 28.9440], 'Osmangazi' => [40.1950, 29.0600]]],
        'Antalya' => ['weight' => 7, 'districts' => ['Muratpaşa' => [36.8870, 30.7040], 'Konyaaltı' => [36.8770, 30.6340]]],
        'Adana' => ['weight' => 5, 'districts' => ['Seyhan' => [36.9914, 35.3308], 'Çukurova' => [37.0420, 35.2700]]],
        'Konya' => ['weight' => 5, 'districts' => ['Selçuklu' => [37.9380, 32.4930], 'Meram' => [37.8640, 32.4570]]],
        'Kocaeli' => ['weight' => 5, 'districts' => ['İzmit' => [40.7650, 29.9400], 'Gebze' => [40.8020, 29.4300]]],
        'Gaziantep' => ['weight' => 5, 'districts' => ['Şehitkamil' => [37.0790, 37.3830], 'Şahinbey' => [37.0480, 37.3700]]],
    ];

    public const NEIGHBORHOODS = [
        'Atatürk Mah.', 'Cumhuriyet Mah.', 'Yeni Mah.', 'Merkez Mah.', 'Fevzi Çakmak Mah.', 'Barbaros Mah.',
        'Gazi Mah.', 'İnönü Mah.', 'Yıldız Mah.', 'Mimar Sinan Mah.', 'Bahçelievler Mah.', 'Çınar Mah.',
    ];

    public const STREETS = [
        'Gül Sk.', 'Lale Cd.', 'Çiçek Sk.', 'Defne Sk.', 'Papatya Sk.', 'Zambak Cd.', 'Karanfil Sk.',
        'Bağdat Cd.', 'İstiklal Cd.', 'Ihlamur Sk.', 'Nergis Sk.', 'Menekşe Sk.', 'Okul Sk.', 'Çarşı Cd.',
    ];

    /** Salon name patterns; {n} = first name, {s} = surname. */
    public const SALON_PATTERNS_MALE = [
        '{s} Barber', 'Barber {n}', '{n} Erkek Kuaförü', 'Klasik Berber {s}', 'Gentlemen\'s Cut {n}', 'Usta {s} Berber',
        '{n} & {s} Barber Shop', 'The Barber {s}', 'Fade Lab {n}', 'Efsane Berber {s}', 'Royal Barber {n}', 'Dandy {s} Berber',
    ];

    public const SALON_PATTERNS_FEMALE = [
        '{n} Hair Studio', 'Atelier {s}', '{n} Güzellik Salonu', '{s} Kuaför & Güzellik', 'Studio {n}', 'Bella {n} Hair & Beauty',
        '{n} Saç Tasarım', 'Güzellik Atölyesi {s}', 'Maison {n}', '{s} Beauty Lounge', 'Renk Atölyesi {n}', 'Pearl {n} Kuaför',
    ];

    public const TITLES_MALE = [
        'Usta Berber', 'Saç & Sakal Tasarımcısı', 'Fade Uzmanı', 'Klasik Tıraş Ustası', 'Erkek Kuaförü', 'Sakal Tasarım Uzmanı',
    ];

    public const TITLES_FEMALE = [
        'Saç Tasarımcısı', 'Renk Uzmanı', 'Gelin Başı Uzmanı', 'Kuaför & Makyöz', 'Saç Bakım Uzmanı', 'Güzellik Uzmanı',
    ];

    public const SPECIALTIES_MALE = [
        'klasik ustura tıraşı', 'fade ve modern erkek kesimleri', 'sakal tasarımı', 'damat tıraşı', 'çocuk tıraşı', 'erkek saç boyama',
    ];

    public const SPECIALTIES_FEMALE = [
        'saç kesimi ve fön', 'boya, ombre ve röfle', 'gelin başı ve topuz modelleri', 'manikür ve pedikür', 'günlük ve porselen makyaj', 'saç bakımı',
    ];

    public const BIO_INTROS = [
        '{exp} yıllık tecrübemle {city} bölgesinde {specialty} alanında hizmet veriyorum.',
        'Mesleğe {exp} yıl önce başladım; bugün {city} çevresinde {specialty} konusunda güvenilir bir adres olmaya çalışıyorum.',
        '{city} bölgesinde {exp} yıldır çalışıyorum. En çok {specialty} konusunda tercih ediliyorum.',
        'Bu işi sevdiğim için {exp} yıldır yapıyorum. Özellikle {specialty} benim uzmanlık alanım.',
        '{exp} yıllık mesleki deneyimim ve sürekli yenilediğim eğitimlerimle {specialty} hizmeti sunuyorum.',
    ];

    public const BIO_MIDDLES = [
        'Müşterilerimin yüz şekline, saç yapısına ve yaşam tarzına uygun modeli birlikte belirliyoruz.',
        'Hijyene ve temiz çalışmaya büyük önem veriyorum; tüm ekipmanlarım her müşteriden önce sterilize edilir.',
        'Randevu saatine sadık kalmayı ve size ayırdığım zamanı verimli kullanmayı önemsiyorum.',
        'Kaliteli ürünler kullanıyor, her işlemde saç ve cilt sağlığını ön planda tutuyorum.',
        'Trendleri yakından takip ediyor ama her zaman size en çok yakışacak olanı öneriyorum.',
    ];

    public const BIO_CLOSINGS = [
        'Randevu almadan önce istediğiniz modeli bana mesajla iletebilirsiniz.',
        'Sizi de memnun ayrılan müşterilerim arasında görmekten mutluluk duyarım.',
        'Detaylı bilgi ve özel istekleriniz için mesaj atabilirsiniz.',
        'Galerimdeki çalışmalara göz atıp size uygun hizmeti seçebilirsiniz.',
        'Evinize ya da salonuma beklerim; ilk randevuda ayrıntılı danışmanlık ücretsizdir.',
    ];

    public const REVIEW_OPENINGS_POSITIVE = [
        'Kesinlikle tavsiye ederim.', 'Uzun zamandır aradığım kişiyi buldum.', 'Çok memnun kaldım.',
        'Beklentimin üzerindeydi.', 'Baştan sona profesyoneldi.', 'Harika bir deneyimdi.', 'Çok titiz ve güler yüzlü.',
    ];

    public const REVIEW_CLOSINGS_POSITIVE = [
        'Bir sonraki randevumu şimdiden aldım.', 'Herkese öneririm.', 'Teşekkürler!', 'Tekrar çalışmak isterim.',
        'Fiyat performans olarak da çok iyi.', 'Emeğinize sağlık.', 'Arkadaşlarıma da önerdim.',
    ];

    public const REVIEW_DETAILS_MALE = [
        'Saç kesimi tam istediğim gibi oldu.', 'Sakal tasarımı çok temiz ve simetrik çıktı.', 'Fade geçişleri kusursuzdu.',
        'Ense ve kulak çevresi çok hassas temizlendi.', 'Saç ve sakal bakımını birlikte yaptırdım, çok iyi oldu.',
        'Makas işçiliği gerçekten fark yaratıyor.', 'Damat tıraşım için tercih ettim, her şey planlandığı gibi geçti.',
        'Çocuğumun tıraşında çok sabırlıydı.', 'Ustura ile yaptığı klasik tıraş harikaydı.', 'Boya sonrası saçım doğal ve parlak görünüyor.',
        'Ne istediğimi tarif etmeden anladı.', 'Saç dokuma uygun bir model önerdi, çok yakıştı.',
    ];

    public const REVIEW_DETAILS_FEMALE = [
        'Fön ve şekillendirme çok uzun süre kalıcı oldu.', 'Boya tonu tam istediğim gibi çıktı.', 'Röfle çalışması çok doğal duruyor.',
        'Gelin başım için çalıştık, düğün boyunca hiç bozulmadı.', 'Manikür ve pedikür çok titiz yapıldı.',
        'Makyajım gün boyu sabit kaldı.', 'Yüz şeklime uygun bir kesim önerdi, çok memnunum.',
        'Dip boya çok düzgün uygulandı, saçım yıpranmadı.', 'Kaş şekillendirme çok doğal oldu.', 'Hijyene çok dikkat ediyor.',
        'Saç bakımından sonra saçlarım ipek gibi.', 'Ombre çalışması bayıldığım bir sonuç verdi.',
    ];

    public const REVIEW_MID = [
        'Sonuç fena değildi, bekleme süresi biraz uzundu.', 'Hizmet güzeldi ama randevu saatinden biraz geç başlandı.',
        'Genel olarak memnun kaldım; bir sonraki sefer daha detaylı konuşmak isterim.', 'İşçilik iyi, iletişim biraz daha hızlı olabilirdi.',
    ];

    public const REVIEW_LOW = [
        'Beklediğim sonucu alamadım, anlattığım modelden farklı oldu.', 'Maalesef memnun kalmadım, iletişim zayıftı.',
        'Randevuya geç kalındı ve sonuç beklentimin altında kaldı.', 'Fiyatına göre daha özenli bir hizmet bekliyordum.',
    ];

    public const REVIEWER_NAMES_HIDDEN = ['Müşteri'];
}
