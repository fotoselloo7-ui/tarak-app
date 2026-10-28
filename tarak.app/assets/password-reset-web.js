(() => {
  'use strict';

  const API_BASE = '/api';
  const LINK_ID = 'tarak-forgot-password-link';
  const MODAL_ID = 'tarak-password-reset-modal';

  const esc = (value) => String(value ?? '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#039;');

  const extractError = (body, fallback) => {
    if (body?.message) return String(body.message);
    const errors = body?.errors;
    if (errors && typeof errors === 'object') {
      const first = Object.values(errors).flat().find(Boolean);
      if (first) return String(first);
    }
    return fallback;
  };

  const request = async (path, payload) => {
    const response = await fetch(API_BASE + path, {
      method: 'POST',
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'X-Requested-With': 'XMLHttpRequest',
      },
      body: JSON.stringify(payload),
      credentials: 'same-origin',
    });
    let body = {};
    try { body = await response.json(); } catch (_) {}
    if (!response.ok) throw new Error(extractError(body, 'İşlem tamamlanamadı. Lütfen tekrar deneyin.'));
    return body;
  };

  const closeModal = () => document.getElementById(MODAL_ID)?.remove();

  const openModal = (prefillEmail = '') => {
    closeModal();
    let step = 1;
    let email = prefillEmail || '';

    const overlay = document.createElement('div');
    overlay.id = MODAL_ID;
    overlay.style.cssText = 'position:fixed;inset:0;z-index:100000;background:rgba(15,23,42,.58);display:flex;align-items:center;justify-content:center;padding:18px;';
    overlay.innerHTML = `
      <div role="dialog" aria-modal="true" aria-labelledby="tarak-reset-title" style="width:min(100%,440px);background:#fff;border-radius:20px;box-shadow:0 24px 80px rgba(15,23,42,.28);padding:24px;position:relative;font-family:Inter,sans-serif;">
        <button type="button" data-reset-close aria-label="Kapat" style="position:absolute;right:16px;top:14px;border:0;background:transparent;font-size:24px;line-height:1;color:#64748b;cursor:pointer;">×</button>
        <div style="font-size:12px;font-weight:800;color:#ff5722;letter-spacing:.08em;text-transform:uppercase;margin-bottom:8px;">Tarak Güvenli Hesap</div>
        <h2 id="tarak-reset-title" style="margin:0 34px 7px 0;font-size:22px;line-height:1.25;color:#0f172a;">Şifremi Unuttum</h2>
        <p data-reset-description style="margin:0 0 20px;color:#64748b;font-size:13px;line-height:1.55;">Hesabınızda kayıtlı e-posta adresine 6 haneli yenileme kodu göndereceğiz.</p>
        <div data-reset-message style="display:none;margin-bottom:14px;padding:11px 12px;border-radius:12px;font-size:12px;line-height:1.45;"></div>
        <form data-reset-form>
          <label style="display:block;font-size:13px;font-weight:700;color:#334155;margin-bottom:6px;">E-posta Adresi</label>
          <input data-reset-email type="email" autocomplete="email" value="${esc(email)}" placeholder="ornek@mail.com" required style="width:100%;box-sizing:border-box;border:1px solid #d8dee8;border-radius:12px;padding:12px 13px;font:inherit;font-size:14px;outline:none;margin-bottom:15px;">
          <div data-reset-step2 style="display:none;">
            <label style="display:block;font-size:13px;font-weight:700;color:#334155;margin-bottom:6px;">Doğrulama Kodu</label>
            <input data-reset-code inputmode="numeric" autocomplete="one-time-code" maxlength="6" placeholder="6 haneli kod" style="width:100%;box-sizing:border-box;border:1px solid #d8dee8;border-radius:12px;padding:12px 13px;font:inherit;font-size:14px;outline:none;margin-bottom:15px;">
            <label style="display:block;font-size:13px;font-weight:700;color:#334155;margin-bottom:6px;">Yeni Şifre</label>
            <input data-reset-password type="password" autocomplete="new-password" placeholder="En az 8 karakter" style="width:100%;box-sizing:border-box;border:1px solid #d8dee8;border-radius:12px;padding:12px 13px;font:inherit;font-size:14px;outline:none;margin-bottom:15px;">
            <label style="display:block;font-size:13px;font-weight:700;color:#334155;margin-bottom:6px;">Yeni Şifre Tekrar</label>
            <input data-reset-password-confirm type="password" autocomplete="new-password" placeholder="Şifrenizi tekrar girin" style="width:100%;box-sizing:border-box;border:1px solid #d8dee8;border-radius:12px;padding:12px 13px;font:inherit;font-size:14px;outline:none;margin-bottom:15px;">
          </div>
          <button data-reset-submit type="submit" style="width:100%;border:0;border-radius:12px;background:#ff5722;color:#fff;font-weight:800;padding:13px 16px;cursor:pointer;font-size:14px;">Kod Gönder</button>
          <button data-reset-resend type="button" style="display:none;width:100%;border:0;background:transparent;color:#ff5722;font-weight:700;padding:12px 8px 0;cursor:pointer;font-size:13px;">Kodu tekrar gönder</button>
        </form>
      </div>`;

    document.body.appendChild(overlay);
    document.body.style.overflow = 'hidden';

    const form = overlay.querySelector('[data-reset-form]');
    const emailInput = overlay.querySelector('[data-reset-email]');
    const step2 = overlay.querySelector('[data-reset-step2]');
    const codeInput = overlay.querySelector('[data-reset-code]');
    const passwordInput = overlay.querySelector('[data-reset-password]');
    const passwordConfirmInput = overlay.querySelector('[data-reset-password-confirm]');
    const submit = overlay.querySelector('[data-reset-submit]');
    const resend = overlay.querySelector('[data-reset-resend]');
    const message = overlay.querySelector('[data-reset-message]');
    const description = overlay.querySelector('[data-reset-description]');

    const showMessage = (text, ok = false) => {
      message.textContent = text;
      message.style.display = 'block';
      message.style.color = ok ? '#166534' : '#991b1b';
      message.style.background = ok ? '#f0fdf4' : '#fef2f2';
      message.style.border = '1px solid ' + (ok ? '#bbf7d0' : '#fecaca');
    };

    const setBusy = (busy) => {
      submit.disabled = busy;
      resend.disabled = busy;
      submit.style.opacity = busy ? '.65' : '1';
      submit.textContent = busy ? 'İşleniyor...' : (step === 1 ? 'Kod Gönder' : 'Şifreyi Yenile');
    };

    const sendCode = async () => {
      email = emailInput.value.trim();
      if (!email || !email.includes('@')) {
        showMessage('Geçerli bir e-posta adresi girin.');
        return false;
      }
      setBusy(true);
      try {
        const body = await request('/auth/password/forgot', {email});
        step = 2;
        emailInput.readOnly = true;
        step2.style.display = 'block';
        resend.style.display = 'block';
        description.textContent = 'E-postanıza gelen 6 haneli kodu ve yeni şifrenizi girin.';
        submit.textContent = 'Şifreyi Yenile';
        showMessage(body?.message || 'Şifre yenileme kodu gönderildi.', true);
        codeInput.focus();
        return true;
      } catch (error) {
        showMessage(error.message);
        return false;
      } finally {
        setBusy(false);
      }
    };

    resend.addEventListener('click', sendCode);
    form.addEventListener('submit', async (event) => {
      event.preventDefault();
      if (step === 1) {
        await sendCode();
        return;
      }

      const code = codeInput.value.replace(/\D/g, '').slice(0, 6);
      const password = passwordInput.value;
      const confirmation = passwordConfirmInput.value;
      if (code.length !== 6) return showMessage('6 haneli doğrulama kodunu girin.');
      if (password.length < 8) return showMessage('Yeni şifre en az 8 karakter olmalıdır.');
      if (password !== confirmation) return showMessage('Şifre tekrarı eşleşmiyor.');

      setBusy(true);
      try {
        const body = await request('/auth/password/reset', {
          email, code, password, password_confirmation: confirmation,
        });
        showMessage(body?.message || 'Şifreniz başarıyla yenilendi.', true);
        submit.style.display = 'none';
        resend.style.display = 'none';
        setTimeout(() => closeModal(), 1300);
      } catch (error) {
        showMessage(error.message);
      } finally {
        setBusy(false);
      }
    });

    overlay.querySelector('[data-reset-close]').addEventListener('click', closeModal);
    overlay.addEventListener('click', (event) => { if (event.target === overlay) closeModal(); });
    const escHandler = (event) => {
      if (event.key === 'Escape') {
        document.removeEventListener('keydown', escHandler);
        closeModal();
      }
    };
    document.addEventListener('keydown', escHandler);
    emailInput.focus();
  };

  const installLink = () => {
    if (document.getElementById(LINK_ID)) return;
    const password = [...document.querySelectorAll('input[type="password"]')]
      .find(input => input.closest('form') && input.closest('form').textContent.includes('Giriş Yap'));
    if (!password) return;

    const form = password.closest('form');
    const loginButton = [...form.querySelectorAll('button')]
      .find(button => button.textContent.trim().startsWith('Giriş Yap'));
    if (!loginButton) return;

    const row = document.createElement('div');
    row.id = LINK_ID;
    row.style.cssText = 'display:flex;justify-content:flex-end;margin-top:-2px;margin-bottom:4px;';
    const link = document.createElement('button');
    link.type = 'button';
    link.textContent = 'Şifremi Unuttum?';
    link.style.cssText = 'border:0;background:transparent;color:#ff5722;font:inherit;font-size:12px;font-weight:700;cursor:pointer;padding:7px 0;';
    link.addEventListener('click', () => {
      const emailInput = form.querySelector('input[type="email"]');
      openModal(emailInput?.value?.trim() || '');
    });
    row.appendChild(link);
    loginButton.parentNode.insertBefore(row, loginButton);
  };

  const observer = new MutationObserver(installLink);
  observer.observe(document.documentElement, {childList: true, subtree: true});
  installLink();

  const originalClose = closeModal;
  window.addEventListener('beforeunload', () => observer.disconnect());
})();