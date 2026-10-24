/* Safe navigation only: never mutate the compiled React application state. */
(function () {
  'use strict';
  document.addEventListener('click', function (event) {
    var el = event.target;
    if (!(el instanceof Element)) return;
    var control = el.closest('a,button,[role="button"]');
    if (!control || control.closest('[data-no-secure-register]')) return;
    var text = (control.textContent || '').trim().replace(/\s+/g, ' ').toLocaleLowerCase('tr-TR');
    var target = (control.getAttribute('href') || '').toLowerCase();
    var provider = ['hizmet veren ol','hizmet vererek kazan','berber olarak kaydol','kuaför olarak kaydol'].includes(text);
    var register = provider || ['kayıt ol','üye ol','hesap oluştur','hesap oluşturun','müşteri kaydı','hizmet veren kaydı'].includes(text);
    if (!register && !/\/(register|signup|kayit-ol|uye-ol)([/?#]|$)/.test(target)) return;
    event.preventDefault(); event.stopImmediatePropagation();
    window.location.assign('/guvenli-kayit.html' + (provider ? '?role=PROVIDER' : ''));
  }, true);
}());