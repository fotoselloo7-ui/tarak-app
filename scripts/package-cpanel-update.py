"""Export only deployable files, under the two existing cPanel folders.

Controller queries require ProviderProfile.scopeDiscoverable. Keep its model in
the same archive as those controllers; a partial deployment otherwise returns
HTTP 500 before it can compute any provider distances.
"""
from datetime import datetime
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile, ZipInfo
import stat

ROOT = Path(__file__).resolve().parent.parent
BACKEND = [
    'tarak-backend/app/Http/Controllers/CustomerAppointmentController.php',
    'tarak-backend/app/Http/Controllers/Api/PublicProviderController.php',
    'tarak-backend/app/Models/ProviderProfile.php',
    'tarak-backend/app/Services/ListingAdService.php',
    'tarak-backend/app/Services/SavedCustomerLocation.php',
]
WEB = ['tarak.app/index.html'] + sorted(
    path.relative_to(ROOT).as_posix()
    for path in (ROOT / 'tarak.app/assets').glob('*.js')
    if 'sync-conflict' not in path.name
)
contents = {name: (ROOT / name).read_bytes() for name in BACKEND + WEB}
model = contents['tarak-backend/app/Models/ProviderProfile.php']
if b'function scopeDiscoverable(' not in model:
    raise SystemExit('ProviderProfile.scopeDiscoverable is missing; refusing an incomplete deployment archive.')

output = ROOT / '.tools/TARAK-CPANEL-SUNUCU-HATASI-FIX-2026-10-30.zip'
output.parent.mkdir(exist_ok=True)
stamp = datetime.now().timetuple()[:6]
with ZipFile(output, 'w', ZIP_DEFLATED) as archive:
    for folder in ['tarak-backend/', 'tarak.app/']:
        info = ZipInfo(folder, stamp)
        info.create_system = 3
        info.external_attr = ((stat.S_IFDIR | 0o755) << 16) | 0x10
        archive.writestr(info, b'')
    for name, data in contents.items():
        info = ZipInfo(name, stamp)
        info.create_system = 3
        info.external_attr = (stat.S_IFREG | 0o644) << 16
        archive.writestr(info, data, compress_type=ZIP_DEFLATED)

# Archive validation only: no application test, preview, build or deployment.
with ZipFile(output) as archive:
    assert archive.testzip() is None
    assert {name.split('/')[0] for name in archive.namelist()} == {'tarak-backend', 'tarak.app'}
    assert {name for name in archive.namelist() if not name.endswith('/')} == set(contents)
    for name, data in contents.items():
        assert archive.read(name) == data, name

print(output)
print(f'{len(BACKEND)} backend files, {len(WEB)} web files; archive contents match the current sources.')
print('Includes app/Models/ProviderProfile.php with scopeDiscoverable(). No mobile, credentials or database files.')
