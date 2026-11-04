"""Draws Lockout's 1024x1024 app icon (no transparency, as Apple requires):
a white padlock whose body is a clock face, on a deep red gradient.
Run: python scripts/make-icon.py"""
import math, os, sys
from PIL import Image, ImageDraw

S = 4096  # draw big, shrink at the end for smooth edges
img = Image.new("RGB", (S, S))
top, bottom = (196, 38, 46), (92, 10, 22)
d = ImageDraw.Draw(img)
for y in range(S):
    t = y / (S - 1)
    d.line([(0, y), (S, y)], fill=tuple(round(a + (b - a) * t) for a, b in zip(top, bottom)))

white = (255, 255, 255)
cx = S / 2
# Shackle: a thick arch above the body.
sw, r = 330, 760
arch_top = 820
d.arc([cx - r, arch_top, cx + r, arch_top + 2 * r], 180, 360, fill=white, width=sw)
leg_bottom = 2050
for x in (cx - r, cx + r - sw):
    d.rectangle([x, arch_top + r - 60, x + sw, leg_bottom], fill=white)
# Body.
bw, bh, top_y = 2500, 1900, 1700
d.rounded_rectangle([cx - bw / 2, top_y, cx + bw / 2, top_y + bh], radius=330, fill=white)
# Clock face cut into the body.
ccx, ccy, cr = cx, top_y + bh / 2, 640
red = (150, 22, 32)
d.ellipse([ccx - cr, ccy - cr, ccx + cr, ccy + cr], fill=red)
hand = 150
def line(angle_deg, length):
    a = math.radians(angle_deg - 90)
    ex, ey = ccx + length * math.cos(a), ccy + length * math.sin(a)
    d.line([(ccx, ccy), (ex, ey)], fill=white, width=hand)
    d.ellipse([ex - hand / 2, ey - hand / 2, ex + hand / 2, ey + hand / 2], fill=white)
line(0, 470)    # minute hand at 12
line(120, 330)  # hour hand at 4
d.ellipse([ccx - hand, ccy - hand, ccx + hand, ccy + hand], fill=white)

out = sys.argv[1] if len(sys.argv) > 1 else "App/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
img.resize((1024, 1024), Image.LANCZOS).save(out)
print("wrote", out)
