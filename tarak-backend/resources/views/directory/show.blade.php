@extends('directory.layout')

@section('title', "{$displayName} — {$typeLabel} | Tarak Rehber")
@section('description', $profile->bio ? \Illuminate\Support\Str::limit($profile->bio, 155) : "{$displayName} ({$typeLabel}) hizmetleri, çalışma saatleri ve çalışma galerisi.")
@section('canonical', $canonicalUrl)
@section('og_type', 'business.business')

@push('head')
@if($profile->cover_url || $profile->pinImageUrl())
<meta property="og:image" content="{{ \App\Support\MediaUrl::resolve($profile->cover_url) ?: $profile->pinImageUrl() }}">
@endif
<script type="application/ld+json">{!! $schemaJson !!}</script>
@if($hasPublicPin)
<link rel="stylesheet" href="https://unpkg.com/maplibre-gl@4.7.1/dist/maplibre-gl.css" crossorigin="anonymous">
@endif
<style>
    .cover-banner {
        width: 100%; height: 220px; border-radius: 16px; object-fit: cover; margin-bottom: 18px;
    }
    .profile-header { display: flex; gap: 16px; align-items: flex-start; flex-wrap: wrap; }
    .profile-logo {
        width: 80px; height: 80px; border-radius: 18px; object-fit: cover; background: #FFF7ED;
        display: flex; align-items: center; justify-content: center; font-size: 28px; font-weight: 800; color: var(--primary);
    }
    .two-col { display: grid; grid-template-columns: 2fr 1fr; gap: 20px; margin-top: 20px; }
    @media (max-width: 820px) { .two-col { grid-template-columns: 1fr; } }
    .hours-table { width: 100%; border-collapse: collapse; font-size: 14px; }
    .hours-table td { padding: 7px 0; border-bottom: 1px solid #F1F5F9; }
    .gallery-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(150px, 1fr)); gap: 10px; }
    .gallery-grid img { width: 100%; height: 140px; object-fit: cover; border-radius: 12px; }
    #business-map { width: 100%; height: 240px; border-radius: 14px; overflow: hidden; border: 1px solid var(--border); }
</style>
@endpush

@section('content')
<div style="margin-bottom: 12px; font-size: 13px; color: var(--muted);">
    <a href="{{ url('/isletmeler') }}">← Tüm İşletmeler</a>
</div>

<article class="card">
    @if($profile->cover_url)
        <img src="{{ \App\Support\MediaUrl::resolve($profile->cover_url) }}" alt="{{ $displayName }} kapak görseli" class="cover-banner">
    @endif

    <div class="profile-header">
        @if($profile->pinImageUrl())
            <img src="{{ $profile->pinImageUrl() }}" alt="{{ $displayName }} logosu" class="profile-logo">
        @else
            <div class="profile-logo" aria-hidden="true">{{ mb_strtoupper(mb_substr($displayName, 0, 1)) }}</div>
        @endif

        <div style="flex: 1; min-width: 220px;">
            <h1 style="margin: 0 0 6px;">{{ $displayName }}</h1>
            <div style="display: flex; flex-wrap: wrap; gap: 8px; align-items: center; margin-bottom: 8px;">
                <span class="badge">{{ $typeLabel }}</span>
                @if($profile->isVerified())
                    <span class="badge badge-verified">✓ Tarak Doğrulanmış</span>
                @endif
                @if($profile->canAcceptTarakBookings())
                    <span class="badge badge-booking">Tarak Üzerinden Randevu</span>
                @else
                    <span class="badge">İşletme Rehberi Kaydı</span>
                @endif
                @if($profile->work_mode === 'mobile')
                    <span class="badge">Adreste Hizmet</span>
                @elseif($profile->work_mode === 'venue')
                    <span class="badge">İşletmede Hizmet</span>
                @else
                    <span class="badge">İşletmede &amp; Adreste Hizmet</span>
                @endif
            </div>
            @if($publicAddress)
                <p style="margin: 0; color: var(--muted); font-size: 14px;">{{ $publicAddress }}</p>
            @endif
            @if($ratingAvg !== null && $reviewCount > 0)
                <p style="margin: 6px 0 0; font-weight: 700; font-size: 14px;">Tarak Puanı: {{ number_format($ratingAvg, 1) }}/5 ({{ $reviewCount }} değerlendirme)</p>
            @endif
        </div>

        @if($hasPublicPin)
            <a class="btn btn-primary" target="_blank" rel="noopener noreferrer"
               href="https://www.openstreetmap.org/directions?to={{ $profile->latitude }}%2C{{ $profile->longitude }}">
                Yol Tarifi Al
            </a>
        @endif
    </div>

    @if($profile->bio)
        <p style="margin-top: 16px; color: #334155;">{{ $profile->bio }}</p>
    @endif
</article>

<div class="two-col">
    <div class="grid">
        @if($activeServices->isNotEmpty())
        <section class="card">
            <h2 style="margin-top: 0; font-size: 18px;">Hizmetler</h2>
            @foreach($activeServices as $ps)
                <div style="display: flex; justify-content: space-between; padding: 10px 0; border-bottom: 1px solid #F1F5F9;">
                    <div>
                        <strong>{{ $ps->service->name }}</strong>
                        @if($ps->description)
                            <div style="font-size: 13px; color: var(--muted);">{{ $ps->description }}</div>
                        @endif
                        <div style="font-size: 12px; color: var(--muted);">{{ max(15, $ps->effectiveDurationMinutes()) }} dk</div>
                    </div>
                    <strong style="color: var(--primary);">₺{{ number_format($ps->effectivePrice(), 0, ',', '.') }}</strong>
                </div>
            @endforeach
        </section>
        @endif

        @if(!empty($gallery))
        <section class="card">
            <h2 style="margin-top: 0; font-size: 18px;">Galeri</h2>
            <div class="gallery-grid">
                @foreach($gallery as $imgUrl)
                    <img src="{{ $imgUrl }}" alt="{{ $displayName }} çalışma görseli" loading="lazy">
                @endforeach
            </div>
        </section>
        @endif

        @if($reviews->isNotEmpty())
        <section class="card">
            <h2 style="margin-top: 0; font-size: 18px;">Müşteri Değerlendirmeleri</h2>
            @foreach($reviews as $rev)
                <div style="padding: 10px 0; border-bottom: 1px solid #F1F5F9;">
                    <div style="display: flex; justify-content: space-between; font-size: 14px; font-weight: 700;">
                        <span>{{ $rev->customer?->name ?? 'Müşteri' }}</span>
                        <span>Tarak Puanı: {{ $rev->rating }}/5</span>
                    </div>
                    @if($rev->comment)
                        <p style="margin: 4px 0 0; font-size: 14px; color: var(--muted);">{{ \App\Support\CustomerNote::forDisplay($rev->comment) }}</p>
                    @endif
                </div>
            @endforeach
        </section>
        @endif
    </div>

    <aside class="grid" style="align-content: start;">
        <section class="card">
            <h2 style="margin-top: 0; font-size: 17px;">Konum ve Hizmet Alanı</h2>
            @if($hasPublicPin)
                <div id="business-map" aria-label="{{ $displayName }} konumu"></div>
                <p style="margin: 10px 0 0; font-size: 13px; color: var(--muted);">{{ $publicAddress }}</p>
            @else
                <p style="margin: 0; font-size: 13px; color: var(--muted);">
                    Bu uzman adreste hizmet vermektedir. Gizlilik gereği açık adres ve ev pini yayınlanmaz.
                </p>
            @endif
            @if($profile->work_mode !== 'venue')
                <p style="margin: 10px 0 0; font-size: 13px; font-weight: 600;">Hizmet yarıçapı: {{ (int) ($profile->service_radius_km ?: 15) }} km</p>
            @endif
            @if($profile->serviceAreas->isNotEmpty())
                <div style="display: flex; flex-wrap: wrap; gap: 6px; margin-top: 10px;">
                    @foreach($profile->serviceAreas as $area)
                        <span class="badge">{{ $area->neighborhood ? "{$area->neighborhood}, " : '' }}{{ $area->district }} / {{ $area->province }}</span>
                    @endforeach
                </div>
            @endif
        </section>

        <section class="card">
            <h2 style="margin-top: 0; font-size: 17px;">Çalışma Saatleri</h2>
            <table class="hours-table">
                @foreach($workingHours as $wh)
                    <tr>
                        <td><strong>{{ $wh['label'] }}</strong></td>
                        <td style="text-align: right; color: var(--muted);">
                            {{ $wh['enabled'] && $wh['start_time'] && $wh['end_time'] ? "{$wh['start_time']} - {$wh['end_time']}" : 'Kapalı' }}
                        </td>
                    </tr>
                @endforeach
            </table>
        </section>
    </aside>
</div>

@if($hasPublicPin)
<script src="https://unpkg.com/maplibre-gl@4.7.1/dist/maplibre-gl.js" crossorigin="anonymous"></script>
<script>
document.addEventListener('DOMContentLoaded', function () {
    if (!window.maplibregl) return;
    var lat = {{ (float) $profile->latitude }};
    var lng = {{ (float) $profile->longitude }};
    var map = new maplibregl.Map({
        container: 'business-map',
        style: 'https://tiles.openfreemap.org/styles/liberty',
        center: [lng, lat],
        zoom: 15
    });
    new maplibregl.Marker({ color: '#F97316' }).setLngLat([lng, lat]).addTo(map);
});
</script>
@endif
@endsection
