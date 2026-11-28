<!doctype html>
<html lang="tr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex">
<title>Tarak ile giriş · Randevuya Koş</title>
<style>
  :root { color-scheme: dark; }
  body { margin: 0; min-height: 100vh; display: grid; place-items: center; background: #15171b; color: #f3f4f6; font: 16px/1.45 system-ui, -apple-system, "Segoe UI", sans-serif; }
  main { width: min(92vw, 380px); background: #1e2126; border: 1px solid #2c3037; border-radius: 18px; padding: 28px 24px; }
  h1 { font-size: 22px; margin: 0 0 4px; }
  p { margin: 0 0 18px; color: #b8bec8; font-size: 14px; }
  label { display: block; font-size: 13px; color: #b8bec8; margin: 12px 0 6px; }
  input { width: 100%; box-sizing: border-box; padding: 12px 14px; border-radius: 12px; border: 1px solid #353a43; background: #111317; color: #fff; font-size: 16px; }
  button { width: 100%; margin-top: 20px; padding: 13px; border: 0; border-radius: 12px; background: #ffc21a; color: #1c1c1c; font-weight: 800; font-size: 16px; cursor: pointer; }
  .hata { background: #4a1f22; color: #ffb4b4; padding: 10px 12px; border-radius: 10px; font-size: 14px; margin-bottom: 8px; }
  small { display: block; margin-top: 16px; color: #8a919c; font-size: 12px; }
</style>
</head>
<body>
<main>
  <h1>Tarak ile giriş</h1>
  <p>Randevuya Koş oyununda kazandığın hediyeler Tarak hesabına, müşteri profiline kaydedilir.</p>
  @if ($hata)<div class="hata" role="alert">{{ $hata }}</div>@endif
  <form method="post" action="{{ url('/api/game/giris') }}">
    <input type="hidden" name="donus" value="{{ $donus }}">
    <input type="hidden" name="durum" value="{{ $durum }}">
    <label for="login">E-posta ya da telefon</label>
    <input id="login" name="login" autocomplete="username" required>
    <label for="password">Şifre</label>
    <input id="password" name="password" type="password" autocomplete="current-password" required>
    <button type="submit">Giriş yap ve oyuna dön</button>
  </form>
  <small>Şifren yalnızca Tarak'a gönderilir; oyun şifreni görmez. Hesabın yoksa tarak.app'ten ücretsiz kayıt olabilirsin.</small>
</main>
</body>
</html>
