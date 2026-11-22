<!DOCTYPE html>
<html lang="tr">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>@yield('title', 'Tarak İşletme Rehberi — Berber ve Kuaförler')</title>
    <meta name="description" content="@yield('description', 'Türkiye genelindeki berber ve kuaför işletmelerini Tarak Harita ve İşletme Rehberi üzerinde inceleyin.')">
    <link rel="canonical" href="@yield('canonical', url('/isletmeler'))">
    <meta property="og:type" content="@yield('og_type', 'website')">
    <meta property="og:title" content="@yield('title', 'Tarak İşletme Rehberi')">
    <meta property="og:description" content="@yield('description', 'Tarak Harita ve İşletme Rehberi')">
    <meta property="og:url" content="@yield('canonical', url('/isletmeler'))">
    <meta property="og:locale" content="tr_TR">
    @stack('head')
    <style>
        :root {
            --bg: #F8FAFC;
            --surface: #FFFFFF;
            --navy: #0F172A;
            --primary: #F97316;
            --primary-dark: #EA580C;
            --text: #0F172A;
            --muted: #64748B;
            --border: #E2E8F0;
            --success: #16A34A;
            --verified: #2563EB;
        }
        * { box-sizing: border-box; }
        body {
            margin: 0;
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Inter, sans-serif;
            background: var(--bg);
            color: var(--text);
            line-height: 1.55;
        }
        a { color: inherit; text-decoration: none; }
        .container { max-width: 1120px; margin: 0 auto; padding: 0 16px; }
        .site-header {
            background: var(--navy);
            color: #fff;
            padding: 14px 0;
            border-bottom: 1px solid rgba(255,255,255,0.08);
        }
        .header-row { display: flex; align-items: center; justify-content: space-between; gap: 16px; flex-wrap: wrap; }
        .brand { font-size: 20px; font-weight: 800; letter-spacing: -0.02em; color: #fff; }
        .brand span { color: var(--primary); }
        .nav-links { display: flex; gap: 16px; font-size: 14px; font-weight: 600; color: #CBD5E1; }
        .nav-links a:hover { color: #fff; }
        main { padding: 28px 0 56px; }
        .card {
            background: var(--surface);
            border: 1px solid var(--border);
            border-radius: 16px;
            padding: 20px;
            box-shadow: 0 1px 3px rgba(15, 23, 42, 0.04);
        }
        .btn {
            display: inline-flex;
            align-items: center;
            justify-content: center;
            gap: 8px;
            padding: 10px 16px;
            border-radius: 12px;
            font-weight: 700;
            font-size: 14px;
            border: 1px solid transparent;
            cursor: pointer;
        }
        .btn-primary { background: var(--primary); color: #fff; }
        .btn-primary:hover { background: var(--primary-dark); }
        .btn-outline { background: #fff; border-color: var(--border); color: var(--navy); }
        .badge {
            display: inline-flex;
            align-items: center;
            gap: 5px;
            padding: 3px 10px;
            border-radius: 999px;
            font-size: 12px;
            font-weight: 700;
            background: #F1F5F9;
            color: #334155;
        }
        .badge-verified { background: #EFF6FF; color: var(--verified); }
        .badge-booking { background: #ECFDF5; color: var(--success); }
        .grid { display: grid; gap: 16px; }
        .grid-cards { grid-template-columns: repeat(auto-fill, minmax(280px, 1fr)); }
        .site-footer {
            border-top: 1px solid var(--border);
            background: #fff;
            padding: 24px 0;
            color: var(--muted);
            font-size: 13px;
        }
    </style>
</head>
<body>
<header class="site-header">
    <div class="container header-row">
        <a href="{{ url('/') }}" class="brand">tarak<span>.app</span></a>
        <nav class="nav-links" aria-label="Ana gezinme">
            <a href="{{ url('/isletmeler') }}">Harita ve İşletme Rehberi</a>
            <a href="{{ url('/') }}">Ana Sayfa</a>
        </nav>
    </div>
</header>
<main class="container">
    @yield('content')
</main>
<footer class="site-footer">
    <div class="container">
        Tarak.app İşletme Rehberi &amp; Tarak Harita — Berber ve Kuaför Keşif Platformu
    </div>
</footer>
</body>
</html>
