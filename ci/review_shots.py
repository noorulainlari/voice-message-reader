# Uploads an App Review screenshot for each subscription that doesn't have one yet.
import jwt, time, os, json, hashlib, urllib.request
from PIL import Image, ImageDraw, ImageFont

kid = os.environ["ASC_KEY_ID"]; iss = os.environ["ASC_ISSUER_ID"]
key = open(os.path.expanduser(f"~/private_keys/AuthKey_{kid}.p8")).read()
tok = jwt.encode({"iss": iss, "iat": int(time.time()), "exp": int(time.time()) + 900, "aud": "appstoreconnect-v1"},
                 key, algorithm="ES256", headers={"kid": kid, "typ": "JWT"})
API = "https://api.appstoreconnect.apple.com/v1/"

def call(path, method="GET", body=None, url=None, headers=None, raw=None):
    h = {"Authorization": "Bearer " + tok, "Content-Type": "application/json"} if url is None else (headers or {})
    data = raw if raw is not None else (json.dumps(body).encode() if body is not None else None)
    req = urllib.request.Request(url or API + path, data=data, headers=h, method=method)
    with urllib.request.urlopen(req) as r:
        b = r.read()
        return json.loads(b) if b and url is None else {}

def font(size):
    for p in ["/System/Library/Fonts/SFNS.ttf", "/System/Library/Fonts/Helvetica.ttc", "/Library/Fonts/Arial.ttf"]:
        try: return ImageFont.truetype(p, size)
        except Exception: pass
    return ImageFont.load_default()

def make_image(path):
    W, H = 1290, 2796
    img = Image.new("RGB", (W, H), (242, 242, 247))
    d = ImageDraw.Draw(img)
    for y in range(900):
        t = y / 900
        d.line([(0, y), (W, y)], fill=(int(13 + (10 - 13) * t), int(166 + (92 - 166) * t), int(148 + (107 - 148) * t)))
    d.text((W / 2, 520), "Voice Reader Pro", font=font(96), fill="white", anchor="mm")
    d.text((W / 2, 650), "Read every voice message in seconds", font=font(48), fill="white", anchor="mm")
    feats = ["Unlimited transcriptions", "AI summary & smart replies", "Translate to any language",
             "Live transcription", "Export PDF, TXT & subtitles"]
    y = 1000
    for f in feats:
        d.ellipse((120, y - 22, 164, y + 22), fill=(13, 166, 148))
        d.text((200, y), f, font=font(50), fill=(20, 20, 20), anchor="lm")
        y += 110
    plans = [("Yearly", "$29.99/year", "3-day free trial"), ("Monthly", "$5.99/month", "Cancel anytime"), ("Weekly", "$2.99/week", "Cancel anytime")]
    y = 1650
    for i, (n, p, s) in enumerate(plans):
        d.rounded_rectangle((90, y, W - 90, y + 200), radius=40, fill="white",
                            outline=(13, 166, 148) if i == 0 else (220, 220, 225), width=8 if i == 0 else 3)
        d.text((150, y + 70), n, font=font(56), fill=(20, 20, 20), anchor="lm")
        d.text((150, y + 140), s, font=font(40), fill=(13, 140, 125), anchor="lm")
        d.text((W - 150, y + 100), p, font=font(54), fill=(20, 20, 20), anchor="rm")
        y += 240
    d.rounded_rectangle((90, 2420, W - 90, 2580), radius=50, fill=(13, 140, 125))
    d.text((W / 2, 2500), "Start Free Trial", font=font(60), fill="white", anchor="mm")
    img.save(path)

subs = call("apps/6818769380/subscriptionGroups?include=subscriptions&limit=10")
ids = [x["id"] for x in subs.get("included", []) if x["type"] == "subscriptions"]
shot = "/tmp/review.png"
make_image(shot)
blob = open(shot, "rb").read()
for sid in ids:
    try:
        existing = call(f"subscriptions/{sid}/appStoreReviewScreenshot")
        if existing.get("data"):
            print("screenshot exists for", sid); continue
    except Exception:
        pass
    res = call("subscriptionAppStoreReviewScreenshots", "POST", {"data": {"type": "subscriptionAppStoreReviewScreenshots",
          "attributes": {"fileName": "paywall.png", "fileSize": len(blob)},
          "relationships": {"subscription": {"data": {"type": "subscriptions", "id": sid}}}}})
    rid = res["data"]["id"]
    for op in res["data"]["attributes"]["uploadOperations"]:
        hdrs = {h["name"]: h["value"] for h in op.get("requestHeaders", [])}
        part = blob[op["offset"]: op["offset"] + op["length"]]
        call(None, op["method"], url=op["url"], headers=hdrs, raw=part)
    call(f"subscriptionAppStoreReviewScreenshots/{rid}", "PATCH", {"data": {"type": "subscriptionAppStoreReviewScreenshots", "id": rid,
          "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(blob).hexdigest()}}})
    print("uploaded review screenshot for", sid)
