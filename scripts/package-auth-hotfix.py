"""Package the two stale production auth files identified from live logs/hashes.

Extract the archive inside the existing tarak-backend directory. No database,
environment, OAuth, verifier or unrelated feature files are included.
"""
from datetime import datetime
import hashlib
from pathlib import Path
import stat
from zipfile import ZIP_DEFLATED, ZipFile, ZipInfo

ROOT = Path(__file__).resolve().parent.parent
BACKEND = ROOT / "tarak-backend"
FILES = {
    "app/Http/Requests/RegisterRequest.php": [
        b"function isLegacyNativeClient(",
        b"$this->headers->has('X-Tarak-Client')",
    ],
    "app/Http/Controllers/Api/RegistrationVerificationController.php": [
        b"function config(",
        b"$this->verification->isSmsVerificationEnabled()",
    ],
}
contents = {name: (BACKEND / name).read_bytes() for name in FILES}
for name, markers in FILES.items():
    if not all(marker in contents[name] for marker in markers):
        raise SystemExit(f"Auth contract missing from {name}; refusing an incomplete hotfix.")

# Both public callers must be compatible with the files being shipped.
assert b"$request->isLegacyNativeClient()" in (BACKEND / "app/Http/Controllers/Api/AuthController.php").read_bytes()
assert b"'config'" in (BACKEND / "routes/api.php").read_bytes()
assert b"function isSmsVerificationEnabled(" in (BACKEND / "app/Services/RegistrationVerificationService.php").read_bytes()

output = ROOT / ".tools/TARAK-CPANEL-FINAL-AUTH-FIX-2026-11-04.zip"
output.parent.mkdir(exist_ok=True)
stamp = datetime.now().timetuple()[:6]
with ZipFile(output, "w", ZIP_DEFLATED) as archive:
    for name, data in contents.items():
        info = ZipInfo(name, stamp)
        info.create_system = 3
        info.external_attr = (stat.S_IFREG | 0o644) << 16
        archive.writestr(info, data, compress_type=ZIP_DEFLATED)

with ZipFile(output) as archive:
    assert archive.testzip() is None
    assert set(archive.namelist()) == set(FILES)
    for name, data in contents.items():
        assert archive.read(name) == data
        print(hashlib.sha256(data).hexdigest(), name)
print(output)
print("2 backend files; verified byte-for-byte. No migration or cache/config changes required.")
