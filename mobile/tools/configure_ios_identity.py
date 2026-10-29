"""Inject Google OAuth routing into the iOS build.

Inputs come from the build environment and are never committed to source.
Google Maps is not used; maps are rendered by MapLibre/OpenFreeMap.
"""

import os
import plistlib
from pathlib import Path


client_id = os.environ.get("GOOGLE_IOS_CLIENT_ID", "").strip()
suffix = ".apps.googleusercontent.com"

if not client_id.endswith(suffix) or len(client_id) <= len(suffix):
    raise SystemExit("GOOGLE_IOS_CLIENT_ID must be the iOS OAuth client ID")

plist_path = Path("ios/Runner/Info.plist")
with plist_path.open("rb") as source:
    plist = plistlib.load(source)

reversed_client_id = "com.googleusercontent.apps." + client_id[: -len(suffix)]
existing = plist.get("CFBundleURLTypes", [])
other_types = [
    entry for entry in existing
    if reversed_client_id not in entry.get("CFBundleURLSchemes", [])
]
plist["CFBundleURLTypes"] = other_types + [
    {"CFBundleTypeRole": "Editor", "CFBundleURLSchemes": [reversed_client_id]}
]
plist["GIDClientID"] = client_id

with plist_path.open("wb") as destination:
    plistlib.dump(plist, destination)

print("iOS Google OAuth URL scheme configured for this build")
