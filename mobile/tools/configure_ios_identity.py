"""Inject public OAuth routing and restricted Maps SDK key during a local/CI build.

Inputs come from the build environment and are never committed to source.
"""

import os
import plistlib
from pathlib import Path


client_id = os.environ.get("GOOGLE_IOS_CLIENT_ID", "").strip()
maps_key = os.environ.get("GOOGLE_MAPS_IOS_API_KEY", "").strip()
suffix = ".apps.googleusercontent.com"

if not client_id.endswith(suffix) or len(client_id) <= len(suffix):
    raise SystemExit("GOOGLE_IOS_CLIENT_ID must be the iOS OAuth client ID")
if not maps_key:
    raise SystemExit("GOOGLE_MAPS_IOS_API_KEY is required")

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
plist["GoogleMapsApiKey"] = maps_key

with plist_path.open("wb") as destination:
    plistlib.dump(plist, destination)

print("iOS Google OAuth URL scheme and Maps key configured for this build")
