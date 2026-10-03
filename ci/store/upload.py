# Uploads App Store listing text + iPhone screenshots for the current editable version.
import jwt, time, os, json, hashlib, glob, sys, urllib.request, urllib.error

APP_ID = "6818769380"
kid = os.environ["ASC_KEY_ID"]; iss = os.environ["ASC_ISSUER_ID"]
key = open(os.path.expanduser(f"~/private_keys/AuthKey_{kid}.p8")).read()
tok = jwt.encode({"iss": iss, "iat": int(time.time()), "exp": int(time.time()) + 1100, "aud": "appstoreconnect-v1"},
                 key, algorithm="ES256", headers={"kid": kid, "typ": "JWT"})
API = "https://api.appstoreconnect.apple.com/v1/"

def call(path, method="GET", body=None, url=None, headers=None, raw=None):
    h = {"Authorization": "Bearer " + tok, "Content-Type": "application/json"} if url is None else (headers or {})
    data = raw if raw is not None else (json.dumps(body).encode() if body is not None else None)
    req = urllib.request.Request(url or API + path, data=data, headers=h, method=method)
    try:
        with urllib.request.urlopen(req) as r:
            b = r.read()
            return json.loads(b) if b and url is None else {}
    except urllib.error.HTTPError as e:
        print("HTTP", e.code, method, path, e.read().decode()[:500])
        raise

meta = json.load(open(os.path.join(os.path.dirname(__file__), "metadata.json")))
shots_dir = sys.argv[1] if len(sys.argv) > 1 else "store_shots"

vers = call(f"apps/{APP_ID}/appStoreVersions?filter[platform]=IOS&limit=5")["data"]
ver = next(v for v in vers if v["attributes"]["appStoreState"] in
           ("PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED"))
vid = ver["id"]
call(f"appStoreVersions/{vid}", "PATCH", {"data": {"type": "appStoreVersions", "id": vid,
     "attributes": {"copyright": meta["copyright"]}}})
print("version", ver["attributes"]["versionString"], vid)

locs = call(f"appStoreVersions/{vid}/appStoreVersionLocalizations")["data"]
loc = next(l for l in locs if l["attributes"]["locale"] == "en-US")
call(f"appStoreVersionLocalizations/{loc['id']}", "PATCH", {"data": {"type": "appStoreVersionLocalizations", "id": loc["id"],
     "attributes": {"description": meta["description"], "keywords": meta["keywords"],
                    "promotionalText": meta["promotionalText"], "supportUrl": meta["supportUrl"],
                    "marketingUrl": meta["marketingUrl"]}}})
print("version localization updated")

infos = call(f"apps/{APP_ID}/appInfos")["data"]
info = infos[0]
ilocs = call(f"appInfos/{info['id']}/appInfoLocalizations")["data"]
iloc = next(l for l in ilocs if l["attributes"]["locale"] == "en-US")
call(f"appInfoLocalizations/{iloc['id']}", "PATCH", {"data": {"type": "appInfoLocalizations", "id": iloc["id"],
     "attributes": {"name": meta["name"], "subtitle": meta["subtitle"], "privacyPolicyUrl": meta["privacyUrl"]}}})
print("app info updated")
try:
    call(f"appInfos/{info['id']}", "PATCH", {"data": {"type": "appInfos", "id": info["id"], "relationships": {
         "primaryCategory": {"data": {"type": "appCategories", "id": "UTILITIES"}},
         "secondaryCategory": {"data": {"type": "appCategories", "id": "PRODUCTIVITY"}}}}})
    print("categories set")
except Exception as e:
    print("category error", e)

sets = call(f"appStoreVersionLocalizations/{loc['id']}/appScreenshotSets")["data"]
sset = next((s for s in sets if s["attributes"]["screenshotDisplayType"] == "APP_IPHONE_65"), None)
if sset is None:
    sset = call("appScreenshotSets", "POST", {"data": {"type": "appScreenshotSets",
           "attributes": {"screenshotDisplayType": "APP_IPHONE_65"},
           "relationships": {"appStoreVersionLocalization": {"data": {"type": "appStoreVersionLocalizations", "id": loc["id"]}}}}})["data"]
for old in call(f"appScreenshotSets/{sset['id']}/appScreenshots")["data"]:
    call(f"appScreenshots/{old['id']}", "DELETE")
for path in sorted(glob.glob(os.path.join(shots_dir, "iphone_*.png"))):
    blob = open(path, "rb").read()
    res = call("appScreenshots", "POST", {"data": {"type": "appScreenshots",
          "attributes": {"fileName": os.path.basename(path), "fileSize": len(blob)},
          "relationships": {"appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": sset["id"]}}}}})["data"]
    for op in res["attributes"]["uploadOperations"]:
        hdrs = {h["name"]: h["value"] for h in op.get("requestHeaders", [])}
        call(None, op["method"], url=op["url"], headers=hdrs, raw=blob[op["offset"]: op["offset"] + op["length"]])
    call(f"appScreenshots/{res['id']}", "PATCH", {"data": {"type": "appScreenshots", "id": res["id"],
         "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(blob).hexdigest()}}})
    print("uploaded", os.path.basename(path))
print("done")
