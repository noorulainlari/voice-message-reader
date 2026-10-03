# Renders premium App Store screenshots (1242x2688) from HTML with Playwright.
import os, sys
from playwright.sync_api import sync_playwright

OUT = sys.argv[1] if len(sys.argv) > 1 else "store_shots"
os.makedirs(OUT, exist_ok=True)
W, H = 1242, 2688

CSS = """
*{margin:0;padding:0;box-sizing:border-box}
body{width:1242px;height:2688px;overflow:hidden;font-family:'Inter','Inter Display',sans-serif;color:#fff;
 background:radial-gradient(1200px 900px at 15% 8%,#2fd3bd 0%,rgba(47,211,189,0) 60%),
            radial-gradient(1000px 1000px at 100% 60%,#0b6e7a 0%,rgba(11,110,122,0) 65%),
            linear-gradient(160deg,#0fb39f 0%,#0a7f86 45%,#06414f 100%);position:relative}
.glow{position:absolute;border-radius:50%;filter:blur(80px);opacity:.45}
.head{position:absolute;top:150px;left:0;right:0;text-align:center;padding:0 70px}
.kicker{display:inline-block;font-weight:700;font-size:38px;letter-spacing:4px;text-transform:uppercase;
 background:rgba(255,255,255,.16);border:2px solid rgba(255,255,255,.28);padding:14px 34px;border-radius:60px;margin-bottom:38px}
h1{font-family:'Inter Display','Inter',sans-serif;font-weight:900;font-size:118px;line-height:1.04;letter-spacing:-2px;
 text-shadow:0 8px 30px rgba(0,0,0,.18)}
h1 em{font-style:normal;color:#ffe27a}
.sub{margin-top:34px;font-size:48px;font-weight:500;opacity:.92;line-height:1.3}
.phone{position:absolute;left:50%;transform:translateX(-50%);top:930px;width:900px;height:1900px;border-radius:120px;
 background:#0d0f12;padding:26px;box-shadow:0 60px 120px rgba(0,0,0,.45),0 0 0 6px rgba(255,255,255,.08) inset}
.screen{width:100%;height:100%;border-radius:96px;overflow:hidden;background:#f2f3f7;position:relative;color:#111}
.island{position:absolute;top:30px;left:50%;transform:translateX(-50%);width:250px;height:72px;background:#000;border-radius:40px;z-index:9}
.status{height:130px;display:flex;justify-content:space-between;align-items:flex-end;padding:0 70px 18px;font-weight:700;font-size:34px}
.nav{display:flex;justify-content:space-between;align-items:center;padding:20px 50px 26px;font-size:36px;font-weight:600}
.teal{color:#0b9e8c}
.card{background:#fff;border-radius:42px;padding:40px;margin:0 36px 30px;box-shadow:0 6px 24px rgba(0,0,0,.06)}
.grad{background:linear-gradient(135deg,#12b5a0,#0a6b78);color:#fff}
.btn{border-radius:36px;padding:34px;text-align:center;font-weight:700;font-size:38px}
.pill{display:inline-flex;align-items:center;gap:12px;background:#e7f6f3;color:#0b8a7a;border-radius:40px;padding:14px 26px;font-size:30px;font-weight:600}
.row{display:flex;gap:22px;margin:0 36px 30px}
.act{flex:1;background:#fff;border-radius:34px;padding:30px 10px;text-align:center;font-size:28px;font-weight:600;color:#333;box-shadow:0 6px 20px rgba(0,0,0,.05)}
.act i{display:block;font-style:normal;font-size:46px;margin-bottom:10px;color:#0b9e8c}
.badge{position:absolute;background:#fff;color:#0a5c64;border-radius:40px;padding:26px 36px;font-weight:800;font-size:38px;
 box-shadow:0 24px 60px rgba(0,0,0,.28);display:flex;align-items:center;gap:16px;z-index:20}
.badge b{display:inline-flex;width:62px;height:62px;border-radius:20px;align-items:center;justify-content:center;
 background:linear-gradient(135deg,#12b5a0,#0a6b78);color:#fff;font-size:34px}
.wave{display:flex;align-items:center;gap:8px;height:80px}
.wave span{width:10px;border-radius:6px;background:#0b9e8c}
.t{font-size:40px;line-height:1.45;color:#1b1b1f}
.muted{color:#8a8f98}
"""

def wave(n=34, color="#0b9e8c", h=80):
    import math
    bars = "".join(f'<span style="height:{int(18 + (h-18) * abs(math.sin(i*0.55)*math.cos(i*0.23)))}px;background:{color}"></span>' for i in range(n))
    return f'<div class="wave" style="height:{h}px">{bars}</div>'

def page(kicker, title, sub, screen, extras=""):
    return f"""<!doctype html><html><head><meta charset="utf-8"><style>{CSS}</style></head><body>
<div class="glow" style="width:600px;height:600px;background:#5ef2d9;left:-180px;top:1500px"></div>
<div class="glow" style="width:520px;height:520px;background:#ffe27a;right:-220px;top:700px;opacity:.18"></div>
<div class="head"><div class="kicker">{kicker}</div><h1>{title}</h1><div class="sub">{sub}</div></div>
<div class="phone"><div class="screen"><div class="island"></div>
<div class="status"><span>9:41</span><span>&#9679;&#9679;&#9679; 100%</span></div>{screen}</div></div>{extras}</body></html>"""

player = f"""<div class="card"><div style="display:flex;align-items:center;gap:26px">
<div style="width:96px;height:96px;border-radius:50%;background:#0b9e8c;color:#fff;display:flex;align-items:center;justify-content:center;font-size:40px">&#9654;</div>
<div style="flex:1">{wave(30)}</div><div class="pill">1.5x</div></div></div>"""

S1 = page("Voice Message Reader", "Read Voice Notes<br><em>Instead of Listening</em>",
          "Turn any voice message into text in seconds",
          f"""<div class="nav"><span class="teal">Done</span><span>Voice Reader</span><span class="teal">English</span></div>
{player}
<div class="card"><div class="t">Hey! I'm running about 10 minutes late. Can you order me a cappuccino and grab the table by the window? Also bring the contract, we need to sign it today. See you soon!</div>
<div style="margin-top:26px" class="muted">0:34 &middot; 41 words</div></div>
<div class="row"><div class="act"><i>&#10697;</i>Copy</div><div class="act"><i>&#10022;</i>Summary</div><div class="act"><i>&#127760;</i>Translate</div><div class="act"><i>&#8679;</i>Share</div></div>
<div style="margin:10px 36px"><div class="btn grad">Open in Voice Reader</div></div>""",
          '<div class="badge" style="right:30px;top:2330px"><b>&#10003;</b>Done in 2 sec</div>')

S2 = page("Works with your chats", "Works With<br><em>WhatsApp &amp; Telegram</em>",
          "Tap Share, then Transcribe. That's it.",
          f"""<div style="padding:30px 46px 10px;display:flex;align-items:center;gap:22px">
<div style="width:90px;height:90px;border-radius:22px;background:#3b82f6;color:#fff;display:flex;align-items:center;justify-content:center;font-size:40px">&#9835;</div>
<div><div style="font-size:36px;font-weight:700">Voice message.opus</div><div class="muted" style="font-size:28px">Audio &middot; 0:34</div></div></div>
<div style="display:flex;justify-content:space-around;padding:40px 30px">
{''.join(f'<div style="text-align:center;font-size:26px"><div style="width:120px;height:120px;border-radius:30px;background:{c};margin:0 auto 12px"></div>{n}</div>' for n,c in [("AirDrop","#4aa3ff"),("Messages","#34c759"),("Mail","#2f7cf6")])}
<div style="text-align:center;font-size:26px;font-weight:700"><div style="width:120px;height:120px;border-radius:30px;background:linear-gradient(135deg,#12b5a0,#0a6b78);margin:0 auto 12px;box-shadow:0 0 0 8px #bff0e7;color:#fff;display:flex;align-items:center;justify-content:center;font-size:56px">&#10077;</div>Voice Reader</div></div>
<div class="card" style="padding:0;overflow:hidden">
{''.join(f'<div style="display:flex;justify-content:space-between;padding:40px;font-size:38px;border-bottom:2px solid #eee">{t}<span class="muted">&#8250;</span></div>' for t in ["Copy","New Quick Note","Save to Files"])}
<div style="display:flex;justify-content:space-between;padding:40px;font-size:40px;font-weight:800;background:#dff5f1;color:#0a7f72">Transcribe<span>&#10077;</span></div></div>""",
          '<div class="badge" style="right:50px;top:2230px"><b>1</b>One tap</div>')

S3 = page("AI powered", "AI Summary<br><em>Get the Point Fast</em>",
          "Long voice notes, summed up in one tap",
          f"""<div class="nav"><span class="teal">&#8249; Back</span><span>Transcript</span><span class="teal">&#9734;</span></div>
<div class="card"><div style="font-size:44px;font-weight:800;margin-bottom:16px">Team meeting update</div>
<div class="t" style="font-size:36px;color:#555">So about tomorrow's meeting, we moved it to 3 pm because the client asked for more time. Sarah will present the new design and I need everyone to review the budget sheet before...</div></div>
<div class="card" style="border:4px solid #12b5a0">
<div style="font-size:38px;font-weight:800;color:#0b9e8c;margin-bottom:24px">&#10022; Summary</div>
{''.join(f'<div class="t" style="margin-bottom:16px">&bull; {b}</div>' for b in ["Meeting moved to <b>3 pm tomorrow</b>","Sarah presents the new design","Review the budget sheet first"])}
</div>
<div class="card"><div style="font-size:36px;font-weight:800;color:#0b9e8c;margin-bottom:20px">Smart replies</div>
<div class="pill" style="margin:0 10px 14px 0">Got it, see you at 3!</div><div class="pill">I'll review it tonight</div></div>""",
          '<div class="badge" style="right:30px;top:2450px"><b>&#10022;</b>Smart replies</div>')

S4 = page("50+ languages", "Translate Into<br><em>Any Language</em>",
          "Understand voice notes from anyone",
          f"""<div class="nav"><span class="teal">&#8249; Back</span><span>Translate</span><span></span></div>
<div class="card"><div class="pill" style="margin-bottom:22px">Spanish</div>
<div class="t">Hola, ya llegué al aeropuerto. ¿Puedes recogerme en la puerta 3 en veinte minutos?</div></div>
<div style="text-align:center;font-size:70px;color:#0b9e8c;margin:-6px 0 20px">&#8595;</div>
<div class="card" style="border:4px solid #12b5a0"><div class="pill" style="margin-bottom:22px">English</div>
<div class="t" style="font-weight:600">Hi, I just arrived at the airport. Can you pick me up at gate 3 in twenty minutes?</div></div>
<div style="display:flex;flex-wrap:wrap;gap:16px;margin:10px 36px">
{''.join(f'<div class="pill" style="background:#fff;color:#333;box-shadow:0 4px 14px rgba(0,0,0,.06)">{l}</div>' for l in ["Arabic","Hindi","Urdu","French","German","Portuguese","Turkish","Russian"])}</div>""",
          '<div class="badge" style="right:30px;top:2380px"><b>&#127760;</b>50+ languages</div>')

S5 = page("Live transcription", "Speak and<br><em>See the Text</em>",
          "Record meetings, notes and ideas live",
          f"""<div class="nav"><span class="teal">Close</span><span>Live Transcribe</span><span></span></div>
<div class="card" style="min-height:760px"><div class="t" style="font-size:44px">Today's ideas: launch the new menu on Friday, call the supplier about delivery times, and post the offer on Instagram<span class="teal">|</span></div></div>
<div style="text-align:center;font-size:84px;font-weight:800;margin:10px 0 30px">01:24</div>
<div style="display:flex;justify-content:center;margin-bottom:30px">{wave(40, "#12b5a0", 120)}</div>
<div style="display:flex;justify-content:center"><div style="width:260px;height:260px;border-radius:50%;background:rgba(18,181,160,.18);display:flex;align-items:center;justify-content:center">
<div style="width:190px;height:190px;border-radius:50%;background:#ff3b30;display:flex;align-items:center;justify-content:center"><div style="width:64px;height:64px;border-radius:12px;background:#fff"></div></div></div></div>""",
          '<div class="badge" style="left:30px;top:2100px"><b>&#9679;</b>Real-time</div>')

S6 = page("Private &amp; unlimited", "Everything Saved.<br><em>100% Private</em>",
          "Search, folders, export PDF & Face ID lock",
          f"""<div style="padding:10px 50px 26px;font-size:64px;font-weight:900">History</div>
<div style="margin:0 36px 26px;background:#e6e7ec;border-radius:28px;padding:24px 30px;font-size:34px" class="muted">&#9906; Search in transcriptions</div>
<div style="display:flex;gap:16px;margin:0 36px 30px">{''.join(f'<div class="pill" style="{s}">{t}</div>' for t,s in [("All","background:linear-gradient(135deg,#12b5a0,#0a6b78);color:#fff"),("Favorites",""),("Work",""),("Family","")])}</div>
{''.join(f'<div class="card" style="padding:34px 40px"><div style="display:flex;justify-content:space-between;font-size:38px;font-weight:800"><span>{a}</span><span style="color:#f5b700">{s}</span></div><div class="muted" style="font-size:31px;margin-top:10px">{b}</div><div class="muted" style="font-size:26px;margin-top:12px">{c}</div></div>' for a,b,c,s in [("Dinner plans tonight","Let's meet at 8 at the Italian place near...","0:21 &middot; English &middot; 2 min ago","&#9733;"),("Client call notes","The client approved the design and wants...","1:47 &middot; English &middot; 1 h ago",""),("Mom's voice note","Don't forget to buy milk and call your...","0:15 &middot; Urdu &middot; Yesterday","&#9733;"),("Flight details","Gate changed to B12, boarding at 6:40...","0:28 &middot; English &middot; Mon","")])}""",
          '<div class="badge" style="right:36px;top:1180px"><b>&#128274;</b>Face ID lock</div><div class="badge" style="left:36px;top:2380px"><b>&#8681;</b>Export PDF</div>')

PAGES = [S1, S2, S3, S4, S5, S6]

with sync_playwright() as p:
    b = p.chromium.launch()
    pg = b.new_page(viewport={"width": W, "height": H}, device_scale_factor=1)
    for i, html in enumerate(PAGES, 1):
        pg.set_content(html)
        pg.wait_for_timeout(300)
        pg.screenshot(path=f"{OUT}/iphone_{i}.png")
        print("rendered", i)
    b.close()
