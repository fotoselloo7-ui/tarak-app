import { r as React, j as jsx } from './react-vendor-Dj04zrcb.js?v=20261028-integrations1';
import { M as Modal } from './index-Bj5sn6If.js?v=20261028-integrations1';

let mapsPromise;

async function api(path) {
  const response = await fetch(path, { headers: { Accept: 'application/json' } });
  const body = await response.json().catch(() => ({}));
  if (!response.ok || !body.success) throw new Error(body.message || 'Adres servisine ulaşılamıyor.');
  return body.data;
}

async function loadMaps() {
  const { browser_key: key, map_id: mapId } = await api('/api/geo/config');
  if (!key) throw new Error('Google Maps tarayıcı anahtarı yapılandırılmadı.');
  if (window.google?.maps) return { maps: window.google.maps, mapId };
  if (!mapsPromise) {
    mapsPromise = new Promise((resolve, reject) => {
      const script = document.createElement('script');
      script.src = `https://maps.googleapis.com/maps/api/js?key=${encodeURIComponent(key)}&language=tr&region=TR&loading=async`;
      script.async = true;
      script.onload = () => window.google?.maps ? resolve(window.google.maps) : reject(new Error('Google Maps yüklenemedi.'));
      script.onerror = () => reject(new Error('Google Maps yüklenemedi. API anahtarı ve ağ bağlantısını kontrol edin.'));
      document.head.appendChild(script);
    }).catch(error => { mapsPromise = null; throw error; });
  }
  return { maps: await mapsPromise, mapId };
}

/** Existing address forms stay in charge of editing and saving the selected fields. */
export function MapAddressPicker({ onClose, onSelect, initialLatitude, initialLongitude, initialQuery = '' }) {
  const mapElement = React.useRef(null);
  const map = React.useRef(null);
  const marker = React.useRef(null);
  const lookupSequence = React.useRef(0);
  const [query, setQuery] = React.useState(initialQuery);
  const [selected, setSelected] = React.useState(null);
  const [busy, setBusy] = React.useState(true);
  const [error, setError] = React.useState('');
  const [ready, setReady] = React.useState(false);

  const place = React.useCallback((address) => {
    const position = { lat: Number(address.latitude), lng: Number(address.longitude) };
    if (!Number.isFinite(position.lat) || !Number.isFinite(position.lng)) return;
    map.current?.panTo(position);
    map.current?.setZoom(16);
    marker.current?.setPosition(position);
    setSelected(address);
    setError('');
  }, []);

  const reverse = React.useCallback(async (lat, lng) => {
    const sequence = ++lookupSequence.current;
    setBusy(true);
    setError('');
    setSelected(null);
    try {
      const address = await api(`/api/geo/reverse?lat=${encodeURIComponent(lat)}&lng=${encodeURIComponent(lng)}`);
      if (sequence === lookupSequence.current) place(address);
    } catch (reason) {
      if (sequence === lookupSequence.current) {
        setSelected(null);
        setError(reason.message || 'Bu noktanın adresi çözümlenemedi. Başka bir nokta deneyin.');
      }
    } finally {
      if (sequence === lookupSequence.current) setBusy(false);
    }
  }, [place]);

  const search = React.useCallback(async (value) => {
    const trimmed = value.trim();
    if (trimmed.length < 3) { setError('Aramak için en az 3 karakter yazın.'); return; }
    const sequence = ++lookupSequence.current;
    setBusy(true);
    setError('');
    setSelected(null);
    try {
      const address = await api(`/api/geo/search?q=${encodeURIComponent(trimmed)}`);
      if (sequence === lookupSequence.current) place(address);
    } catch (reason) {
      if (sequence === lookupSequence.current) setError(reason.message || 'Adres bulunamadı.');
    } finally {
      if (sequence === lookupSequence.current) setBusy(false);
    }
  }, [place]);

  React.useEffect(() => {
    let active = true;
    const latitude = Number(initialLatitude), longitude = Number(initialLongitude);
    const hasPosition = Number.isFinite(latitude) && Number.isFinite(longitude)
      && initialLatitude !== null && initialLatitude !== undefined
      && initialLongitude !== null && initialLongitude !== undefined;
    loadMaps().then(({ maps, mapId }) => {
      if (!active || !mapElement.current) return;
      const center = hasPosition ? { lat: latitude, lng: longitude } : { lat: 41.0082, lng: 28.9784 };
      map.current = new maps.Map(mapElement.current, {
        center, zoom: hasPosition ? 16 : 10,
        ...(mapId ? { mapId } : {}),
        streetViewControl: true,
        mapTypeControl: false,
      });
      marker.current = new maps.Marker({ map: map.current, position: center, draggable: true });
      setReady(true);
      map.current.addListener('click', event => {
        const point = event.latLng;
        marker.current?.setPosition(point);
        reverse(point.lat(), point.lng());
      });
      marker.current.addListener('dragend', event => reverse(event.latLng.lat(), event.latLng.lng()));
      if (initialQuery.trim().length >= 3) search(initialQuery);
      else if (hasPosition) reverse(latitude, longitude);
      else setBusy(false);
    }).catch(reason => { if (active) { setError(reason.message); setBusy(false); } });
    return () => {
      active = false; lookupSequence.current++;
      window.google?.maps?.event?.clearInstanceListeners(marker.current);
      window.google?.maps?.event?.clearInstanceListeners(map.current);
      marker.current?.setMap(null);
    };
  }, []);

  return jsx.jsxs(Modal, {
    onClose,
    role: 'dialog', 'aria-modal': true, 'aria-label': 'Haritadan adres seç',
    className: 'fixed inset-0 flex items-center justify-center p-3 sm:p-5',
    style: {backgroundColor: 'rgba(0,0,0,.55)'},
    onMouseDown: event => { if (event.target === event.currentTarget) onClose(); },
    children: [jsx.jsxs('div', { className: 'w-full max-w-2xl rounded-2xl bg-white shadow-2xl overflow-hidden', children: [
      jsx.jsxs('div', { className: 'flex items-center justify-between px-4 sm:px-5 py-3 border-b border-gray-100', children: [
        jsx.jsx('h3', { className: 'font-bold text-gray-900', children: 'Haritadan Adres Seç' }),
        jsx.jsx('button', { type: 'button', onClick: onClose, 'aria-label': 'Kapat', className: 'text-gray-500 hover:text-gray-900 text-2xl leading-none', children: '×' }),
      ] }),
      jsx.jsxs('form', { className: 'flex gap-2 p-4 pb-2', onSubmit: event => { event.preventDefault(); event.stopPropagation(); if (ready) search(query); }, children: [
        jsx.jsx('input', { value: query, disabled: !ready, onChange: event => setQuery(event.target.value), placeholder: 'Adres, mahalle veya sokak ara', 'aria-label': 'Adres ara', className: 'flex-1 min-w-0 rounded-xl border border-gray-300 px-3 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-[#FF5722]' }),
        jsx.jsx('button', { type: 'submit', disabled: busy || !ready, className: 'rounded-xl bg-[#FF5722] px-4 py-2.5 text-sm font-semibold text-white disabled:opacity-60', children: 'Ara' }),
      ] }),
      jsx.jsx('div', { ref: mapElement, className: 'mx-4 rounded-xl bg-gray-100', style: {height: '45vh', minHeight: 260, maxHeight: 430}, 'aria-label': 'Sürüklenebilir konum haritası' }),
      jsx.jsxs('div', { className: 'px-4 sm:px-5 py-3', children: [
        jsx.jsx('p', { className: 'text-xs text-gray-500', children: 'Haritaya dokunun veya pini sürükleyin. Eksik adres alanlarını formda düzenleyebilirsiniz.' }),
        busy && jsx.jsx('p', { role: 'status', className: 'mt-2 text-xs text-gray-600', children: 'Adres aranıyor…' }),
        error && jsx.jsx('p', { role: 'alert', className: 'mt-2 text-xs text-red-700', children: error }),
        selected && jsx.jsx('p', { className: 'mt-2 text-sm font-medium text-gray-800', children: selected.formatted_address || [selected.street, selected.neighborhood, selected.district, selected.province].filter(Boolean).join(', ') }),
      ] }),
      jsx.jsxs('div', { className: 'flex justify-end gap-2 px-4 sm:px-5 pb-4', children: [
        jsx.jsx('button', { type: 'button', onClick: onClose, className: 'rounded-xl border border-gray-300 px-4 py-2.5 text-sm font-semibold text-gray-700', children: 'Vazgeç' }),
        jsx.jsx('button', { type: 'button', disabled: !selected || busy, onClick: () => { onSelect(selected); onClose(); }, className: 'rounded-xl bg-[#FF5722] px-4 py-2.5 text-sm font-semibold text-white disabled:opacity-50', children: 'Adresi Kullan' }),
      ] }),
    ] }) ],
  });
}
