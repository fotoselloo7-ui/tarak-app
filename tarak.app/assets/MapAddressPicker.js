import { r as React, j as jsx } from './react-vendor-Dj04zrcb.js?v=20261030-address-rules1';
import { M as Modal } from './index-Bj5sn6If.js?v=20261030-address-rules1';

let mapLibrePromise;

async function api(path) {
  const response = await fetch(path, { headers: { Accept: 'application/json' } });
  const body = await response.json().catch(() => ({}));
  if (!response.ok || !body.success) throw new Error(body.message || 'Adres servisine ulaşılamıyor.');
  return body.data;
}

async function loadMapLibre() {
  if (!document.querySelector('link[data-tarak-maplibre]')) {
    const css = document.createElement('link');
    css.rel = 'stylesheet';
    css.href = 'https://unpkg.com/maplibre-gl@6.16.0/dist/maplibre-gl.css';
    css.dataset.tarakMaplibre = '1';
    document.head.appendChild(css);
  }

  if (!mapLibrePromise) {
    mapLibrePromise = import('https://unpkg.com/maplibre-gl@6.16.0/dist/maplibre-gl.mjs')
      .catch(error => {
        mapLibrePromise = null;
        throw error;
      });
  }
  return mapLibrePromise;
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
    const lat = Number(address.latitude);
    const lng = Number(address.longitude);
    if (!Number.isFinite(lat) || !Number.isFinite(lng)) return;
    map.current?.easeTo({ center: [lng, lat], zoom: 16, duration: 350 });
    marker.current?.setLngLat([lng, lat]);
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
    if (trimmed.length < 3) {
      setError('Aramak için en az 3 karakter yazın.');
      return;
    }
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
    const latitude = Number(initialLatitude);
    const longitude = Number(initialLongitude);
    const hasPosition = Number.isFinite(latitude) && Number.isFinite(longitude)
      && initialLatitude !== null && initialLatitude !== undefined
      && initialLongitude !== null && initialLongitude !== undefined;

    loadMapLibre().then(maplibregl => {
      if (!active || !mapElement.current) return;
      const center = hasPosition ? [longitude, latitude] : [32.0, 39.0];

      map.current = new maplibregl.Map({
        container: mapElement.current,
        style: 'https://tiles.openfreemap.org/styles/liberty',
        center,
        zoom: hasPosition ? 16 : 5.5,
        attributionControl: true,
      });

      map.current.addControl(new maplibregl.NavigationControl({ showCompass: false }), 'top-right');

      marker.current = new maplibregl.Marker({ draggable: true })
        .setLngLat(center)
        .addTo(map.current);

      marker.current.on('dragend', () => {
        const point = marker.current?.getLngLat();
        if (point) reverse(point.lat, point.lng);
      });

      map.current.on('click', event => {
        marker.current?.setLngLat(event.lngLat);
        reverse(event.lngLat.lat, event.lngLat.lng);
      });

      map.current.once('load', () => {
        if (!active) return;
        setReady(true);
        if (initialQuery.trim().length >= 3) search(initialQuery);
        else if (hasPosition) reverse(latitude, longitude);
        else setBusy(false);
      });
    }).catch(() => {
      if (active) {
        setError('Harita yüklenemedi. İnternet bağlantınızı kontrol edin.');
        setBusy(false);
      }
    });

    return () => {
      active = false;
      lookupSequence.current++;
      marker.current?.remove();
      map.current?.remove();
      marker.current = null;
      map.current = null;
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
      jsx.jsx('div', { ref: mapElement, className: 'mx-4 rounded-xl bg-gray-100 overflow-hidden', style: {height: '45vh', minHeight: 260, maxHeight: 430}, 'aria-label': 'Sürüklenebilir konum haritası' }),
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
