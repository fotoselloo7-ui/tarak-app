import {r as React} from './react-vendor-Dj04zrcb.js?v=20261028-integrations1';

const h = React.createElement;
const googleButtonStyles = `
.tarak-google-auth{min-height:52px;display:flex;align-items:center;justify-content:center;border-radius:999px;background:#fff;box-shadow:0 3px 10px #0f172a0d;transition:box-shadow .18s ease}
.tarak-google-auth:focus-within{outline:2px solid #4285f4;outline-offset:3px}
.tarak-google-auth>button{display:flex;align-items:center;justify-content:center;gap:10px;width:100%;min-height:52px;padding:12px 16px;border:1px solid #747775;border-radius:999px;background:#fff;color:#1f1f1f;font:600 14px/20px Inter,Arial,sans-serif;letter-spacing:.1px}
.tarak-google-auth>button:disabled{cursor:not-allowed;color:#747775}
.tarak-google-auth>button img{width:20px;height:20px;flex:none}
@media(prefers-reduced-motion:reduce){.tarak-google-auth{transition:none}}
`;
const scripts = new Map();
function loadScript(src) {
  if (!scripts.has(src)) scripts.set(src, new Promise((resolve, reject) => {
    const script = document.createElement('script');
    script.src = src;
    script.async = true;
    script.onload = resolve;
    script.onerror = () => { scripts.delete(src); reject(new Error('Giriş sağlayıcısına ulaşılamadı.')); };
    document.head.append(script);
  }));
  return scripts.get(src);
}

export function SocialButtons({api, mode = 'prefill', onResult, onError, extraPayload = {}}) {
  const googleHost = React.useRef(null);
  const callback = React.useRef({onResult, onError, extraPayload});
  callback.current = {onResult, onError, extraPayload};
  const [config, setConfig] = React.useState(null);
  const [apple, setApple] = React.useState(null);
  const [busy, setBusy] = React.useState(false);
  const [generation, setGeneration] = React.useState(0);
  const [message, setMessage] = React.useState('');

  React.useEffect(() => {
    let active = true;
    api.get('/auth/social/config').then(result => { if (active) setConfig(result.data); })
      .catch(error => { if (active) setMessage(error.message); });
    return () => { active = false; };
  }, [api]);

  React.useEffect(() => {
    if (!config) return;
    let active = true;
    setApple(null);
    const noncePromise = api.get('/auth/social/nonce');
    const complete = async (provider, payload) => {
      if (!active) return;
      setBusy(true);
      try {
        const result = await api.post(`/auth/social/${provider}/${mode}`, {...payload, ...callback.current.extraPayload});
        if (active) callback.current.onResult(result.data);
      } catch (error) { if (active) callback.current.onError(error.message); }
      finally { if (active) { setBusy(false); setGeneration(value => value + 1); } }
    };
    if (config.google_client_id) {
      Promise.all([loadScript('https://accounts.google.com/gsi/client'), noncePromise])
        .then(([, result]) => {
          if (!active || !googleHost.current) return;
          const nonce = result.data.nonce;
          window.google.accounts.id.initialize({
            client_id: config.google_client_id, nonce, auto_select: false,
            callback: response => complete('google', {id_token: response.credential, nonce}),
          });
          googleHost.current.replaceChildren();
          window.google.accounts.id.renderButton(googleHost.current, {
            type: 'standard', theme: 'outline', size: 'large', text: 'continue_with',
            shape: 'pill', locale: 'tr', width: Math.max(200, Math.min(360, googleHost.current.clientWidth)),
          });
        }).catch(error => { if (active) callback.current.onError(error.message); });
    }
    if (config.apple_client_id && config.apple_redirect_uri) {
      Promise.all([loadScript('https://appleid.cdn-apple.com/appleauth/static/jsapi/appleid/1/en_US/appleid.auth.js'), noncePromise])
        .then(([, result]) => {
          if (!active) return;
          const nonce = result.data.nonce;
          window.AppleID.auth.init({clientId: config.apple_client_id, scope: 'name email',
            redirectURI: config.apple_redirect_uri, state: nonce, nonce, usePopup: true});
          setApple({nonce, complete});
        }).catch(error => { if (active) callback.current.onError(error.message); });
    }
    return () => { active = false; };
  }, [api, config, generation, mode]);

  // Google Identity Services owns the iframe it injects into this host. React
  // re-renders elsewhere on the login form can occasionally clear that external
  // DOM. Watch the host and restore the official Google button immediately.
  React.useEffect(() => {
    const host = googleHost.current;
    if (!config?.google_client_id || !host) return;

    let restoreTimer = null;
    const restoreGoogleButton = () => {
      if (restoreTimer) clearTimeout(restoreTimer);
      restoreTimer = setTimeout(() => {
        if (!host.isConnected || !window.google?.accounts?.id) return;
        const hasVisibleButton = host.querySelector('iframe, div[role="button"]');
        if (hasVisibleButton) return;
        try {
          host.replaceChildren();
          window.google.accounts.id.renderButton(host, {
            type: 'standard', theme: 'outline', size: 'large', text: 'continue_with',
            shape: 'pill', locale: 'tr',
            width: Math.max(200, Math.min(360, host.clientWidth || 360)),
          });
        } catch (_) {}
      }, 0);
    };

    restoreGoogleButton();
    const observer = new MutationObserver(restoreGoogleButton);
    observer.observe(host, {childList: true, subtree: true});

    return () => {
      observer.disconnect();
      if (restoreTimer) clearTimeout(restoreTimer);
    };
  }, [config?.google_client_id]);

  const signInApple = async () => {
    if (!apple || busy) return;
    try {
      const result = await window.AppleID.auth.signIn();
      if (result.authorization.state !== apple.nonce) throw new Error('Apple güvenlik kontrolü başarısız oldu.');
      await apple.complete('apple', {id_token: result.authorization.id_token,
        authorization_code: result.authorization.code, nonce: apple.nonce});
    } catch (error) {
      if (error.error !== 'popup_closed_by_user') callback.current.onError(error.message || 'Apple girişi tamamlanamadı.');
      setGeneration(value => value + 1);
    }
  };

  return h('div', {className: 'space-y-3', style: {marginBottom: 20}},
    h('style', null, googleButtonStyles),
    h('div', {style: {display: 'grid', gridTemplateColumns: 'repeat(auto-fit,minmax(200px,1fr))', gap: 12}},
      h('div', {ref: googleHost, className: 'tarak-google-auth'}, !config?.google_client_id &&
        h('button', {type: 'button', disabled: true},
          h('img', {src: '/brand/google-g.png', alt: '', 'aria-hidden': true}), 'Google ile devam et')),
      h('button', {type: 'button', onClick: signInApple, disabled: !apple || busy,
        style: {minHeight: 44, borderRadius: 8, background: '#111827', color: 'white', fontSize: 14, fontWeight: 600, opacity: !apple || busy ? .5 : 1}}, 'Apple ile devam et')),
    h('p', {className: 'text-xs text-gray-500', role: message ? 'status' : undefined},
      message || (config && !config.google_client_id && !config.apple_client_id
        ? 'Google ve Apple girişi henüz yapılandırılmadı.'
        : mode === 'prefill' ? 'Bilgileriniz forma aktarılır. Hesabınız, formu onayladığınızda oluşturulur.' : 'Önceden hesabınıza bağladığınız sağlayıcıyla giriş yapın.')));
}

export function VerificationControl({api, channel, destination, verified, onVerified}) {
  const [available, setAvailable] = React.useState(channel !== 'sms');
  const [code, setCode] = React.useState('');
  const [wait, setWait] = React.useState(0);
  const [sent, setSent] = React.useState(false);
  const [busy, setBusy] = React.useState(false);
  const [message, setMessage] = React.useState('');
  const currentDestination = React.useRef(destination);
  currentDestination.current = destination;
  React.useEffect(() => {
    if (channel !== 'sms') {
      setAvailable(true);
      return;
    }
    let active = true;
    api.get('/auth/verification/config')
      .then(result => {
        const enabled = !!result.data?.sms_enabled;
        window.__TARAK_SMS_VERIFICATION_ENABLED__ = enabled;
        if (active) setAvailable(enabled);
      })
      .catch(() => {
        window.__TARAK_SMS_VERIFICATION_ENABLED__ = false;
        if (active) setAvailable(false);
      });
    return () => { active = false; };
  }, [api, channel]);
  React.useEffect(() => { setCode(''); setWait(0); setSent(false); setMessage(''); }, [destination]);
  React.useEffect(() => {
    if (wait <= 0) return;
    const timer = setTimeout(() => setWait(value => Math.max(0, value - 1)), 1000);
    return () => clearTimeout(timer);
  }, [wait]);
  const payload = channel === 'email' ? {email: destination.trim()} : {phone: destination.trim()};
  const act = async confirm => {
    const target = destination;
    setBusy(true); setMessage('');
    try {
      const result = await api.post(`/auth/verification/${channel}/${confirm ? 'confirm' : 'send'}`, {...payload, ...(confirm ? {code} : {})});
      if (currentDestination.current !== target) return;
      if (confirm) { onVerified(result.data.verification_token); setMessage('Doğrulandı.'); }
      else { setSent(true); setWait(result.data.resend_after_seconds); setMessage('6 haneli kod gönderildi. Kod 10 dakika geçerlidir.'); }
    } catch (error) { if (currentDestination.current === target) setMessage(error.message); }
    finally { setBusy(false); }
  };
  if (!available || !destination.trim()) return null;
  return h('div', {className: 'p-3 rounded-xl border border-gray-200 space-y-2'},
    h('div', {className: 'flex items-center justify-between gap-2'},
      h('span', {className: 'text-xs font-semibold text-gray-700'}, channel === 'email' ? 'E-posta doğrulama' : 'Telefon doğrulama'),
      verified ? h('span', {className: 'text-xs text-emerald-600'}, 'Doğrulandı ✓') :
        h('button', {type: 'button', onClick: () => act(false), disabled: busy || wait > 0,
          className: 'text-xs font-semibold text-brand-orange disabled:opacity-50', style: {minHeight: 32}}, wait > 0 ? `Tekrar gönder (${wait} sn)` : sent ? 'Tekrar gönder' : 'Kod gönder')),
    sent && !verified && h('div', {className: 'flex gap-2'},
      h('input', {value: code, onChange: event => setCode(event.target.value.replace(/\D/g, '').slice(0, 6)),
        inputMode: 'numeric', autoComplete: 'one-time-code', maxLength: 6, 'aria-label': channel === 'email' ? 'E-posta doğrulama kodu' : 'SMS doğrulama kodu',
        className: 'w-full px-3 py-2 text-sm border border-gray-300 rounded-lg', placeholder: '6 haneli kod'}),
      h('button', {type: 'button', disabled: busy || code.length !== 6, onClick: () => act(true),
        className: 'px-3 py-2 text-sm font-semibold text-brand-orange disabled:opacity-50'}, 'Doğrula')),
    message && h('p', {role: 'status', className: 'text-xs text-gray-600'}, message));
}

export function ConsentFields({value, onChange}) {
  const item = (name, text, required, href) => h('label', {key: name, className: 'flex items-start gap-2 text-xs text-gray-600', style: {lineHeight: 1.6}},
    h('input', {type: 'checkbox', checked: !!value[name], required, onChange: event => onChange({...value, [name]: event.target.checked}), style: {marginTop: 4, accentColor: '#FF5722'}}),
    h('span', null, href ? h('a', {href, target: '_blank', rel: 'noopener', className: 'text-brand-orange underline'}, text) : text,
      required ? ' okudum ve kabul ediyorum. *' : ''));
  return h('div', {className: 'space-y-3'},
    item('accept_terms', 'Kullanıcı Sözleşmesi’ni', true, '/legal/terms'),
    item('accept_kvkk', 'KVKK Aydınlatma Metni’ni', true, '/legal/kvkk'),
    item('marketing_consent', 'Kampanya ve fırsatlardan e-posta/SMS ile haberdar olmak istiyorum (isteğe bağlı).', false));
}

export function SocialAccountLink({api}) {
  const [password, setPassword] = React.useState('');
  const [message, setMessage] = React.useState('');
  return h('details', {className: 'border border-gray-200 rounded-xl p-3 mt-4'},
    h('summary', {className: 'text-sm font-semibold text-gray-800', style: {cursor: 'pointer'}}, 'Google / Apple hesabı bağla'),
    h('p', {className: 'text-xs text-gray-500 my-3'}, 'Bağlantıyı onaylamak için mevcut Tarak şifrenizi girin, ardından sağlayıcınızı seçin.'),
    h('input', {type: 'password', value: password, onChange: event => setPassword(event.target.value), autoComplete: 'current-password',
      'aria-label': 'Hesap bağlamak için mevcut şifre', placeholder: 'Mevcut şifreniz', className: 'w-full px-3 py-2 border border-gray-300 rounded-lg text-sm mb-3'}),
    password && h(SocialButtons, {api, mode: 'link', extraPayload: {current_password: password},
      onResult: () => { setPassword(''); setMessage('Sağlayıcı hesabınız güvenle bağlandı.'); }, onError: setMessage}),
    message && h('p', {role: 'status', className: 'text-xs text-gray-600'}, message));
}
