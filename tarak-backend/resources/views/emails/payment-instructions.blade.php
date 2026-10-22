@extends('emails.layout')

@section('title', 'Komisyon ödeme bilgileriniz')
@section('preheader', 'Komisyon bakiyesi yüklemek için banka bilgileriniz ve TRK referans kodunuz.')

@php
    $tl = fn ($n) => '₺' . number_format((float) $n, 2, ',', '.');
@endphp

@section('content')
    <h1 style="margin:0 0 6px;font-size:22px;line-height:1.3;color:#14161c;">Merhaba {{ $instructions['business_name'] }},</h1>
    <p style="margin:0 0 18px;">Komisyon bakiyesi yüklemek için istediğiniz ödeme bilgileri aşağıdadır.</p>

    @if (!empty($instructions['bank_account_configured']))
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#faf6ec;border:1px solid #eadcb8;border-radius:12px;margin:0 0 18px;">
            <tr>
                <td style="padding:16px 18px;font-size:14px;">
                    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="font-size:14px;">
                        <tr><td style="padding:5px 0;color:#4b5160;width:38%;">Şirket unvanı</td><td style="padding:5px 0;font-weight:bold;">{{ $instructions['account_holder'] }}</td></tr>
                        @if (!empty($instructions['bank_name']))
                            <tr><td style="padding:5px 0;color:#4b5160;">Banka</td><td style="padding:5px 0;font-weight:bold;">{{ $instructions['bank_name'] }}</td></tr>
                        @endif
                        <tr><td style="padding:5px 0;color:#4b5160;">IBAN</td><td style="padding:5px 0;font-weight:bold;font-family:'Courier New',monospace;letter-spacing:.5px;">{{ $instructions['iban_formatted'] }}</td></tr>
                        <tr><td style="padding:5px 0;color:#4b5160;">TRK referans kodunuz</td><td style="padding:5px 0;font-weight:bold;font-family:'Courier New',monospace;font-size:16px;color:#7a5617;">{{ $instructions['reference_code'] }}</td></tr>
                        <tr><td style="padding:5px 0;color:#4b5160;">Transfer açıklaması</td><td style="padding:5px 0;font-weight:bold;">{{ $instructions['transfer_description'] }}</td></tr>
                        <tr><td style="padding:5px 0;color:#4b5160;">En az tutar</td><td style="padding:5px 0;font-weight:bold;">{{ $tl($instructions['min_amount'] ?? 0) }}</td></tr>
                    </table>
                </td>
            </tr>
        </table>
        @if (!empty($instructions['instructions']))
            <p style="margin:0 0 16px;white-space:pre-line;">{{ $instructions['instructions'] }}</p>
        @endif
    @else
        <p style="margin:0 0 18px;padding:14px 16px;background:#fff4e5;border:1px solid #f3d3a0;border-radius:10px;">Banka hesabı bilgileri şu anda yönetici tarafından hazırlanıyor. Hazır olduğunda İşletme Finans Merkezi'nde görünür; lütfen daha sonra tekrar deneyin.</p>
    @endif

    <p style="margin:0 0 8px;"><strong>Nasıl ilerler?</strong></p>
    <ol style="margin:0 0 18px;padding-left:20px;">
        <li style="margin-bottom:4px;">Transfer açıklamasına <strong>{{ $instructions['reference_code'] }}</strong> kodunu aynen yazın.</li>
        <li style="margin-bottom:4px;">İsterseniz İşletme Finans Merkezi'nden "Ödeme bildir" ile tutarı ve tarihi bize bildirin.</li>
        <li style="margin-bottom:4px;">Ödemeniz banka kaydımızda doğrulandığında komisyon bakiyeniz güncellenir. Dekont veya bildirim tek başına bakiye eklemez.</li>
    </ol>

    <table role="presentation" cellpadding="0" cellspacing="0" style="margin:0 auto 22px;">
        <tr>
            <td align="center" style="background:#b8862f;border-radius:10px;">
                <a href="{{ $financeUrl }}" style="display:inline-block;padding:13px 26px;font-family:Arial,Helvetica,sans-serif;font-size:15px;font-weight:bold;color:#ffffff;text-decoration:none;">İşletme Finans Merkezi'ni Aç</a>
            </td>
        </tr>
    </table>
@endsection
