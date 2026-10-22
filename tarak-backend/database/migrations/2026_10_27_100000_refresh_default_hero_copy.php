<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    /**
     * The home hero read like a slogan ("Berberin veya Kuaförün Sana Gelsin"). The stock copy is replaced by a
     * plainer, more professional one. Only a hero that still carries the OLD stock wording is touched: copy an
     * admin has written themselves is never overwritten.
     */
    private const OLD = [
        'badge' => "Türkiye'nin Güvenilir Berber ve Kuaför Platformu",
        'title_prefix' => 'Berberin veya Kuaförün',
        'title_highlight' => 'Sana Gelsin',
        'description' => 'Profesyonel berber ve kuaför hizmetleri şimdi çok daha kolay, güvenli ve kapında. İstediğin hizmeti seç, uygun zamanı belirle, doğrulanmış uzmanlar evine gelsin.',
        'cta_primary' => 'Hemen Hizmet Al',
        'cta_primary_desc' => 'Berber veya kuaför çağır',
        'cta_secondary' => 'Hizmet Veren Ol',
        'cta_secondary_desc' => 'Kazancını sen belirle',
    ];

    private const NEW = [
        'badge' => 'Berber ve kuaför platformu',
        'title_prefix' => 'Doğrulanmış berber ve kuaförler,',
        'title_highlight' => 'adresinizde.',
        'description' => 'Belgeleri ve kimliği kontrol edilmiş uzmanları karşılaştırın; fiyatı, süreyi ve gerçek müşteri değerlendirmelerini önceden görün, randevunuzu dakikalar içinde oluşturun.',
        'cta_primary' => 'Randevu Oluştur',
        'cta_primary_desc' => 'Doğrulanmış uzmanlar arasından seçin',
        'cta_secondary' => 'Hizmet Veren Olarak Katıl',
        'cta_secondary_desc' => 'Başvurunuz ekibimizce incelenir',
    ];

    public function up(): void
    {
        $this->swap(self::OLD, self::NEW);
    }

    public function down(): void
    {
        $this->swap(self::NEW, self::OLD);
    }

    /** Replaces the hero fields that still hold the [from] wording; anything else stays as it is. */
    private function swap(array $from, array $to): void
    {
        foreach (DB::table('site_contents')->get() as $row) {
            $content = json_decode((string) $row->content, true);
            if (!is_array($content) || !isset($content['landing']['hero']) || !is_array($content['landing']['hero'])) {
                continue;
            }

            $hero = $content['landing']['hero'];
            $changed = false;
            foreach ($from as $key => $value) {
                if (($hero[$key] ?? null) === $value) {
                    $hero[$key] = $to[$key];
                    $changed = true;
                }
            }
            if ($changed) {
                $content['landing']['hero'] = $hero;
                DB::table('site_contents')->where('id', $row->id)->update([
                    'content' => json_encode($content, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES),
                ]);
            }
        }
    }
};
