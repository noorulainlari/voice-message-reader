# Generates the 1024px app icon (keeps the repo text-only).
from PIL import Image, ImageDraw, ImageFilter
S = 1024
img = Image.new("RGB", (S, S))
top, bot = (16, 190, 165), (8, 82, 104)
v = Image.linear_gradient("L")
grad = Image.blend(v, v.rotate(90), 0.5).resize((S, S))
img = Image.composite(Image.new("RGB", (S, S), bot), Image.new("RGB", (S, S), top), grad)
glow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
ImageDraw.Draw(glow).ellipse((150, 120, 900, 820), fill=(255, 255, 255, 40))
glow = glow.filter(ImageFilter.GaussianBlur(80))
img.paste(glow, (0, 0), glow)
bx0, by0, bx1, by1 = 170, 220, 854, 720
shadow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
sd = ImageDraw.Draw(shadow)
sd.rounded_rectangle((bx0, by0 + 24, bx1, by1 + 24), radius=150, fill=(0, 40, 50, 90))
sd.polygon([(300, by1 + 10), (270, 860), (440, by1 + 10)], fill=(0, 40, 50, 90))
shadow = shadow.filter(ImageFilter.GaussianBlur(24))
img.paste(shadow, (0, 0), shadow)
d = ImageDraw.Draw(img, "RGBA")
d.rounded_rectangle((bx0, by0, bx1, by1), radius=150, fill=(255, 255, 255, 255))
d.polygon([(290, by1 - 30), (250, 840), (450, by1 - 30)], fill=(255, 255, 255, 255))
teal, deep = (13, 150, 140), (8, 82, 104)
cy = (by0 + by1) // 2
x = 245
for h in [90, 170, 250, 140, 210, 110]:
    d.rounded_rectangle((x, cy - h // 2, x + 34, cy + h // 2), radius=17, fill=teal)
    x += 52
ax = x + 6
d.polygon([(ax, cy - 40), (ax + 46, cy), (ax, cy + 40)], fill=deep)
lx = ax + 80
for i, w in enumerate([150, 120, 150, 90]):
    y = cy - 105 + i * 70
    d.rounded_rectangle((lx, y, lx + w, y + 30), radius=15, fill=deep)
img.save("App/Assets.xcassets/AppIcon.appiconset/icon.png")
print("icon ok")
