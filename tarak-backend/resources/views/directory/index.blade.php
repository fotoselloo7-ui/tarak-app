@extends('directory.layout')

@section('title', 'Tarak Harita ve İşletme Rehberi — Berber ve Kuaförler')
@section('description', 'Şehre ve hizmet türüne göre berber ve kuaför işletmelerini keşfedin, adres, çalışma saatleri ve hizmet bilgilerini inceleyin.')
@section('canonical', $canonicalUrl)

@push('head')
<link rel="stylesheet" href="https://unpkg.com/maplibre-gl@4.7.1/dist/maplibre-gl.css" crossorigin="anonymous">
<style>
    .filter-form { display: flex; flex-wrap: wrap; gap: 10px; margin: 18px 0; }
    .filter-form input, .filter-form select {
        padding: 10px 12px;
        border: 1px solid var(--border);
        border-radius: 10px;
        font-size: 14px;
        background: #fff;
        min-width: 180px;
    }
    #directory-map {
        width: 100%;
        height: 360px;
        border-radius: 16px;
        overflow: hidden;
        border: 1px solid var(--border);
        margin-bottom: 24px;
        background: #E2E8F0;
    }
    .biz-card { display: flex; flex-direction: column; gap: 10px; }
    .biz-head { display: flex; gap: 12px; align-items: center; }
    .biz-avatar {
        width: 52px; height: 52px; border-radius: 12px; object-fit: cover;
        background: #FFF7ED; display: flex; align-items: center; justify-content: center;
        font-weight: 800; color: var(--primary); flex-shrink: 0;
    }
    .pagination { margin-top: 24px; display: flex; gap: 8px; flex-wrap: wrap; }
</style>
@endpush

@section('content')
<h1>Tarak Harita ve İşletme Rehberi</h1>
<p style="color: var(--muted); margin-top: 4px;">Yakınınızdaki berber ve kuaför işletmelerini harita ve rehber üzerinden keşfedin.</p>

<form method="get" action="{{ url('/isletmeler') }}" class="filter-form" role="search">
    <input type="search" name="q" value="{{ $q }}" placeholder="İşletme adı, ilçe veya hizmet ara" aria-label="İşletme ara">
    <select name="city" aria-label="Şehir seçin">
        <option value="">Tüm Şehirler</option>
        @foreach($cities as $c)
            <option value="{{ $c }}" @selected($city === $c)>{{ $c }}</option>
        @endforeach
    </select>
    <select name="type" aria-label="Hizmet türü seçin">
        <option value="">Tümü (Berber &amp; Kuaför)</option>
        <option value="barber" @selected($type === 'barber')>Erkek Berberi</option>
        <option value="coiffeur" @selected($type === 'coiffeur')>Kadın Kuaförü</option>
    </select>
    <button type="submit" class="btn btn-primary">Filtrele</button>
</form>

@if($mapPins->isNotEmpty())
<div id="directory-map" aria-label="İşletmeler Haritası"></div>
@endif

@if($businesses->isEmpty())
    <div class="card">
        <p style="margin: 0; color: var(--muted);">Aramanıza uygun yayınlanmış işletme bulunamadı.</p>
    </div>
@else
    <div class="grid grid-cards">
        @foreach($businesses as $profile)
            @php
                $name = $profile->business_name ?: ($profile->user?->name ?: 'İşletme');
                $stat = $reviewStats->get($profile->user_id);
                $count = (int) ($stat->review_total ?? 0);
                $avg = $count > 0 ? number_format((float) $stat->review_avg, 1) : null;
                $photo = $profile->pinImageUrl();
            @endphp
            <article class="card biz-card">
                <div class="biz-head">
                    @if($photo)
                        <img src="{{ $photo }}" alt="{{ $name }}" class="biz-avatar" loading="lazy">
                    @else
                        <div class="biz-avatar" aria-hidden="true">{{ mb_strtoupper(mb_substr($name, 0, 1)) }}</div>
                    @endif
                    <div>
                        <h2 style="margin: 0; font-size: 16px;">
                            <a href="{{ url('/isletme/' . $profile->slug) }}">{{ $name }}</a>
                        </h2>
                        <div style="font-size: 13px; color: var(--muted);">
                            {{ $profile->provider_type === 'coiffeur' ? 'Kadın Kuaförü' : 'Erkek Berberi' }}
                            @if($profile->isVerified())
                                · <span style="color: var(--verified); font-weight: 700;">Doğrulanmış</span>
                            @endif
                        </div>
                    </div>
                </div>
                @if($profile->publicFormattedAddress())
                    <div style="font-size: 13px; color: var(--muted);">{{ $profile->publicFormattedAddress() }}</div>
                @endif
                <div style="display: flex; justify-content: space-between; align-items: center; margin-top: auto;">
                    <span style="font-size: 13px; font-weight: 700;">
                        {{ $avg ? "Tarak Puanı: {$avg} ({$count})" : 'Yeni işletme' }}
                    </span>
                    <a href="{{ url('/isletme/' . $profile->slug) }}" class="btn btn-outline" style="padding: 6px 12px; font-size: 13px;">Profili Gör</a>
                </div>
            </article>
        @endforeach
    </div>

    <div class="pagination">
        @if($businesses->previousPageUrl())
            <a class="btn btn-outline" href="{{ $businesses->previousPageUrl() }}">Önceki</a>
        @endif
        @if($businesses->nextPageUrl())
            <a class="btn btn-outline" href="{{ $businesses->nextPageUrl() }}">Sonraki</a>
        @endif
    </div>
@endif

@if($mapPins->isNotEmpty())
<script src="https://unpkg.com/maplibre-gl@4.7.1/dist/maplibre-gl.js" crossorigin="anonymous"></script>
<script>
document.addEventListener('DOMContentLoaded', function () {
    if (!window.maplibregl) return;
    var pins = @json($mapPins);
    if (!pins.length) return;
    var map = new maplibregl.Map({
        container: 'directory-map',
        style: 'https://tiles.openfreemap.org/styles/liberty',
        center: [pins[0].lng, pins[0].lat],
        zoom: 11
    });
    map.addControl(new maplibregl.NavigationControl(), 'top-right');
    var bounds = new maplibregl.LngLatBounds();
    pins.forEach(function (pin) {
        bounds.extend([pin.lng, pin.lat]);
        var el = document.createElement('div');
        el.style.width = '18px';
        el.style.height = '18px';
        el.style.borderRadius = '999px';
        el.style.background = pin.type === 'coiffeur' ? '#0F172A' : '#F97316';
        el.style.border = '2px solid #FFFFFF';
        el.style.boxShadow = '0 2px 6px rgba(0,0,0,0.25)';
        var popup = new maplibregl.Popup({ offset: 14 }).setHTML(
            '<div style="font-family:sans-serif;max-width:220px;">' +
            '<strong>' + (pin.name || '') + '</strong><br>' +
            '<span style="font-size:12px;color:#64748B;">' + (pin.address || '') + '</span><br>' +
            '<a href="' + pin.url + '" style="display:inline-block;margin-top:6px;color:#F97316;font-weight:700;font-size:12px;">İşletme Sayfasına Git →</a>' +
            '</div>'
        );
        new maplibregl.Marker({ element: el }).setLngLat([pin.lng, pin.lat]).setPopup(popup).addTo(map);
    });
    if (pins.length > 1) {
        map.fitBounds(bounds, { padding: 48, maxZoom: 14 });
    }
});
</script>
@endif
@endsection
