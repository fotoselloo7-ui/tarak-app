<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/** "Randevuya Koş" oyunu: Tarak ile giriş, sponsorluk, bölgeye göre kupon, işletme doğrulaması, istatistik. */
class GameIntegrationTest extends TestCase
{
    use RefreshDatabase;

    private const ANAHTAR = 'test-oyun-anahtari';

    protected function setUp(): void
    {
        parent::setUp();
        config(['services.game.key' => self::ANAHTAR, 'services.game.return_urls' => ['https://tarak.app/oyun']]);
    }

    private function kullanici(string $rol, string $eposta): User
    {
        return User::create(['role' => $rol, 'name' => 'Test', 'first_name' => 'Ayşe', 'last_name' => 'Yılmaz',
            'email' => $eposta, 'password' => 'guvenli-sifre', 'status' => 'active']);
    }

    private function musteri(): User
    {
        $u = $this->kullanici('CUSTOMER', 'musteri@example.test');
        $u->customerProfile()->create()->addresses()->create(['title' => 'Ev', 'province' => 'Antalya', 'district' => 'Alanya', 'is_default' => true]);
        return $u;
    }

    private function isletme(string $eposta, string $il, string $ilce): User
    {
        $u = $this->kullanici('PROVIDER', $eposta);
        $u->providerProfile()->create(['business_name' => 'Makas ' . $ilce, 'provider_type' => 'barber', 'city' => $il, 'district' => $ilce]);
        return $u;
    }

    public function test_tarak_ile_giris_tek_kullanimlik_kod_ve_bolge(): void
    {
        $m = $this->musteri();
        $this->get('/api/game/giris?donus=https://kotu.example/x')->assertStatus(400);
        $this->get('/api/game/giris?donus=https://tarak.app/oyun&durum=abc')->assertOk()->assertSee('Tarak ile giriş');
        $this->post('/api/game/giris', ['donus' => 'https://tarak.app/oyun', 'login' => 'musteri@example.test', 'password' => 'yanlis'])->assertStatus(422);

        $yanit = $this->post('/api/game/giris', ['donus' => 'https://tarak.app/oyun', 'durum' => 'abc', 'login' => 'musteri@example.test', 'password' => 'guvenli-sifre']);
        $yanit->assertRedirect();
        parse_str(parse_url($yanit->headers->get('Location'), PHP_URL_QUERY), $q);
        $this->assertSame('abc', $q['durum']);

        $this->postJson('/api/game/kod', ['kod' => $q['tarak_kod']])->assertStatus(401);   // anahtarsız
        $this->postJson('/api/game/kod', ['kod' => $q['tarak_kod']], ['X-Oyun-Anahtar' => self::ANAHTAR])
            ->assertOk()->assertJsonPath('data.kullanici_id', $m->id)->assertJsonPath('data.ilce', 'Alanya');
        $this->postJson('/api/game/kod', ['kod' => $q['tarak_kod']], ['X-Oyun-Anahtar' => self::ANAHTAR])->assertStatus(404); // tekrar kullanılamaz
    }

    public function test_kupon_oyuncunun_ilcesindeki_sponsordan_gelir_ve_isletme_dogrular(): void
    {
        $m = $this->musteri();
        $uzak = $this->isletme('erzurum@example.test', 'Erzurum', 'Yakutiye');
        $yakin = $this->isletme('alanya@example.test', 'Antalya', 'Alanya');
        foreach ([$uzak, $yakin] as $i) {
            Sanctum::actingAs($i);
            $this->postJson('/api/provider/game-sponsorship', ['service_name' => 'Sakal Tıraşı', 'audience' => 'erkek', 'scope' => 'district', 'monthly_quota' => 5])->assertOk();
        }
        $this->getJson('/api/game/sponsorlar?il=Antalya&ilce=Alanya')->assertOk()->assertJsonCount(1, 'data')->assertJsonPath('data.0.isletme_id', $yakin->id);

        $h = ['X-Oyun-Anahtar' => self::ANAHTAR];
        $k = $this->postJson('/api/game/hediye', ['kullanici_id' => $m->id, 'il' => 'Antalya', 'ilce' => 'Alanya', 'kitle' => 'erkek', 'oyun_ref' => 'oyun-1'], $h)
            ->assertOk()->assertJsonPath('data.sponsor.isletme_id', $yakin->id)->json('data');
        $this->assertMatchesRegularExpression('/^TRK-[A-Z2-9]{4}-[A-Z2-9]{4}$/', $k['kod']);
        // aynı oyun kaydı ikinci kupon üretmez; yılda bir hak
        $this->postJson('/api/game/hediye', ['kullanici_id' => $m->id, 'il' => 'Antalya', 'ilce' => 'Alanya', 'oyun_ref' => 'oyun-1'], $h)->assertOk()->assertJsonPath('data.kod', $k['kod']);
        $this->postJson('/api/game/hediye', ['kullanici_id' => $m->id, 'il' => 'Antalya', 'ilce' => 'Alanya', 'oyun_ref' => 'oyun-2'], $h)->assertStatus(409);

        Sanctum::actingAs($m);
        $this->getJson('/api/customer/game-coupons')->assertOk()->assertJsonPath('data.0.kod', $k['kod']);

        Sanctum::actingAs($uzak);
        $this->postJson('/api/provider/game-coupons/verify', ['kod' => $k['kod']])->assertStatus(404);   // başka işletme
        Sanctum::actingAs($yakin);
        $this->getJson('/api/provider/game-coupons')->assertOk()->assertJsonPath('data.0.kod', $k['kod']);
        $this->postJson('/api/provider/game-coupons/verify', ['kod' => $k['kod'], 'kullan' => true])->assertOk()->assertJsonPath('data.durum', 'used');
        $this->postJson('/api/provider/game-coupons/verify', ['kod' => $k['kod'], 'kullan' => true])->assertStatus(409);
    }

    public function test_suresi_dolan_kupon_gecersiz_ve_istatistikler(): void
    {
        $m = $this->musteri();
        $i = $this->isletme('alanya@example.test', 'Antalya', 'Alanya');
        Sanctum::actingAs($i);
        $sid = $this->postJson('/api/provider/game-sponsorship', ['service_name' => 'Saç Kesimi', 'audience' => 'hepsi', 'scope' => 'city', 'monthly_quota' => 3])->json('data.id');
        $h = ['X-Oyun-Anahtar' => self::ANAHTAR];
        $kod = $this->postJson('/api/game/hediye', ['kullanici_id' => $m->id, 'il' => 'Antalya', 'ilce' => 'Manavgat'], $h)->assertOk()->json('data.kod');
        DB::table('game_coupons')->where('code', $kod)->update(['expires_at' => now()->subDay()]);
        $this->postJson('/api/provider/game-coupons/verify', ['kod' => $kod, 'kullan' => true])->assertStatus(409)->assertJsonPath('data.durum', 'expired');

        $this->postJson('/api/game/gosterim', ['kayitlar' => [['sponsorluk_id' => $sid, 'rota' => 'Antalya · Alanya', 'gosterim' => 3, 'oyuncu' => 2]]], $h)->assertOk();
        $this->postJson('/api/game/gosterim', ['kayitlar' => [['sponsorluk_id' => $sid, 'rota' => 'Antalya · Alanya', 'gosterim' => 1, 'oyuncu' => 1]]], $h)->assertOk();
        $this->getJson('/api/provider/game-stats')->assertOk()->assertJsonPath('data.toplam_gosterim', 4)->assertJsonPath('data.haritalar.0.route', 'Antalya · Alanya');

        $admin = $this->kullanici('ADMIN', 'admin@example.test');
        Sanctum::actingAs($admin);
        $this->putJson('/api/admin/game/settings', ['link_android' => 'https://play.google.com/store/apps/details?id=app.tarak.oyun'])->assertOk();
        $this->getJson('/api/game/linkler')->assertJsonPath('data.link_android', 'https://play.google.com/store/apps/details?id=app.tarak.oyun');
        $this->getJson('/api/admin/game/stats')->assertOk()->assertJsonPath('data.kupon.suresi_dolan', 1);
    }
}
