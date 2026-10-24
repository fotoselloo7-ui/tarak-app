/* Tarak secure web onboarding. No credentials or provider secrets shipped. */
(function () {
  'use strict';
  var $ = function (id) { return document.getElementById(id); };
  var state = { challenge: null, proof: null, verifiedEmail: null, pin: null, map: null, marker: null, geocoder: null, config: {} };
  var status = function (msg, good) {
    var el = $('status'); el.textContent = msg; el.classList.add('show');
    el.style.background = good ? '#ecfbf1' : '#fff4eb';
  };
  async function api(route, payload) {
    var response = await fetch('/api/auth/' + route, {
      method: 'POST', headers: {'Accept':'application/json','Content-Type':'application/json'},
      credentials: 'same-origin', body: JSON.stringify(payload)
    });
    var data = await response.json().catch(function () { return { message:'Sunucudan geçersiz yanıt alındı.' }; });
    if (!response.ok || data.success === false) throw new Error(data.message || 'Sunucu hatası');
    return data.data || {};
  }
  $('role').addEventListener('change', function () { $('business-area').hidden = $('role').value !== 'PROVIDER'; });
  if (new URLSearchParams(location.search).get('role') === 'PROVIDER') {
    $('role').value = 'PROVIDER'; $('business-area').hidden = false;
  }
  $('email').addEventListener('input', function () { state.proof = null; state.verifiedEmail = null; });
  $('send-code').addEventListener('click', async function () {
    try {
      $('send-code').disabled = true;
      var result = await api('registration/start', { email: $('email').value.trim() });
      state.challenge = result.challenge_id; state.proof = null;
      status('Kod e-posta adresinize gönderildi. Gelen kutunuzu kontrol edin.', true);
    } catch (e) { status(e.message); }
    finally { $('send-code').disabled = false; }
  });
  $('verify-code').addEventListener('click', async function () {
    try {
      if (!state.challenge) throw new Error('Önce kod isteyin.');
      var email = $('email').value.trim();
      var result = await api('registration/confirm', {
        challenge_id: state.challenge, email: email, code: $('code').value.trim()
      });
      state.proof = result.registration_proof; state.verifiedEmail = email;
      status('E-posta doğrulandı. Adres ve bilgilerinizi onaylayın.', true);
    } catch (e) { status(e.message); }
  });

  function appendScript(url) { return new Promise(function (resolve, reject) {
    var s = document.createElement('script'); s.src = url; s.async = true;
    s.onload = resolve; s.onerror = reject; document.head.appendChild(s);
  }); }
  function mapPin(position) {
    var google = window.google;
    if (!google || !google.maps || !state.map) return;
    if (state.marker) state.marker.setMap(null);
    state.marker = new google.maps.Marker({map: state.map, position:position, draggable:true});
    state.pin = {latitude:position.lat(), longitude:position.lng()};
    state.marker.addListener('dragend', function (event) {
      state.pin = {latitude:event.latLng.lat(), longitude:event.latLng.lng()};
      $('coords').textContent = 'Konum belirlendi (pini kontrol edin).';
    });
    $('coords').textContent = 'Konum belirlendi (pini kontrol edin).';
  }
  async function startMap() {
    if (!state.config.maps_browser_api_key) throw new Error('Harita API anahtarı henüz etkin değil. Adresi elle kaydedebilirsiniz.');
    if (!window.google || !window.google.maps) {
      await appendScript('https://maps.googleapis.com/maps/api/js?key=' +
        encodeURIComponent(state.config.maps_browser_api_key));
    }
    $('map').style.display = 'block';
    if (!state.map) {
      state.map = new google.maps.Map($('map'), {center:{lat:39, lng:35}, zoom:5, streetViewControl:false});
      state.geocoder = new google.maps.Geocoder();
      state.map.addListener('click', function (event) { mapPin(event.latLng); });
    }
    return state.map;
  }
  $('find-map').addEventListener('click', async function () {
    try {
      await startMap();
      var address = ['street','neighborhood','district','province'].map(function (k) {
        return $(k).value.trim();
      }).filter(Boolean).join(', ') + ', Türkiye';
      state.geocoder.geocode({address:address}, function (items, code) {
        if (code !== 'OK' || !items || !items.length) {
          status('Adres haritada bulunamadı. Haritaya dokunup pini elle işaretleyin.'); return;
        }
        var p = items[0].geometry.location;
        state.map.setCenter(p); state.map.setZoom(17); mapPin(p);
      });
    } catch (e) { status(e.message); }
  });
  $('signup').addEventListener('submit', async function (event) {
    event.preventDefault();
    if (!state.proof || state.verifiedEmail !== $('email').value.trim()) {
      status('Önce e-posta kodunu doğrulayın.'); return;
    }
    if ($('password').value !== $('password2').value) { status('Şifreler eşleşmiyor.'); return; }
    if (!$('terms').checked || !$('privacy').checked) { status('Zorunlu onayları işaretleyin.'); return; }
    var button = $('register'); button.disabled = true;
    var address = {
      province:$('province').value.trim(), district:$('district').value.trim(),
      neighborhood:$('neighborhood').value.trim(), street:$('street').value.trim(),
      building_no:$('building').value.trim(), apartment_no:$('apartment').value.trim(),
      directions:$('directions').value.trim(),
    };
    if (state.pin) { address.latitude = state.pin.latitude; address.longitude = state.pin.longitude; }
    try {
      await api('register', {
        first_name:$('first').value.trim(), last_name:$('last').value.trim(), role:$('role').value,
        business_name:$('business').value.trim(), email:$('email').value.trim(), phone:$('phone').value.trim(),
        password:$('password').value, password_confirmation:$('password2').value,
        terms_accepted:$('terms').checked, privacy_acknowledged:$('privacy').checked,
        marketing_consent:$('marketing').checked, address: address,
        registration_proof:state.proof,
      });
      $('signup').style.display = 'none'; $('success').style.display = 'block'; $('status').classList.remove('show');
      window.scrollTo({top:0,behavior:'smooth'});
    } catch (e) { status(e.message); button.disabled = false; }
  });
  function initGoogle(client) {
    if (!client) return;
    var tries = 0, timer = setInterval(function () {
      if (!window.google || !google.accounts || !google.accounts.id) { if (++tries > 40) clearInterval(timer); return; }
      clearInterval(timer);
      google.accounts.id.initialize({client_id:client, callback:async function (response) {
        try {
          var data = await api('social/preview', {provider:'google',identity_token:response.credential});
          $('first').value = data.first_name || ''; $('last').value = data.last_name || '';
          $('email').value = data.email || '';
          state.proof = null; state.verifiedEmail = null; state.challenge = null;
          status('Google bilgileri getirildi. Düzenleyebilir ve sonra doğrulama kodu isteyebilirsiniz. Hesap açılmadı.', true);
        } catch (e) { status(e.message); }
      }});
      google.accounts.id.renderButton($('google-button'), {theme:'outline',size:'large',width:240,text:'continue_with'});
    },150);
  }
  fetch('/api/auth/registration/config', {headers:{Accept:'application/json'}})
    .then(function (r) { return r.json(); }).then(function (r) {
      state.config = r.data || {}; initGoogle(state.config.google_client_id);
    }).catch(function () { /* Manual sign up still works. */ });
}());