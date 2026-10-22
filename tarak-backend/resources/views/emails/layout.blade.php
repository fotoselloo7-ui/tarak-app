<!DOCTYPE html>
<html lang="tr">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="x-apple-disable-message-reformatting">
    <title>@yield('title', 'Tarak.app')</title>
</head>
<body style="margin:0;padding:0;background:#f3f1ec;-webkit-text-size-adjust:100%;">
<div style="display:none;max-height:0;overflow:hidden;opacity:0;color:#f3f1ec;">@yield('preheader')</div>
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#f3f1ec;">
    <tr>
        <td align="center" style="padding:28px 12px;">
            <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:600px;background:#ffffff;border-radius:18px;overflow:hidden;border:1px solid #e7e2d8;">
                <tr>
                    <td align="center" style="padding:26px 24px 18px;border-bottom:3px solid #b8862f;">
                        <img src="{{ $message->embed($logoPath) }}" alt="Tarak.app" width="150" style="display:block;border:0;outline:none;height:auto;max-width:150px;">
                    </td>
                </tr>
                <tr>
                    <td style="padding:28px 28px 8px;font-family:Arial,Helvetica,sans-serif;color:#1f2430;font-size:15px;line-height:1.6;">
                        @yield('content')
                    </td>
                </tr>
                <tr>
                    <td style="padding:8px 28px 28px;font-family:Arial,Helvetica,sans-serif;font-size:12px;line-height:1.6;color:#6b7280;">
                        <div style="border-top:1px solid #eee9de;padding-top:16px;">
                            Bu ileti, Tarak.app'e kayıtlı işletme hesabınızın e-posta adresine otomatik olarak gönderildi.
                            Tarak ekibi sizden hiçbir zaman şifre, SMS kodu veya kart bilgisi istemez.
                            Ödeme bilgilerini yalnızca giriş yaptığınız <strong>tarak.app İşletme Finans Merkezi</strong>'nden doğrulayın.
                        </div>
                    </td>
                </tr>
            </table>
            <div style="font-family:Arial,Helvetica,sans-serif;font-size:11px;color:#9a9588;padding:14px 8px;">© {{ date('Y') }} Tarak.app</div>
        </td>
    </tr>
</table>
</body>
</html>
