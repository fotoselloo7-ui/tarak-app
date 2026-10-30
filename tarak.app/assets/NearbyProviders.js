import {r as React} from './react-vendor-Dj04zrcb.js?v=20261030-address-rules1';
const h = React.createElement;

export function NearbyProviders({api, renderCard, onEditAddress, gender = null, embedded = false}) {
  const type = gender === 'female' ? 'coiffeur' : gender === 'male' ? 'barber' : null;
  const [refresh, setRefresh] = React.useState(0);
  React.useEffect(() => {
    const update = () => { setOrigin(null); setPage(1); setRefresh(value => value + 1); };
    window.addEventListener('tarak:addresses-changed', update);
    return () => window.removeEventListener('tarak:addresses-changed', update);
  }, []);
  const [radius, setRadius] = React.useState(10);
  const [origin, setOrigin] = React.useState(null);
  const [data, setData] = React.useState([]);
  const [page, setPage] = React.useState(1);
  const [meta, setMeta] = React.useState(null);
  const [loading, setLoading] = React.useState(false);
  const [locating, setLocating] = React.useState(false);
  const [error, setError] = React.useState('');
  React.useEffect(() => {
    let active = true;
    const timer = setTimeout(async () => {
      setLoading(true); setError('');
      const params = new URLSearchParams({radius_km: String(radius), per_page: '8', page: String(page)});
      if (type) params.set('type', type);
      if (origin) { params.set('lat', String(origin.lat)); params.set('lng', String(origin.lng)); }
      try {
        const result = await api.get(`/customer/providers/nearby?${params}`);
        if (active) { setData(result.data); setMeta(result.meta); }
      } catch (failure) { if (active) { setError(failure.message); setData([]); setMeta(null); } }
      finally { if (active) setLoading(false); }
    }, 300);
    return () => { active = false; clearTimeout(timer); };
  }, [api, radius, origin, page, type, refresh]);
  const locate = () => {
    if (!navigator.geolocation) { setError('Tarayıcınız konum servisini desteklemiyor. Kayıtlı adresinizi kullanabilirsiniz.'); return; }
    setLocating(true);
    navigator.geolocation.getCurrentPosition(position => {
      setOrigin({lat: position.coords.latitude, lng: position.coords.longitude}); setPage(1); setLocating(false);
    }, () => { setLocating(false); setError('Konum izni alınamadı. Kayıtlı adresinizi kullanabilirsiniz.'); },
    {enableHighAccuracy: false, timeout: 10000, maximumAge: 300000});
  };
  return h('section', {id: 'nearby-providers', className: embedded ? '' : 'py-5 sm:py-7 bg-white'},
    h('div', {className: embedded ? '' : 'max-w-[1200px] mx-auto px-4 sm:px-6'},
      h('h2', {className: 'text-xl sm:text-2xl font-extrabold text-gray-950 tracking-tight'}, type === 'barber' ? 'Size Yakın Berberler' : 'Size Yakın Kuaförler'),
      h('p', {className: 'text-gray-500 text-sm mt-1.5'}, origin ? 'İzin verdiğiniz cihaz konumuna göre sıralanır.' : 'Kayıtlı adresinize göre en yakından uzağa sıralanır.'),
      h('div', {className: 'flex flex-wrap items-center gap-3 my-4'},
        h('label', {htmlFor: 'nearby-radius', className: 'text-sm font-semibold text-gray-700'}, `Mesafe: ${radius} km`),
        h('input', {id: 'nearby-radius', type: 'range', min: 1, max: 50, step: 1, value: radius,
          onChange: event => { setRadius(Number(event.target.value)); setPage(1); }, style: {accentColor: '#FF5722', flex: '1 1 180px', maxWidth: 360}}),
        h('button', {type: 'button', onClick: locate, disabled: locating,
          className: 'px-3 py-2 border border-gray-200 rounded-xl text-xs font-semibold text-brand-orange'}, locating ? 'Konum alınıyor…' : 'Cihaz konumumu kullan'),
        origin && h('button', {type: 'button', onClick: () => { setOrigin(null); setPage(1); }, className: 'text-xs font-semibold text-gray-600 underline'}, 'Kayıtlı adresimi kullan')),
      error && h('div', {role: 'alert', className: 'p-4 rounded-xl bg-orange-50 text-sm text-gray-700'},
        error, ' ', h('button', {type: 'button', onClick: onEditAddress, className: 'font-semibold text-brand-orange underline'}, 'Adresimi düzenle')),
      loading && h('p', {role: 'status', className: 'text-sm text-gray-500 py-3'}, 'Yakındaki hizmet verenler yükleniyor…'),
      !loading && !error && data.length === 0 && h('p', {className: 'text-sm text-gray-500 py-4'}, 'Seçtiğiniz mesafede konumu kayıtlı hizmet veren bulunamadı.'),
      h('div', {className: 'grid grid-cols-2 lg:grid-cols-4 gap-3 sm:gap-4', 'aria-busy': loading}, data.map(provider => h(React.Fragment, {key: provider.user_id}, renderCard(provider)))),
      meta?.last_page > 1 && h('div', {className: 'flex items-center justify-center gap-4 mt-4'},
        h('button', {type: 'button', disabled: page <= 1 || loading, onClick: () => setPage(value => value - 1), className: 'text-sm font-semibold text-brand-orange disabled:opacity-50'}, 'Önceki'),
        h('span', {className: 'text-xs text-gray-500'}, `${page} / ${meta.last_page}`),
        h('button', {type: 'button', disabled: page >= meta.last_page || loading, onClick: () => setPage(value => value + 1), className: 'text-sm font-semibold text-brand-orange disabled:opacity-50'}, 'Sonraki'))));
}
