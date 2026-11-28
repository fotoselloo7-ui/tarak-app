/* tarak.app sitesinde "Oyna, bedava tıraş kazan" bağlantısı (sitenin derlenmiş React koduna dokunmadan).
 * Girişliyse rolüne göre: müşteri › Oyun hediyelerim, işletme › Oyuna Sponsor Ol, yönetici › Oyun yönetimi.
 * Kapatılırsa 7 gün görünmez. Yönetici oyun bağlantılarını kapattıysa (oyun_acik = 0) hiç görünmez. */
(function () {
  'use strict';
  if (/^\/oyun(\/|$)/.test(location.pathname)) return;
  var KAPALI = 'tarak_oyun_baglanti_kapali';
  try { if (Number(localStorage.getItem(KAPALI) || 0) > Date.now()) return; } catch (e) {}
  var jeton = null; try { jeton = localStorage.getItem('berberim_auth_token'); } catch (e) {}

  function ciz(rol) {
    if (document.getElementById('tarak-oyun-baglanti')) return;
    var metin = '🎮 Oyna, bedava tıraş kazan', adres = '/oyun/';
    if (rol === 'CUSTOMER') { metin = '🎮 Oyun hediyelerim'; adres = '/oyun/hesap/'; }
    else if (rol === 'PROVIDER') { metin = '🎮 Oyuna sponsor ol'; adres = '/oyun/hesap/'; }
    else if (rol === 'ADMIN') { metin = '🎮 Oyun yönetimi'; adres = '/oyun/yonetim/'; }
    var kap = document.createElement('div');
    kap.id = 'tarak-oyun-baglanti';
    kap.setAttribute('style', 'position:fixed;left:12px;bottom:calc(88px + env(safe-area-inset-bottom));z-index:2147483000;display:flex;align-items:center;' +
      'background:#0f172a;color:#fff;border-radius:999px;box-shadow:0 6px 20px rgba(15,23,42,.28);font:600 13px/1 system-ui,-apple-system,Segoe UI,sans-serif;');
    var a = document.createElement('a');
    a.href = adres; a.textContent = metin;
    a.setAttribute('style', 'color:#fff;text-decoration:none;padding:10px 6px 10px 14px;');
    var x = document.createElement('button');
    x.type = 'button'; x.setAttribute('aria-label', 'Kapat'); x.textContent = '×';
    x.setAttribute('style', 'background:none;border:0;color:#94a3b8;font:400 18px/1 system-ui;padding:8px 12px 8px 4px;cursor:pointer;');
    x.addEventListener('click', function () { try { localStorage.setItem(KAPALI, String(Date.now() + 7 * 864e5)); } catch (e) {} kap.remove(); });
    kap.appendChild(a); kap.appendChild(x);
    document.body.appendChild(kap);
  }

  function rolAl() {
    if (!jeton) return Promise.resolve(null);
    return fetch('/api/auth/me', { headers: { Accept: 'application/json', Authorization: 'Bearer ' + jeton } })
      .then(function (r) { return r.ok ? r.json() : null; })
      .then(function (j) { return j && j.data && j.data.user ? j.data.user.role : null; })
      .catch(function () { return null; });
  }

  function basla() {
    fetch('/api/game/linkler', { headers: { Accept: 'application/json' } })
      .then(function (r) { return r.ok ? r.json() : null; })
      .then(function (j) {
        var acik = j && j.data ? j.data.oyun_acik : null;
        if (acik === '0' || acik === 0 || acik === false) return;
        return rolAl().then(ciz);
      })
      .catch(function () { rolAl().then(ciz); });
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', basla); else basla();
})();
