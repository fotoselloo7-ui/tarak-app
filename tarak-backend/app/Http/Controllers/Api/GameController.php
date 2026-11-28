<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

/**
 * "Randevuya Koş" oyunu: Tarak ile giriş, sponsor işletmeler, oyundan kazanılan kuponlar, istatistik.
 * Kuponun tek doğruluk kaynağı Tarak'tır; oyun sunucusu yalnız "bu kullanıcı hak kazandı" der.
 * Sunucudan sunucuya uçlar `X-Oyun-Anahtar` başlığı ister (GAME_SERVER_KEY).
 */
class GameController extends Controller
{
    private const KUPON_GUN = 30;
    private const AYARLAR = ['link_ios', 'link_android', 'link_web', 'oyun_acik', 'oyun_baslik'];

    // ---------------------------------------------------------------- yardımcılar
    private function ayar(string $k, $vars = null)
    {
        $v = DB::table('game_settings')->where('key', $k)->value('value');
        return $v ?? $vars;
    }

    private function sunucuMu(Request $r): bool
    {
        $anahtar = (string) config('services.game.key');
        return $anahtar !== '' && hash_equals($anahtar, (string) $r->header('X-Oyun-Anahtar'));
    }

    private function donusGecerli(?string $donus): bool
    {
        if (!$donus) return false;
        foreach (config('services.game.return_urls', []) as $izin) {
            $izin = trim($izin);
            if ($izin !== '' && str_starts_with($donus, $izin)) return true;
        }
        return false;
    }

    private static function norm(?string $s): string
    {
        return mb_strtolower(trim((string) $s), 'UTF-8');
    }

    private function kuponKodu(): string
    {
        $harf = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
        do {
            $k = 'TRK-';
            for ($i = 0; $i < 8; $i++) { $k .= $harf[random_int(0, strlen($harf) - 1)]; if ($i === 3) $k .= '-'; }
        } while (DB::table('game_coupons')->where('code', $k)->exists());
        return $k;
    }

    private function sureleriGuncelle(): void
    {
        DB::table('game_coupons')->where('status', 'active')->where('expires_at', '<', now())
            ->update(['status' => 'expired', 'updated_at' => now()]);
    }

    private function sponsorKarti(object $s): array
    {
        $u = DB::table('users')->where('id', $s->provider_user_id)->first(['id', 'name', 'avatar_url']);
        $p = DB::table('provider_profiles')->where('user_id', $s->provider_user_id)->first(['business_name', 'city', 'district']);
        return [
            'sponsorluk_id' => $s->id,
            'isletme_id' => $s->provider_user_id,
            'ad' => $p->business_name ?? $u->name ?? 'Tarak işletmesi',
            'logo' => $u->avatar_url ?? null,
            'il' => $p->city ?? $s->province,
            'ilce' => $p->district ?? $s->district,
            'hizmet' => $s->service_name,
        ];
    }

    /** Bölgedeki aktif ve bu ay kotası dolmamış sponsorluklar (önce ilçe, sonra il). */
    private function bolgeSponsorlari(?string $il, ?string $ilce, ?string $kitle = null)
    {
        $bugun = now()->toDateString();
        $q = DB::table('game_sponsorships')->where('is_active', true)
            ->where(fn ($q) => $q->whereNull('starts_on')->orWhere('starts_on', '<=', $bugun))
            ->where(fn ($q) => $q->whereNull('ends_on')->orWhere('ends_on', '>=', $bugun));
        if ($kitle) $q->whereIn('audience', [$kitle, 'hepsi']);
        $hepsi = $q->get();
        $il = self::norm($il); $ilce = self::norm($ilce);
        $ilceDe = $hepsi->filter(fn ($s) => $s->scope === 'district' && self::norm($s->province) === $il && self::norm($s->district) === $ilce);
        $ilde = $hepsi->filter(fn ($s) => self::norm($s->province) === $il && ($s->scope === 'city' || self::norm($s->district) !== $ilce));
        return $ilceDe->values()->concat($ilde->filter(fn ($s) => $s->scope === 'city')->values());
    }

    private function kotaKaldi(object $s): bool
    {
        $buAy = DB::table('game_coupons')->where('sponsorship_id', $s->id)
            ->where('created_at', '>=', now()->startOfMonth())->count();
        return $buAy < $s->monthly_quota;
    }

    // ---------------------------------------------------------------- Tarak ile giriş (oyun)
    /** GET /api/game/giris?donus=...&durum=... — Tarak'ın kendi giriş sayfası (şifre oyuna hiç gitmez). */
    public function girisSayfasi(Request $r)
    {
        $donus = (string) $r->query('donus');
        if (!$this->donusGecerli($donus)) return response('Geçersiz dönüş adresi.', 400);
        return response()->view('game.giris', ['donus' => $donus, 'durum' => (string) $r->query('durum'), 'hata' => null]);
    }

    /** POST /api/game/giris — bilgiler doğruysa tek kullanımlık kodla oyuna döner (5 dk). */
    public function girisYap(Request $r)
    {
        $donus = (string) $r->input('donus');
        $durum = (string) $r->input('durum');
        if (!$this->donusGecerli($donus)) return response('Geçersiz dönüş adresi.', 400);
        $kimlik = trim((string) $r->input('login'));
        $sifre = (string) $r->input('password');
        $user = null;
        if ($kimlik !== '' && $sifre !== '') {
            $e = User::normalizeEmail($kimlik); $t = User::normalizePhone($kimlik);
            $user = User::where(function ($q) use ($kimlik, $e, $t) {
                if ($e) $q->orWhere('email', $e);
                if ($t) $q->orWhere('phone', $t);
                $q->orWhere('email', strtolower($kimlik));
            })->first();
        }
        if (!$user || !Hash::check($sifre, $user->password) || $user->status !== 'active') {
            return response()->view('game.giris', ['donus' => $donus, 'durum' => $durum, 'hata' => 'E-posta/telefon ya da şifre hatalı.'], 422);
        }
        $kod = Str::random(48);
        DB::table('game_auth_codes')->insert([
            'user_id' => $user->id, 'code_hash' => hash('sha256', $kod), 'expires_at' => now()->addMinutes(5),
            'created_at' => now(), 'updated_at' => now(),
        ]);
        $ayirac = str_contains($donus, '?') ? '&' : '?';
        return redirect()->away($donus . $ayirac . http_build_query(['tarak_kod' => $kod, 'durum' => $durum]));
    }

    /** POST /api/game/kod (sunucudan sunucuya) {kod} -> kullanıcı kimliği ve bölgesi. Kod tek kullanımlık. */
    public function kodDegistir(Request $r): JsonResponse
    {
        if (!$this->sunucuMu($r)) return response()->json(['success' => false, 'message' => 'Yetkisiz.'], 401);
        $satir = DB::table('game_auth_codes')->where('code_hash', hash('sha256', (string) $r->input('kod')))
            ->whereNull('used_at')->where('expires_at', '>', now())->first();
        if (!$satir) return response()->json(['success' => false, 'message' => 'Kod geçersiz ya da süresi doldu.'], 404);
        DB::table('game_auth_codes')->where('id', $satir->id)->update(['used_at' => now(), 'updated_at' => now()]);
        $u = User::with(['customerProfile', 'providerProfile'])->find($satir->user_id);
        $il = null; $ilce = null;
        if ($u->customerProfile) {
            $adr = DB::table('customer_addresses')->where('customer_profile_id', $u->customerProfile->id)
                ->orderByDesc('is_default')->orderByDesc('id')->first(['province', 'district']);
            if ($adr) { $il = $adr->province; $ilce = $adr->district; }
        } elseif ($u->providerProfile) { $il = $u->providerProfile->city; $ilce = $u->providerProfile->district; }
        return response()->json(['success' => true, 'data' => [
            'kullanici_id' => $u->id, 'ad' => $u->first_name ?: $u->name, 'rol' => $u->role, 'il' => $il, 'ilce' => $ilce,
        ]]);
    }

    // ---------------------------------------------------------------- oyunun kullandığı uçlar
    /** GET /api/game/sponsorlar?il=&ilce=&kitle= — oyundaki tabelalar için bölgenin sponsorları (herkese açık). */
    public function sponsorlar(Request $r): JsonResponse
    {
        $liste = $this->bolgeSponsorlari($r->query('il'), $r->query('ilce'), $r->query('kitle'))->take(12)
            ->map(fn ($s) => $this->sponsorKarti($s))->values();
        return response()->json(['success' => true, 'data' => $liste]);
    }

    /** GET /api/game/linkler — oyun indirme bağlantıları (tarak.app sitesi ve uygulama için). */
    public function linkler(): JsonResponse
    {
        $d = []; foreach (self::AYARLAR as $k) $d[$k] = $this->ayar($k);
        return response()->json(['success' => true, 'data' => $d]);
    }

    /**
     * POST /api/game/hediye (sunucudan sunucuya) {kullanici_id, il, ilce, kitle, oyun_ref, hizmet_varsayilan}
     * Bölgedeki kotası olan sponsorun hizmetinden kupon üretir (yoksa Tarak'ın genel hediyesi). 30 gün geçerli.
     */
    public function hediye(Request $r): JsonResponse
    {
        if (!$this->sunucuMu($r)) return response()->json(['success' => false, 'message' => 'Yetkisiz.'], 401);
        $uid = (int) $r->input('kullanici_id');
        if (!User::whereKey($uid)->exists()) return response()->json(['success' => false, 'message' => 'Kullanıcı yok.'], 404);
        $ref = $r->input('oyun_ref');
        if ($ref && ($eski = DB::table('game_coupons')->where('game_ref', $ref)->first())) return response()->json(['success' => true, 'data' => $this->kuponDizi($eski)]);
        // Yılda bir hak (hesap başına)
        if (DB::table('game_coupons')->where('customer_user_id', $uid)->where('created_at', '>=', now()->startOfYear())->exists()) {
            return response()->json(['success' => false, 'message' => 'Bu yılın oyun hediyesi zaten alındı.'], 409);
        }
        $sec = $this->bolgeSponsorlari($r->input('il'), $r->input('ilce'), $r->input('kitle'))->first(fn ($s) => $this->kotaKaldi($s));
        $id = DB::table('game_coupons')->insertGetId([
            'code' => $this->kuponKodu(), 'customer_user_id' => $uid,
            'provider_user_id' => $sec->provider_user_id ?? null, 'sponsorship_id' => $sec->id ?? null,
            'service_name' => $sec->service_name ?? ((string) $r->input('hizmet_varsayilan') ?: 'Tarak hediyesi'),
            'status' => 'active', 'game_ref' => $ref, 'province' => $r->input('il'), 'district' => $r->input('ilce'),
            'expires_at' => now()->addDays(self::KUPON_GUN), 'created_at' => now(), 'updated_at' => now(),
        ]);
        return response()->json(['success' => true, 'data' => $this->kuponDizi(DB::table('game_coupons')->find($id))]);
    }

    /** POST /api/game/gosterim (sunucudan sunucuya) {kayitlar: [{sponsorluk_id, rota, gosterim, oyuncu}]} */
    public function gosterim(Request $r): JsonResponse
    {
        if (!$this->sunucuMu($r)) return response()->json(['success' => false, 'message' => 'Yetkisiz.'], 401);
        $gun = now()->toDateString(); $n = 0;
        foreach ((array) $r->input('kayitlar', []) as $k) {
            $sid = (int) ($k['sponsorluk_id'] ?? 0);
            if (!$sid || !DB::table('game_sponsorships')->where('id', $sid)->exists()) continue;
            $rota = mb_substr((string) ($k['rota'] ?? ''), 0, 120);
            $mevcut = DB::table('game_impressions')->where(['sponsorship_id' => $sid, 'day' => $gun, 'route' => $rota])->first();
            $g = max(0, (int) ($k['gosterim'] ?? 1)); $o = max(0, (int) ($k['oyuncu'] ?? 1));
            if ($mevcut) DB::table('game_impressions')->where('id', $mevcut->id)->update(['views' => $mevcut->views + $g, 'players' => $mevcut->players + $o, 'updated_at' => now()]);
            else DB::table('game_impressions')->insert(['sponsorship_id' => $sid, 'day' => $gun, 'route' => $rota, 'views' => $g, 'players' => $o, 'created_at' => now(), 'updated_at' => now()]);
            $n++;
        }
        return response()->json(['success' => true, 'data' => ['islenen' => $n]]);
    }

    private function kuponDizi(object $c): array
    {
        $sp = $c->sponsorship_id ? DB::table('game_sponsorships')->find($c->sponsorship_id) : null;
        return [
            'id' => $c->id, 'kod' => $c->code, 'hizmet' => $c->service_name, 'durum' => $c->status,
            'son_tarih' => (string) $c->expires_at, 'kullanildi' => $c->used_at ? (string) $c->used_at : null,
            'sponsor' => $sp ? $this->sponsorKarti($sp) : null,
        ];
    }

    // ---------------------------------------------------------------- müşteri
    /** GET /api/customer/game-coupons — "Oyundan kazandığın hediyeler" */
    public function musteriKuponlari(Request $r): JsonResponse
    {
        $this->sureleriGuncelle();
        $l = DB::table('game_coupons')->where('customer_user_id', $r->user()->id)->orderByDesc('id')->get()->map(fn ($c) => $this->kuponDizi($c));
        return response()->json(['success' => true, 'data' => $l]);
    }

    // ---------------------------------------------------------------- işletme ("Oyuna Sponsor Ol")
    public function isletmeSponsorluk(Request $r): JsonResponse
    {
        $uid = $r->user()->id;
        $l = DB::table('game_sponsorships')->where('provider_user_id', $uid)->orderByDesc('id')->get()->map(function ($s) {
            $s->bu_ay_kupon = DB::table('game_coupons')->where('sponsorship_id', $s->id)->where('created_at', '>=', now()->startOfMonth())->count();
            return $s;
        });
        $profil = DB::table('provider_profiles')->where('user_id', $uid)->value('id');
        $hizmetler = DB::table('provider_services')->join('services', 'services.id', '=', 'provider_services.service_id')
            ->where('provider_services.provider_profile_id', $profil)->where('provider_services.is_active', true)
            ->pluck('services.name')->unique()->values();
        return response()->json(['success' => true, 'data' => ['sponsorluklar' => $l, 'hizmetler' => $hizmetler]]);
    }

    public function isletmeSponsorlukKaydet(Request $r): JsonResponse
    {
        $v = $r->validate([
            'id' => 'nullable|integer',
            'service_name' => 'required|string|max:120',
            'audience' => 'required|in:erkek,kadin,hepsi',
            'scope' => 'required|in:district,city',
            'monthly_quota' => 'required|integer|min:1|max:500',
            'is_active' => 'boolean',
            'ends_on' => 'nullable|date',
        ]);
        $uid = $r->user()->id;
        $p = DB::table('provider_profiles')->where('user_id', $uid)->first(['city', 'district']);
        if (!$p || !$p->city) return response()->json(['success' => false, 'message' => 'Önce işletme adresinizi (il/ilçe) tamamlayın.'], 422);
        $satir = [
            'service_name' => $v['service_name'], 'audience' => $v['audience'], 'scope' => $v['scope'],
            'province' => $p->city, 'district' => $p->district, 'monthly_quota' => $v['monthly_quota'],
            'is_active' => $v['is_active'] ?? true, 'ends_on' => $v['ends_on'] ?? null, 'updated_at' => now(),
        ];
        if (!empty($v['id'])) {
            $n = DB::table('game_sponsorships')->where('id', $v['id'])->where('provider_user_id', $uid)->update($satir);
            if (!$n) return response()->json(['success' => false, 'message' => 'Bulunamadı.'], 404);
            $id = $v['id'];
        } else {
            $id = DB::table('game_sponsorships')->insertGetId($satir + ['provider_user_id' => $uid, 'starts_on' => now()->toDateString(), 'created_at' => now()]);
        }
        return response()->json(['success' => true, 'data' => DB::table('game_sponsorships')->find($id)]);
    }

    public function isletmeKuponlari(Request $r): JsonResponse
    {
        $this->sureleriGuncelle();
        $l = DB::table('game_coupons')->where('game_coupons.provider_user_id', $r->user()->id)
            ->join('users', 'users.id', '=', 'game_coupons.customer_user_id')
            ->orderByDesc('game_coupons.id')->limit(200)
            ->get(['game_coupons.*', 'users.first_name', 'users.last_name'])
            ->map(fn ($c) => $this->kuponDizi($c) + ['musteri' => trim($c->first_name . ' ' . mb_substr((string) $c->last_name, 0, 1) . '.')]);
        return response()->json(['success' => true, 'data' => $l]);
    }

    /** POST /api/provider/game-coupons/verify {kod, kullan: bool} — berber kuponu doğrular ve kullanıldı işaretler. */
    public function isletmeKuponDogrula(Request $r): JsonResponse
    {
        $this->sureleriGuncelle();
        $kod = strtoupper(trim((string) $r->input('kod')));
        $c = DB::table('game_coupons')->where('code', $kod)->where('provider_user_id', $r->user()->id)->first();
        if (!$c) return response()->json(['success' => false, 'message' => 'Bu kod sizin işletmenize ait değil ya da yok.'], 404);
        if ($c->status !== 'active') return response()->json(['success' => false, 'message' => $c->status === 'used' ? 'Kupon daha önce kullanılmış.' : 'Kuponun süresi dolmuş.', 'data' => $this->kuponDizi($c)], 409);
        if ($r->boolean('kullan')) {
            DB::table('game_coupons')->where('id', $c->id)->update(['status' => 'used', 'used_at' => now(), 'updated_at' => now()]);
            $c = DB::table('game_coupons')->find($c->id);
        }
        return response()->json(['success' => true, 'data' => $this->kuponDizi($c)]);
    }

    /** GET /api/provider/game-stats — reklamın kaç kez görüldüğü, hangi haritalarda, kaç oyuncu. */
    public function isletmeIstatistik(Request $r): JsonResponse
    {
        $ids = DB::table('game_sponsorships')->where('provider_user_id', $r->user()->id)->pluck('id');
        $q = fn () => DB::table('game_impressions')->whereIn('sponsorship_id', $ids);
        return response()->json(['success' => true, 'data' => [
            'toplam_gosterim' => (int) $q()->sum('views'),
            'toplam_oyuncu' => (int) $q()->sum('players'),
            'son_30_gun' => (int) $q()->where('day', '>=', now()->subDays(30)->toDateString())->sum('views'),
            'haritalar' => $q()->selectRaw('route, SUM(views) as gosterim, SUM(players) as oyuncu')->groupBy('route')->orderByDesc('gosterim')->limit(30)->get(),
            'gunluk' => $q()->where('day', '>=', now()->subDays(30)->toDateString())->selectRaw('day, SUM(views) as gosterim')->groupBy('day')->orderBy('day')->get(),
            'kuponlar' => [
                'toplam' => DB::table('game_coupons')->where('provider_user_id', $r->user()->id)->count(),
                'kullanilan' => DB::table('game_coupons')->where('provider_user_id', $r->user()->id)->where('status', 'used')->count(),
            ],
        ]]);
    }

    // ---------------------------------------------------------------- yönetici
    public function adminAyarlar(): JsonResponse
    {
        return $this->linkler();
    }

    public function adminAyarKaydet(Request $r): JsonResponse
    {
        $v = $r->validate([
            'link_ios' => 'nullable|url|max:500', 'link_android' => 'nullable|url|max:500', 'link_web' => 'nullable|url|max:500',
            'oyun_acik' => 'nullable|boolean', 'oyun_baslik' => 'nullable|string|max:120',
        ]);
        foreach ($v as $k => $deger) {
            DB::table('game_settings')->updateOrInsert(['key' => $k], ['value' => is_bool($deger) ? (int) $deger : $deger, 'updated_at' => now(), 'created_at' => now()]);
        }
        return $this->linkler();
    }

    public function adminIstatistik(): JsonResponse
    {
        $this->sureleriGuncelle();
        return response()->json(['success' => true, 'data' => [
            'bagli_oyuncu' => DB::table('game_auth_codes')->whereNotNull('used_at')->distinct('user_id')->count('user_id'),
            'kupon' => [
                'toplam' => DB::table('game_coupons')->count(),
                'aktif' => DB::table('game_coupons')->where('status', 'active')->count(),
                'kullanilan' => DB::table('game_coupons')->where('status', 'used')->count(),
                'suresi_dolan' => DB::table('game_coupons')->where('status', 'expired')->count(),
            ],
            'sponsor' => [
                'aktif' => DB::table('game_sponsorships')->where('is_active', true)->count(),
                'isletme' => DB::table('game_sponsorships')->distinct('provider_user_id')->count('provider_user_id'),
            ],
            'gosterim_30_gun' => (int) DB::table('game_impressions')->where('day', '>=', now()->subDays(30)->toDateString())->sum('views'),
            'bolgeler' => DB::table('game_coupons')->selectRaw('province, district, COUNT(*) as kupon')->groupBy('province', 'district')->orderByDesc('kupon')->limit(30)->get(),
        ]]);
    }
}
