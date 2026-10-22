@extends('emails.layout')

@section('title', 'Hediye komisyon hakkınız tamamlandı')
@section('preheader', 'Hediye komisyon hakkınız kullanıldı. Ödeme bilgileriniz İşletme Finans Merkezi\'nde.')

@php
    $tl = fn ($n) => '₺' . number_format((float) $n, 2, ',', '.');
@endphp

@section('content')
    <h1 style="margin:0 0 6px;font-size:22px;line-height:1.3;color:#14161c;">Merhaba {{ $businessName }},</h1>
    <p style="margin:0 0 18px;">Tarak.app'in size tanıdığı <strong>hediye komisyon hakkı</strong> tamamen kullanıldı. Bu hak yalnızca Tarak komisyonunu karşılıyordu; para olarak çekilemezdi.</p>

    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#faf6ec;border:1px solid #eadcb8;border-radius:12px;margin:0 0 18px;">
        <tr>
            <td style="padding:16px 18px;font-size:14px;">
                <div style="font-weight:bold;color:#7a5617;margin-bottom:8px;letter-spacing:.3px;">HEDİYE KULLANIM ÖZETİ</div>
                <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="font-size:14px;">
                    <tr><td style="padding:3px 0;color:#4b5160;">Tanımlanan hediye</td><td align="right" style="padding:3px 0;font-weight:bold;">{{ $tl($gift['granted'] ?? 0) }}</td></tr>
                    <tr><td style="padding:3px 0;color:#4b5160;">Komisyona kullanılan</td><td align="right" style="padding:3px 0;font-weight:bold;">{{ $tl($gift['used'] ?? 0) }}</td></tr>
                    <tr><td style="padding:3px 0;color:#4b5160;">Hediyeyle karşılanan hizmet</td><td align="right" style="padding:3px 0;font-weight:bold;">{{ $servicesCovered }}</td></tr>
                    <tr><td style="padding:3px 0;color:#4b5160;">Kalan hediye</td><td align="right" style="padding:3px 0;font-weight:bold;">{{ $tl($gift['remaining'] ?? 0) }}</td></tr>
                </table>
            </td>
        </tr>
    </table>

    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#f6f7f9;border:1px solid #e5e8ee;border-radius:12px;margin:0 0 18px;">
        <tr>
            <td style="padding:16px 18px;font-size:14px;">
                <div style="font-weight:bold;color:#2b3342;margin-bottom:8px;letter-spacing:.3px;">KALAN HESAP DURUMU</div>
                <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="font-size:14px;">
                    <tr><td style="padding:3px 0;color:#4b5160;">Yüklenen komisyon bakiyesi</td><td align="right" style="padding:3px 0;font-weight:bold;">{{ $tl($account['deposited_balance'] ?? 0) }}</td></tr>
                    <tr><td style="padding:3px 0;color:#4b5160;">Rezerve edilen komisyon</td><td align="right" style="padding:3px 0;font-weight:bold;">{{ $tl($account['reserved_total'] ?? 0) }}</td></tr>
                    <tr><td style="padding:3px 0;color:#4b5160;">Yeni işler için kullanılabilir</td><td align="right" style="padding:3px 0;font-weight:bold;">{{ $tl($account['usable_commission_balance'] ?? 0) }}</td></tr>
                </table>
            </td>
        </tr>
    </table>

    <p style="margin:0 0 12px;"><strong>Ne değişiyor?</strong> Müşteriniz hizmet bedelini doğrudan size (nakit veya kendi POS cihazınızla) ödemeye devam eder. Tamamlanan her hizmetin Tarak komisyonu artık yüklediğiniz komisyon bakiyesinden düşülür. Bakiyeniz yetmezse yalnızca <em>yeni</em> ücretli nakit iş ve randevu kabulü durur; onaylı randevularınız, iptaller ve uyuşmazlıklar normal işlemeye devam eder.</p>
    <p style="margin:0 0 20px;"><strong>Ödeme bilgileriniz nerede?</strong> IBAN, işletmenize özel TRK referans kodu ve transfer açıklaması, giriş yaptığınız <strong>tarak.app İşletme Finans Merkezi</strong>'nde yer alır. Ödemeniz banka kaydımızla doğrulandıktan sonra bakiyeniz güncellenir.</p>

    <table role="presentation" cellpadding="0" cellspacing="0" style="margin:0 auto 22px;">
        <tr>
            <td align="center" style="background:#b8862f;border-radius:10px;">
                <a href="{{ $financeUrl }}" style="display:inline-block;padding:13px 26px;font-family:Arial,Helvetica,sans-serif;font-size:15px;font-weight:bold;color:#ffffff;text-decoration:none;">İşletme Finans Merkezi'ni Aç</a>
            </td>
        </tr>
    </table>
@endsection
