<?php

namespace Database\Seeders;

use App\Models\Service;
use App\Models\ServiceCategory;
use Illuminate\Database\Seeder;

class ServiceCatalogSeeder extends Seeder
{
    /**
     * Seed official BerberimGelsin service catalog.
     * Idempotent & matches frontend constants exactly.
     */
    public function run(): void
    {
        // 1. Categories
        $categories = [
            [
                'id' => 'cat-1',
                'name' => 'Erkek Bakım',
                'slug' => 'erkek-bakim',
                'icon' => 'scissors',
                'provider_type' => 'barber',
                'is_active' => true,
                'sort_order' => 1,
            ],
            [
                'id' => 'cat-2',
                'name' => 'Kadın Kuaför',
                'slug' => 'kadin-kuafor',
                'icon' => 'hair',
                'provider_type' => 'coiffeur',
                'is_active' => true,
                'sort_order' => 2,
            ],
        ];

        foreach ($categories as $cat) {
            ServiceCategory::updateOrCreate(['id' => $cat['id']], $cat);
        }

        // 2. Services
        $services = [
            // Erkek Bakım (cat-1)
            [
                'id' => 1,
                'category_id' => 'cat-1',
                'name' => 'Saç Kesimi',
                'slug' => 'sac-kesimi-erkek',
                'description' => 'Profesyonel saç kesimi ve stil danışmanlığı.',
                'duration_minutes' => 30,
                'base_price' => 250.00,
                'icon_class' => 'fa-solid fa-scissors',
                'is_active' => true,
                'sort_order' => 1,
            ],
            [
                'id' => 2,
                'category_id' => 'cat-1',
                'name' => 'Sakal Tıraşı',
                'slug' => 'sakal-tirasi',
                'description' => 'Klasik ustura veya makine ile sakal tıraşı ve sakal tasarımı.',
                'duration_minutes' => 15,
                'base_price' => 150.00,
                'icon_class' => 'fa-solid fa-user',
                'is_active' => true,
                'sort_order' => 2,
            ],
            [
                'id' => 3,
                'category_id' => 'cat-1',
                'name' => 'Saç & Sakal (VIP)',
                'slug' => 'sac-sakal-vip',
                'description' => 'Komple saç kesimi, sakal tıraşı, yıkama ve özel bakım.',
                'duration_minutes' => 45,
                'base_price' => 350.00,
                'icon_class' => 'fa-solid fa-crown',
                'is_active' => true,
                'sort_order' => 3,
            ],
            [
                'id' => 4,
                'category_id' => 'cat-1',
                'name' => 'Çocuk Tıraşı',
                'slug' => 'cocuk-tirasi',
                'description' => 'Çocuklara özel sabırlı ve eğlenceli saç kesimi deneyimi.',
                'duration_minutes' => 30,
                'base_price' => 200.00,
                'icon_class' => 'fa-solid fa-child',
                'is_active' => true,
                'sort_order' => 4,
            ],
            [
                'id' => 5,
                'category_id' => 'cat-1',
                'name' => 'Damat Tıraşı',
                'slug' => 'damat-tirasi',
                'description' => 'Özel gününüze yakışır VIP komple bakım paketi ve maske.',
                'duration_minutes' => 60,
                'base_price' => 1000.00,
                'icon_class' => 'fa-solid fa-crown',
                'is_active' => true,
                'sort_order' => 5,
            ],
            [
                'id' => 6,
                'category_id' => 'cat-1',
                'name' => 'Saç Boyama (Erkek)',
                'slug' => 'sac-boyama-erkek',
                'description' => 'Doğal beyaz kapatma veya modern saç renklendirme.',
                'duration_minutes' => 45,
                'base_price' => 400.00,
                'icon_class' => 'fa-solid fa-paintbrush',
                'is_active' => true,
                'sort_order' => 6,
            ],

            // Kadın Kuaför (cat-2)
            [
                'id' => 101,
                'category_id' => 'cat-2',
                'name' => 'Saç Kesimi (Kadın)',
                'slug' => 'sac-kesimi-kadin',
                'description' => 'Kişiye özel saç modeli kesimi ve yıkama.',
                'duration_minutes' => 45,
                'base_price' => 400.00,
                'icon_class' => 'fa-solid fa-scissors',
                'is_active' => true,
                'sort_order' => 1,
            ],
            [
                'id' => 102,
                'category_id' => 'cat-2',
                'name' => 'Fön',
                'slug' => 'fon',
                'description' => 'Düz, dalgalı veya kırık fön uygulaması.',
                'duration_minutes' => 30,
                'base_price' => 200.00,
                'icon_class' => 'fa-solid fa-wind',
                'is_active' => true,
                'sort_order' => 2,
            ],
            [
                'id' => 103,
                'category_id' => 'cat-2',
                'name' => 'Dip Boya',
                'slug' => 'dip-boya',
                'description' => 'Kaliteli profesyonel ürünlerle dip boyama işlemi.',
                'duration_minutes' => 60,
                'base_price' => 500.00,
                'icon_class' => 'fa-solid fa-paintbrush',
                'is_active' => true,
                'sort_order' => 3,
            ],
            [
                'id' => 104,
                'category_id' => 'cat-2',
                'name' => 'Tüm Boya',
                'slug' => 'tum-boya',
                'description' => 'Tüm saça renk değişimi ve homojen boya uygulaması.',
                'duration_minutes' => 90,
                'base_price' => 900.00,
                'icon_class' => 'fa-solid fa-paintbrush',
                'is_active' => true,
                'sort_order' => 4,
            ],
            [
                'id' => 105,
                'category_id' => 'cat-2',
                'name' => 'Röfle / Ombre',
                'slug' => 'rofle-ombre',
                'description' => 'Doğal geçişli ışıltı, balyaj veya modern ombre.',
                'duration_minutes' => 120,
                'base_price' => 1800.00,
                'icon_class' => 'fa-solid fa-palette',
                'is_active' => true,
                'sort_order' => 5,
            ],
            [
                'id' => 106,
                'category_id' => 'cat-2',
                'name' => 'Manikür',
                'slug' => 'manikur',
                'description' => 'El tırnak bakımı, kütikül temizliği ve oje.',
                'duration_minutes' => 30,
                'base_price' => 250.00,
                'icon_class' => 'fa-solid fa-hand-sparkles',
                'is_active' => true,
                'sort_order' => 6,
            ],
            [
                'id' => 107,
                'category_id' => 'cat-2',
                'name' => 'Pedikür',
                'slug' => 'pedikur',
                'description' => 'Ayak ve tırnak spa bakımı, topuk bakımı.',
                'duration_minutes' => 40,
                'base_price' => 300.00,
                'icon_class' => 'fa-solid fa-shoe-prints',
                'is_active' => true,
                'sort_order' => 7,
            ],
            [
                'id' => 108,
                'category_id' => 'cat-2',
                'name' => 'Manikür + Pedikür',
                'slug' => 'manikur-pedikur-kombin',
                'description' => 'Komple el ve ayak bakım paketi.',
                'duration_minutes' => 60,
                'base_price' => 500.00,
                'icon_class' => 'fa-solid fa-hand-sparkles',
                'is_active' => true,
                'sort_order' => 8,
            ],
            [
                'id' => 109,
                'category_id' => 'cat-2',
                'name' => 'Gelin Başı',
                'slug' => 'gelin-basi',
                'description' => 'Düğün gününüze özel gelin saçı tasarımı ve provası.',
                'duration_minutes' => 120,
                'base_price' => 3000.00,
                'icon_class' => 'fa-solid fa-gem',
                'is_active' => true,
                'sort_order' => 9,
            ],
            [
                'id' => 110,
                'category_id' => 'cat-2',
                'name' => 'Makyaj (Günlük)',
                'slug' => 'makyaj-gunluk',
                'description' => 'Doğal, tazeleyici ve hafif günlük makyaj uygulaması.',
                'duration_minutes' => 45,
                'base_price' => 450.00,
                'icon_class' => 'fa-solid fa-wand-magic-sparkles',
                'is_active' => true,
                'sort_order' => 10,
            ],
            [
                'id' => 111,
                'category_id' => 'cat-2',
                'name' => 'Makyaj (Porselen)',
                'slug' => 'makyaj-porselen',
                'description' => 'Gece ve özel davetler için kalıcı porselen makyaj.',
                'duration_minutes' => 60,
                'base_price' => 900.00,
                'icon_class' => 'fa-solid fa-wand-magic-sparkles',
                'is_active' => true,
                'sort_order' => 11,
            ],
            [
                'id' => 112,
                'category_id' => 'cat-2',
                'name' => 'Ağda (Tüm Vücut)',
                'slug' => 'agda-tum-vucut',
                'description' => 'Hijyenik ve profesyonel komple ağda uygulaması.',
                'duration_minutes' => 60,
                'base_price' => 700.00,
                'icon_class' => 'fa-solid fa-leaf',
                'is_active' => true,
                'sort_order' => 12,
            ],
            [
                'id' => 113,
                'category_id' => 'cat-2',
                'name' => 'Kaş & Bıyık',
                'slug' => 'kas-biyik',
                'description' => 'İp veya cımbız ile kaş tasarımı ve bıyık alımı.',
                'duration_minutes' => 15,
                'base_price' => 150.00,
                'icon_class' => 'fa-solid fa-eye',
                'is_active' => true,
                'sort_order' => 13,
            ],
        ];

        foreach ($services as $srv) {
            Service::updateOrCreate(['id' => $srv['id']], $srv);
        }
    }
}
