# Oyun hediyeleri → Tarak Mobil entegrasyonu

Oyunda (Randevuya Koş) oyuncular zor yerlerdeki **hediye parçalarını** toplar.
Bu yıl yeterli parça (varsayılan 20, adminden değişir) toplayan oyuncu **yılda bir kez**
`TRK-XXXX-XXXX` biçiminde bir hediye kodu alır:

- Koko (berber) ile oynayanlar: **Sakal Tıraşı** (admin: "Erkek hediyesi")
- Kiki (kadın kuaför) ile oynayanlar: **Manikür** (admin: "Kadın hediyesi")
- 20 Aralık – 15 Ocak arasında verilen kodların adı "Yılbaşı Hediyesi: …" diye başlar.

Parçalar oyun sunucusunda sayılır: yalnızca şüpheli işaretlenmemiş, en az 20 sn süren
koşulardan ve koşu başına en fazla 3 parça.

## Tarak Mobil tarafında yapılacaklar

1. Randevu/ödeme ekranına "Hediye kodu" alanı ekleyin.
2. Kod girildiğinde oyun sunucusuna **sunucudan sunucuya** sorun (anahtar uygulamaya gömülmez):

```
GET  https://<oyun-adresi>/api/index.php?islem=hediyeDogrula&kod=TRK-XXXX-XXXX
     Başlık: X-Tarak-Anahtar: <admin › Hediyeler › Entegrasyon anahtarı>
→ 200 { "gecerli": true, "hediye": { "kod", "tur": "berber"|"kuafor", "ad", "yil", "durum": "verildi", ... } }
→ 404 kod yok · 401 anahtar yanlış
```

3. Randevu tamamlandığında kodu kullanıldı olarak işaretleyin:

```
POST https://<oyun-adresi>/api/index.php?islem=hediyeKullan&kod=TRK-XXXX-XXXX&not=randevu-123
     Başlık: X-Tarak-Anahtar: <anahtar>
→ 200 { "gecerli": true, "hediye": { "durum": "kullanildi", ... } }
→ 409 kod daha önce kullanılmış ya da iptal edilmiş
```

4. Önerilen kurallar (Tarak hesabı tarafında):
   - Bir Tarak hesabı yılda en fazla bir oyun hediyesi kullanabilsin (oyun tarafı cihaz başına sınırlar).
   - `tur = berber` kodu yalnızca erkek bakım, `tur = kuafor` kodu yalnızca kadın kuaför hizmetlerinde geçerli olsun.
   - **Doğum günü hediyesi**: doğum tarihi yalnızca Tarak hesabında bulunduğu için doğum günü kuralı
     (ör. doğum gününde Saç + Sakal) Tarak Mobil tarafında uygulanmalı; oyun kişisel tarih toplamaz.

Admin panelinde (Hediyeler) kodlar listelenir, elle "Kullanıldı / İptal" yapılabilir,
gerekli parça sayısı ve hediye adları değiştirilebilir, hediye verme kapatılabilir.
