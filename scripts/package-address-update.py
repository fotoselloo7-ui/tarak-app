"""Build the manual web/backend update without credentials, databases or seeds."""
from pathlib import Path
from hashlib import sha256
from zipfile import ZipFile, ZIP_DEFLATED
import json
import subprocess

ROOT = Path(__file__).resolve().parent.parent
BACKEND = '''
app/Http/Controllers/Api/ConversationController.php
app/Http/Controllers/Api/CustomerProfileController.php
app/Http/Controllers/Api/CustomerServiceRequestController.php
app/Http/Controllers/Api/FavoriteController.php
app/Http/Controllers/Api/PublicProviderController.php
app/Http/Controllers/Api/SocialAuthController.php
app/Http/Controllers/CustomerAppointmentController.php
app/Models/User.php
app/Models/UserNotification.php
app/Services/ConversationService.php
app/Services/SocialIdentityVerifier.php
app/Services/SavedCustomerLocation.php
app/Services/InstantOpportunityNotifier.php
app/Services/InstantMatchingService.php
app/Services/NotificationService.php
app/Services/FcmPushService.php
app/Services/ListingAdService.php
app/Services/GoogleGeocodingService.php
app/Support/Geo.php
app/Jobs/SendPushNotification.php
app/Events/NotificationCreated.php
bootstrap/app.php
config/services.php
routes/api.php
app/Http/Controllers/Api/AuthController.php
app/Http/Requests/RegisterRequest.php
app/Http/Controllers/Api/RegistrationVerificationController.php
app/Services/RegistrationVerificationService.php
app/Support/MediaUrl.php
app/Http/Controllers/Api/PublicMediaController.php
app/Http/Controllers/Api/ProfileMediaController.php
app/Http/Resources/UserResource.php
app/Http/Resources/ProviderProfileResource.php
app/Http/Resources/CustomerProfileResource.php
'''.split()

files = {f'backend/{name}': ROOT / 'tarak-backend' / name for name in BACKEND}
files['web/index.html'] = ROOT / 'tarak.app/index.html'
for path in (ROOT / 'tarak.app/assets').glob('*.js'):
    if 'sync-conflict' not in path.name:
        files[f'web/assets/{path.name}'] = path
files['ADDRESS_MATCHING_UPDATE_2026-10-30.md'] = ROOT / 'ADDRESS_MATCHING_UPDATE_2026-10-30.md'

for name in BACKEND:
    result = subprocess.run(['php', '-l', str(ROOT / 'tarak-backend' / name)], capture_output=True)
    if result.returncode:
        raise SystemExit(result.stdout.decode(errors='replace') + result.stderr.decode(errors='replace'))

manifest = [{'path': name, 'size': path.stat().st_size, 'sha256': sha256(path.read_bytes()).hexdigest()}
            for name, path in sorted(files.items())]
readme = '''# TARAK — Adres, randevu ve yeni iş fırsatı güncellemesi

Bu paket canlıya yüklenmemiştir. Ana kaynak klasöründeki güncel dosyalardan hazırlanmıştır.

1. Mevcut sunucu kodunun yedeğini alın ve yerel sunucu özelleştirmeleriniz varsa dosya farklarını inceleyin.
2. `backend/` içeriğini mevcut Laravel uygulamasının `artisan` dosyasının bulunduğu köke, aynı alt yolları koruyarak uygulayın. Önceki giriş/kayıt/avatar düzeltmeleri ve ortak servisleri de içerir.
3. Laravel kökünde `php artisan optimize:clear` ve `php artisan queue:restart` çalıştırın. Mevcut worker `push` kuyruğunu tüketmelidir; örnek worker parametresi `--queue=push,default`. Yeni worker kurmak, mevcut Firebase kimlik bilgilerini değiştirmek gerekmez; çalışır ayarlarınızı koruyun.
4. `web/` içeriğini tarak.app web köküne aynı yollarla uygulayın. Bütün JavaScript modülleri birlikte aktarılmalıdır; index.html aynı modül sürümünü kullanır. Mevcut CSS, görsel dosyaları ve diğer web dosyalarını silmeyin.
5. CDN kullanılıyorsa index.html önbelleğini temizleyin. Mobil kaynak değişiklikleri için uygulamayı yeniden derleyin; bu pakette mağaza dosyası bulunmaz.
6. Kendi test hesabınızla kayıtlı adres → hizmet → yakındaki işletme akışını, varsayılan adres değişimini ve Randevu Oluştur yönlendirmesini kontrol edin. Gerçek push teslimi için kendi hizmet veren test cihazınızla izin/token/worker durumunu doğrulayın.

Migration, seed, SQL, .env, servis hesabı anahtarı ve üretim veritabanı pakette yoktur. `migrate:fresh`, seed veya veri temizleme çalıştırmayın. Mevcut kullanıcı ve işletme verileri korunur. Uygulama sürümü 1.1.1+6 olarak kalmıştır.

Bildirim sadece aktif, mesleki onaylı, çevrimiçi, müsait, yeni müşteri kabul eden, tüm hizmetleri sunan ve seçilen adresi hizmet yarıçapında karşılayan işletmelere oluşur. Başlık: Yeni iş fırsatı. Mevcut FCM kuyruğu kullanılır. Aynı talep/işletme için tek bildirim vardır; açık adres/koordinat payload'a eklenmez.

Yerel testlerde gerçek işletmeye talep/push gönderilmedi. Sonuçlar ve bilinen eski DemoIntegrityTest hataları ek rapordadır. `manifest.json` paketteki kaynak dosyalarının SHA-256 değerlerini içerir.
'''

output = ROOT / '.tools/tarak-address-opportunity-web-backend-2026-10-30.zip'
output.parent.mkdir(exist_ok=True)
with ZipFile(output, 'w', ZIP_DEFLATED) as archive:
    for name, path in sorted(files.items()):
        archive.write(path, name)
    archive.writestr('KURULUM.md', readme.encode('utf-8'))
    archive.writestr('manifest.json', json.dumps(manifest, ensure_ascii=False, indent=2).encode('utf-8'))
with ZipFile(output) as archive:
    assert archive.testzip() is None
    for entry in manifest:
        assert sha256(archive.read(entry['path'])).hexdigest() == entry['sha256']
print(f'Validated {len(BACKEND)} PHP files and {len(files)} packaged files: {output}')
print(f'Archive SHA-256: {sha256(output.read_bytes()).hexdigest()}')
